#!/usr/bin/perl -w
use strict;

# Usage example:
#   cat *.log | plot_activitytime.pl out.tex && pdflatex out.tex 

# Create a plot of activity over time

use Getopt::Long;

my $cm_per_hour = 0.7;
my $height = 3;
my $color = 'red';

GetOptions ("hour=f"   => \$cm_per_hour,
            "height=f" => \$height,
            "color=s"  => \$color);

my $outfile = pop(@ARGV);
open(TEX, ">$outfile") or die("Couldn't open $outfile\n");


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

print TEX "\\draw[fill=$color] (0,0) -- ";


my $t0 = 0;
my $t_stop = 0;
my $x_coord = 0;
while (<STDIN>){
    if ( /^([0-9]+)\t(0|1|-1)\t.*$/ ){
        if ($t0 == 0){
            $t0 = $1;
            $t_stop = $t0;
            if ($2 == 1){
                print TEX "(0,$height) -- ";
            }
            next;
        }
        $x_coord = $cm_per_hour * ($1 - $t0) / 3600;
        $t_stop = $1;
        if ($2 == 1) {
            if ($prev_status == 0){
                print TEX "($x_coord, 0) -- ($x_coord, $height) --";
            }
            $prev_status = 1;
        } else {
            if ($prev_status == 1){
                print TEX "($x_coord, $height) -- ($x_coord, 0) --";
            }
            $prev_status = 0;
        }
    } else {
        die ("Couldn't parse line:\n$_");
    }
}
$x_coord = $cm_per_hour * ($t_stop - $t0) / 3600;
if ($prev_status == 1){
    print TEX "($x_coord,$height) -- ";
} else {
    print TEX "($x_coord,0) -- ";
}

if ($prev_status == 1){
    print TEX "+(0, -$height) --";
}
print TEX "(0, 0) -- cycle;\n";

# y-axis
print TEX "\\node[left] at (0,$height){active};\n";

# x-axis
$x_coord += $cm_per_hour;
print TEX "\\node[below] at ($x_coord, -0.1) {hour};\n";
my $seconds_to_next_hour = 3600 - ($t0 % 3600);
my $axis_t = $t0 + $seconds_to_next_hour;
my $first = 1;
while ($axis_t <= $t_stop){
    my ($sec,$min,$hour,$day,
        $month,$year,$wday,$yday,$isdst) = localtime($axis_t);
    $year += 1900;
    $month += 1;
    my $date = sprintf("%04i-%02i-%02i", $year, $month, $day);
    my $x_coord = $cm_per_hour * ($axis_t - $t0) / 3600;
    print TEX "\\draw ($x_coord, 0) +(0,0.1) -- +(0,-0.1) node[below] {$hour};\n";
    if ($first or $hour == 0){
        $first = 0;
        print TEX "\\node[left, rotate=45] at ($x_coord,-0.8) {$date};\n";
    }
    $axis_t += 3600;
}

print TEX '\end{tikzpicture}', "\n";
print TEX '\end{document}', "\n";

close TEX;
