#!/usr/bin/perl -w
use strict;
use IO::Handle;
#use Proc::Daemon;

# Don't daemonize if you're running this as a launch agent!

my $monitor_user = 'goerz';

my $timelimit = 3800;

sub notify{
    my $program_name = "/usr/local/bin/growlnotify -s -t 'Activity Logger Error' > /dev/null 2>&1";
    open(PIPE, "| $program_name") or die("Can't open pipe");
    print PIPE "Last activity was recorded more then $timelimit seconds ago\n";
    close(PIPE)
}

my $log_folder = '/Users/'. $monitor_user . '/.activity_logs';
my ($sec,$min,$hour,$mday,
    $month,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$month = sprintf("%02i", $month+1);
my $log_file = $log_folder . '/' . 'activity' . $year . '-' . $month .  '.log';

open(IN, $log_file) or die("Can't open $log_file\n");
my $timediff = $timelimit + 1;
while (<IN>){
    if ( /^([0-9]+)\t(0|1|-1)\t(.*)$/ ){
        $timediff = time() - $1;
    } else {
        die ("Couldn't parse line:\n$_");
    }
}
if ($timediff > $timelimit){
    notify();
}

close(IN);
