#!/usr/bin/perl -w
my $RCS_Id = '$Id: Proof.pm,v 1.12 2006/01/04 21:59:13 jv Exp $ ';

package main;

our $config;
our $dbh;
our $app;

package EB::Report::Proof;

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Dec 31 21:59:29 2005
# Update Count    : 284
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::Finance;

################ Subroutines ################

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    $opts = {} unless $opts;
    bless { %$opts }, $class;
}

sub proefensaldibalans {
    my ($self, $opts) = @_;
    $self->perform($opts);
}

sub perform {
    my ($self, $opts) = @_;

    my $detail = $opts->{detail};
    $detail = $opts->{verdicht} ? 2 : -1 unless defined $detail;
    $opts->{proef} = 1;
    $opts->{detail} = $detail;

    my @grand = (0) x 4;	# grand total

    $opts->{STYLE} = "proef";
    $opts->{LAYOUT} =
      [ { name => "acct", title => _T("RekNr"),    width => 6, },
	{ name => "desc",
	  title => $detail >= 0 ? _T("Verdichting/Grootboekrekening")
				: _T("Grootboekrekening"),
	  width => 40, },
	{ name => "deb",  title => _T("Debet"),    width => 9, align => ">", },
	{ name => "crd",  title => _T("Credit"),   width => 9, align => ">", },
	{ name => "sdeb", title => _T("Saldo Db"), width => 9, align => ">" },
	{ name => "scrd", title => _T("Saldo Cr"), width => 9, align => ">" },
      ];

    my $rep = EB::Report::GenBase->backend($self, $opts);

    my $rr;
    my $date = $dbh->adm("begin");
    my $now = $ENV{EB_SQL_NOW} || iso8601date();

    $rep->start(_T("Proef- en Saldibalans"));

    my $sth;

    my $hvd_hdr;
    my $vd_hdr;

    my $journaal = sub {
	my ($acc_id, $acc_desc, $acc_ibalance) = @_;
	my @tot = (0) x 4;
	my $did = 0;
	if ( $acc_ibalance ) {
	    $did++;
	    if ( $acc_ibalance < 0 ) {
		$tot[1] = -$acc_ibalance;
	    }
	    else {
		$tot[0] = $acc_ibalance;
	    }
	    # $rep->addline('D2', '', _T("Beginsaldo"), @tot);
	}
	my $sth = $dbh->sql_exec
	  ("SELECT jnl_amount,jnl_desc".
	   " FROM Journal".
	   " WHERE jnl_acc_id = ?".
	   " ORDER BY jnl_bsr_date", $acc_id);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($amount, $desc) = @$rr;
	    $did++;
	    my @t = (0) x 4;
	    $t[$amount<0] += abs($amount);
	    # $rep->addline('D2', '', $desc, @t);
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	$tot[0] ||= "00" if $did;
	$tot[1] ||= "00" if $did;
	@tot;
    };
    my $grootboeken = sub {
	my ($vd, $hvd) = shift;
	my @tot = (0) x 4;
	my $sth = $dbh->sql_exec
	  ("SELECT acc_id, acc_desc, acc_balance, acc_ibalance".
	   " FROM Accounts".
	   " WHERE acc_struct = ?".
	   " AND ( acc_ibalance <> 0".
	   "       OR acc_id IN ( SELECT DISTINCT jnl_acc_id FROM Journal ))".
	   " ORDER BY acc_id", $vd->[0]);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($acc_id, $acc_desc, $acc_balance, $acc_ibalance) = @$rr;
	    my @t = $journaal->($acc_id, $acc_desc, $acc_ibalance);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    next unless $detail > 1;

	    if ( $hvd_hdr ) {
		$rep->add({ acct => $hvd_hdr->[0],
			    desc => $hvd_hdr->[1],
			    _style => 'h1',
			  });
		undef $hvd_hdr;
	    }
	    if ( $vd_hdr ) {
		$rep->add({ acct => $vd_hdr->[0],
			    desc => $vd_hdr->[1],
			    _style => 'h2',
			  });
		undef $vd_hdr;
	    }
	    $rep->add({ _style => 'd2',
			acct => $acc_id,
			desc => $acc_desc,
			deb  => numfmt($t[0]),
			crd  => numfmt($t[1]),
			$t[2] ? ( sdeb => numfmt($t[2]) ) : (),
			$t[3] ? ( scrd => numfmt($t[3]) ) : (),
		      });
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	@tot;
    };
    my $verdichtingen = sub {
	my ($hvd) = shift;
	my @tot = (0) x 4;
	my $did = 0;
	foreach my $vd ( @{$hvd->[2]} ) {
	    next unless defined $vd;
	    $vd_hdr = [ $vd->[0], $vd->[1] ];
	    my @t = $grootboeken->($vd, $hvd);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    next unless $detail > 0;
	    if ( $hvd_hdr ) {
		$rep->add({ acct => $hvd_hdr->[0],
			    desc => $hvd_hdr->[1],
			    _style => 'h1',
			  });
		undef $hvd_hdr;
	    }
	    $rep->add({ _style => 't2',
			acct => $vd->[0],
			desc => __x("Totaal {vrd}", vrd => $vd->[1]),
			$t[0] ? ( deb  => numfmt($t[0]) ) : (),
			$t[1] ? ( crd  => numfmt($t[1]) ) : (),
			$t[2] ? ( sdeb => numfmt($t[2]) ) : (),
			$t[3] ? ( scrd => numfmt($t[3]) ) : (),
		      });
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	@tot;
    };
    my $hoofdverdichtingen = sub {
	my (@hvd) = @_;
	my @tot = (0) x 4;
	foreach my $hvd ( @hvd ) {
	    next unless defined $hvd;
	    $hvd_hdr = [ $hvd->[0], $hvd->[1] ];
	    my @t = $verdichtingen->($hvd);
	    next if "@t" eq "0 0 0 0";
	    if ( $detail && $hvd_hdr ) {
		$rep->add({ acct => $hvd_hdr->[0],
			    desc => $hvd_hdr->[1],
			    _style => 'h1',
			  });
		undef $hvd_hdr;
	    }
	    $rep->add({ _style => 't1',
			acct => $hvd->[0],
			desc => __x("Totaal {vrd}", vrd => $hvd->[1]),
			$t[0] ? ( deb  => numfmt($t[0]) ) : (),
			$t[1] ? ( crd  => numfmt($t[1]) ) : (),
			$t[2] ? ( sdeb => numfmt($t[2]) ) : (),
			$t[3] ? ( scrd => numfmt($t[3]) ) : (),
		      });
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	}
	@tot;
    };

    if ( $detail >= 0 ) {	# Verdicht
	my @vd;
	my @hvd;
	$sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
			      " FROM Verdichtingen".
			      " WHERE vdi_struct IS NULL".
			      " ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    $hvd[$rr->[0]] = [ @$rr, []];
	}

	@vd = @hvd;
	$sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc, vdi_struct".
			      " FROM Verdichtingen".
			      " WHERE vdi_struct IS NOT NULL".
			      " ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    push(@{$hvd[$rr->[2]]->[2]}, [@$rr]);
	    @vd[$rr->[0]] = [@$rr];
	}

	my @tot = $hoofdverdichtingen->(@hvd);
	$rep->add({ _style => 't',
		    desc => _T("TOTAAL"),
		    $tot[0] ? ( deb  => numfmt($tot[0]) ) : (),
		    $tot[1] ? ( crd  => numfmt($tot[1]) ) : (),
		    $tot[2] ? ( sdeb => numfmt($tot[2]) ) : (),
		    $tot[3] ? ( scrd => numfmt($tot[3]) ) : (),
		  });
    }

    else {			# Op Grootboek

	my @tot = (0) x 4;
	my $sth = $dbh->sql_exec
	  ("SELECT acc_id, acc_desc, acc_balance, acc_ibalance".
	   " FROM Accounts".
	   " WHERE ( acc_ibalance <> 0".
	   "         OR acc_id IN ( SELECT DISTINCT jnl_acc_id FROM Journal ))".
	   " ORDER BY acc_id");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($acc_id, $acc_desc, $acc_balance, $acc_ibalance) = @$rr;
	    my @t = $journaal->($acc_id, $acc_desc, $acc_ibalance);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    $rep->add({ _style => 'd',
			acct => $acc_id,
			desc => $acc_desc,
			deb  => numfmt($t[0]),
			crd  => numfmt($t[1]),
			$t[2] ? ( sdeb => numfmt($t[2]) ) : (),
			$t[3] ? ( scrd => numfmt($t[3]) ) : (),
		      });
	}
	$rep->add({ _style => 't',
		    desc => _T("TOTAAL"),
		    deb  => numfmt($tot[0]),
		    crd  => numfmt($tot[1]),
		    $tot[2] ? ( sdeb => numfmt($tot[2]) ) : (),
		    $tot[3] ? ( scrd => numfmt($tot[3]) ) : (),
		  });
    }
    $rep->finish;
}

package EB::Report::Proof::Text;

use EB;
use base qw(EB::Report::Reporter::Text);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
    $self->{detail} = $opts->{detail};
    $self;
}

# Style mods.

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	d2  => {
	    desc   => { indent      => 2 },
	},
	t2  => {
	    _style => { skip_after  => $self->{detail} > 1, },
	    desc   => { indent      => 1 },
	},
	h2  => {
	    desc   => { indent      => 1 },
	},
	t1 => {
	    _style => { skip_after  => $self->{detail} > 0,
			skip_before => $self->{detail} > 1,
		      },
	},
	t => {
	    _style => { line_before => 1 }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::Proof::XXXText;

use strict;
use warnings;

use EB;
use EB::Finance;
use base qw(EB::Report::GenBase);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

my ($title, $period, $tag3, $adm, $now, $ident);

sub start {
    my ($self, $t1, $t2) = @_;
    $title = $t1;
    $period = $t2;
    $tag3 = $self->{detail} >= 0 ? _T("Verdichting/Grootboekrekening") : _T("Grootboekrekening");
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
    $self->{fh}->format_top_name('rt00');
}

my ($acc, $desc, $deb, $crd, $sdeb, $scrd);

sub addline {
    my ($self, $type);
    ($self, $type, $acc, $desc, $deb, $crd, $sdeb, $scrd) = @_;

    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd, $sdeb, $scrd ) {
	$_ = $_ ? numfmt($_) : '';
    }

    if ( $type =~ /^D(\d+)/ ) {
	$desc = (" " x $1) . $desc;
    }
    elsif ( $type =~ /^[HT](\d+)/ ) {
	$desc = (" " x ($1-1)) . $desc;
    }

    if ( $type eq 'T' ) {
	$self->{fh}->format_write(__PACKAGE__.'::rtl');
	$self->{fh}->format_write(__PACKAGE__.'::rt01');
	return;
    }

    $self->{fh}->format_write(__PACKAGE__.'::rt01');
    if ( $type =~ /^T(\d+)$/ && $1 <= $self->{detail} ) {
	($acc, $desc, $deb, $crd, $sdeb, $scrd) = ('') x 6;
	$self->{fh}->format_write(__PACKAGE__.'::rt01');
    }
}

sub finish {
}

format rt00 =
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$period
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $ident . ", " . $now

@<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>  @>>>>>>>>  @>>>>>>>>  @>>>>>>>>
_T("RekNr"), $tag3, _T("Debet"), _T("Credit"), _T("Saldo Db"), _T("Saldo Cr")
--------------------------------------------------------------------------------------------
.

format rtl =
--------------------------------------------------------------------------------------------
.

format rt01 =
@<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>  @>>>>>>>>  @>>>>>>>>  @>>>>>>>>
$acc, $desc, $deb, $crd, $sdeb, $scrd
.

1;
