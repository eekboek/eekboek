#!/usr/bin/perl -w
my $RCS_Id = '$Id: acc.pl,v 1.1 2005/07/31 22:18:58 jv Exp $ ';

# Skeleton for Getopt::Long.

# Author          : Johan Vromans
# Created On      : Sun Jul 31 23:35:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug  1 00:04:37 2005
# Update Count    : 6
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

# Package or program libraries, if appropriate.
# $LIBDIR = $ENV{'LIBDIR'} || '/usr/local/lib/sample';
# use lib qw($LIBDIR);
# require 'common.pl';

# Package name.
my $my_package = 'EekBoek';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $s_album;		# searching for album
my $s_artist;		# searching for artist
our $trace = 1;
our $verbose = 1;

# Development options (not shown with -help).
my $debug = 0;			# debugging
#my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Save options array (for restart).
my @opts = @ARGV;

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

our $config;

use Wx 0.15 qw[:allclasses];
use strict;

our $dbh;
our $app;
our $appname = $my_package;
my $appclass = lc($appname);

our $restart = 0;

package AccApp;

use base qw(Wx::App);
use strict;

use MaintAccFrame;

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

sub OnInit {
    my( $self ) = shift;

    Wx::InitAllImageHandlers();

    my $frame = MaintAccFrame->new
      (undef, undef, $appname,
       [ max($config->xpos, 0),
	 max($config->ypos, 0) ],
       [ max($config->xwidth, 50),
	 max($config->ywidth, 50) ],
       undef,
       $appname);

    $frame->SetTitle("EekBoek: Grootboekrekeningen");

    $self->SetTopWindow($frame);
    $::app->{TOP} = $frame;

    $frame->Show(1);
    $frame->SetSize([ max($config->xwidth, 50),
		      max($config->ywidth, 50) ]);

    ::showtips($config->showtips);

    return 1;
}

sub OnExit {
    main::exit();
}

# end of class AccApp

package main;

use Wx qw(wxID_HIGHEST);

my $next_id;
sub next_id {
    $next_id ||= wxID_HIGHEST;
    ++$next_id;
}

sub set_status {
    my ($text, $ix) = @_;
    return unless $app && $app->{TOP} && $app->{TOP}->{acc_frame_statusbar};
    $app->{TOP}->{acc_frame_statusbar}->SetStatusText($text, $ix||0);
}

sub exit {
    store_state();
    if ( $restart ) {		# for development
	exec($^X, $0, @opts);
    }
}

sub showtips {
    if ( shift ) {
	my $t = Wx::CreateFileTipProvider("/etc/passwd", $config->lasttip);
	$config->showtips(Wx::ShowTip($app->{TOP}, $t, $config->showtips) || 0);
	$config->lasttip($t->GetCurrentTip);
    }
}

################ Configuration / State ################

sub init_state {
    use AppConfig qw(:argcount);
    $config = AppConfig->new();

    # Predefine config variables.
    $config->define("xpos",   { DEFAULT =>  50, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("ypos",   { DEFAULT =>  50, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("xwidth", { DEFAULT => 450, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("ywidth", { DEFAULT => 450, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("sash1",  { DEFAULT => 400, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("showtips", { DEFAULT => 1, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("lasttip", { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $config->define("expand", { ARGCOUNT => ARGCOUNT_HASH });

    # Load config (actually, state) file.
    my $f = $ENV{HOME} . "/.$appclass/state_$my_name";
    $config->file($f) if -f $f;
}

sub store_state {
    my $f = $ENV{HOME} . "/.$appclass/state_$my_name";
    mkdir($ENV{HOME} . "/.$appclass") unless -d $ENV{HOME} . "/.$appclass";
    open (my $cfg, ">$f");

    my %vars = $config->{STATE}->varlist(".");
    #my %vars = %{$config->{STATE}->{VARIABLE}};  # voids warranty

    my $p = sub { $_[0] eq "" ? '"<empty>"' : $_[0] };

    while ( my ($var, $value) = each(%vars) ) {
	unless ( ref($value) ) {
	    print $cfg ("$var = ", $p->($value), "\n");
	}
	elsif ( ref($value) eq 'ARRAY' ) {
	    foreach my $v ( @$value ) {
		print $cfg ("$var = $v\n");
	    }
	}
	elsif ( ref($value) eq 'HASH' ) {
	    while ( my($k,$v) = each(%$value) ) {
		print $cfg ("$var = $k=$v\n");
	    }
	}
    }

    close($cfg);
}


################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'album=s'	=> \$s_album,
		     'artist=s'	=> \$s_artist,
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace!'	=> \$trace,
		     'help|?'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_ident() if $ident;
}

sub app_ident {
    print STDERR ("This is $my_package [$my_name $my_version]\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    print STDERR <<EndOfUsage;
Usage: $0 [options] [file ...]
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    CORE::exit $exit if defined $exit && $exit != 0;
}

################ ################

unless(caller){
#	my $local = Wx::Locale->new("English", "en", "en"); # replace with ??
#	$local->AddCatalog("acc"); # replace with the appropriate catalog name


    use EB::Globals;
    use EB::DB;

    init_state();

    $::dbh = EB::DB->new(trace => $ENV{EB_SQL_TRACE});

    my $acc = AccApp->new();
    $acc->MainLoop();
}
