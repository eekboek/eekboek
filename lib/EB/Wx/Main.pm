#!/usr/bin/perl -w
my $RCS_Id = '$Id: Main.pm,v 1.6 2008/02/15 22:08:54 jv Exp $ ';

package main;

our $cfg;
our $state;
our $app;
our $dbh;

package EB::Wx::Main;

# Author          : Johan Vromans
# Created On      : Sun Jul 31 23:35:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Feb 15 23:07:06 2008
# Update Count    : 282
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

our $VERSION = "0.10";

use EekBoek;

# Package name.
my $my_package = $EekBoek::PACKAGE;

# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pm,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Configuration ################

# This will set up the config at 'use' time.
use EB::Config $EekBoek::PACKAGE;

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
use EekBoek;
BEGIN {
    my $req = "1.03.08";
    die("EekBoek $EekBoek::VERSION -- GUI vereist EekBoek versie $req of nieuwer\n")
      if $req gt $EekBoek::VERSION;
}

use strict;

use Wx 0.74 qw[:everything];

sub Wx::wxTHICK_FRAME() { 0 }

use POSIX qw(locale_h);
use Wx::Locale;
use EB::DB;
use lib EB::findlib("CPAN");
use File::Spec ();
use File::HomeDir ();

my $app_name;
my $app_class;
my $app_dir;
my $app_state;

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
      (undef, undef, $app_name,
       wxDefaultPosition, wxDefaultSize,
       undef,
       $app_name);

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

################ State ################

sub init_state {
    use EB::Wx::State;
    $state = EB::Wx::State->new;
    $state->load($app_state) if -f $app_state;
}

sub store_state {
    mkdir($app_dir) unless -d $app_dir;
    $state->store($app_state);
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

    $app_name = $my_package;
    $app_class = lc($app_name);

    # Process command line options.
    app_options();

    # Post-processing.
    $trace |= ($debug || $test);

    # This is for my temporary convenience. I always forget to set up
    # the right environment variable...
    setlocale(LC_ALL, "nl_NL");

    my $local = Wx::Locale->new("Dutch");
    $local->AddCatalog("wxstd");
#    $local->Init();

    $app_dir = File::Spec->catfile(File::HomeDir->my_data,
				   ".$app_class");
    $app_state = File::Spec->catfile($app_dir, "eb_state");

    init_state();

    if ( $state->showsplash ) {
	use Wx::Perl::SplashFast;
	Wx::Perl::SplashFast->new(EB::findlib("Wx/icons/ebsplash.jpg"), 3000);
	sleep(2);
    }

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
    $dbh->dbh->{HandleError} = sub { my $a = shift;
				     $a =~ s/\n+$//;
				     Wx::LogMessage($a);
				     return 0;
				 };
    $app->MainLoop();
}

run() unless caller;
