%% @doc REST time handler.
-module(story_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([get_next_part/2]).
-export([options/2,generate/0,get_node_name/0,get_data/1,createResponse/1]).


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
    {UUID,Part} = get_data(Req),
    Node_Name = get_node_name(),
    [Sname,_IpURL] = string:tokens(Node_Name,"@"),
    ResponseFromworker = gen_server:call({list_to_atom(Sname),list_to_atom(Node_Name)},{get_next,UUID,Part}),
    {Body,Done} = createResponse(ResponseFromworker),
    if
        Done == true ->
            gen_server:cast({list_to_atom(Sname),list_to_atom(Node_Name)},{client_done,UUID});
        true->
            ok
    end,
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
    [{<<"uuid">>,UUIDb},{<<"part">>,Partb}] = cowboy_req:parse_qs(Req),
    {binary_to_list(UUIDb),binary_to_list(Partb)}.

createResponse({ok,Position})->
        Done = (Position == "23"),
        IntPosition = erlang:list_to_integer(Position),
        if
            (IntPosition > 23) or (IntPosition <1) ->
                "{\"status\": \"bad position\"}";
            true -> 
                BackDir = filename:dirname(element(2,file:get_cwd())),
                RootDir = filename:dirname(BackDir),
                FileName = filename:join([RootDir,"media","story.txt"]),
                io:fwrite("here is the file name and the position ~p $$ ~p",[FileName,Position]),
                Line = readLineFromFile(FileName,IntPosition),
                {
                io_lib:format("{\"status\": \"ok\", \"story\": ~p, \"done\" : ~p}",[Line,Done]),
                Done
                }
        end;
createResponse({not_ok,Ip,Port,Alias})->
        Body = io_lib:format("{\"status\": \"redirect\",\"worker_name\": \"~p\",\"port\": \"~p\",\"ip\": ~p}",[Alias,Port,atom_to_list(Ip)]),
	{Body,false};
createResponse(Other)->io:fwrite("got bad reply from worker gen_server response was ~p~n",[Other]).

readLineFromFile(FileName,N)->
    lists:nth(N,readfile(FileName)).

readfile(FileName) ->
  {ok, Binary} = file:read_file(FileName),
  string:tokens(erlang:binary_to_list(Binary), "\n").
