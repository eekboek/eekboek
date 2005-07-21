#!/usr/bin/perl -w
my $RCS_Id = '$Id: DB.pm,v 1.3 2005/07/21 15:30:25 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat May  7 09:18:15 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 21 17:27:58 2005
# Update Count    : 55
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

    my ($std_acc_deb, $std_acc_crd, $std_acc_btw_ih, $std_acc_btw_il,
	$std_acc_btw_vh, $std_acc_btw_vl, $std_acc_btw_paid, $std_acc_winst) =
      @{$self->do("SELECT std_acc_deb, std_acc_crd,".
		  " std_acc_btw_ih, std_acc_btw_il,".
		  " std_acc_btw_vh, std_acc_btw_vl,".
		  " std_acc_btw_paid, std_acc_winst".
		  " FROM Standaardrekeningen")};
    my $fail = 0;

    my $rr = $self->do("SELECT acc_debcrd, acc_balres FROM Accounts where acc_id = ?", $std_acc_deb);
    $fail++, warn("?Geen grootboekrekening voor debiteuren ($std_acc_deb)\n")
      unless $rr;
    $fail++, warn("?Verkeerde grootboekrekening voor debiteuren ($std_acc_deb)\n")
      unless $rr->[0] && $rr->[1];

    $rr = $self->do("SELECT acc_debcrd, acc_balres FROM Accounts where acc_id = ?", $std_acc_crd);
    $fail++, warn("?Geen grootboekrekening voor crediteuren ($std_acc_crd)\n")
      unless $rr;
    $fail++, warn("?Verkeerde grootboekrekening voor crediteuren ($std_acc_crd)\n")
      if $rr->[0] || !$rr->[1];

    $rr = $self->do("SELECT acc_balres FROM Accounts where acc_id = ?", $std_acc_btw_paid);
    $fail++, warn("?Geen grootboekrekening voor BTW betaald ($std_acc_btw_paid)\n")
      unless $rr;
    $fail++, warn("?Verkeerde grootboekrekening voor BTW betaald ($std_acc_btw_paid)\n")
      unless $rr->[0];

    $rr = $self->do("SELECT acc_balres FROM Accounts where acc_id = ?", $std_acc_winst);
    $fail++, warn("?Geen grootboekrekening voor overboeking winst ($std_acc_winst)\n")
      unless $rr;
    $fail++, warn("?Verkeerde grootboekrekening voor overboeking winst ($std_acc_winst)\n")
      unless $rr->[0];

    my $sth = $self->sql_exec("SELECT acc_id, acc_desc, dbk_id, dbk_type, dbk_desc FROM Dagboeken, Accounts".
			      " WHERE dbk_acc_id = acc_id");
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $dbk_id, $dbk_type, $dbk_desc) = @$rr;
	if ( $dbk_type == DBKTYPE_INKOOP && $acc_id != $std_acc_crd ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening $acc_id ($acc_desc) voor dagboek $dbk_id ($dbk_desc)\n")
	}
	elsif ( $dbk_type == DBKTYPE_VERKOOP && $acc_id != $std_acc_deb ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening $acc_id ($acc_desc) voor dagboek $dbk_id ($dbk_desc)\n")
	}
    }

    $sth = $self->sql_exec("SELECT btw_id, btw_desc, btg_id, btg_desc, btg_acc_inkoop, btg_acc_verkoop".
			   " FROM BTWTabel, BTWTariefgroepen".
			   " WHERE btw_tariefgroep = btg_id");
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($btw_id, $btw_desc, $btg_id, $btg_desc, $btg_acc_inkoop, $btg_acc_verkoop) = @$rr;
	if ( $btg_id == BTWTYPE_GEEN && $btg_acc_inkoop ) {
	    $fail++;
	    warn("?BTW tariefgroep $btg_id ($btg_desc) mag geen grootboekrekening voor inkoop hebben\n");
	}
	if ( $btg_id == BTWTYPE_GEEN && $btg_acc_verkoop ) {
	    $fail++;
	    warn("?BTW tariefgroep $btg_id ($btg_desc) mag geen grootboekrekening voor verkoop hebben\n");
	}
	if ( $btg_id == BTWTYPE_HOOG && $btg_acc_inkoop != $std_acc_btw_ih ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening voor inkoop ($btg_acc_inkoop) voor BTW tariefgroep $btg_id ($btg_desc) -- moet zijn $std_acc_btw_ih\n");
	}
	if ( $btg_id == BTWTYPE_HOOG && $btg_acc_verkoop != $std_acc_btw_vh ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening voor verkoop ($btg_acc_verkoop) voor BTW tariefgroep $btg_id ($btg_desc) -- moet zijn $std_acc_btw_vh\n");
	}
	if ( $btg_id == BTWTYPE_LAAG && $btg_acc_inkoop != $std_acc_btw_il ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening voor inkoop ($btg_acc_inkoop) voor BTW tariefgroep $btg_id ($btg_desc) -- moet zijn $std_acc_btw_il\n");
	}
	if ( $btg_id == BTWTYPE_LAAG && $btg_acc_verkoop != $std_acc_btw_vl ) {
	    $fail++;
	    warn("?Verkeerde grootboekrekening voor verkoop ($btg_acc_verkoop) voor BTW tariefgroep $btg_id ($btg_desc) -- moet zijn $std_acc_btw_vl\n");
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
    $self->check_stdacc;
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
