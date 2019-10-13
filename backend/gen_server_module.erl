%%%-------------------------------------------------------------------
%%% @author aviran and amit
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%% Eralng final project
%%% @end
%%% Created : 23. Jun 2017 10:11
%%%-------------------------------------------------------------------
-module(gen_server_module).
-author("AviranAmit").
-behaviour(gen_server).

-export([start/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-export([updateStateForNewServer/7,
         add_to_state_nested/4,
         add_uuid_to_state/3]).

-record(state, {}).
-define(SERVER, ?MODULE).

-spec(start(T :: term()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start({master,MasterNode,_,Ip,Port,_,DnsName,DnsNode}) ->
    io:fwrite("Master start function ~n"),
    gen_server:start_link({local, master_node}, ?MODULE, [{master,MasterNode,"",Ip,Port,"",DnsName,DnsNode}], []);
start({worker,MasterNode,NodeName,Ip,Port,Alias,DnsName,DnsNode}) ->
    io:fwrite("Worker start function ~n"),
    gen_server:start_link({local, NodeName}, ?MODULE, [{worker,MasterNode,NodeName,Ip,Port,Alias,DnsName,DnsNode}], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([{master,MasterNode,_,Ip,Port,_,DnsName,DnsNode}]) ->
    io:fwrite("Master init function ~n"),
    gen_server:cast({DnsName,DnsNode},{set_server,Ip,Port}),
    {ok, #{
    	dnsName=>DnsName,
    	dnsNode=>DnsNode,
        role=>master,
        master=>MasterNode,
        masterId=>0,
        nodeName=>master_node,
        id=>0,
        numOfActiveServers=>0,
        numOfActiveClients=>0,
        serverAlias=>#{0=>master}, %% ServerId => Alias
        servers=>#{}, %% ServerId => Pid
        serverClients=>#{}, %% ServerId => [Uuid list]
        clients=>#{}, %% Uuid => Server
        nodes=>#{0=>MasterNode}, %% ServerId => Node
        nodeNames=>#{0=>master_node}, %% ServerId => NodeName
        ip=>#{}, %% ServerId => Ip
        port=>#{},%% ServerId => Port
        idCounter=>0
    }};
init([{worker,MasterNode,NodeName,Ip,Port,Alias,_,_}]) ->
    io:fwrite("Worker init function ~n"),
    {InitalState,Node}=gen_server:call({master_node,MasterNode},{connect,node(),Ip,Port,NodeName,Alias}), % call main_server to connect
    monitor_node(Node,true),
    {ok,InitalState}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle call messages
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).


%% Worker is connected to master
handle_call({connect,Node,Ip,Port,NodeName,Alias}, From, State) ->
  Role = maps:get(role,State),
  case Role of
    worker ->
    	log("error: connect to Worker Node ( master function but role is worker)~n",State),
        io:fwrite("error: connect to Worker Node ( master function but role is worker)~n"),
        {noreply, State};
    _Otherwise ->
    	log(["New Worker connect to master: ~p~n",Alias],State),
        io:fwrite("New Worker connect to master: ~p~n",[Alias]),
        monitor_node(Node,true),
        {Pid,_}=From,
        NewState=updateStateForNewServer(Pid,Node,Ip,Port,NodeName,Alias,State),
        InitalState=#{
        	dnsName=>maps:get(dnsName,NewState),
    		dnsNode=>maps:get(dnsNode,NewState),
            role=>worker,
            master=>maps:get(master,NewState),
            masterId=>maps:get(masterId,NewState),
            nodeName=>NodeName,
            id=>maps:get(idCounter,NewState),
            numOfActiveServers=>maps:get(numOfActiveServers,NewState),
            numOfActiveClients=>maps:get(numOfActiveClients,NewState),
            serverAlias=>maps:get(serverAlias,NewState), %% ServerId => Alias
            servers=>maps:get(servers,NewState), %% ServerId => Pid
            serverClients=>maps:get(serverClients,NewState), %% ServerId => [Uuid list]
            clients=>maps:get(clients,NewState), %% Uuid => ServerId
            nodes=>maps:get(nodes,NewState), %% ServerId => Node
            nodeNames=>maps:get(nodeNames,NewState), %% ServerId => NodeName
            ip=>maps:get(ip,NewState), %% ServerId => Ip
            port=>maps:get(port,NewState),%% ServerId => Port
            idCounter=>maps:get(idCounter,NewState)
        },
        {reply,{InitalState,node()}, NewState}
  end;
%%New Client is connected, return value: {WorkerName,Port,Ip}
handle_call({new_client,Uuid}, _From, State) ->
  Role = maps:get(role,State),
  case Role of
    worker ->
    	log(["error: handle call new_client is master function but role is worker"],State),
        io:fwrite("error: handle call new_client is master function but role is worker"),
        {noreply, State};
    _Otherwise ->
    	log(["New client connect to master: ~p~n",Uuid],State),
        io:fwrite("New client connect to master: ~p~n",[Uuid]),
        ServerId=loadBlancerChooseServer(State),
        if
          ServerId == no_workers ->
          	log(["client: ~p is asked to start session but there are no availabe workers for him~n",Uuid],State),
            io:fwrite("client: ~p is asked to start session but there are no availabe workers for him~n",[Uuid]),
            {reply,{no_workers},State};
          true ->
          	log(["client: ~p is handled by server: ~p~n",Uuid, ServerId],State),
            io:fwrite("client: ~p is handled by server: ~p~n",[Uuid, ServerId]),
            NewState=updateStateForNewClient(Uuid,ServerId,State),
            updateWorkers(NewState),
            Ip=getFromState(ip,ServerId,NewState),
            Port=getFromState(port,ServerId,NewState),
            Alias=getFromState(serverAlias,ServerId,NewState),
            {reply,{Ip,Port,Alias},NewState}
        end
    end;
%%manager updated a worker and gave him a new state
handle_call({update_state,NewState}, _From, State) ->
  log(["Update_state for worker ~n"],State),
  io:fwrite("Update_state for worker ~n"),
  Role = maps:get(role,State),
  case Role of
    worker -> 
         {reply,{ack_change_state,maps:get(id,State)},NewState};    
    Otherwise ->
    	log(["error: update_state is a worker function but role is ~p",Otherwise],State),
        io:fwrite("error: update_state is a worker function but role is ~p",[Otherwise]),
        {noreply, State}
    end;

%%get next part, worker function
handle_call({get_next,UUID,Position}, _From, State) ->
        ServerId=getFromState(clients,UUID,State),
        MyServerId=maps:get(id,State),
        log(["get next part from client: ~p. serverId: ~p~n",UUID, MyServerId],State),
        io:fwrite("get next part from client: ~p. serverId: ~p~n",[UUID, MyServerId]),
        if
            ServerId==MyServerId ->
            	log(["ok: get_next approved by serverId: ~p~n",MyServerId],State),
                io:fwrite("ok: get_next approved by serverId: ~p~n",[MyServerId]),
                {reply,{ok,Position},State};
            true ->
              log(["error: get_next wrong server, server id should be: ~p~n",ServerId],State),
              io:fwrite("error: get_next wrong server, server id should be: ~p~n",[ServerId]),
                Ip=getFromState(ip,ServerId,State),
                Port=getFromState(port,ServerId,State),
                Alias=getFromState(serverAlias,ServerId,State),
                {reply,{not_ok,Ip,Port,Alias},State}
        end;



%%redirect client to new worker, master function
handle_call({redirect,UUID}, _From, State) ->
  Role = maps:get(role,State),
  case Role of
    master ->
    	log(["get new Worker for client ~p~n",UUID],State),
        io:fwrite("get new Worker for client ~p~n",[UUID]),
        ServerId=getFromState(clients,UUID,State),
        Ip=getFromState(ip,ServerId,State),
        Port=getFromState(port,ServerId,State),
        Alias=getFromState(serverAlias,ServerId,State),
        {reply,{redirect,Ip,Port,Alias},State};
    _Otherwise ->
    	log(["error: handle call redirect is master function but role is worker"],State),
        io:fwrite("error: handle call redirect is master function but role is worker"),
        {noreply, State}
  end;

%TODO
handle_call(info, _From, State) ->
  log(["handle_call info"],State),
  io:fwrite("handle_call info~n"),
  {reply,
  {
    maps:get(numOfActiveServers,State),
    maps:get(numOfActiveClients,State),
    maps:get(serverAlias,State),
    maps:get(serverClients,State)
  },State};

handle_call(state, _From, State) ->
  log(["handle_call get state"],State),
  io:fwrite("handle_call get state~n"),
  {reply, {ok,State}, State};

handle_call(Request, _From, State) ->
  log(["ERROR: default handle_call"],State),
  io:fwrite("ERROR: default handle_call~n"),
  {reply, {ok,Request}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle cast messages
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).


handle_cast({client_done,Uuid}, State) ->
  Role = maps:get(role,State),
    case Role of
      master ->
        ServerId = getFromState(clients,Uuid,State),
        log(["handle cast: client done. Client Uuid: ~p, ServerId: ~p~n",Uuid,ServerId],State),
        io:fwrite("handle cast: client done. Client Uuid: ~p, ServerId: ~p~n",[Uuid,ServerId]),
        NumOfActiveClients=maps:get(numOfActiveClients,State),
        State1=maps:put(numOfActiveClients,NumOfActiveClients - 1,State),
        State2=remove_from_state_nested(clients,Uuid,State1),
        ServerClients=maps:get(serverClients,State2),
        ServerClientsList=maps:get(ServerId,ServerClients),
        NewServerClientsList=lists:delete(Uuid, ServerClientsList),
        NewServerClients=maps:update(ServerId,NewServerClientsList,ServerClients),
        State3=maps:update(serverClients,NewServerClients,State2),
        ServerClientsMap = maps:get(serverClients,State3),
        {MaxId,MaxVal}=get_longest_list_key(ServerClientsMap,maps:keys(ServerClientsMap)),
        ServerUsersList = maps:get(ServerId,ServerClientsMap),
        UserListLength = length(ServerUsersList),
        Treshold = MaxVal - 1,
        if
          Treshold > UserListLength -> 
            NewState=moveClientBetweenServers(ServerId,MaxId,State3),
            updateWorkers(NewState),
            {noreply, NewState};
          true -> 
            updateWorkers(State3),
            {noreply, State3}
        end;
      _Otherwise ->
        MasterNode = maps:get(master,State),
        MasterId = maps:get(masterId,State),
        MasterName = getFromState(nodeNames,MasterId,State),
        gen_server:cast({MasterName,MasterNode},{client_done,Uuid}),
        {noreply, State}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle info
%% @end
%%--------------------------------------------------------------------

-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).

%%handle case when node falls
handle_info({nodedown,Node}, State) ->
  Role = maps:get(role,State),
  %io:fwrite("node down, state:~p~n",[State]),
 
  case Role of
    worker ->
        MasterNode=maps:get(master,State),
        if
          MasterNode == Node ->
            log(["Master is down! ~n"],State),
            io:fwrite("Master is down! ~n"),
            NewMasterServerId=getNewMasterId(State),
            MyServerId=maps:get(id,State),
            NewState=workerHandleMasterFall(MyServerId,NewMasterServerId,State),
            DnsName = maps:get(dnsName,NewState),
            DnsNode = maps:get(dnsNode,NewState),
            Ip = getFromState(ip,MyServerId,State),
            Port = getFromState(port,MyServerId,State),
            gen_server:cast({DnsName,DnsNode},{set_server,Ip,Port}),
            {noreply,NewState};
          true -> 
          	log(["Worker down: ~p~n",Node],State),
            io:fwrite("Worker down: ~p~n",[Node]),
            {noreply, State}
        end;
    _Otherwise ->
      NodesList=maps:to_list(maps:get(nodes,State)),
      LengthOfNodesList = length(NodesList),
      log(["OMG OMG OMG Node ~p is down!\n  NodesList before deleting is ~p",Node,NodesList],State),
      io:fwrite("OMG OMG OMG Node ~p is down!\n  NodesList before deleting is ~p",[Node,NodesList]),
      if % if to handle case when the worker that was terminated was the last worker
        LengthOfNodesList == 2 -> % was the last worker, we dont update anyone we throw away all clients sadly
          FallenServerId=getServerIdFromNode(NodesList,Node),
          ServerClientsMap=maps:get(serverClients,State),
          FallenServerClientsList=maps:get(FallenServerId,ServerClientsMap),
          StateWithoutFallenWorker=removeServerFromState(FallenServerId,State),
          NewState=removeClientsFromState(FallenServerClientsList,StateWithoutFallenWorker),
          {noreply, NewState};
        true ->
          FallenServerId=getServerIdFromNode(NodesList,Node),
          ServerClientsMap=maps:get(serverClients,State),
          FallenServerClientsList=maps:get(FallenServerId,ServerClientsMap),
          StateWithoutFallenWorker=removeServerFromState(FallenServerId,State),
          StateWithoutFallenWorkerClients=removeClientsFromState(FallenServerClientsList,StateWithoutFallenWorker),
          NewState=addClientsAndUpdateWorkers(FallenServerClientsList,StateWithoutFallenWorkerClients),
          {noreply, NewState}
      end
      
    end.

	%% get the server id by getting the node of the server
getServerIdFromNode([],_) ->
  %log(["didnt found server id from node"],State),
  io:fwrite("didnt found server id from node"),
  ok;
getServerIdFromNode([{ServerId,Node}|T],NodeName) ->
  if 
    Node == NodeName ->
      ServerId;
    true ->
      getServerIdFromNode(T,NodeName) 
  end.

  %% remove a server from the shared state of the master and the workers and update all workers this function will be called only in master
removeServerFromState(ServerId,State) ->
  NumOfActiveServers=maps:get(numOfActiveServers,State),
  State0=maps:put(numOfActiveServers,NumOfActiveServers - 1,State),
  State1=remove_from_state_nested(serverAlias,ServerId,State0),
  State2=remove_from_state_nested(servers,ServerId,State1),
  State3=remove_from_state_nested(serverClients,ServerId,State2),
  State4=remove_from_state_nested(nodes,ServerId,State3),
  State5=remove_from_state_nested(ip,ServerId,State4),
  State6=remove_from_state_nested(nodeNames,ServerId,State5),
  NewState=remove_from_state_nested(port,ServerId,State6),
  NewState.

  %%remove the server of worker from the state before promoting it to master
removeServerFromStateForPromotion(ServerId,State) -> 
    State1 = remove_from_state_nested(servers,ServerId,State),
    State2 = remove_from_state_nested(serverClients,ServerId,State1),
    State3=remove_from_state_nested(ip,ServerId,State2),
    remove_from_state_nested(port,ServerId,State3).

	%%remopve old master when a worker replaced the master 
removeOldMaster(Id,State)->
  NumOfActiveServers=maps:get(numOfActiveServers,State),
  State0=maps:put(numOfActiveServers,NumOfActiveServers - 1,State),
  State1 = remove_from_state_nested(serverAlias,Id,State0),
  State2 = remove_from_state_nested(nodeNames,Id,State1),
  State3 = remove_from_state_nested(nodes,Id,State2),
  remove_from_state_nested(serverAlias,Id,State3).

  
%% remove the client from the state when the client finished
removeClientsFromState([],State) -> State;
removeClientsFromState([Uuid|T],State) -> 
  NumOfActiveClients=maps:get(numOfActiveClients,State),
  State1=maps:put(numOfActiveClients,NumOfActiveClients - 1,State),
  NewState=remove_from_state_nested(clients,Uuid,State1),
  removeClientsFromState(T,NewState).

  %%add new client to state and update the workers
addClientsAndUpdateWorkers([],State) -> 
  updateWorkers(State),
  State;
addClientsAndUpdateWorkers([Uuid|T],State) ->
  ServerId=loadBlancerChooseServer(State),
  if 
  	ServerId == no_workers -> 
  		State;
  	true ->	
  		NewState=updateStateForNewClient(Uuid,ServerId,State),
  		addClientsAndUpdateWorkers(T,NewState)
  end.

  %%triggered when server terminates
terminate(_Reason, State) ->
  log(["terminating $$$$$$$$$$$$$$$$$$$$$$$$$$$$"],State),
  io:fwrite("terminating $$$$$$$$$$$$$$$$$$$$$$$$$$$$"),
    ok.
 
 %%not being used
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Internal functions
%%update the state when a new worker is attached to the master
updateStateForNewServer(Pid,Node,Ip,Port,NodeName,Alias,State)->
    NumOfActiveServers = maps:get(numOfActiveServers,State),
    State1 = maps:put(numOfActiveServers,NumOfActiveServers + 1,State),
    ServerId = maps:get(idCounter,State1) + 1,
    State2 = maps:put(idCounter,ServerId,State1),
    State3 = add_to_state_nested(serverAlias,ServerId,Alias,State2),
    State4 = add_to_state_nested(servers,ServerId,Pid,State3),
    State5 = add_to_state_nested(serverClients,ServerId,[],State4),
    State6 = add_to_state_nested(nodes,ServerId,Node,State5),
    State7 = add_to_state_nested(nodeNames,ServerId,NodeName,State6),
    State8 = add_to_state_nested(ip,ServerId,Ip,State7),
    add_to_state_nested(port,ServerId,Port,State8).

	%%update the state when new client start the service
updateStateForNewClient(UUID,ServerId,State)->
    NumOfActiveClients = maps:get(numOfActiveClients,State),
    State1 = maps:put(numOfActiveClients,NumOfActiveClients+1,State),
    State2 = add_uuid_to_state(ServerId,UUID,State1),
    add_to_state_nested(clients,UUID,ServerId,State2).

	%%function to load balance between the workers
loadBlancerChooseServer(State)->
    Server2ClientsMap = maps:get(serverClients,State),
    {MinId,_} = get_shortest_list_key(Server2ClientsMap,maps:keys(Server2ClientsMap)),
    MinId.

	%%send the new state to all workers in a manner that fits their state(id and so on)
updateWorkers(State) ->
    ServersIdList = maps:keys(maps:get(servers,State)),
    updateWorkers(ServersIdList,State).
updateWorkers([],_State)->ok;
updateWorkers([Id|T],State)->
    Node = getFromState(nodes,Id,State),
    NodeName = getFromState(nodeNames,Id,State),
    NewState1 = maps:put(role,worker,State),
    NewState2 = maps:put(nodeName,NodeName,NewState1),
    NewState3 = maps:put(id,Id,NewState2),
    gen_server:call({NodeName,Node},{update_state,NewState3}),
    updateWorkers(T,State).

	%%get element from a nested map inside the state
getFromState(Atom,Key,State)->
    MapFromState=maps:get(Atom,State),
    maps:get(Key,MapFromState).

	%%add element to a nested map inside the state map
add_to_state_nested(Atom,Key,Value,State)->
    MapFromState=maps:get(Atom,State),
    NewInnerMapForState = maps:put(Key,Value,MapFromState),
    maps:put(Atom,NewInnerMapForState,State).

	%%rempve element from a nested map inside the state
remove_from_state_nested(Atom,Key,State)->
    MapFromState=maps:get(Atom,State),
    NewInnerMapForState = maps:remove(Key,MapFromState),
    maps:update(Atom,NewInnerMapForState,State).

	%%get shortest list of the clients lists of the workers
get_shortest_list_key(_M,[])-> {no_workers,ok};
get_shortest_list_key(M,List)->
  get_shortest_list_key(M,List,-1,2000000).
get_shortest_list_key(_M,[],MinId,MinVal)->{MinId,MinVal};
get_shortest_list_key(M,[Id|T],MinId,MinVal)->
  UsersList = maps:get(Id,M),
  Length = length(UsersList),
  if
    Length < MinVal -> 
      get_shortest_list_key(M,T,Id,Length);
    true -> 
      get_shortest_list_key(M,T,MinId,MinVal)
  end.

  %%get longest list of the lists of the workers
get_longest_list_key(_M,[])-> {no_workers,ok};
get_longest_list_key(M,List)->
  get_longest_list_key(M,List,-1,-1).
get_longest_list_key(_M,[],MaxId,MaxVal)-> {MaxId,MaxVal};
get_longest_list_key(M,[Id|T],MaxId,MaxVal)->
  UsersList = maps:get(Id,M),
  Length = length(UsersList),
  if
    Length > MaxVal -> 
      get_longest_list_key(M,T,Id,Length);
    true -> 
      get_longest_list_key(M,T,MaxId,MaxVal)
  end.

%%add uuid of a new client to state
add_uuid_to_state(ServerId,UUID,State)->
  ServersMap = maps:get(serverClients,State),
  ClientsList = maps:get(ServerId,ServersMap),
  NewServersMap = maps:put(ServerId,[UUID|ClientsList],ServersMap),
  maps:put(serverClients,NewServersMap,State).

  %%move client from one worker to the other
moveClientBetweenServers(DestId,SrcId,State) ->
  ServerClients=maps:get(serverClients,State),
  DestClients=maps:get(DestId,ServerClients),
  SrcClients=maps:get(SrcId,ServerClients),
  [Uuid|T]=SrcClients,
  NewDestClients=DestClients ++ [Uuid],
  NewServerClients0=maps:update(DestId,NewDestClients,ServerClients),
  NewServerClients=maps:update(SrcId,T,NewServerClients0),
  ClientsMap=maps:get(clients,State),
  NewClientsMap=maps:update(Uuid,DestId,ClientsMap),
  NewState0=maps:update(clients,NewClientsMap,State),
  NewState=maps:update(serverClients,NewServerClients,NewState0),
  NewState.

  %% get the id of the new master
getNewMasterId(State) ->
  ServersMap=maps:get(servers,State),
  ServerIds=maps:keys(ServersMap),
  NewManagerId=lists:min(ServerIds),
  NewManagerId.

  %%the function that triggerws in worker machine when master falls and the worker needs to replace him
workerHandleMasterFall(MyServerId,MyServerId,State) ->
  log(["New Master: ~p ~n",MyServerId],State),
  io:fwrite("New Master: ~p ~n",[MyServerId]),
  NewMasterId=maps:get(id,State),
  MasterId=maps:get(masterId,State),
  ServerClientsMap=maps:get(serverClients,State),
  ServerClientsList=maps:get(NewMasterId,ServerClientsMap),
  StateWithoutMaster = removeOldMaster(MasterId,State),
  StateWithoutWorker=removeServerFromStateForPromotion(NewMasterId,StateWithoutMaster),
  StateWithoutWorkerClients=removeClientsFromState(ServerClientsList,StateWithoutWorker),
  StateWithNewMasterRole=maps:update(role,master,StateWithoutWorkerClients),
  StateWithMasterId = maps:update(masterId,MyServerId,StateWithNewMasterRole),
  StateWithNewMaster=maps:update(master,node(),StateWithMasterId),
  %io:fwrite("workerHandleMasterFall after state change: ~p ~n",[StateWithNewMaster]),	
  NewState=addClientsAndUpdateWorkers(ServerClientsList,StateWithNewMaster),
 % io:fwrite("workerHandleMasterFall after update workers: ~p ~n",[NewState]),
  monitorNodes(NewState),
  NewState;
workerHandleMasterFall(_MyServerId,NewMasterServerId,State) ->
  %monitor new master node
  log(["monitor new master: ~p ~n",NewMasterServerId],State),
  io:fwrite("monitor new master: ~p ~n",[NewMasterServerId]),
  NodesMap=maps:get(nodes,State),
  Node = maps:get(NewMasterServerId,NodesMap),
  monitor_node(Node,true),
  State.

  %%monitor all workers
monitorNodes(State) ->
  NodesMap=maps:get(nodes,State),
  NodesIds=maps:keys(NodesMap),
  lists:foreach(fun(Id) ->
                      Node = maps:get(Id,NodesMap),
                      monitor_node(Node,true)
              end, NodesIds).

			  %%not being used at the moment
loadBlance(State) -> %TODO Where to call ?
  ServerClientsMap = maps:get(serverClients,State),
  {MaxId,MaxVal}=get_longest_list_key(ServerClientsMap,maps:keys(ServerClientsMap)),
  {MinId,MinVal}=get_shortest_list_key(ServerClientsMap,maps:keys(ServerClientsMap)),
  Treshold = MinVal + 1,
    if
      MaxVal > Treshold ->
        NewState=moveClientBetweenServers(MinId,MaxId,State),
        loadBlance(NewState);
      true -> 
        updateWorkers(State),
        State
    end.
    
	%%send log to dns server
log(DataToLog,State)->
	%Id = maps:get(id,State),
	%Alias = getFromState(serverAlias,Id,State),
	DnsName = maps:get(dnsName,State),
    DnsNode = maps:get(dnsNode,State),
    %io:fwrite(MSG),
	gen_server:cast({DnsName,DnsNode},{log,DataToLog}).



