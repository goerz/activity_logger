#!/usr/bin/perl -w
use strict;

# Usage example:
#   cat *.log | plot_usage.pl out.tex && pdflatex out.tex 

# Create a plot of usage per day

use Getopt::Long;
use Date::Parse;

my $hheight = 1;
my $dwidth = 1;
my $percent = 2;
my $debug='';

GetOptions ("hheight=f"   => \$hheight,  # height (cm) of one hour
            "dwidth=f" => \$dwidth,      # width (cm) of one day
            "percent=f"  => \$percent,
            "debug" => \$debug);  # min % of a day an app must be used

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

my %activity_data;
my %colors;
my %app_usage;

my $plot_start_time = 0; # epoch seconds of first data point
my $plot_stop_time = 0;  # epoch seoncds of last data point

my $act_start_time = 0;

my $current_program = '';
my $prev_status = 0;

my $total_usage_time = 0; # total accumulated usage time

my $max_total = 0; # the longest usage on any day, in seconds
my @totals; # array of usage (in seconds) per day

my $x_offset_per_day = 0.1; # extra vertical space to add per day
my $global_x_offset = 0; # extra space for spreading out activity boxes

sub draw_activity_box{
    my $day = shift;   # column in which to print (1 = first day)
    my $start = shift; # start of activity (seconds since 00:00)
    my $stop = shift;  # end of activity (seconds since 00:00)
    my $color = shift; # color to draw box in
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

sub get_usagetime_for_day{ # usage in seconds
    my $year = shift;
    my $month = shift;
    my $day = shift;
    if (exists $activity_data{$year} 
    and exists $activity_data{$year}->{$month}
    and exists $activity_data{$year}->{$month}->{$day}){
        my $result = 0;
        foreach my $app (keys(%{$activity_data{$year}->{$month}->{$day}})){
            $result += $activity_data{$year}->{$month}->{$day}->{$app};
        }
        return $result;
    } else {
        return 0;
    }
}


sub hsv2rgb{
    my $h = shift; # hue (in [0,360])
    my $s = shift; # saturation (in [0,1])
    my $v = shift; # value = brightness (in [0,1])
    my ($red, $green, $blue);
    if($v == 0) {
        ($red, $green, $blue) = (0, 0, 0);
    } elsif($s == 0) {
        ($red, $green, $blue) = ($v, $v, $v);
    } else {
        my $hf = $h / 60;
        my $i = int($hf);
        my $f = $hf - $i;
        my $pv = $v * (1 - $s);
        my $qv = $v * (1 - $s * $f);
        my $tv = $v * (1 - $s * (1 - $f));
        if($i == 0) {
            $red = $v;
            $green = $tv;
            $blue = $pv;
        } elsif($i == 1) {
            $red = $qv;
            $green = $v;
            $blue = $pv;
        } elsif($i == 2) {
            $red = $pv;
            $green = $v;
            $blue = $tv;
        } elsif($i == 3) {
            $red = $pv;
            $green = $qv;
            $blue = $v;
        } elsif($i == 4) {
            $red = $tv;
            $green = $pv;
            $blue = $v;
        } elsif($i == 5) {
            $red = $v;
            $green = $pv;
            $blue = $qv;
        } elsif($i == 6) {
            $red = $v;
            $blue = $tv;
            $green = $pv;
        } elsif($i == -1) {
            $red = $v;
            $green = $pv;
            $blue = $qv;
        } else {
            die('Invalid HSV -> RGB conversion.')
        }
    }
    return ($red, $green, $blue);
}

# collect data
while (<STDIN>){
    if ( /^([0-9]+)\t(0|1|-1)\t(.*)$/ ){
        $plot_start_time = $1 if ($plot_start_time == 0);
        $plot_stop_time = $1;
        my ($sec,$min,$hour,$day,
            $month,$year,$wday,$yday,$isdst) = localtime($1);
        $month += 1;
        $year += 1900;
        my $date = sprintf("%04i-%02i-%02i", $year, $month, $day);
        if ($2 == 1) { # switch to active
            if ($prev_status == 1){
                $activity_data{$year}->{$month}->{$day}->{$current_program} 
                += $1 - $act_start_time;
            }
            $act_start_time = $1;
            $current_program = $3;
            $prev_status = 1;
        } else { # switch to inactive
            if ($prev_status == 1){
                $activity_data{$year}->{$month}->{$day}->{$current_program} 
                += $1 - $act_start_time;
            }
            $prev_status = 0;
        }
    } else {
        die ("Couldn't parse line:\n$_");
    }
}

# combine rare apps in "Other", build color dict, and app_usage dict
foreach my $year (keys(%activity_data)){
    foreach my $month (keys(%{$activity_data{$year}})){
        foreach my $day (keys(%{$activity_data{$year}->{$month}})){
            my $total = get_usagetime_for_day($year, $month, $day);
            $max_total = $total if ($total > $max_total);
            $total_usage_time += $total;
            push(@totals, $total);
            foreach my $app (keys(%{$activity_data{$year}->{$month}->{$day}})){
                my $app_t = $activity_data{$year}->{$month}->{$day}->{$app};
                if ($app_t < ($percent / 100.0) * $total){
                    delete($activity_data{$year}->{$month}->{$day}->{$app});
                    $activity_data{$year}->{$month}->{$day}->{'Other'} 
                    += $app_t;
                } else {
                    $app_usage{$app} += $app_t;
                    $colors{$app} = 'red';
                }
            }
        }
    }
}

my @apps_by_usage = sort{$app_usage{$b} <=> $app_usage{$a}} keys %app_usage;
push(@apps_by_usage, 'Other');

# fill color pallette
my $hue = 5;
my $hue_step = 360.0 / @apps_by_usage;
my $brightness = 1;
my $saturation = 1;
foreach my $app (@apps_by_usage){
    my ($r, $g, $b) = hsv2rgb($hue, $saturation, $brightness);
    print TEX "\\definecolor{$app}{rgb}{$r,$g,$b}\n";
    $colors{$app} = $app;
    $hue = ($hue + $hue_step) % 360;
    $brightness -= 0.1;
    $brightness += 0.3 if ($brightness <= 0.7);
    $saturation -= 0.2;
    $saturation += 0.3 if ($saturation <= 0.7);
}

# print plot
my $day_number = 0;
my $t = $plot_start_time;
while ($t <= $plot_stop_time){
    my ($sec,$min,$hour,$day,
        $month,$year,$wday,$yday,$isdst) = localtime($t);
    $t -= $hour * 3600  + $min*60 + $sec;
    $month += 1;
    $year += 1900;
    my $date = sprintf("%04i-%02i-%02i", $year, $month, $day);
    my $usage_seconds = 0; # total seconds of usage on current day
    foreach my $app (@apps_by_usage){
        if (exists $activity_data{$year}->{$month}->{$day}->{$app}){
            my $app_seconds = $activity_data{$year}->{$month}->{$day}->{$app};
            draw_activity_box($day_number, $usage_seconds, 
                              $usage_seconds + $app_seconds, $colors{$app});
            $usage_seconds += $app_seconds;
        }
    }
    $day_number += 1;
    my $dayname = $weekday[int($wday)];
    my $hours_for_day = get_usagetime_for_day($year, $month, $day) / 3600;
    print TEX "\\node[above, rotate=90] at (",
            ($day_number-0.2) * $dwidth + $global_x_offset, ",", 
            $hours_for_day * $hheight + 1.0, 
            ") {(\\kern2pt", sprintf("%.1f", $hours_for_day), 
            " h\\kern2pt)};\n";
    print TEX "\\node[below, rotate=90] at (", 
                ($day_number - 0.8) * $dwidth + $global_x_offset,  
                ",-1.5) {$date \$\\cdot\$ $dayname};\n";
    $t += 24 * 3600;
    $global_x_offset += $x_offset_per_day;
}

# statistics
my $total_days = ($plot_stop_time - $plot_start_time) / (24 * 3600);
my $avg_usage_per_day = ($total_usage_time / 3600) / $total_days;
my $median;
@totals = sort @totals;
my $full_days = @totals;
if ($full_days % 2 ==0){
    $median = ( $totals[int($full_days / 2)-1] 
              + $totals[int($full_days / 2)] ) / 2;
} else {
    $median = $totals[int($full_days / 2)];
}
$median = $median / 3600;
my $from_tstring = localtime($plot_start_time);
my $to_tstring = localtime($plot_stop_time);
print "*** Analysis ***\n";
print sprintf("From : %s\n", $from_tstring);
print sprintf("To   : %s\n", $to_tstring);
print sprintf("Days : %.2f\n", $total_days);
print sprintf("Total usage (hours)        : %.2f\n", $total_usage_time/3600);
print sprintf("Average use per day (hours): %.2f\n", $avg_usage_per_day);
print sprintf("Median use per day (hours) : %.2f\n", $median);

# legend
my $available_space = $hheight * $max_total/3600;
my $needed_space = 0.5 * @apps_by_usage;
my $ly0 = ($available_space - $needed_space) / 2.0;
my $i = 0;
foreach my $app (@apps_by_usage){
    print TEX "\\draw[fill=$colors{$app}] (", 
          ($day_number+1) * $dwidth + $global_x_offset, ",", $ly0 + $i*0.5, 
          ") rectangle +(0.4,0.4) +(0.4,0.2) node[right]{$app};\n";
    $i += 1;
}

# y-axis
my $h = 0;
while ($h<=int($max_total/3600) + 1){
    my $y = $h * $hheight;
    print TEX "\\draw (-0.1,$y) -- (-0.3, $y) node[left] {$h};";
    $h += 1;
}

print TEX '\end{tikzpicture}', "\n";
print TEX '\end{document}', "\n";

if ($debug){
    use Data::Dumper;
    print "\%activity_data: ";
    print Dumper(\%activity_data);
}

close TEX;
