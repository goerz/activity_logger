#!/usr/bin/perl -w
use strict;

# Usage example:
#   cat *.log | actfilter.pl --from="21/dec/93 17:05" --to="21 dec 17:05" 

# Filter out those lines from an activity log file that are note between --from
# and --to

use Getopt::Long;
use Date::Parse;

my $from_epoch_sec = 0;
my $to_epoch_sec = 1e11;


my $from_time = "";
my $to_time = "";
my $result = GetOptions ("from=s" => \$from_time,
                         "to=s"   => \$to_time);

if ($from_time ne ""){
    $from_epoch_sec = str2time($from_time);
}
if ($to_time ne ""){
    $to_epoch_sec = str2time($to_time);
}

while (<STDIN>){
    if ( /^([0-9]+)\t(0|1|-1)\t.*$/ ){
        if ( ($1 >= $from_epoch_sec) and ($1 <= $to_epoch_sec) ){
            print;
        }
    } else {
        die ("Couldn't parse line:\n$_");
    }
}
