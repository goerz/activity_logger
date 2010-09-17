# activity_logger

[http://github.com/goerz/activity_logger](http://github.com/goerz/activity_logger)

Author: [Michael Goerz](http://michaelgoerz.net)

Collection of scripts to log and analyze computer usage on Mac OS X

`activity_logger.pl` runs in the background and monitors when the computer is
active or idle, and which program is in the foreground. It will store this data
in a log file.

This code is licensed under the [GPL](http://www.gnu.org/licenses/gpl.html)

## Install ##

Store the `activity_logger.pl` script anywhere in your `$PATH`. Edit it to set
the location where log files should be stored.

Note that that this software will only work on Mac OS X

## Usage ##

Start `activity_logger.pl` from the command line. It will start as a daemon.
Information about the system activity will be stored in a (monthly) log file.
Each line in the log file is a "switching event". There are three columns. The
first column is the time stamp in epoch second, the second column is an integer
code ('1' for 'computer is active', '0' for 'computer is idle', '-1' for
'computer is off/sleeping or activity_logger.pl is not running'). The third
column is the name of the active application, in the case that the computer is
active. Each event entry marks the start of that event; an event ends with the
start of the following event.
