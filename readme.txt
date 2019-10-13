
**instruction to install and setup the cowboy component in a machine:

make sure you have python installed

make sure you have make(for Makefile) and curl installed (some computers in the lab don't have those)

the cowboy project is auto generated according to the erlang version that is installed on a computer we need 5 of thos and each one of them is 50 mb therfore we could not submit the whole cowboy project.

*create an empty cowboy project


create a folder called hello_cowboy (the folder can have a different name but then you will need to modify some configuration files)

go inside the folder you created

open terminal make sure you have privilages to modify files (you may need to run commands using sudo)

run the following:
wget https://erlang.mk/erlang.mk
make -f erlang.mk bootstrap bootstrap-rel
make

notice you have some new files in the directory and one of them is Makefile

add th following to Makefile

DEPS = cowboy
dep_cowboy_commit = master

now the Makefile should look like that

PROJECT = hello_cowboy
PROJECT_DESCRIPTION = New project
PROJECT_VERSION = 0.1.0
DEPS = cowboy
dep_cowboy_commit = master
include erlang.mk

run make again

*we now finished installing an empty cowboy server project.
you can use the project files of this empty project on other computers with the same otp and erlang version instead of generating them again on another computer. if you want you now can change the name of the folder, the cowboy project will still work.


*add our project's logic to the cowboy project do the following:

inside the cowboy project there is a config directory, inside the files we submmited with the project, inside the cowboy directory there is also a config directory, we will call the folder config we submited config2 to avoid confusion. inside the config2 directory there is a folder for each roll, master, worker1, etc... replace tyhe files in the config directory with the files of the role you need in config2 directory. for example if the computer you are using is going to be the master use the files in config2 inside the master directory.

open the name_of_node.txt and make sure that the name of the gen_server node and the port are correct

you can change the port, the name of the gen_server node the server is attached to and the cookie by modifying the files inside config2

in the files we submited, inside the cowboy directory there is an src folder we will call it src2 to avoid confusions. inside the empty project we generated there is a directory called src, replace the src folder with the src2 folder we submitted. in case you generated ther project with a different name then hello_cowboy you will need to change the files inside src2 folder that start with hello_cowboy to the correct name. the src2 is good for workers and master for the dns use the src folder inside the files we submited inside the dns folder


with the files we submitted, inside the cowboy directory there is a media folder, copy it into the cowboy project

make sure you generated server for master worker1 worker2 worker3 and dns

*how to run the whole project
here we explain how to start each type of machine 

run the dns first next the master only then the workers
-dns
  -open terminal in the dns cowboy folder that you created and run "make clean" (do not skip) and then  "make run"
  -go the backend folder in the files we submited, compile the dns_module
  * if you change the name of the dns node from dns_node you need to change the commands
  run the following:
  - erl -sname dns_node -setcookie hello_cowboy
  - dns_module:start({dns_node,"",""}).

-master
  -open terminal in the master cowboy folder that you created and run "make clean" (do not skip) and then  "make run"
  -go the backend folder in the files we submited, compile the gen_server_module
  * if you change the name of the master node from master_node you need to change the commands
  run the following:
  - erl -sname master_node -setcookie hello_cowboy
  - gen_server_module:start({master,'master_node@127.0.0.1',"",'127.0.0.1',8080,"",dns_node,'dns_node@127.0.0.1'}).
  * you need to change the 127.0.0.1 to the correct ips
  for example 
  gen_server_module:start({master,'master_node@amit-Lenovo-B50-80',"",'amit-Lenovo-B50-80',8080,"",dns_node,'dns_node@amit-Lenovo-B50-80'}).

-worker1
   -open terminal in the worker1 cowboy folder that you created and run "make clean" (do not skip) and then  "make run"
   -go the backend folder in the files we submited, compile the gen_server_module
  * if you change the name of the worker1 node from worker1_node you need to change the commands
  run the following:
   -erl -sname worker1_node -setcookie hello_cowboy
   -gen_server_module:start({worker,'master_node@127.0.0.1',worker1_node,'127.0.0.1',8070,worker1,dns_node,'dns_node@127.0.0.1'}).
  * you need to change the 127.0.0.1 to the correct ips
  for example 
   gen_server_module:start({worker,'master_node@amit-Lenovo-B50-80',worker1_node,'amit-Lenovo-B50-80',8070,worker1,dns_node,'dns_node@amit-Lenovo-B50-80'}).

-worker2
   -open terminal in the worker2 cowboy folder that you created and run "make clean" (do not skip) and then  "make run"
   -go the backend folder in the files we submited, compile the gen_server_module
  * if you change the name of the worker2 node from worker2_node you need to change the commands
  run the following:
   -erl -sname worker2_node -setcookie hello_cowboy
   -gen_server_module:start({worker,'master_node@127.0.0.1',worker2_node,'127.0.0.1',8060,worker2,dns_node,'dns_node@127.0.0.1'}).
  * you need to change the 127.0.0.1 to the correct ips
  for example 
   gen_server_module:start({worker,'master_node@amit-Lenovo-B50-80',worker2_node,'amit-Lenovo-B50-80',8060,worker2,dns_node,'dns_node@amit-Lenovo-B50-80'}).

-worker3
   -open terminal in the worker3 cowboy folder that you created and run "make clean" (do not skip) and then  "make run"
   -go the backend folder in the files we submited, compile the gen_server_module
  * if you change the name of the worker3 node from worker3_node you need to change the commands
  run the following:
   -erl -sname worker3_node -setcookie hello_cowboy
   -gen_server_module:start({worker,'master_node@127.0.0.1',worker3_node,'127.0.0.1',8050,worker3,dns_node,'dns_node@127.0.0.1'}).
  * you need to change the 127.0.0.1 to the correct ips
  for example 
   gen_server_module:start({worker,'master_node@amit-Lenovo-B50-80',worker3_node,'amit-Lenovo-B50-80',8050,worker3,dns_node,'dns_node@amit-Lenovo-B50-80'}).


 -client the client must be served using python http server
  - go to the frontend directory in the submission files 
  go to the html file
  open it in editor change the ip in line 29 to the correct dns ip
	run 
  		if you have python3:
  			python3 -m http.server
  		if you have python2 run:
  			python -m SimpleHTTPServer 8000
  		the client will be available at localhost:8000
