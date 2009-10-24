#!/usr/bin/perl -w
my $RCS_Id = '$Id: Main.pm,v 1.10 2009/10/24 21:26:53 jv Exp $ ';

package main;

our $cfg;
our $state;
our $dbh;
our $app;
use EB::Wx::FakeApp;

package EB::Wx::Main;

# Author          : Johan Vromans
# Created On      : Sun Jul 31 23:35:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct 24 23:13:15 2009
# Update Count    : 330
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

our $VERSION = "0.21";

use EekBoek;

# Package name.
my $my_package = $EekBoek::PACKAGE;

# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pm,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Configuration ################

# Save options array (for restart).
my @opts; BEGIN { @opts = @ARGV }

# This will set up the config at 'use' time.
use EB::Config $EekBoek::PACKAGE;
use EB;

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $trace = 0;
my $verbose = 1;
my $precmd;

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $test = 0;			# test mode.

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use base qw(Exporter);
our @EXPORT = qw(run);

use Wx 0.74 qw[:everything];
sub Wx::wxTHICK_FRAME() { 0 }
use EB::Wx::Window;
use POSIX qw(locale_h);
use Wx::Locale;			# WHY?
use EB::DB;
use File::Basename ();
use File::Spec ();
use File::HomeDir ();

my $app_name;
my $app_class;
my $app_dir;
my $app_state;

our $restart = 0;

use base qw(Wx::App);

use EB::Wx::MainFrame;

sub OnInit {
    my( $self ) = shift;

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
	my $t = Wx::CreateFileTipProvider(EB::findlib("Wx/tips.txt"), $state->lasttip);
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
    warn("This is $my_package [$my_name $my_version]\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    warn <<EndOfUsage;
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

    $app_dir = File::Spec->catfile(File::HomeDir->my_data,
				   ".$app_class");
    $app_state = File::Spec->catfile($app_dir, "ebgui_state");

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
	die(_T("Geen dataset opgegeven.".
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

    # Since Wx::Bitmap cannot be convinced to use a search path, we
    # need a stronger method...
    my $wxbitmapnew = \&Wx::Bitmap::new;
    no warnings 'redefine';
    *Wx::Bitmap::new = sub {
	# Only handle Wx::Bitmap->new(file, type) case.
	goto &$wxbitmapnew if @_ != 3 || -f $_[1];
	my ($self, @rest) = @_;
	$rest[0] = EB::findlib("Wx/icons/".File::Basename::basename($rest[0]));
	$wxbitmapnew->($self, @rest);
    };
    use warnings 'redefine';

run() unless caller;
