#!/usr/bin/perl -w
#
# perfstats.pl
# 27 Aug 09, ver 0.01
#
# USAGE:    perfstats.pl filepath [-interval]
#
#           filepath     # path to output csv file
#           interval     # optional interval, default 20 seconds
#
# DEPENDENCIES:
#  This script requires installation of sysstat,
#  which should be in the standard RHEL distro.
#  e.g. rpm -ivh sysstat-7.0.2-3.el5.i386.rpm
#
# FIELDS:
#  MEM  -> r, b, swpd, free, buff, cache, si, so, bi, bo, in, cs, us, sy, id, wa, st
#  DISK -> device, rrqm/s, wrqm/s, r/s, w/s, rkB/s, wkB/s, avgrq-sz, avgqu-sz, await, svctm, %util
#  CPU  -> proc, %user, %nice, %sys, %iowait, %irq, %soft, %steal, %idle, intr/s
#  NET  -> iface, rxpck/s, txpck/s, rxbyt/s, txbyt/s, rxcmp/s, txcmp/s, rxmcst/s

use strict;
use POSIX qw(strftime);

# args
my $filepath = $ARGV[0];
my $interval = $ARGV[1] || 20;    # default 20 seconds

# exit unless output csv file specified
&usage unless $filepath;

# write parent PID of this script to stdout for later kill
print "Process [$$] started\n";

# piped opens will automatically reap child processes
# could make it more simple just by using sar but some
# of these include additional metrics which are useful
open( MEM, "/usr/bin/vmstat -n $interval |" )
  or die "Can't initialize vmstat: $!\n";
open( DISK, "/usr/bin/iostat -xdk $interval |" )
  or die "Can't initialize iostat: $!\n";
open( CPU, "/usr/bin/mpstat $interval |" )
  or die "Can't initialize mpstat: $!\n";
open( NET, "/usr/bin/sar -n DEV $interval 0 |" )
  or die "Can't initialize sar: $!\n";

# open output csv file for appending
open( FILE, ">> $filepath" )
  or die "Couldn't open $filepath for writing: $!\n";
local $| = 1;    # make stdout hot ...

# main
my $counter = 0; 
# use a counter to avoid printing first entries as these
# are typically averages since last boot on some OS's ...
while () {
    my $datetime = strftime( "%Y-%m-%d %H:%M:%S", gmtime );

    while (<MEM>) {
        next if /memory|free/;
        &printer( $datetime, "MEM", $_, 1 ) if $counter > 1;
        last; 
    }

    while (<DISK>) {
        next if /Linux|Device/;
        last if length($_) < 2;
        &printer( $datetime, "DISK", $_, 0 ) if $counter > 1;
    }

    while (<CPU>) {
        next if /Linux|CPU/;
        last if length($_) < 2;
        &printer( $datetime, "CPU", $_, 2 ) if $counter > 1;
        last; 
    }

    while (<NET>) {
        next if /Linux|IFACE/;
        last if length($_) < 2;
        &printer( $datetime, "NET", $_, 2 ) if $counter > 1;
    }
    $counter++;
}

# close output csv file
close(FILE);

# subs
sub printer() {
    my $datetime = $_[0];
    my $type     = $_[1];
    my $line     = $_[2];
    my $offset   = $_[3];
    my @this     = split( /\s+/, $line );
    my $this     = join( ", ", splice( @this, $offset ) );
    print FILE "$datetime, $type, ", $this, "\n" if length($line) > 1;
}

sub usage {
    print STDERR <<END;
USAGE: perfstats.pl filepath [-interval]
       
       filepath     # path to output csv file
       interval     # optional interval, default 20 seconds

  e.g. perfstats.pl /var/tmp/perfstats.csv
       perfstats.pl /var/tmp/perfstats.csv 5 
END
    exit 1;
}