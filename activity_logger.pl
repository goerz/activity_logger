#!/usr/bin/perl -w
use strict;
use IO::Handle;
use POSIX;
#use Proc::Daemon;

#Proc::Daemon::Init;
# Don't daemonize if you're running this as a launch agent!

use constant IDLE_TIMEOUT   => 600;  # seconds of inactivity after which an
                                     # idle status is recognized

use constant SLEEP_TIME     => 30;   # seconds to sleep between polling status

use constant MAX_LOG_DELTA  => 3600; # Put a point in the log file at least
                                     # every so many seconds

my $monitor_user = 'goerz';

my $log_folder = '/Users/'. $monitor_user . '/.activity_logs';

sub get_logfilename{
    my ($sec,$min,$hour,$mday,
        $month,$year,$wday,$yday,$isdst) = gmtime(time);
    $year += 1900;
    $month = sprintf("%02i", $month+1);
    return $log_folder . '/' . 'activity' . $year . '-' . $month .  '.log';
}

sub lock_logfile{
    my $log_file = shift;
    if ( -f "$log_file.lock"){
        open(LOCK, "$log_file.lock") or die ("Can't set lock\n");
        my $pid = <LOCK>;
        close LOCK;
        my $locking_process = `ps -p $pid`;
        if ($locking_process =~ /activity_logger/){
            exit(1) # another process is writing to the log file
        } else {
            system("rm -f $log_file.lock");
        }
    }
    open(LOCK, ">$log_file.lock") or die ("Can't set lock\n");
    print LOCK $$;
    close LOCK;
}

sub open_logfile{
    my $log_file = shift;
    lock_logfile($log_file);
    my $mtime = (stat $log_file)[9];
    open my($LOG), ">>", $log_file or die ("Can't open $log_file\n");
    $LOG->autoflush(1);
    if (defined($mtime)){
        print $LOG int($mtime) . "\t-1\t\n";
    }
    return $LOG;
}

my $system_is_active = 0;
my $user_is_logged_in = 1;

my $log_file = get_logfilename();
my $LOG = open_logfile($log_file);
my $front_app = '';

sub finish_logger{
    $LOG->close;
    unlink("$log_file.lock");
    exit;
}
$SIG{TERM} = \&finish_logger;

my $loop_timestamp = time;
my $last_logged = time;
while (1){
    my $new_logfile_name = get_logfilename();
    # start a new log file if we're passing to a new month
    if ($new_logfile_name ne $log_file){
        $LOG->close;
        unlink("$log_file.lock");
        $log_file = $new_logfile_name;
        $LOG = open_logfile($log_file);
    }
    open(IOREG, 'ioreg -c IOHIDSystem|') or die("Can't read ioreg\n");
    my $idle = 0.0;
    while (<IOREG>){
        if (/Idle.* ([0-9]+)$/){
            $idle=$1 / 1e9; # idle time in seconds
            last;
        }
    }
    close(IOREG);
    my $switched = 0;
    my $now = time;
    my $tz = strftime("%Z", localtime());
    if ($now - $loop_timestamp > 2*SLEEP_TIME){
        # computer must have just woken up from sleep mode (loop was paused)
        print $LOG int($loop_timestamp + 1) . "\t-1\t\n";
        $system_is_active = 0;
    }
    my $user = `stat -f%Su /dev/console`;
    $user =~ s/^.* //;
    $user =~ s/\s*$//;
    if ($user ne $monitor_user){
        if ($user_is_logged_in){
            print $LOG int($now) . "\t$tz\t-1\t\n";
            $last_logged = $now;
        }
        $user_is_logged_in = 0;
    } else {
        $user_is_logged_in = 1;
    }
    if ($user_is_logged_in){
        if ($idle > IDLE_TIMEOUT){
            if ($system_is_active){
                # switch from active to idle
                $switched = 1;
                $system_is_active = 0;
                print $LOG int($now - $idle) . "\t$tz\t0\t\n";
                $last_logged = $now;
            } elsif ($now - $last_logged > MAX_LOG_DELTA) {
                # we were idle before and are still idle now, but we should put
                # something in the log file just to keep it fresh
                print $LOG int($now) . "\t$tz\t0\t\n";
                $last_logged = $now;
            }
        } elsif ( ($idle <= IDLE_TIMEOUT) and not $system_is_active ) {
            # switch from idle to active
            $switched = 1;
            $system_is_active = 1;
        }
        if ($system_is_active){
            my $cur_front_app = `osascript -e 'tell application "System Events"' -e 'set frontApp to name of first application process whose frontmost is true' -e 'end tell'`;
            $cur_front_app =~ s/\s*$//;
            if (($cur_front_app ne $front_app) or ($switched)
            or  ($now - $last_logged > MAX_LOG_DELTA)){
                $front_app = $cur_front_app;
                print $LOG int($now - $idle - 1) . "\t$tz\t1\t".$front_app."\n";
                $last_logged = $now;
            }
        }
    } else {
        # Even if the user is not actively logged in, we should keep the log
        # file fresh
        if ($now - $last_logged > MAX_LOG_DELTA){
            print $LOG int($now) . "\t$tz\t-1\t\n";
            $last_logged = $now;
        }
    }
    $loop_timestamp = $now;
    sleep SLEEP_TIME;
}
