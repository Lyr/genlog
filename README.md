genlog
=========

Just a random log generator.

It assembles entries from different files to make random messages, displayed in standard output.

Notifications can be displayed in error output.

# Detailled description
## Main algorithm
For n occurs do:

 - pick on line in each given files
 - write the assembled message in standard output

Optionnaly, each n occurs, perform a special treatment wich allow, for example, to send an aggregated message.

## Profile description
A profile must contains:

 - a *.sh file which overload some functions
 - n *.txt files which contain, in fact, assigned shell variables.

One of the assigned variables must be named _MESSAGE_. This is the one which will be printed in standard output.

Overloadable functions are:

 - \_on\_init
 - \_on\_stop
 - \_on\_log
 - \_on\_batch_full

See default profile as an example.

# Current profiles
## default

The generator launches two types of log which are:

 - raw log wich join a user, a message/code and a numerical value in range [0 TO 20].
 - aggregated event which show statistical informations of the last batch raw logs.

uid.list can be modified in 'uid.lst'

message/code.list can be modified in 'messages.lst'

A logstash configuration file is given as an example to feed an elasticsearch database.

## cw
Another example of a simple generator.

# Usage
    genlog.sh [-h] [-m <int_value>] [-t <decimal_value>] [-b <int_value> [-r]] [-p <profile>] [-c <es-host>])
      -m: Number of raw log to fire (Default is 5000)
      -t: Sleep time between each raw log (Default is 0.5 seconds)
      -b: batch size (default is none). Perform a special action each time the batch size is reached.
      -r: Randomize batch size (b is mandatory and its value will be the maximum random value).
      -p: Profile name. Must match a directory name under resources (Default is default).
      -c: Elasticsearch Host where the log are be sended with the curl command line with -XPOST argument.

