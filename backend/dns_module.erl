%%%-------------------------------------------------------------------
%%% @author aviran and amit
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%% Eralng final project
%%% @end
%%% Created : 23. Jun 2017 10:11
%%%-------------------------------------------------------------------
-module(dns_module).
-author("AviranAmit").
-behaviour(gen_server).

-export([start/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-export([]).

-record(state, {}).
-define(SERVER, ?MODULE).

-spec(start(T :: term()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start({NodeName,IP,Port}) ->
    io:fwrite("dns start function ~n"),
    gen_server:start_link({local, NodeName}, ?MODULE, [{IP,Port}], []).

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
init([{IP,Port}]) ->
    io:fwrite("dns init function ~n"),
    {ok, #{
        ip=>IP, %% ServerId => Ip
        port=>Port,%% ServerId => Port
        log=>[]
    }}.


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

  %%get new server address
handle_call(get_server, _From, State) ->
  io:fwrite("handle_call get_server~n"),
  {reply,
  {
    maps:get(ip,State),
    maps:get(port,State)
  },State};
%% return the state 
  handle_call(state, _From, State) ->
  io:fwrite("handle_call get state~n"),
  {reply, {ok,State}, State};
%%returns the logs and empty the buffer
handle_call(get_log, _From, State) ->
  io:fwrite("handle_call get_log~n"),
  Log = maps:get(log,State),
  NewState = maps:put(log,[],State),
  {reply,
  {
    Log
  },NewState}.

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
%%get a new log and add it to buffer
handle_cast({log,MSG}, State) ->
    Log = maps:get(log,State),
    io:fwrite("~p",[MSG]),
    NewLog = [MSG|Log],
    NewState = maps:put(log,NewLog,State),
    {noreply, NewState};

	%%set the server adress
handle_cast({set_server,Ip,Port}, State) ->
    State1 = maps:put(ip,Ip,State),
    NewState = maps:put(port,Port,State1),
    {noreply, NewState}.

        

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

handle_info({nodedown,_Node}, State) ->
    {noreply, State}.



terminate(_Reason, _State) ->
  io:fwrite("terminating $$$$$$$$$$$$$$$$$$$$$$$$$$$$"),
    ok.

code_change(_OldVsn, State, _Extra) ->
  io:fwrite("changing code"),
    {ok, State}.

