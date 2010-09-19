# activity_logger

[http://github.com/goerz/activity_logger](http://github.com/goerz/activity_logger)

Author: [Michael Goerz](http://michaelgoerz.net)

Collection of scripts to log and analyze computer usage on Mac OS X

`activity_logger.pl` runs in the background and monitors when the computer is
active or idle, and which program is in the foreground. It will store this data
in a log file.

Several scripts are provided to aid in the analysis of the logged data.

This code is licensed under the [GPL](http://www.gnu.org/licenses/gpl.html)

## Install ##

Store the `activity_logger.pl` script anywhere in your `$PATH`. Edit it to set
the user to monitor and the location where log files should be stored.

Run it in the background by setting a launch agent. For example put a file
`net.michaelgoerz.activity_logger.plist` in `~/Library/LaunchAgents` with the
following content (adapt to your home directory path):

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>KeepAlive</key>
    	<true/>
    	<key>Label</key>
    	<string>net.michaelgoerz.activity_logger</string>
    	<key>ProgramArguments</key>
    	<array>
    		<string>/Users/goerz/bin/activity_logger.pl</string>
    	</array>
    </dict>
    </plist>

You can also do this with [Lingon](http://lingon.sourceforge.net/).

Note that that this software will only work on Mac OS X.

## Usage ##

### Activity Logger
Keep `activity_logger.pl` running in the background (see above).  Information
about the system activity will be stored in a (monthly) log file.  Each line in
the log file is a "switching event". There are three columns. The first column
is the time stamp in epoch second, the second column is an integer code ('1'
for 'computer is active', '0' for 'computer is idle', '-1' for 'computer is
off/sleeping or activity_logger.pl is not running'). The third column is the
name of the active application, in the case that the computer is active. Each
event entry marks the start of that event; an event ends with the start of the
following event.
