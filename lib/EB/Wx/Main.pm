#!/usr/bin/perl -w
my $RCS_Id = '$Id: Main.pm,v 1.1 2008/02/04 23:25:49 jv Exp $ ';

package main;

our $cfg;
our $state;
our $app;
our $dbh;

package EB::Wx::Main;

# Author          : Johan Vromans
# Created On      : Sun Jul 31 23:35:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Feb  4 13:50:29 2008
# Update Count    : 229
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

################ Configuration ################

# This will set up the config at 'use' time.
use EB::Config 'EekBoek';

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $trace = 0;
my $verbose = 1;
my $precmd;

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $test = 0;			# test mode.

# Save options array (for restart).
my @opts = @ARGV;

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use base qw(Exporter);
our @EXPORT = qw(run);

# Note: a non-null $app is a signal for EB to load the GUI version of
# the Locale module.
BEGIN { $app = {} }

use EB;

use Wx 0.25 qw[:everything];
use strict;

my $appname = $my_package;
my $appclass = lc($appname);

our $restart = 0;

use base qw(Wx::App);
use strict;

use EB::Wx::MainFrame;

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

sub OnInit {
    my( $self ) = shift;

    # Since Wx::Bitmap cannot be convinced to use a search path, we
    # need a stronger method...
    my $wxbitmapnew = \&Wx::Bitmap::new;
    no warnings 'redefine';
    *Wx::Bitmap::new = sub {
	# Only handle Wx::Bitmap->new(file, type) case.
	goto &$wxbitmapnew if @_ != 3 || -f $_[1];
	my ($self, @rest) = @_;
	$rest[0] = EB::findlib("Wx/icons/".$rest[0]);
	$wxbitmapnew->($self, @rest);
    };
    use warnings 'redefine';

    Wx::InitAllImageHandlers();

    my $frame = EB::Wx::MainFrame->new
      (undef, undef, $appname,
       wxDefaultPosition, wxDefaultSize,
       undef,
       $appname);

    $self->SetTopWindow($frame);
    $app->{TOP} = $frame;
    $frame->sizepos_restore("mainw");
    $frame->Show(1);
    showtips($state->showtips);

    $frame->command($precmd) if $precmd;

    return 1;
}

sub OnClose {
    goto &OnExit;
}

sub OnExit {
    my ($self) = @_;
    app_exit();
}

sub app_exit {
    store_state();
    if ( $restart ) {		# for development
	warn("=== restarting ===\n");
	exec($^X, $0, @opts);
    }
}

sub showtips {
    if ( shift ) {
#	require EB::Wx::Tools::TipProvider;
#	my $t = EB::Wx::Tools::TipProvider->new($state->lasttip);
	my $t = Wx::CreateFileTipProvider(EB::findlib("tips.txt"), $state->lasttip);
	$state->showtips(Wx::ShowTip($app->{TOP}, $t, $state->showtips) || 0);
	$state->lasttip($t->GetCurrentTip);
    }
}

################ Configuration / State ################

sub init_state {
    use EB::Wx::AppConfig qw(:argcount);
    $state = EB::Wx::AppConfig->new();

    # Predefine config variables.
    $state->define("app",      { ARGCOUNT => ARGCOUNT_ONE });
    $state->define("appname",  { DEFAULT => $appname, ARGCOUNT => ARGCOUNT_ONE });

    $state->define("trace",    { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("verbose",  { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("debug",    { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });

    $state->define("showsplash", { DEFAULT => 1, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("showtips", { DEFAULT => 1, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("lasttip",  { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("lastdb",   { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("bky",      { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("expfile",  { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("expdir",   { DEFAULT => 0, ARGCOUNT => ARGCOUNT_ONE });

    # Windows that remember their size/positions.
    my @windows =
      ( "mainw",		# MainFrame
	"prpw",			# Properties...
	"prefw",		# Preferences...
	"accw",			# Maint -- AccPanel
	"relw",			# Maint -- RelPanel
	"btww",			# Maint -- BtwPanel
	"stdw",			# Maint -- MStdAccPanel
	"rprfw",		# Report -- RepPrf
	"rbalw",		# Report -- RepBalRes
	"robalw",		# Report -- RepBalRes
	"rresw",		# Report -- RepBalRes
	"rgbkw",		# Report -- RepGbk
	"rjnlw",		# Report -- RepJnl
	"rbtww",		# Report -- RepBtw
	"rdebw",		# Report -- RepDebCrd
	"rcrdw",		# Report -- RepDebCrd
	"rbrpw",		# Report -- BalResProof -- Preferences
	"ropnw",		# Report -- Openstaand
	"ivw",			# Bookings -- IV
	"bkmw",			# Bookings -- BKM
      );

    foreach my $w ( @windows ) {
	$state->define($w, { ARGCOUNT => ARGCOUNT_HASH });
	$state->$w->{$_} = -1 foreach qw(xpos ypos xwidth ywidth);
    }

    $state->define("accsash",  { DEFAULT => 400, ARGCOUNT => ARGCOUNT_ONE });
    $state->define("accexp",   { ARGCOUNT => ARGCOUNT_HASH });

    # Load config (actually, state) file.
    my $f = $ENV{HOME} . "/.$appclass/$my_name";
    $state->file($f) if -f $f;
}

sub store_state {
    my $f = $ENV{HOME} . "/.$appclass/$my_name";
    mkdir($ENV{HOME} . "/.$appclass") unless -d $ENV{HOME} . "/.$appclass";
    open (my $cfg, ">$f");

    my %vars = $state->{STATE}->varlist(".");
    #my %vars = %{$state->{STATE}->{VARIABLE}};  # voids warranty

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
		     'open=s'	=> \$precmd,
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace!'	=> \$trace,
		     'help|?'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_usage(2) if @ARGV;
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

################ Run ################

sub run {
    # Process command line options.
    app_options();

    # Post-processing.
    $trace |= ($debug || $test);

    # This is for my temporary convenience. I always forget to set up
    # the right environment variable...
    use POSIX qw(locale_h);
    setlocale(LC_ALL, "nl_NL");

    use Wx::Locale;
    my $local = Wx::Locale->new("Dutch");
    $local->AddCatalog("wxstd");
#    $local->Init();

    use EB::DB;

    init_state();

#    if ( $state->showsplash ) {
#	require Wx::Perl::SplashFast;
#	Wx::Perl::SplashFast->new("ebsplash.jpg", 3000);
#	sleep(2);
#    }

    $state->set(verbose => $verbose);
    $state->set(trace   => $trace);
    $state->set(debug   => $debug);

    my $dataset = $cfg->val(qw(database name));
    if ( !$dataset ) {
	die("?"._T("Geen dataset opgegeven.".
		   " Specificeer een dataset in de configuratiefile.").
	    "\n");
    }
    $cfg->newval(qw(database name), $dataset);

    $dbh = EB::DB->new(trace => $trace || $ENV{EB_SQL_TRACE});

    if ( $state->lastdb ne $dataset ) {
	$state->set(lastdb => $dataset);
	$state->set(bky => $dbh->adm("bky"));
    }

    my $app = EB::Wx::Main->new();
    $dbh->dbh->{HandleError} = sub { Wx::LogMessage(shift); return 0 };
    $app->MainLoop();
}

run() unless caller;
