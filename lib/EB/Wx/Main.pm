#! perl --			-*- coding: utf-8 -*-

use utf8;

# RCS Id          : $Id: Main.pm,v 1.12 2009/11/11 12:45:35 jv Exp $
# Author          : Johan Vromans
# Created On      : Sun Jul 31 23:35:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Nov 11 13:45:15 2009
# Update Count    : 366
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;
our $state;
our $dbh;
our $app;
use EB::Wx::FakeApp;

package EB::Wx::Main;

use strict;
use warnings;

# Save options array (for restart).
my @opts; BEGIN { @opts = @ARGV }

use EekBoek;
use EB;
use EB::Config ();
use EB::DB;
use Getopt::Long 2.13;

################ The Process ################

use Wx 0.74 qw[:everything];
sub Wx::wxTHICK_FRAME() { 0 }
use EB::Wx::Window;
use POSIX qw(locale_h);
use Wx::Locale;			# WHY?
use File::Basename ();
use File::Spec ();
use File::HomeDir ();

my $app_dir;
my $app_state;

our $restart = 0;

use base qw(Wx::App);

sub OnInit {
    my( $self ) = shift;

    my $locale = Wx::Locale->new( Wx::Locale::GetSystemLanguage );

    Wx::InitAllImageHandlers();

    require EB::Wx::MainFrame;
    my $frame = EB::Wx::MainFrame->new
      (undef, undef, $EekBoek::PACKAGE,
       wxDefaultPosition, wxDefaultSize,
       undef,
       $EekBoek::PACKAGE);

    $self->SetTopWindow($frame);
    $app->{TOP} = $frame;
    $frame->sizepos_restore("mainw");
    $frame->Show(1);
    showtips($state->showtips);

#    $frame->command($precmd) if $precmd;

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
    $state->store($app_state);
}

################ Run ################

sub run {

    my ( $pkg, $opts ) = @_;
    $opts = {} unless defined $opts;

    binmode(STDOUT, ":encoding(utf8)");
    binmode(STDERR, ":encoding(utf8)");

    # Command line options.
    $opts =
      {
	#config,			# config file
	#nostdconf,			# skip standard configs
	#define,			# config overrides

	verbose	      => 0,		# verbose processing

	# Development options (not shown with -help).
	debug	     => 0,		# debugging
	trace	     => 0,		# trace (show process)
	test	     => 0,		# test mode.

	# Let supplied options override.
	%$opts,
      };

    # Process command line options.
    app_options($opts);

    # Post-processing.
    $opts->{trace} |= ($opts->{debug} || $opts->{test});

    # Initialize config.
    EB::Config->init_config( { app => $EekBoek::PACKAGE, %$opts } );

    if ( $opts->{printconfig} ) {
	$cfg->printconf( \@ARGV );
	exit;
    }

    $app_dir = $cfg->user_dir;
    mkdir($app_dir) unless -d $app_dir;
    $app_state = $cfg->user_dir("ebgui_state");
    init_state();

    Wx::InitAllImageHandlers();

    if ( $state->showsplash ) {
	require Wx::Perl::SplashFast;
	Wx::Perl::SplashFast->new(EB::findlib("Wx/icons/ebsplash.jpg"), 3000);
	sleep(2);
    }

    $state->set(verbose => $opts->{verbose});
    $state->set(trace   => $opts->{trace});
    $state->set(debug   => $opts->{debug});

    #### WHAT THE ***** IS GOING ON HERE????
    *Fcntl::O_NOINHERIT = sub() { 0 };
    *Fcntl::O_EXLOCK = sub() { 0 };
    *Fcntl::O_TEMPORARY = sub() { 0 };

    unless ( $opts->{nowizard} || $opts->{config} ) {
	require EB::Wx::IniWiz;
	EB::Wx::IniWiz->run($opts); # sets $opts->{runeb}
	return unless $opts->{runeb};
	undef $cfg;
	EB::Config->init_config( { app => $EekBoek::PACKAGE, %$opts } );
    }

    my $dataset = $cfg->val(qw(database name));
    if ( !$dataset ) {
	die(_T("Geen dataset opgegeven.".
			 " Specificeer een dataset in de configuratiefile.").
		      "\n");
    }
    $cfg->newval(qw(database name), $dataset);

    $dbh = EB::DB->new(trace => $opts->{trace} || $ENV{EB_SQL_TRACE});

    if ( ($state->lastdb||'') ne $dataset ) {
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


################ Subroutines ################

sub app_options {
    my ( $opts ) = @_;
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    Getopt::Long::Configure(qw(no_ignore_case));

    if ( !GetOptions( $opts,
		      'define|D=s%',
		      'nostdconf|X',
		      'config|f=s',
		      'admdir=s',
		      'open=s',
		      'nowizard|no-wizard|nw',
		      'printconfig|P',
		      'ident'	=> \$ident,
		      'verbose',
		      'trace!',
		      'help|?',
		      'debug',
		    ) or $help )
    {
	app_usage(2);
    }
    app_usage(2) if @ARGV && !$opts->{printconfig};
    app_ident() if $ident;
}

sub app_ident {
    return;
    print STDERR (__x("Dit is {pkg} [{name} {version}]",
		      pkg     => $EekBoek::PACKAGE,
		      name    => "GUI",
		      version => $EekBoek::VERSION) . "\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    warn <<EndOfUsage;
Gebruik: {prog} [options] [file ...]

    --config=XXX -f     specificeer configuratiebestand
    --nostdconf -X      gebruik uitsluitend dit configuratiebestand
    --define=XXX -D     definieer configuratiesetting
    --printconfig -P	print config waarden
    --admdir=XXX	directory voor de config files
    --help		deze hulpboodschap
    --ident		toon identificatie
    --verbose		geef meer uitgebreide information
EndOfUsage
    CORE::exit $exit if defined $exit && $exit != 0;
}

