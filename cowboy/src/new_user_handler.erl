%% this handler is triggered when a new user start the service and request to start a story
%%this handler should be triggered only at the master's node
-module(new_user_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([initialize_user_session/2]).
-export([options/2,generate/0,get_node_name/0]).

%%will run each time the handler is triggered. 
init(Req, Opts) ->
%io:fwrite("~p",[cowboy_req:read_urlencoded_body(Req)]),
  Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {cowboy_rest, Req3, Opts}.

content_types_provided(Req, State) ->
    {[

        {<<"application/json">>, initialize_user_session}
    ], Req, State}.


%%here we initialize the user's session we generate a uuid for the user and ask the gen_server to map it to a worker then we return the worker the client should start talking to
initialize_user_session(Req, State) ->
    UUID = binary_to_list(generate()),
    Node_Name = get_node_name(),
    [Sname,_IpURL] = string:tokens(Node_Name,"@"),
    ResponseFromMaster = gen_server:call({list_to_atom(Sname),list_to_atom(Node_Name)},{new_client,UUID}),
    if%%handle of the case of there are no available workers and only a master node
        ResponseFromMaster == {no_workers} ->
            Body = "{\"error:\": \"no_workers\"}",
            Body2 = list_to_binary(Body),
            Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
            Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
            Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
            {Body2, Req3, State};
        true -> %%normal case map client to a worker return uuid name ip and port in a json also add http headers for dealing with cross origins
            {Ip,Port,Alias} = ResponseFromMaster,
            Body = io_lib:format("{\"uuid\": ~p,\"worker_name\": \"~p\",\"port\": \"~p\",\"ip\": ~p}",[UUID,Alias,Port,atom_to_list(Ip)]),
            Body2 = list_to_binary(Body),
            Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
            Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
            Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
            {Body2, Req3, State}
    end.
    


options(Req, State) ->
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),  
    {ok, Req3, State}.


   %%the actual function that generate the unique uuid the code was copied from stackoverflow
generate() ->
    Now = {_, _, Micro} = os:timestamp(),
    Nowish = calendar:now_to_universal_time(Now),
    Nowsecs = calendar:datetime_to_gregorian_seconds(Nowish),
    Then = calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}),
    Prefix = io_lib:format("~14.16.0b", [(Nowsecs - Then) * 1000000 + Micro]),
    list_to_binary(Prefix ++ to_hex(crypto:strong_rand_bytes(9))).
 
to_hex([]) ->
    [];
to_hex(Bin) when is_binary(Bin) ->
    to_hex(binary_to_list(Bin));
to_hex([H|T]) ->
    [to_digit(H div 16), to_digit(H rem 16) | to_hex(T)].
     
to_digit(N) when N < 10 -> $0 + N;
to_digit(N) -> $a + N-10.

%%get the gen_server node name that this cowboy server talk to 
get_node_name()->
    [{_K,V}|_T] = ets:lookup(configTable,node),
    V.

