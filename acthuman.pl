#!/usr/bin/perl -w
use strict;

# Usage example:
#   cat *.log | acthuman.pl 

# Change time stamps to something human readable


while (<STDIN>){
    if ( /^([0-9]+)\t(0|1|-1)\t(.*)$/ ){
        my ($sec,$min,$hour,$day,
            $month,$year,$wday,$yday,$isdst) = localtime($1);
        $year = $year + 1900;
        my $time = sprintf("%04i-%02i-%02i %02i:%02i:%02i", 
                        $year, $month+1, $day, $hour, $min, $sec);
        print "$time\t$2\t$3\n";
    } else {
        die ("Couldn't parse line:\n$_");
    }
}
