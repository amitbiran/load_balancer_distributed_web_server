%% this handler will handle client that request the ip and port of the master server.
-module(get_server_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([get_server/2]).
-export([options/2,get_node_name/0]).

%%will run each time the handler is triggered. 
init(Req, Opts) ->
%io:fwrite("~p",[cowboy_req:read_urlencoded_body(Req)]),
	io:fwrite("hii"),
  	Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {cowboy_rest, Req3, Opts}.%% cowboy_rest is a cowboy feature will do most of the work behind the scene for us

content_types_provided(Req, State) ->
    {[

        {<<"application/json">>, get_server}
    ], Req, State}.


%%we get the ip and port from the gen_server then we construct a json out of them and we add http headers for cross origin
get_server(Req, State) ->
    Node_Name = get_node_name(),
    [Sname,_IpURL] = string:tokens(Node_Name,"@"),
    {Ip,Port} = gen_server:call({list_to_atom(Sname),list_to_atom(Node_Name)},get_server),
    io:fwrite("~p   ~p",[Ip,Port]),
    Body = io_lib:format("{\"ip\": ~p,\"port\": \"~p\"}",[atom_to_list(Ip),Port]),
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

