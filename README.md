# improved-succotash
stuff just happend as i figured out that automysqlbackup doesn't let you set destination port for your SQL server...


*use wrapper to wrap around succotash if you have multiple databases to dump 


*gentle-checker might be used with nagios or something. needs wrapper conf in order to work.


*broken-differ, well, diffs mysql output vs. what you have on disk. needs to be rewritten because it didnt work well. 

configuration files included in conf
# install
clone repo and run install.bash


alternatively, copy executables to $PATH or whatever you like.