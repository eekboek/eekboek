#!/usr/bin/perl -w
my $RCS_Id = '$Id: example.pl,v 1.1 2006/07/19 08:54:04 jv Exp $ ';

# Skeleton for an EekBoek application.

# Author          : Johan Vromans
# Created On      : Sun Apr 13 17:25:07 2008
# Last Modified By: Johan Vromans
# Last Modified On: Wed Oct 28 23:43:40 2009
# Update Count    : 82
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'EekBoekApp';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

# EekBoek 'handles'.
our $cfg;			# configuration
our $dbh;			# data base

# EekBoek modules.

use EekBoek;
# The name passed will be used for the config files,
# e.g., Foo -> /etc/foo.conf, ~/.foo/foo.conf, ./.foo.conf
use EB::Config ( $EekBoek::PACKAGE );
use EB;				# common
use EB::DB;			# database

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

# Connect to the data base.
EB::DB::->connect;

# SQL query.
my $sql =
  "SELECT acc_id, acc_desc, acc_balres".
  " FROM Accounts".
  " ORDER BY acc_id";

# Parse SQL and execute.
my $sth = $dbh->sql_exec($sql);

# Bind result columns.
$sth->bind_columns(\my($acc_id, $acc_desc, $acc_balans));

# Fetch results.
while ( $sth->fetch ) {
    # Print balansrekeningen.
    printf("%5d %s\n", $acc_id, $acc_desc) if $acc_balans;
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace'	=> \$trace,
		     'help|?'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
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
    exit $exit if defined $exit && $exit != 0;
}
