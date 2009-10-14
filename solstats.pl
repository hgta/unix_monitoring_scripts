#!/usr/bin/perl -w
#
# solstats.pl
# 8 Sep 09, ver 0.02, http://90kts.com
#
# USAGE:    solstats.pl filepath [-interval]
#
#           filepath     # path to output file
#           interval     # optional interval, default 5 seconds
use strict;
use POSIX qw(strftime);
use Time::Local;

# globals
my $filepath    = $ARGV[0];         # output file
my $interval    = $ARGV[1] || 5;    # interval in seconds
my $last_iostat = "";
my $last_mpstat = "";
my $os          = "$^O";            # operating system
my $hostname    = `hostname`;       # hostname
chomp $hostname;
local $| = 1;                       # stdout is hot
my $pid_prstat = 9999;             # kiddy pids ...
my $pid_iostat = 9999;
my $pid_vmstat = 9999;
my $pid_mpstat = 9999;
my $pid_nistat = 9999;
my $counter = 0;
my $first_iostat = "true";
my $first_vmstat = "true";
my $first_mpstat = "true";
my %prev_processes = ();
# avoid zombies, ignore deceased <defunct> kids
$SIG{CHLD} = 'IGNORE';

# exit unless output file specified
&usage unless $filepath;

# main
while () {

   # open processes and pipe output
   $pid_prstat = &launch_prstat($pid_prstat);
   $pid_iostat = &launch_iostat($pid_iostat);
   $pid_vmstat = &launch_vmstat($pid_vmstat);
   $pid_mpstat = &launch_mpstat($pid_mpstat);
   $pid_nistat = &launch_nistat($pid_nistat);

   # fudge day of week log rolling
   my $now         = time();
   my @days        = qw(sun mon tue wed thu fri sat);
   my $today       = $days[ ( localtime $now )[6] ];
   my $still_today = $days[ ( localtime $now - $interval )[6] ];
   if ( $today eq $still_today ) {
       open( FILE, ">>" . $filepath . "_" . $today );    # open and append
   }
   else {
       open( FILE, " >" . $filepath . "_" . $today );    # open and truncate
   }

   # loop through results
   my %curr_processes = ();
   open(PS_F, "ps -ef|");
    while (<PS_F>) {
      my $pid = $1 if $_ =~ /\w+\s+(\d+)/;
      my $cmd = $1 if $_ =~ /:\d+\s+(.+)/;
      $curr_processes{$pid} = "\"$cmd\"" if $pid;
    }
   close(PS_F);
   my @same_processes = ();
   my @noob_processes = ();
   foreach (keys %curr_processes) {
     push(@same_processes, $_) if exists $prev_processes{$_};
     push(@noob_processes, $_) unless exists $prev_processes{$_};
   }
   
   # discard all previous processes
   %prev_processes = ();
   
   # print out new processes
   my @data = ();
   foreach my $key ( @noob_processes ) {
     my $class = "process";
     my @headers = qw(pid command);
      my $instance = "";
     push(@data, $key);
     push(@data, $curr_processes{$key} );
     &printer( $now, $class, $instance, \@headers, \@data );
     # populate prev with new process
     $prev_processes{$key} = $curr_processes{$key};
   }
   
   foreach my $key ( @same_processes ) {
     # populate prev with same processes
     $prev_processes{$key} = $curr_processes{$key};
   }
   
   while (<PRSTAT>) {
       next if /PID|CPU/;
       last if /Total/;     # readline until last device
       my $class = "prstat";
       my @headers =
         qw(pid username size rss state pri nice time cpu process/nlwp);
       my @data = split(/\s+/);
       shift(@data);
       foreach my $i ( 2 .. 3 ) {    # turn M into KBytes
           $data[$i] = $1 * 1024 if $data[$i] =~ /(\d+)M/;
           $data[$i] = $1        if $data[$i] =~ /(\d+)K/;
       }
       my $instance = "";
       # only use following line for debugging
       push(@data, $curr_processes{$data[0]}) if exists($curr_processes{$data[0]});
       &printer( $now, $class, $instance, \@headers, \@data );
   }
   
   while (<IOSTAT>) {
       next if /extended device statistics|device/;
       my $class    = "iostat";
       my @headers  = qw(r/s w/s kr/s kw/s wait actv svc_t %w %b);
       my @data     = split(/,/);
       my $instance = "_" . shift(@data);
       &printer( $now, $class, $instance, \@headers, \@data ) if $first_iostat =~ /false/;
       last if /$last_iostat/;    # readline until last device
   }
   $first_iostat = "false";

   while (<VMSTAT>) {
       next if /memory|swap/;
       my $class = "vmstat";
       my @headers =
         qw(r b w swap free re mf pi po fr de sr f0 lf lf rm in sy cs us sy id);
       my @data = split(/\s+/);
       shift(@data);
       my $instance = "";
       &printer( $now, $class, $instance, \@headers, \@data ) if $first_vmstat =~ /false/;
       last;                      # readline once
   }
   $first_vmstat = "false";

   while (<MPSTAT>) {
       next if /CPU/;
       my $class = "mpstat";
       my @headers =
         qw(minf mjf xcal  intr ithr  csw icsw migr smtx  srw syscl usr sys  wt idl);
       my @data = split(/\s+/);
       shift(@data) if /^\s+/;
       my $instance = "_" . shift(@data);
       &printer( $now, $class, $instance, \@headers, \@data ) if $first_mpstat =~ /false/;
       last if /^$last_mpstat|^\s+$last_mpstat/;    # readline until last device
   }
   $first_mpstat = "false";

   while (<NISTAT>) {
       next if /Time/;
       last if /done/;    # readline until "done" text added to nicstat.pl
       my $class   = "nistat";
       my @headers = qw(rKB/s wKB/s rPk/s wPk/s rAvs wAvs Util Sat);
       my @data    = split(/\s+/);
       shift(@data);
       my $instance = "_" . shift(@data);
       &printer( $now, $class, $instance, \@headers, \@data );
   }

   close(FILE);
}

# subs
sub launch_prstat {
   if (&pidalive($_[0])) {
       return $_[0];
   }
   else {
       return open( PRSTAT, "prstat -acn 1000 $interval | " )
         or die " Can't initialize prstat : $! \n ";
   }
}

sub launch_iostat {
   if (&pidalive($_[0])) {
       return $_[0];
   }
   else {
       open( IOSTAT, "iostat -xr 1 1 | " )
         or die " Can't initialize iostat : $! \n ";
       while (<IOSTAT>) {
           ($last_iostat) = ( $_ =~ /^([\w\d]+),/ );
       }
       close(IOSTAT);

       return open( IOSTAT, "iostat -xr $interval | " )
         or die " Can't initialize iostat : $! \n ";
   }
}

sub launch_vmstat {
   if (&pidalive($_[0])) {
       return $_[0];
   }
   else {
       return open( VMSTAT, "vmstat $interval | " )
         or die " Can't initialize vmstat : $! \n ";
   }
}

sub launch_mpstat {
   if (&pidalive($_[0])) {
       return $_[0];
   }
   else {
       open( MPSTAT, "mpstat -p 1 1 | " )
         or die " Can't initialize mpstat : $! \n ";
       while (<MPSTAT>) {
           ($last_mpstat) = ( $_ =~ /([\d]+)/ );
       }
       close(MPSTAT);

       return open( MPSTAT, "mpstat -p $interval | " )
         or die " Can't initialize mpstat : $! \n ";
   }
}

sub launch_nistat {
   if (&pidalive($_[0])) {
       return $_[0];
   }
   else {
       return open( NISTAT, "./nicstat.pl $interval | " )
         or die " Can't initialize nistat : $! \n ";
   }
}

sub pidalive {
   my $pid     = $_[0];
   my $pidinfo = `ps -p $pid | tail -1`;
   if ($pidinfo !~ /PID/) {
     return 1;
   }
}

sub printer() {
   my ( $now, $class, $instance, $headers, $data ) = @_;
   my @headers = @$headers;
   my @data    = @$data;
   chomp(@data);

  # csv style
  # {hostname}_{operatingsystem}_{class}_[instance] {columns:...} {sampletime}:{values:...}
  print FILE $hostname . "_"
    . $os . "_"
    . $class
    . $instance . ","
    . join( ",", @headers ) . ","
    . $now
    . "000,"
    . join( ",", @data ) . "\n";
}

sub usage {
   print STDERR <<END;
USAGE: solstats.pl filepath [-interval]

      filepath     # path to output file
      interval     # optional interval, default 5 seconds

 e.g. solstats.pl /tmp/solstats
      solstats.pl /tmp/solstats 5
END
   exit 1;
}

