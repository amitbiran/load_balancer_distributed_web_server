-module( test ).
 
-export( [readfile/1,readLineFromFile/2] ).

readLineFromFile(FileName,N)->
	lists:nth(N,readfile(FileName)).

readfile(FileName) ->
  {ok, Binary} = file:read_file(FileName),
  Lines = string:tokens(erlang:binary_to_list(Binary), "\n").
 
