#!/usr/bin/perl -w
use strict;

# Usage example:
#   cat *.log | plot_activitymatrix.pl out.tex && pdflatex out.tex

# Create a plot of activity over time and day

use Getopt::Long;
use Date::Parse;

my $hheight = 1;
my $dwidth = 1;
my $color = 'red';

GetOptions ("hheight=f"   => \$hheight,
            "dwidth=f" => \$dwidth,
            "color=s"  => \$color);

my $outfile = pop(@ARGV);
open(TEX, ">$outfile") or die("Couldn't open $outfile\n");

my @weekday = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

print TEX
'\documentclass{minimal}
\usepackage{tikz}
\usepackage[T1]{fontenc}
\usepackage{tgadventor}
\renewcommand*\familydefault{\sfdefault}

\usepackage[active,tightpage]{preview}
\PreviewEnvironment{tikzpicture}
\setlength\PreviewBorder{2mm}

\begin{document}', "\n";

print TEX '\begin{tikzpicture}[]', "\n";

my $prev_status = 0;
my $act_start_time = 0;
my $current_day = '';
my $day_number = 0;
my $acumulated_day_activity = 0;

my $x_offset_per_day = 0.1; # extra vertical space to add per day
my $global_x_offset = 0; # extra space for spreading out activity boxes


sub draw_activity_box{
    my $day = shift;   # column in which to print (1 = first day)
    my $start = shift; # start of activity (seconds since 00:00)
    my $stop = shift;  # end of activity (seconds since 00:00)
    $day = $day - 1;
    my $nw_x = $day * $dwidth + $global_x_offset;
    my $nw_y = $hheight * $stop / 3600;
    my $sw_x = $day * $dwidth + $global_x_offset;
    my $sw_y = $hheight * $start / 3600;
    my $se_x = ($day + 1) * $dwidth + $global_x_offset;
    my $se_y = $hheight * $start / 3600;
    my $ne_x = ($day + 1) * $dwidth + $global_x_offset;
    my $ne_y = $hheight * $stop / 3600;
    print TEX "\\draw[fill=$color] ($sw_x,$sw_y) -- ($se_x,$se_y) -- ($ne_x, $ne_y) -- ($nw_x, $nw_y) -- ($sw_x, $sw_y) -- cycle;\n";
}

while (<STDIN>){
    if ( /^([0-9]+)\t(0|1|-1)\t.*$/ ){
        my ($sec,$min,$hour,$day,
            $month,$year,$wday,$yday,$isdst) = localtime($1);
        $month += 1;
        $year += 1900;
        my $date = sprintf("%04i-%02i-%02i", $year, $month, $day);
        if ($date ne $current_day){ # it's a new day
            if ($prev_status == 1){
                # finish up previous day
                my $sds = str2time("$current_day 00:00:00"); # start of day
                draw_activity_box($day_number, $act_start_time-$sds, 24*3600);
                $acumulated_day_activity += 24 * 3600 - $act_start_time + $sds;
                $act_start_time = $sds + 24 * 3600;
            }
            my $dayname = $weekday[int($wday)];
            print TEX "\\node[below, rotate=90] at (",
                      $day_number * $dwidth + $global_x_offset,
                      ",-1.5) {$date \$\\cdot\$ $dayname};\n";
            $current_day = $date;
            $day_number += 1;
            if ($acumulated_day_activity > 0){
                print TEX "\\node[above, right, rotate=90] at (",
                      ($day_number-1.5) * $dwidth + $global_x_offset, ",",
                      24 * $hheight + 0.5,
                      ") {(\\kern2pt",
                      sprintf("%.1f", $acumulated_day_activity / 3600),
                      " h\\kern2pt)};\n";
                $acumulated_day_activity = 0;
            }
            $global_x_offset += $x_offset_per_day;
        }
        if ($2 == 1) { # switch to active
            if ($prev_status == 0){
                $act_start_time = $1;
            }
            $prev_status = 1;
        } else { # switch to inactive
            if ($prev_status == 1){
                my $sds = str2time("$current_day 00:00:00"); # start of day
                draw_activity_box($day_number, $act_start_time-$sds, $1-$sds);
                $acumulated_day_activity += $1 - $act_start_time;
            }
            $prev_status = 0;
        }
    } else {
        die ("Couldn't parse line:\n$_");
    }
}

# y-axis
my $h = 0;
while ($h<=24){
    my $y = $h * $hheight;
    print TEX "\\draw (-0.1,$y) -- (-0.3, $y) node[left] {$h};";
    $h += 1;
}

print TEX '\end{tikzpicture}', "\n";
print TEX '\end{document}', "\n";

close TEX;
