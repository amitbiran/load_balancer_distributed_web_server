%% this handlr will handle client that ask to get the logs buffer from the DNS server
-module(get_log_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([get_log/2]).
-export([options/2,get_node_name/0]).

%%will run each time the handler is triggered. 
init(Req, Opts) ->
%io:fwrite("~p",[cowboy_req:read_urlencoded_body(Req)]),
  Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {cowboy_rest, Req3, Opts}.%% cowboy_rest is a cowboy feature will do most of the work behind the scene for us

content_types_provided(Req, State) ->
    {[

        {<<"application/json">>, get_log}
    ], Req, State}.


%%we get the log buffer from the gen_server parse it into json and add the response http headers for cross origins
get_log(Req, State) ->
    Node_Name = get_node_name(),
    [Sname,_IpURL] = string:tokens(Node_Name,"@"),
    {Log} = gen_server:call({list_to_atom(Sname),list_to_atom(Node_Name)},get_log),
    Body = io_lib:format("{\"log\": ~p}",[Log]),
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

%%get the gen_server node from the ets
get_node_name()->
    [{_K,V}|_T] = ets:lookup(configTable,node),
    V.

