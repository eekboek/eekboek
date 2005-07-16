#!/usr/bin/perl -w
my $RCS_Id = '$Id: DB.pm,v 1.2 2005/07/16 16:43:51 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat May  7 09:18:15 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jul 16 18:10:49 2005
# Update Count    : 44
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::DB;

use strict;

use DBI;

my $postgres = 1;		# PostgreSQL

my $dbh;			# singleton for DB
my $db;				# singleton for EBDB

my $verbose = 0;
my $trace = 0;

################ high level ################

sub upd_account {
    my ($self, $acc, $amt) = @_;
#    my $acc_debcrd = $self->lookup($acc, qw(Accounts acc_id acc_debcrd =)) ? 1 : 0;
#    $amt = -$amt unless $acc_debcrd;
    my $op = '+';
    if ( $amt < 0 ) {
	$amt = -$amt;
	$op = '-';
    }
    $self->sql_exec("UPDATE Accounts".
		    " SET acc_balance = acc_balance $op ?".
		    " WHERE acc_id = ?",
		    $amt, $acc);
}

sub store_journal {
    my ($self, $jnl) = @_;
    foreach ( @$jnl ) {
	$self->sql_insert("Journal",
			  [qw(jnl_date jnl_dbk_id jnl_bsk_id jnl_bsr_seq
			      jnl_acc_id jnl_amount jnl_desc jnl_rel)],
			  @$_);
    }
}

################ low level ################

sub new {
    my ($pkg, %atts) = @_;
    $pkg = ref($pkg) || $pkg;

    $verbose = delete($atts{verbose}) || 0;
    $trace   = delete($atts{trace}) || 0;

    $db = {};
    bless $db, $pkg;
    $db->_init;
    $db;
}

sub _init {
    my ($self) = @_;
}

my %std_acc;
sub std_acc {
    my ($self, $name) = @_;
    unless ( %std_acc ) {
	$self->connectdb;
	my @stdkeys = qw(deb crd btw_vh btw_vl btw_ih btw_il btw_paid winst);

	my $rr = $self->do("SELECT".
			   " " . join(", ", map { "std_acc_$_"} @stdkeys).
			   " FROM Standaardrekeningen");
	@std_acc{@stdkeys} = @$rr;
    }
    $std_acc{$name};
}

sub connectdb {
    my ($self) = @_;

    return $dbh if $dbh;
    $dbh = DBI::->connect($ENV{EB_DB} || "dbi:Pg:dbname=eekboek")
      or die("Cannot connect to database: $DBI::errstr\n");
    $dbh->{RaiseError} = 1;
    $dbh->{AutoCommit} = 0;
    $dbh;
}

sub trace {
    my ($self, $value) = @_;
    $trace = !$trace, return unless defined $value;
    $trace = $value;
}

sub sql_insert {
    my ($self, $table, $columns, @args) = @_;
    $self->sql_exec("INSERT INTO $table ".
		    "(" . join(",", @$columns) . ") ".
		    "VALUES (" . join(",", ("?") x @$columns) . ")",
		    @args);
}

my %sth;
sub sql_prep {
    my ($self, $sql) = @_;
    $dbh ||= $self->connectdb();
    $sth{$sql} ||= $dbh->prepare($sql);
}

sub sql_exec {
    my ($self, $sql, @args) = @_;
    if ( $trace ) {
	$dbh ||= $self->connectdb();
	my $s = $sql;
	my @a = map {
	    !defined($_) ? "NULL" :
	      /^[0-9]+$/ ? $_ : $dbh->quote($_)
	} @args;
	$s =~ s/\?/shift(@a)/eg;
	warn("=> $s;\n");
    }
    my $sth = $self->sql_prep($sql);
    $sth->execute(@args);
    $sth;
}

sub lookup {
    my ($self, $value, $table, $arg, $res, $op) = @_;
    $op ||= "=";
    my $sth = $self->sql_exec("SELECT $res FROM $table".
			      " WHERE $arg $op ?", $value);
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;

    return ($rr && defined($rr->[0]) ? $rr->[0] : undef);

}

sub get_value {
    my ($self, $column, $table) = @_;
    my $sth = $self->sql_exec("SELECT $column FROM $table");
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;

    return ($rr && defined($rr->[0]) ? $rr->[0] : undef);
}

sub get_sequence {
    my ($self, $seq, $noinc) = @_;
    my $sth = $self->sql_exec("SELECT ".
			      ($noinc ? "currval" : "nextval").
			      "('$seq')");
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;

    return ($rr && defined($rr->[0]) ? $rr->[0] : undef);
}

sub set_sequence {
    my ($self, $seq, $value) = @_;
    my $sth = $self->sql_exec("SELECT setval('$seq',$value)");
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;

    return ($rr && defined($rr->[0]) ? $rr->[0] : undef);
}

sub do {
    my $self = shift;
    my $sql = shift;
    my $atts = ref($_[0]) eq 'HASH' ? shift : undef;
    my @args = @_;
    my $sth = $self->sql_exec($sql, @args);
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;
    $rr;
}

sub rollback {
    my ($self) = @_;

    return unless $dbh;
    $dbh->rollback
}

sub commit {
    my ($self) = @_;

    return unless $dbh;
    $dbh->commit;
}

sub disconnectdb {
    my ($self) = @_;

    return unless $dbh;
    $dbh->disconnect;
}

END {
    disconnectdb();
}

1;
