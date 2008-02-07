#! perl

# RCS Id          : $Id: Main.pm,v 1.2 2008/02/07 14:36:17 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  7 14:59:14 2008
# Update Count    : 898
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;
our $dbh;

package EB::Main;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)/g;

use EekBoek;

# This will set up the config at 'use' time.
use EB::Config $EekBoek::PACKAGE;

use EB;
use EB::DB;
use Getopt::Long 2.13;

# Command line options.
my $interactive = -t;
my $command;
my $echo;
my $dataset;
my $createdb;			# create database
my $createsampledb;		# create demo database
my $schema;			# initialise w/ schema
my $confirm = 0;
my $journal;
my $inexport;			# in/export
my $inex_file;			# file voor in/export
my $inex_dir;			# directory voor in/export
my $errexit = 0;		# disallow errors in batch
my $verbose = 0;		# verbose processing
my $bky;

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

use base qw(Exporter);
our @EXPORT = qw(run);

sub run {

    if ( @ARGV && ( $ARGV[0] eq '-P' || $ARGV[0] =~ /^--?printcfg$/ ) ) {
	shift(@ARGV);
	printconf();
	exit;
    }

    # Command line options.
    $interactive = -t;
    $confirm = 0;
    $errexit = 0;		# disallow errors in batch
    $verbose = 0;		# verbose processing

    # Development options (not shown with -help).
    $debug = 0;			# debugging
    $trace = 0;			# trace (show process)
    $test = 0;			# test mode.

    # Process command line options.
    app_options();

    # Post-processing.
    $trace |= ($debug || $test);

    my $app = $EekBoek::PACKAGE;
    my $userdir = glob("~/.".lc($app));
    mkdir($userdir) unless -d $userdir;

    $echo = "eb> " if $echo;
    if ( $createsampledb ) {
	$dataset = "sample" unless defined $dataset;
    }
    else {
	$dataset ||= $cfg->val(qw(database name), undef);
    }

    unless ( $dataset ) {
	die("?"._T("Geen dataset opgegeven.".
		   " Specificeer een dataset in de configuratiefile,".
		   " of selecteer een andere configuratiefile".
		   " op de command line met \"--config=...\".").
	    "\n");
    }

    $cfg->newval(qw(database name), $dataset);
    $cfg->newval(qw(preferences journal), $journal) if defined $journal;

    $dbh = EB::DB->new(trace => $trace);

    if ( defined $inexport ) {
	if ( $inexport ) {
	    $command = 1;
	    $createdb = 1;
	    @ARGV = qw(import --noclean);
	    push(@ARGV, "--file", $inex_file) if defined $inex_file;
	    push(@ARGV, "--dir", $inex_dir) if defined $inex_dir;
	}
	else {
	    $command = 1;
	    @ARGV = qw(export);
	    push(@ARGV, "--file", $inex_file) if defined $inex_file;
	    push(@ARGV, "--dir", $inex_dir) if defined $inex_dir;
	}
    }

    if ( $createsampledb ) {
	$command = 1;
	$createdb = 1;
	my $file = findlib("schema/sampledb.ebz");
	die("?".__x("Geen demo gegevens: {ebz}",
		    ebz => "schema/sampledb.ebz")."\n") unless $file;
	@ARGV = qw(import --noclean);
	push(@ARGV, "--file", $file);
    }

    if ( $createdb ) {
	$dbh->createdb($dataset);
	warn("%".__x("Lege dataset {db} is aangemaakt", db => $dataset)."\n");
    }

    if ( $schema ) {
	require EB::Tools::Schema;
	$dbh->connectdb(1);
	EB::Tools::Schema->create($schema);
	$dbh->setup;
    }

    exit(0) if $command && !@ARGV;

    require EB::Shell;
    my $shell = EB::Shell->new
      ({ HISTFILE	   => $userdir."/history",
	 command	   => $command,
	 interactive	   => $interactive,
	 errexit	   => $errexit,
	 verbose	   => $verbose,
	 trace		   => $trace,
	 journal	   => $cfg->val(qw(preferences journal), 0),
	 echo		   => $echo,
	 prompt		   => lc($app),
	 boekjaar	   => $bky,
       });

    $| = 1;

    $shell->run;

}

################ Subroutines ################

sub printconf {
    return unless @ARGV > 0;
    my $sec = "general";
    if ( !GetOptions(
		     'section=s' => \$sec,
		     '<>' => sub {
			 my $conf = shift;
			 my $sec = $sec;
			 ($sec, $conf) = ($1, $2) if $conf =~ /^(.+?):(.+)/;
			 my $val = $cfg->val($sec, $conf, undef);
			 print STDOUT ($val) if defined $val;
			 print STDOUT ("\n");
		     }
		    ) )
    {
	app_ident();
	print STDERR __x(<<EndOfUsage, prog => $0);
Gebruik: {prog} { --printcfg | -P } { [ --section=secname ] var ... } ...

    Print de waarde van configuratie-variabelen.
    Met --section=secname worden de eropvolgende variabelen
    gezocht in sectie [secname].
    Ook: secname:variabele.
EndOfUsage
    }
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    Getopt::Long::Configure(qw(no_ignore_case));

    if ( !GetOptions(
		     'command|c'    => sub {
			 $command = 1;
			 die("!FINISH\n");
		     },
		     'import'       => sub {
			 $inexport = 1;
		     },
		     'export'       => sub {
			 $inexport = 0;
		     },
		     'init'         => sub {
			 $inexport = 1;
			 $inex_dir = ".";
		     },
		     'createdb'     => \$createdb,
		     'createsampledb' => \$createsampledb,
		     'define|D=s%'  => sub {
			 die(__x("Ongeldige aanduiding voor config setting: {arg}",
				 arg => $_[1])."\n");
		     },
		     'schema=s'     => \$schema,
		     'echo|e!'	    => \$echo,
		     'ident'	    => \$ident,
		     'journaal'     => \$journal,
		     'boekjaar=s'   => \$bky,
		     'verbose'	    => \$verbose,
		     'db|dataset=s' => \$dataset,
		     'dir=s'	    => \$inex_dir,
		     'file=s'	    => \$inex_file,
		     'interactive!' => \$interactive,
		     'errexit'      => \$errexit,
		     'trace'	    => \$trace,
		     'help|?'	    => \$help,
		     'debug'	    => \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_usage(2) if @ARGV && !$command;
    app_ident() if $ident;
    if ( $dataset ) {
	print STDERR (_T("De optie '--dataset' (of '--db') komt binnenkort te vervallen.".
			 " Gebruik in plaats daarvan '--config' (of '-f') om een configuratiebestand te selecteren.")."\n");
    }
}

sub app_ident {
    return;
    print STDERR (__x("Dit is {pkg} [{name} {version}]",
		      pkg     => $EekBoek::PACKAGE,
		      name    => "Shell",
		      version => $EekBoek::VERSION) . "\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    print STDERR __x(<<EndOfUsage, prog => $0);
Gebruik: {prog} [options] [file ...]

    --command  -c       voer de rest van de opdrachtregel uit als command
    --echo  -e          toon ingelezen opdrachten
    --boekjaar=XXX	specificeer boekjaar
    --createdb		maak nieuwe database aan
    --createsampledb	maak nieuwe demo database aan
    --schema=XXX        initialisser database met schema
    --import            importeer een nieuwe administratie
    --export            exporteer een administratie
    --dir=XXX           directory voor im/export
    --file=XXX          bestand voor im/export
    --init		creëer nieuwe administratie
    --define=XXX -D     definieer configuratiesetting
    --[no]interactive   forceer [non]interactieve modus
    --errexit           stop direct na een fout in de invoer
    --help		deze hulpboodschap
    --ident		toon identificatie
    --verbose		geef meer uitgebreide information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}

1;
