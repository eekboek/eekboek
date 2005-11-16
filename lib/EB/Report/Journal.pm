#!/usr/bin/perl -w
my $RCS_Id = '$Id: Journal.pm,v 1.21 2005/11/16 14:01:52 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Nov 16 15:01:45 2005
# Update Count    : 243
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $dbh;

package EB::Report::Journal;

use strict;
use warnings;

use EB;
use EB::Finance;
use EB::DB;
use EB::Report::GenBase;

sub new {
    bless {};
}

sub journal {
    my ($self, $opts) = @_;

    my $nr = $opts->{select};
    my $pfx = $opts->{postfix} || "";
    my $detail = $opts->{detail};

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{periode};
    $per->[1] = $ENV{EB_SQL_NOW} if $ENV{EB_SQL_NOW} && $ENV{EB_SQL_NOW} lt $per->[1];
    $rep->start(_T("Journaal"),
		__x("Periode: {from} t/m {to}",
		    from => $per->[0], to => $per->[1]));

    my $sth;
    if ( $nr ) {
	if ( $nr =~ /^([[:alpha:]].+):(\d+)$/ ) {
	    my $rr = $::dbh->do("SELECT dbk_desc, dbk_id".
				" FROM Dagboeken".
				" WHERE dbk_desc ILIKE ?",
				$1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken, Dagboeken".
				    " WHERE bsk_nr = ?".
				    " AND dbk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    " AND jnl_dbk_id = dbk_id".
				    ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				    " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				    $2, $rr->[1], $per ? @$per : ());
	    $pfx ||= __x("Boekstuk {nr}", nr => "$rr->[0]:$2");
	}
	elsif ( $nr =~ /^([[:alpha:]].+)$/ ) {
	    my $rr = $::dbh->do("SELECT dbk_desc, dbk_id".
				" FROM Dagboeken".
				" WHERE dbk_desc ILIKE ?",
				$1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken, Dagboeken".
				    " WHERE dbk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    " AND jnl_dbk_id = dbk_id".
				    ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				    " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				    $rr->[1], $per ? @$per : ());
	    $pfx ||= __x("Dagboek {nr}", nr => $rr->[0]);
	}
	else {
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken".
				    " WHERE jnl_bsk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				    " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				    $nr, $per ? @$per : ());
	    $pfx ||= __x("Boekstuk {nr}", nr => $nr);
	}
    }
    else {
	$sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				"jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				" FROM Journal, Boekstukken".
				" WHERE jnl_bsk_id = bsk_id".
				($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				" ORDER BY jnl_date, jnl_dbk_id, bsk_nr, sign(jnl_amount) DESC, jnl_acc_id, jnl_bsr_seq",
				$per ? @$per : ());
    }
    my $rr;
    my $nl = 0;
    my $totd = my $totc = 0;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($jnl_date, $jnl_bsr_date, $jnl_dbk_id, $jnl_bsk_id, $bsk_nr, $jnl_bsr_seq, $jnl_acc_id,
	    $jnl_amount, $jnl_desc, $jnl_rel) = @$rr;

	if ( $jnl_bsr_seq == 0 ) {
	    $nl++, next unless $detail;
	    $rep->outline(' ') if $nl++;
	    $rep->outline('H', $jnl_bsr_date, $jnl_bsk_id, $bsk_nr, _dbk_desc($jnl_dbk_id), $jnl_desc);
	    next;
	}

	$totd += $jnl_amount if $jnl_amount > 0;
	$totc -= $jnl_amount if $jnl_amount < 0;
	next unless $detail;
	$rep->outline('D', $jnl_bsr_date, _acc_desc($jnl_acc_id),
			$jnl_acc_id, numdebcrd($jnl_amount), $jnl_desc, $jnl_rel || '');
    }
    $rep->outline('T', __x("Totaal {pfx}", pfx => $pfx), $totd, $totc);
    $rep->finish;
}

my %dbk_desc;
sub _dbk_desc {
    $dbk_desc{$_[0]} ||= $::dbh->lookup($_[0],
				      qw(Dagboeken dbk_id dbk_desc =));
}

my %acc_desc;
sub _acc_desc {
    return '' unless $_[0];
    $acc_desc{$_[0]} ||= $::dbh->lookup($_[0],
				      qw(Accounts acc_id acc_desc =));
}

package EB::Report::Journal::Text;

use strict;

use EB;
use EB::Finance;
use base qw(EB::Report::GenBase);

my ($title, $per, $adm, $ident, $now);
my ($date, $bsk, $nr, $loc, $acc, $deb, $crd, $desc, $rel);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

sub start {
    my ($self, $t1, $t2) = @_;
    $title = $t1;
    $per = $t2;
    if ( $self->{boekjaar} ) {
	$adm = $dbh->lookup($self->{boekjaar},
			    qw(Boekjaren bky_code bky_name));
    }
    else {
	$adm = $dbh->adm("name");
    }
    $now = $ENV{EB_SQL_NOW} || iso8601date();
    $ident = $EB::ident;
    $ident = (split(' ', $ident))[0] if $ENV{EB_SQL_NOW};
    $self->{fh}->format_top_name('jnlfmt0');
}

sub outline {
    my ($self, $type, @args) = @_;

    ($date, $bsk, $nr, $loc, $acc, $deb, $crd, $desc, $rel) = ('') x 9;

    if ( $type eq 'H' ) {
	($date, $bsk, $nr, $loc, $desc) = @args;
	$loc .= ":".$nr if $nr;
	$self->{fh}->format_write(__PACKAGE__.'::jnlfmt1');
	return;
    }

    if ( $type eq 'D' ) {
	($date, $loc, $acc, $deb, $crd, $desc, $rel) = @args;
	for ( $deb, $crd ) {
	    $_ = $_ ? numfmt($_) : '';
	}
	$self->{fh}->format_write(__PACKAGE__.'::jnlfmt2');
	return;
    }

    if ( $type eq 'T' ) {
	($loc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::jnlfmtl');
	for ( $deb, $crd ) {
	    $_ = $_ ? numfmt($_) : '';
	}
	$self->{fh}->format_write(__PACKAGE__.'::jnlfmt1');
	return;
    }

    if ( $type eq ' ' ) {
	$self->{fh}->format_write(__PACKAGE__.'::jnlfmt1');
	return;
    }

    die("?".__x("Programmafout: verkeerd type in {here}",
		here => __PACKAGE__ . "::_repline")."\n");
}

sub finish {
    my ($self) = @_;
    $self->{fh}->close;
}

format jnlfmt0 =
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$per
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $ident . ", " . $now . (" " x (10-length(_T("Relatie"))))

@<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>  @>>>>>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
_T("Datum"), _T("Boekstuk/Grootboek"), _T("Rek"), _T("Debet"), _T("Credit"), _T("Boekstuk/regel"), _T("Relatie")
---------------------------------------------------------------------------------------------------------@<<<<<<<<<
'-' x length(_T("Relatie"))
.

format jnlfmtl =
---------------------------------------------------------------------------------------------------------@<<<<<<<<<
'-' x length(_T("Relatie"))
.

format jnlfmt1 =
@<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>  @>>>>>>>>  @>>>>>>>>  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
$date, $loc, $acc, $deb, $crd, $desc, $rel
~~                                                                       ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.
format jnlfmt2 =
@<<<<<<<<<    @<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>  @>>>>>>>>    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
$date, $loc, $acc, $deb, $crd, $desc, $rel
~~                                                                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.

1;

__END__
format jnlfmt0 =
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$per
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $ident . ", " . $now . (" " x (10-length(_T("Relatie"))))

@<<<<<<<<<  @<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>  @>>>>>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
_T("Datum"), _T("Nr"), _T("Dag/Grootboek"), _T("Rek"), _T("Debet"), _T("Credit"), _T("Boekstuk/regel"), _T("Relatie")
---------------------------------------------------------------------------------------------------------------@<<<<<<<<<
'-' x length(_T("Relatie"))
.

format jnlfmtl =
---------------------------------------------------------------------------------------------------------------@<<<<<<<<<
'-' x length(_T("Relatie"))
.

format jnlfmt1 =
@<<<<<<<<<  @<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>  @>>>>>>>>  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
$date, $nr, $loc, $acc, $deb, $crd, $desc, $rel
~~                                                                             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.
format jnlfmt2 =
@<<<<<<<<<  @<<<    @<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>  @>>>>>>>>    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<
$date, $nr, $loc, $acc, $deb, $crd, $desc, $rel
~~                                                                               ^<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.

