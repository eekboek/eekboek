# Sqlite.pm -- EekBoek driver for SQLite database
# RCS Info        : $Id: Sqlite.pm,v 1.1 2006/10/07 20:46:38 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct  7 10:10:36 2006
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct  7 22:46:11 2006
# Update Count    : 74
# Status          : Unknown, Use with caution!

package main;

our $cfg;

package EB::DB::Sqlite;

use strict;
use warnings;
use EB;
use DBI;

my $dbh;			# singleton
my $dataset;

my $trace = $cfg->val(__PACKAGE__, "trace", 0);

sub type { "SQLite" }

sub feature {
    my $self = shift;
    my $feat = lc(shift);

    return \&sqlfilter if $feat eq "filter";
    return 1 if $feat eq "prepcache";

    return;
}

sub _dsn {
    my $dsn = "dbi:SQLite:dbname=" . shift;
}

sub create {
    my ($self, $dbname) = @_;

    $dbname =~ s/^(ebsqlite_|eekboek_)//;
    $dbname =~ s/^/ebsqlite_/;

    # Create (empty) db file.
    open(my $db, '>', $dbname);
    close($db);
}

sub connect {
    my ($self, $dbname) = @_;
    croak("?INTERNAL ERROR: connect db without dataset name") unless $dbname;

    if ( $dataset && $dbh && $dbname eq $dataset ) {
	return $dbh;
    }

    $self->disconnect;

    $dbname =~ s/^(ebsqlite_|eekboek_)//;
    $dbname =~ s/^/ebsqlite_/;

    $cfg->newval(qw(database fullname), $dbname);
    unless ( -e $dbname ) {
	die("?".__x("Geen database met naam {name} gevonden",
		    name => $dbname)."\n");
    }
    $dbh = DBI::->connect(_dsn($dbname))
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

sub setup {
    # Create table for sequences.
    unless ( $dbh->selectrow_arrayref("SELECT name".
				      " FROM sqlite_master".
				      " WHERE name = 'eb_seq'".
				      " AND type = 'table'") ) {
	$dbh->do("CREATE TABLE eb_seq".
		 " (name TEXT PRIMARY KEY,".
		 "  value INT)");
    }

    # Clone Accounts table into TAccounts.
    unless ( $dbh->selectrow_arrayref("SELECT name".
				      " FROM sqlite_master".
				      " WHERE name like 'taccounts'".
				      " AND type = 'table'") ) {
	my $sql = $dbh->selectrow_arrayref("SELECT sql".
					   " FROM sqlite_master".
					   " WHERE name like 'accounts'".
					   " AND type = 'table'")->[0];
	$sql =~ s/TABLE Accounts/TABLE TAccounts/;
	$dbh->do($sql);
    }

    # Caller will commit.
}

sub list {
    my @ds;

    eval {
	@ds = DBI->data_sources("Pg");
    };
    # If the list cannot be established, @ds will be (undef).
    return [] unless defined($ds[0]);
    [ map { $_ =~ s/^.*?dbname=ebsqlite_// and $_ } @ds ];
}

sub _check_sequence {
    my $sn = shift;

    # Create sequence if it does not exist.
    unless ( $dbh->selectrow_arrayref("SELECT name".
				      " FROM eb_seq".
				      " WHERE name = ?", {},
				      $sn) ) {
	$dbh->do("INSERT INTO eb_seq".
		 " (name, value)".
		 " VALUES (?,?)", {}, $sn, 1);
    }
}

my $dummy;

sub get_sequence {
    my ($self, $seq) = @_;
    croak("?INTERNAL ERROR: get sequence while not connected") unless $dbh;

    _check_sequence($seq);
    my $value = $dbh->selectrow_arrayref("SELECT value".
					 " FROM eb_seq".
					 " WHERE name = ?", {}, $seq)->[0];
    $dbh->do("UPDATE eb_seq".
	     " SET value = ?".
	     " WHERE name = ?", {}, $value+1, $seq);

    $value + 1;
}

sub set_sequence {
    my ($self, $seq, $value) = @_;
    croak("?INTERNAL ERROR: set sequence while not connected") unless $dbh;

    _check_sequence($seq);
    $dbh->do("UPDATE eb_seq".
	     " SET value = ?".
	     " WHERE name = ?", {}, $value, $seq);
    return;
}

sub sqlfilter {
    local $_ = shift;
    my (@args) = @_;

    # No sequences.
    return if /^(?:create|drop)\s+sequence\b/i;

    # Constraints are ignored in table defs, but an explicit alter needs to be skipped.
    return if /^alter\s+table\b.*\badd\s+constraint\b/i;

    # UNSOLVED: No insert into temp tables.
    return if /^select\s+\*\s+into\s+temp\b/i;

    # In-line now().
    s/\(select\s+now\(\)\)/iso8601date()/ie;

    # Fortunately, LIKE behaves mostly like ILIKE.
    s/\bilike\b/like/gi;

    return $_;
}

sub isql {
    my ($self, @args) = @_;

    my $dbname = $cfg->val(qw(database fullname));
    my $cmd = "sqlite3";
    my @cmd = ( $cmd );

    push(@cmd, $dbname);

    if ( @args ) {
	push(@cmd, "@args");
    }

    my $res = system { $cmd } @cmd;
    # warn(sprintf("=> ret = %02x", $res)."\n") if $res;

}

1;
