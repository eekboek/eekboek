#! perl --			-*- coding: utf-8 -*-

use utf8;

# Assertions.pm -- Administratie assertions
# Author          : Johan Vromans
# Created On      : Mon Jun 11 09:24:47 2012
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jun 11 13:16:59 2012
# Update Count    : 7
# Status          : Unknown, Use with caution!

package main;

our $cfg;
our $dbh;

package EB::Tools::Assertions;

use strict;
use warnings;

use EB;
use EB::Format;

sub new {
    my ($class) = @_;
    $class = ref($class) || $class;
    return bless {} => $class;
}

sub perform {
    my ($self, $args, $opts) = @_;

    if ( @$args > 0 && lc($args->[0]) eq _T("grootboekrekening") ) {
	shift(@$args);
    }
    if ( @$args == 1 && $args->[0] =~ /^\d+$/ ) {
	# Assert account balance.
	my $balance = $dbh->lookup( $args->[0], qw( Accounts acc_id acc_balance) );
	unless ( defined $balance ) {
	    warn("?".__x("Onbekende grootboekrekening: {acct}",
			 acct => $args->[0])."\n");
	    return;
	}
	if ( defined $opts->{saldo} ) {
	    my $amt = amount( $opts->{saldo} );
	    unless ( defined $amt ) {
		warn("?".__x("Ongeldig bedrag: {amt}",
			     amt => $amt)."\n");
		return;
	    }
	    if ( $amt eq $balance ) {
		warn("%".__x("Grootboekrekening {acct} heeft saldo {amt}",
			     acct => $args->[0], amt => numfmt($balance))."\n")
		  if $opts->{verbose};
		return;
	    }
	    warn("?".__x("Grootboekrekening {acct} heeft saldo {amt} in plaats van {exp}",
			     acct => $args->[0], amt => numfmt($balance), exp => numfmt($amt))."\n");
	    return;
	}
	warn("%".__x("Grootboekrekening {acct} heeft saldo {amt}",
		     acct => $args->[0], amt => numfmt($balance))."\n");
	return;
    }
    warn("?"._T("Ongeldige verificatie-opdracht.")."\n");
    return;
}

1;
