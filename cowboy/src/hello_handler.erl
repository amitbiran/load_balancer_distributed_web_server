%% @doc REST time handler.
-module(hello_handler).

%% Webmachine API
-export([
         init/2,
         content_types_provided/2
        ]).

-export([time_to_json/2]).
-export([options/2]).

init(Req, Opts) ->
  Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    {cowboy_rest, Req3, Opts}.

content_types_provided(Req, State) ->
    {[

        {<<"application/json">>, time_to_json}
    ], Req, State}.



time_to_json(Req, State) ->
    {Hour, Minute, Second} = erlang:time(),
    {Year, Month, Day} = erlang:date(),
    Body = 
    "{
    \"time\": \"~2..0B:~2..0B:~2..0B\",
    \"date\": \"~4..0B/~2..0B/~2..0B\"
}",
    Body1 = io_lib:format(Body, [
        Hour, Minute, Second,
        Year, Month, Day
    ]),
    Body2 = list_to_binary(Body1),
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    
    {Body2, Req3, State}.


options(Req, State) ->
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, OPTIONS">>, Req),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"http://localhost:8000">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,<<"Access-Control-Allow-Origin,content-type">>, Req2),
    
    {ok, Req3, State}.

