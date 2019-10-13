-module(hello_cowboy_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).
-export([options/2]).
%%will run on server init
start(_Type, _Args) ->
        %% anything that happens here will happen before the server really starts so setting global variables is here
        BackDir = filename:dirname(element(2,file:get_cwd())),
        RootDir = filename:dirname(BackDir),
        FileName = filename:join([RootDir,"config","name_of_node.txt"]),
        {ok, Device} = file:open(FileName, [read]),
        NameOfNode = string:trim(io:get_line(Device, "")),
        Port = list_to_integer(string:trim(io:get_line(Device, ""))),
        file:close(Device),
		%%create an ets and save in it all the info from the config files like port ip and so on
        ets:new(configTable,[set,named_table]),
        ets:insert(configTable,{node,NameOfNode}),
        io:fwrite("$$$$$$$$$$$ name of node is ~p port is ~p $$$$$$$$$$$$$$\n",[NameOfNode,Port]), 
        Dispatch = cowboy_router:compile([%%define maping of url to handlers
        {'_', [{"/", hello_handler, []},{"/redirect", redirect_handler, []},{"/start_story", new_user_handler, []},{"/story", story_handler, []},{"/info", info_handler, []}]}
    ]),
	io:fwrite("im a groot"),	    
    {ok, _} = cowboy:start_clear(my_http_listener,
        [{port, Port}],
        #{env => #{dispatch => Dispatch}}
    ),
    hello_cowboy_sup:start_link().

stop(_State) ->
	ok.

options(Req, State) ->
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type, authorization">>, Req2),
    {ok, Req3, State}.


