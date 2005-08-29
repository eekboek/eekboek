#!/usr/bin/perl -w
my $RCS_Id = '$Id: DB.pm,v 1.10 2005/08/29 20:42:22 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat May  7 09:18:15 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug 29 16:59:14 2005
# Update Count    : 96
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::DB;

use strict;

use EB::Globals;
use DBI;

my $postgres = 1;		# PostgreSQL

my $dbh;			# singleton for DB
my $db;				# singleton for EBDB

my $verbose = 0;
my $trace = 0;

################ high level ################

sub check_stdacc {
    my ($self) = @_;

    my $fail = 0;

    for ( $self->std_acc("deb") ) {
	my $rr = $self->do("SELECT acc_debcrd, acc_balres FROM Accounts where acc_id = ?", $_);
	$fail++, warn("?Geen grootboekrekening voor debiteuren ($_)\n")
	  unless $rr;
	# $fail++,
	warn("?Verkeerde grootboekrekening voor debiteuren ($_)\n")
	  unless $rr->[0] && $rr->[1];
    }

    for ( $self->std_acc("crd") ) {
	my $rr = $self->do("SELECT acc_debcrd, acc_balres FROM Accounts where acc_id = ?", $_);
	$fail++, warn("?Geen grootboekrekening voor crediteuren ($_)\n")
	  unless $rr;
	# $fail++,
	warn("?Verkeerde grootboekrekening voor crediteuren ($_)\n")
	  if $rr->[0] || !$rr->[1];
    }

    for ( $self->std_acc("btw_ok") ) {
	my $rr = $self->do("SELECT acc_balres FROM Accounts where acc_id = ?", $_);
	$fail++, warn("?Geen grootboekrekening voor BTW betaald ($_)\n")
	  unless $rr;
	$fail++, warn("?Verkeerde grootboekrekening voor BTW betaald ($_)\n")
	  unless $rr->[0];
    }

    for ( $self->std_acc("winst") ) {
	my $rr = $self->do("SELECT acc_balres FROM Accounts where acc_id = ?", $_);
	$fail++, warn("?Geen grootboekrekening voor overboeking winst ($_)\n")
	  unless $rr;
	$fail++, warn("?Verkeerde grootboekrekening voor overboeking winst ($_)\n")
	  unless $rr->[0];
    }

    my $sth = $self->sql_exec("SELECT acc_id, acc_desc, dbk_id, dbk_type, dbk_desc FROM Dagboeken, Accounts".
			      " WHERE dbk_acc_id = acc_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $dbk_id, $dbk_type, $dbk_desc) = @$rr;
	if ( $dbk_type == DBKTYPE_INKOOP && $acc_id != $self->std_acc("crd") ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening $acc_id ($acc_desc) voor dagboek $dbk_id ($dbk_desc)\n")
	}
	elsif ( $dbk_type == DBKTYPE_VERKOOP && $acc_id != $self->std_acc("deb") ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening $acc_id ($acc_desc) voor dagboek $dbk_id ($dbk_desc)\n")
	}
    }

    die("?CONSISTENTIE-VERIFICATIE STANDAARDREKENINGEN MISLUKT\n") if $fail;
}

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
my @std_acc;
sub std_acc {
    my ($self, $name) = @_;
    if ( $name eq "" ) {
	%std_acc = ();
	@std_acc = ();
	return;
    }
    $self->std_accs unless %std_acc;
    $std_acc{lc($name)} || die("?Niet-bestaande standaardrekening: \"$name\"\n");
}

sub std_accs {
    my ($self) = @_;
    unless ( @std_acc ) {
	$self->connectdb;
	my $sth = $self->sql_exec("SELECT * FROM Standaardrekeningen");
	my $rr = $sth->fetchrow_hashref;
	$sth->finish;
	while ( my($k,$v) = each(%$rr) ) {
	    $k =~ s/^std_acc_//;
	    $std_acc{lc($k)} = $v;
	}
	@std_acc = sort(keys(%std_acc));
    }
    \@std_acc;
}

my %accts;
sub accts {
    my ($self, $sel) = @_;
    $sel = " WHERE $sel" if $sel;
    return \%accts if %accts;
    my $sth = $self->sql_exec("SELECT acc_id,acc_desc".
			      " FROM Accounts".
			      $sel.
			      " ORDER BY acc_id");
    my $rr;
    while ( $rr = $sth->fetchrow_arrayref ) {
	$accts{$rr->[0]} = $rr->[1];
    }
    \%accts;
}

sub dbh{
    $dbh;
}

sub adm_busy {
    my ($self) = @_;
    $self->connectdb;
    $self->do("SELECT COUNT(*) FROM Journal")->[0];
}

sub connectdb {
    my ($self, $dbname) = @_;

    return $dbh if $dbh;

    if ( $dbname ) {
	#$dbname = "eekboek_".$dbname unless $dbname =~ /^eekboek_/;
	$dbname = "dbi:Pg:dbname=" . $dbname;
    }

    $dbh = DBI::->connect($dbname || $ENV{EB_DB} || "dbi:Pg:dbname=eekboek")
      or die("Cannot connect to database: $DBI::errstr\n");
    $dbh->{RaiseError} = 1;
    $dbh->{AutoCommit} = 0;
    $self->check_stdacc;
    $dbh;
}

sub trace {
    my ($self, $value) = @_;
    my $cur = $trace;
    $trace = !$trace, return $cur unless defined $value;
    $trace = $value;
    $cur;
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

sub close {
    my ($self) = @_;
    $dbh->disconnect;
    undef $dbh;
    %sth = ();
    %std_acc = ();
    %accts = ();
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

sub errstr {
    $dbh->errstr;
}

sub rollback {
    my ($self) = @_;

    return unless $dbh;
    $dbh->rollback
}

sub begin_work {
    my ($self) = @_;

    return unless $dbh;
    $dbh->begin_work;
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
