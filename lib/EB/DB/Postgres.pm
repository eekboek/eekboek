# Postgres.pm -- 
# RCS Info        : $Id: Postgres.pm,v 1.5 2006/02/06 14:54:49 jv Exp $
# Author          : Johan Vromans
# Created On      : Tue Jan 24 10:43:00 2006
# Last Modified By: Johan Vromans
# Last Modified On: Mon Feb  6 15:30:36 2006
# Update Count    : 67
# Status          : Unknown, Use with caution!

package main;

our $cfg;

package EB::DB::Postgres;

use strict;
use warnings;
use EB;
use DBI;
use DBD::Pg;

my $dbh;			# singleton
my $dataset;

my $trace = $cfg->val(__PACKAGE__, "trace", 0);

sub type { "Postgres" }

sub create {
    my ($self, $dbname) = @_;
    croak("?INTERNAL ERROR: create db while connected") if $dbh;

    my @ds = @{$self->list};
    if ( grep { $_ eq $dbname } @ds ) {
	$self->connect($dbname);
	$dbh->{RaiseError} = 0;
	$dbh->{PrintError} = 0;
	$dbh->{AutoCommit} = 1;
	$self->clear;
	$self->disconnect;
	return;
    }

    $dbname =~ s/^(?!=eekboek_)/eekboek_/;
    my $cmd = "createdb";
    my @cmd = ( $cmd, qw(-E latin1) );

    for ( $cfg->val("database", "user", undef) ) {
	next unless $_;
	push(@cmd, "-O", $_);
	push(@cmd, "-U", $_);
    }
    for ( $cfg->val("database", "password", undef) ) {
	next unless $_;
	push(@cmd, "--password");
    }
    for ( $cfg->val("database", "host", undef) ) {
	next unless $_;
	push(@cmd, "-h", $_);
    }
    for ( $cfg->val("database", "port", undef) ) {
	next unless $_;
	push(@cmd, "-p", $_);
    }
    push(@cmd, $dbname);

    warn("+ @cmd\n") if $trace;
    my $res = system { $cmd } @cmd;
    # warn(sprintf("=> ret = %02x", $res)."\n") if $res;
    die("?"._T("Aanmaken database mislukt")."\n") if $res;
}

sub connect {
    my ($self, $dbname) = @_;
    croak("?INTERNAL ERROR: connect db without dataset name") unless $dbname;

    if ( $dataset && $dbh && $dbname eq $dataset ) {
	return $dbh;
    }

    $self->disconnect;

    $dbname = "eekboek_".$dbname unless $dbname =~ /^eekboek_/;
    $cfg->newval(qw(database fullname), $dbname);
    $dbname = "dbi:Pg:dbname=" . $dbname;

    my $t;
    $dbname .= ";host=" . $t if $t = $cfg->val(qw(database host), undef);
    $dbname .= ";port=" . $t if $t = $cfg->val(qw(database port), undef);

    my $dbuser = $cfg->val(qw(database user), undef);
    my $dbpass = $cfg->val(qw(database password), undef);

    $dbh = DBI::->connect($dbname, $dbuser, $dbpass)
      or die("?".__x("Database verbindingsprobleem: {err}",
		     err => $DBI::errstr)."\n");
    $dataset = $dbname;
    return $dbh;
}

sub disconnect {
    my ($self) = @_;
    return unless $dbh;
    $dbh->disconnect;
    undef $dbh;
    undef $dataset;
}

sub clear {
    my ($self) = @_;
    croak("?INTERNAL ERROR: clear db while not connected") unless $dbh;

    for my $tbl ( qw(Boekstukregels Journal Boekjaarbalans
		     Metadata Standaardrekeningen Relaties
		     Boekstukken Dagboeken Boekjaren Constants
		     Accounts Btwtabel Verdichtingen) ) {
	warn("+ DROP TABLE $tbl\n") if $trace;
	$dbh->do("DROP TABLE $tbl");
    }

    my $rr = $dbh->selectall_arrayref("SELECT relname".
				      " FROM pg_class".
				      " WHERE relkind = 'S'".
				      ' AND relname LIKE \'bsk_%_seq\'');
    foreach my $seq ( @$rr ) {
	warn("+ DROP SEQUENCE $seq->[0]\n") if $trace;
	$dbh->do("DROP SEQUENCE $seq->[0]");
    }
    $dbh->commit unless $dbh->{AutoCommit};
}

sub list {
    my @ds;
    eval {
	local $ENV{PGUSER} = $cfg->val(qw(database user))
	  if $cfg->val(qw(database user), undef);
	local $ENV{PGPASS} = $cfg->val(qw(database password))
	  if $cfg->val(qw(database password), undef);
	local $ENV{PGHOST} = $cfg->val(qw(database host))
	  if $cfg->val(qw(database host), undef);
	local $ENV{PGPORT} = $cfg->val(qw(database port))
	  if $cfg->val(qw(database port), undef);
	@ds = DBI->data_sources("Pg");
	die("Connect error:\n\t" . ($DBI::errstr||"")) if $DBI::errstr;
    };
    [ map { $_ =~ s/^.*?dbname=eekboek_// and $_ } @ds ];
}

sub get_sequence {
    my ($self, $seq, $noinc) = @_;
    croak("?INTERNAL ERROR: get sequence while not connected") unless $dbh;

    my $rr = $dbh->selectall_arrayref("SELECT ".
				      ($noinc ? "currval" : "nextval").
				      "('$seq')");
    return ($rr && defined($rr->[0]) && defined($rr->[0]->[0])? $rr->[0]->[0] : undef);
}

sub set_sequence {
    my ($self, $seq, $value) = @_;
    croak("?INTERNAL ERROR: set sequence while not connected") unless $dbh;

    # Init a sequence to value.
    # The next call to get_sequence will return this value.
    $dbh->do("SELECT setval('$seq', $value, false)");
    $value;
}

sub isql {
    my ($self, @args) = @_;

    my $dbname = $cfg->val(qw(database fullname));
    my $cmd = "psql";
    my @cmd = ( $cmd );

    for ( $cfg->val("database", "user", undef) ) {
	next unless $_;
	push(@cmd, "-O", $_);
	push(@cmd, "-U", $_);
    }
#    for ( $cfg->val("database", "password", undef) ) {
#	next unless $_;
#	push(@cmd, "--password");
#    }
    for ( $cfg->val("database", "host", undef) ) {
	next unless $_;
	push(@cmd, "-h", $_);
    }
    for ( $cfg->val("database", "port", undef) ) {
	next unless $_;
	push(@cmd, "-p", $_);
    }
    push(@cmd, "-d", $dbname);

    if ( @args ) {
	push(@cmd, "-c", "@args");
    }

    my $res = system { $cmd } @cmd;
    # warn(sprintf("=> ret = %02x", $res)."\n") if $res;

}

1;
