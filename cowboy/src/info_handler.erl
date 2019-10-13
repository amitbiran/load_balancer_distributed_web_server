%% this handler was created for the client to get info from the gen_server we decided not to use it but we leave it here in case we would like to expand the project
-module(info_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([get_next_part/2]).
-export([options/2,generate/0,get_node_name/0,get_data/1]).

%%will run each time the handler is triggered.
init(Req, Opts) ->
%io:fwrite("~p",[cowboy_req:read_urlencoded_body(Req)]),
  Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {cowboy_rest, Req3, Opts}.

content_types_provided(Req, State) ->
    {[

        {<<"application/json">>, get_next_part}
    ], Req, State}.



get_next_part(Req, State) ->
    get_data(Req),
    UUID = binary_to_list(generate()),
    Node_Name = get_node_name(),
    gen_server:call({master,list_to_atom(Node_Name ++ "@" ++ "127.0.0.1")},{new_client,{uuid,UUID}}),
   % io:fwrite("~p",[ResponseFromMaster]),
    Body = io_lib:format("{\"uuid\": ~p,\"workerid\": \"~p\",\"port\": \"~p\"}",[UUID,worker1,8080]),
    Body2 = list_to_binary(Body),
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {Body2, Req3, State}.


options(Req, State) ->
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),  
    {ok, Req3, State}.


     
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

get_node_name()->
    [{_K,V}|_T] = ets:lookup(configTable,node),
    V.

get_data(Req)->
    QS = cowboy_req:parse_qs(Req),
    io:fwrite("~p",[QS]).
