#!/usr/bin/perl -w
#
# solsar.pl
# 7 Sep 09, ver 0.01, http://90kts.com
#
# USAGE:    solsar.pl filepath [-interval]
#
#           filepath     # path to output csv file
#           interval     # optional interval, default 5 seconds
use strict;
use Time::Local;

# basic args
my $filepath = $ARGV[0];
my $interval = $ARGV[1] || 5;    # default 5 seconds

# exit unless output csv file specified
&usage unless $filepath;

# open output csv file for appending
open( FILE, ">> $filepath" )
  or die "Couldn't open $filepath for writing: $!\n";

# globals
my @keys        = ();
my @vals        = ();
my $time        = "";
my $key_counter = 0;
my $val_counter = 0;
my %groups      = ();
my %index       = ();
my $os          = "$^O"; # operating system
my $hostname    = `hostname`;
chomp $hostname;

# make stdout hot
local $| = 1;

# avoid zombies, ignore deceased <defunct> children
$SIG{CHLD} = 'IGNORE';

# launch child processes
my $pid = &launch;

# main
while () {

  while (<SAR>) {
    next if /SunOS/;      # ignore headers
    last if /Average/;    # ignore averages

    my @this = split( /\s+/, $_ );
    foreach (@this) {
      # ignore timestamps
      next if /\d+:\d+:\d+/;

      # if it's not a digit then it's a key
      if ( ( $_ !~ /\d+/ ) and ( length($_) > 0 ) ) {
        $keys[$key_counter] = $_;
        $key_counter++;
      }

      # otherwise it's a value
      elsif ( $_ =~ /\d+/ ) {
        $vals[$val_counter] = $_;
        $val_counter++;
      }

      # if the number of values = number of keys
      # then we have a full set of metrics
      if ( $key_counter == $val_counter ) {

        # group into different classes based on metric
        foreach my $key (@keys) {
          &group_class( $key, "buffer" )
            if $key =~
              /bread|lread|%rcache|bwrit|lwrit|%wcache|pread|pwrit/;
          &group_class( $key, "system_calls" )
            if $key =~ /scall|sread|swrit|fork|exec|rchar|wchar/;
          &group_class( $key, "paging" )
            if $key =~ /pgout|pgfree|pgscan|ufs_ipf/;
          &group_class( $key, "kma" )
            if $key =~ /sml_mem|alloc|fail|lg_mem/;
          &group_class( $key, "page_faults" )
            if $key =~ /atch|pgin|pflt|vflt|slock/;
          &group_class( $key, "queue" )
            if $key =~ /runq|swpq|swpoc|freemem|freeswap/;
          &group_class( $key, "cpu" )
            if $key =~ /%usr|%sys|%wio|%idle/;
          &group_class( $key, "inodes" )
            if $key =~ /proc-sz|inod-sz|file-sz|lock-sz/;
          &group_class( $key, "swap" )
            if $key =~ /swpin|swpot|bswin|bswot|pswch/;
        }

        # print values for each class
        $time = timelocal( localtime() );
        &print_class("buffer");
        &print_class("system_calls");
        &print_class("paging");
        &print_class("kma");
        &print_class("page_faults");
        &print_class("queue");
        &print_class("cpu");
        &print_class("inodes");
        &print_class("swap");

        # reset
        $val_counter = 0;
        @vals        = ();
        %groups      = ();
      }    # end if
    }    # end for
  }    # end while
  close(SAR);

  # relaunch SAR to keep running forever
  &relaunch();
} # end main

# close output csv file
close(FILE);

# subs
sub group_class() {
  my $key   = $_[0];
  my $class = $_[1];
  @index{@keys} = ( 0 .. $#keys );
  my $index = $index{$key};
  push( @{ $groups{$class} }, $index );
}

sub print_class() {
  my $class   = $_[0];
  my @results = ();
  @results = @{ $groups{$class} };
  my @sliced_keys = @keys[@results];
  my @sliced_vals = @vals[@results];
  print FILE $hostname . "_"
    . $os . "_sar_"
    . $class . " "
    . join( ":", @sliced_keys ) . " "
    . $time . "000:"
    . join( ":", @sliced_vals ) . "\n";
}

sub launch() {
  # piped open of sar
  return open( SAR, "/usr/bin/sar -abcgkmpqruvw $interval 100|" )
    or die "Can't initialize sar: $!\n";
}

sub relaunch() {
  # check if child pid is still running
  my $pidinfo = `ps -ef | grep $pid`;

  # relaunch if no child running
  $pid = &launch unless $pidinfo =~ /sar/;

  # reset globals
  @keys        = ();
  @vals        = ();
  $time        = "";
  $key_counter = 0;
  $val_counter = 0;
  %groups      = ();
  %index       = ();
}

sub usage {
  print STDERR <<END;
USAGE: solsar.pl filepath [-interval]
       
       filepath     # path to output csv file
       interval     # optional interval, default 5 seconds

  e.g. solsar.pl /var/tmp/solsar.csv
       solsar.pl /var/tmp/solsar.csv 5 
END
  exit 1;
}
