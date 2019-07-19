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
start({master,MasterNode,_,_,_,_}) ->
    io:fwrite("Master start function"),
    gen_server:start_link({local, master}, ?MODULE, [{master,MasterNode,"","","",""}], []);
start({worker,MasterNode,NodeName,Ip,Port,Alias}) ->
    io:fwrite("Worker start function"),
    gen_server:start_link({local, NodeName}, ?MODULE, [{worker,MasterNode,NodeName,Ip,Port,Alias}], []).

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
init([{master,MasterNode,_,_,_,_}]) ->
    {ok, #{
        role=>master,
        master=>MasterNode,
        nodeName=>master,
        id=>0,
        numOfActiveServers=>0,
        numOfActiveClients=>0,
        serverAlias=>#{0=>master}, %% ServerId => Alias
        servers=>#{}, %% ServerId => Pid
        serverClients=>#{}, %% ServerId => [Uuid list]
        clients=>#{}, %% Uuid => Server
        nodes=>#{0=>MasterNode}, %% ServerId => Node
        nodeNames=>#{0=>master}, %% ServerId => NodeName
        ip=>#{}, %% ServerId => Ip
        port=>#{},%% ServerId => Port
        idCounter=>0
    }};
init([{worker,MasterNode,NodeName,Ip,Port,Alias}]) ->
    {InitalState,Node}=gen_server:call({master,MasterNode},{connect,node(),Ip,Port,NodeName,Alias}), % call main_server to connect
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
        io:fwrite("error: connect is master function but role is worker"),
        {noreply, State};
    _Otherwise ->
       io:fwrite("call: connect to Master"),
        monitor_node(Node,true),
        {Pid,_}=From,
        NewState=updateStateForNewServer(Pid,Node,Ip,Port,NodeName,Alias,State),
        InitalState=#{
            role=>worker,
            master=>maps:get(master,NewState),
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
        io:fwrite("error: new_client is master function but role is worker"),
        {noreply, State};
    _Otherwise ->
        ServerId=loadBlancerChooseServer(State),
        NewState=updateStateForNewClient(Uuid,ServerId,State),
        updateWorkers(NewState),
        Ip=getFromState(ip,ServerId,NewState),
        Port=getFromState(port,ServerId,NewState),
        Alias=getFromState(serverAlias,ServerId,NewState),
        {reply,{Ip,Port,Alias},NewState}
    end;
%%manager updated a worker and gave him a new state
handle_call({update_state,NewState}, _From, State) ->
  Role = maps:get(role,State),
  case Role of
    worker -> 
         {reply,{ack_change_state,maps:get(id,State)},NewState};    
    Otherwise ->
        io:fwrite("error: update_state is a worker function but role is ~p",[Otherwise]),
        {noreply, State}
    end;
%%get next part, worker function
handle_call({get_next,UUID,Position}, _From, State) ->
  Role = maps:get(role,State),
  case Role of
    master ->
        io:fwrite("error: get_next is worker function but role is master"),
        {noreply, State};
    _Otherwise ->
        ServerId=getFromState(clients,UUID,State),
        MyServerId=maps:get(id,State),
        io:fwrite(" ~p $%$ ~p ",[ServerId,MyServerId]),
        if
            ServerId==MyServerId ->
                {reply,{ok,Position},State};
            true ->
                Ip=getFromState(ip,ServerId,State),
                Port=getFromState(port,ServerId,State),
                Alias=getFromState(serverAlias,ServerId,State),
                {reply,{not_ok,Ip,Port,Alias},State}
        end
    end;

%TODO
handle_call(info, _From, State) ->
  {reply,
  {
    maps:get(numOfActiveServers,State),
    maps:get(numOfActiveClients,State),
    maps:get(serverAlias,State),
    maps:get(serverClients,State)
  },State};

handle_call(state, _From, State) ->
  {reply, {ok,State}, State};

handle_call(Request, _From, State) ->
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


handle_cast({client_done,Uuid,ServerId}, State) ->
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
    (Treshold > UserListLength) and MaxId /= ServerId-> 
      NewState=moveClientBetweenServers(ServerId,MaxId,State3),
      updateWorkers(NewState),
      {noreply, NewState};
    true -> 
      {noreply, State3}
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


handle_info({nodedown,Node}, State) ->
  Role = maps:get(role,State),
  case Role of
    worker ->
        io:fwrite("worker dont need to do shit"),
        {noreply, State};
    _Otherwise ->
      NodesList=maps:to_list(maps:get(nodes,State)),
      FallenServerId=getServerIdFromNode(NodesList,Node),
      ServerClientsMap=maps:get(serverClients,State),
      FallenServerClientsList=maps:get(FallenServerId,ServerClientsMap),
      StateWithoutFallenWorker=removeServerFromState(FallenServerId,State),
      StateWithoutFallenWorkerClients=removeClientsFromState(FallenServerClientsList,StateWithoutFallenWorker),
      NewState=addClientsAndUpdateWorkers(FallenServerClientsList,StateWithoutFallenWorkerClients),
      {noreply, NewState}
    end.

getServerIdFromNode([],_) ->
  io:fwrite("didnt found server id from node"),
  ok;
getServerIdFromNode([{ServerId,Node}|T],NodeName) ->
  if 
    Node == NodeName ->
      ServerId;
    true ->
      getServerIdFromNode(T,NodeName) 
  end.

removeServerFromState(ServerId,State) ->
  NumOfActiveServers=maps:get(numOfActiveServers,State),
  State0=maps:put(numOfActiveServers,NumOfActiveServers - 1,State),
  State1=remove_from_state_nested(serverAlias,ServerId,State0),
  State2=remove_from_state_nested(servers,ServerId,State1),
  State3=remove_from_state_nested(serverClients,ServerId,State2),
  State4=remove_from_state_nested(nodes,ServerId,State3),
  State5=remove_from_state_nested(ip,ServerId,State4),
  NewState=remove_from_state_nested(port,ServerId,State5),
  NewState.

removeClientsFromState([],State) -> State;
removeClientsFromState([Uuid|T],State) -> 
  NumOfActiveClients=maps:get(numOfActiveClients,State),
  State1=maps:put(numOfActiveClients,NumOfActiveClients - 1,State),
  NewState=remove_from_state_nested(clients,Uuid,State1),
  removeClientsFromState(T,NewState).

addClientsAndUpdateWorkers([],State) -> 
  updateWorkers(State),
  State;
addClientsAndUpdateWorkers([Uuid|T],State) ->
  ServerId=loadBlancerChooseServer(State),
  NewState=updateStateForNewClient(Uuid,ServerId,State),
  addClientsAndUpdateWorkers(T,NewState).

terminate(_Reason, _State) ->
  io:fwrite("terminating $$$$$$$$$$$$$$$$$$$$$$$$$$$$"),
    ok.

code_change(_OldVsn, State, _Extra) ->
  io:fwrite("pikachu"),
    {ok, State}.

%% Internal functions

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

updateStateForNewClient(UUID,ServerId,State)->
    NumOfActiveClients = maps:get(numOfActiveClients,State),
    State1 = maps:put(numOfActiveClients,NumOfActiveClients+1,State),
    State2 = add_uuid_to_state(ServerId,UUID,State1),
    add_to_state_nested(clients,UUID,ServerId,State2).

loadBlancerChooseServer(State)->
    Server2ClientsMap = maps:get(serverClients,State),
    get_shortest_list_key(Server2ClientsMap,maps:keys(Server2ClientsMap)).

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

getFromState(Atom,Key,State)->
    MapFromState=maps:get(Atom,State),
    maps:get(Key,MapFromState).

add_to_state_nested(Atom,Key,Value,State)->
    MapFromState=maps:get(Atom,State),
    NewInnerMapForState = maps:put(Key,Value,MapFromState),
    maps:put(Atom,NewInnerMapForState,State).

remove_from_state_nested(Atom,Key,State)->
    MapFromState=maps:get(Atom,State),
    NewInnerMapForState = maps:remove(Key,MapFromState),
    maps:update(Atom,NewInnerMapForState,State).

get_shortest_list_key(_M,[])-> no_workers;
get_shortest_list_key(M,List)->
  get_shortest_list_key(M,List,-1,2000000).
get_shortest_list_key(_M,[],MinId,_MinVal)->MinId;
get_shortest_list_key(M,[Id|T],MinId,MinVal)->
  UsersList = maps:get(Id,M),
  Length = length(UsersList),
  if
    Length < MinVal -> 
      get_shortest_list_key(M,T,Id,Length);
    true -> 
      get_shortest_list_key(M,T,MinId,MinVal)
  end.

get_longest_list_key(_M,[])-> no_workers;
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


add_uuid_to_state(ServerId,UUID,State)->
  ServersMap = maps:get(serverClients,State),
  ClientsList = maps:get(ServerId,ServersMap),
  NewServersMap = maps:put(ServerId,[UUID|ClientsList],ServersMap),
  maps:put(serverClients,NewServersMap,State).

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




