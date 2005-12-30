# Reporter.pm -- 
# RCS Info        : $Id: Reporter.pm,v 1.1 2005/12/30 17:09:35 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Dec 28 13:18:40 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Dec 30 16:22:43 2005
# Update Count    : 103
# Status          : Unknown, Use with caution!
#!/usr/bin/perl -w

package EB::Report::Reporter;

use strict;
use warnings;
use EB;

sub new {
    my ($class, $config) = @_;
    $class = ref($class) || $class;
    my $self = bless { _fields => [],
		       _fdata => {},
		     }, $class;

    foreach my $col ( @$config ) {
	if ( $col->{name} ) {
	    my $a = { name  => $col->{name},
		      title => $col->{title} || ucfirst(lc(_T($a->{name}))),
		      width => $col->{width} || length($a->{title}),
		      align => $col->{align} || "<",
		      style => $col->{style} || $col->{name},
		    };
	    $self->{_fdata}->{$a->{name}} = $a;
	    push(@{$self->{_fields}}, $a);
	}
	elsif ( $col->{style} ) {
	    $self->{_style} = $col->{style};
	}
	else {
	    die("?"._T("Ontbrekend \"name\" of \"style\""));
	}
    }

    # Return object.
    $self;
}

sub fields {
    my ($self, @f) = @_;

    my @nf;			# new order of fields

    foreach my $fld ( @f ) {
	my $a = $self->{_fdata}->{$fld};
	die("?".__x("Onbekend veld: {fld}", fld => $fld)."\n")
	  unless defined($a);
	push(@nf, $a);
    }
    $self->{_fields} = \@nf;

    # PBP: Return nothing sensible.
    return;
}

sub start {
    my $self = shift;
    my ($t1, $t2, $t3l, $t3r);
    if ( @_ == 1 && exists($self->{periodex}) ) {
	$t1 = shift;
	if ( $self->{periodex} == 1 ) {
	    $t2 = __x("Periode: t/m {to}",
		      to   => $self->{periode}->[1]);
	}
	else {
	    $t2 = __x("Periode: {from} t/m {to}",
		      from => $self->{periode}->[0],
		      to   => $self->{periode}->[1]);
	}
	$t3l = $::dbh->adm("name");
	my ($begin, $end) = @{$self->{periode}};
	if ( $ENV{EB_SQL_NOW} ) {
	    $t3r = (split(' ', $EB::ident))[0];
	    $end = $ENV{EB_SQL_NOW} if $ENV{EB_SQL_NOW} lt $end;
	    $t3r .= ", " . $end;
	}
	else {
	    $t3r = $EB::ident . ", " . iso8601date();
	}
    }
    else {
	($t1, $t2, $t3l, $t3r) = @_;
    }
    $self->{_title1} = $t1;
    $self->{_title2} = $t2;
    $self->{_title3l} = $t3l;
    $self->{_title3r} = $t3r;
    $self->{_needhdr} = 1;
    $self->{_needskip} = 0;
    $self->{fd} ||= *STDOUT;
}

sub finish {
    my ($self) = @_;
}

sub add {
    my ($self, $data) = @_;

    while ( my($k,$v) = each(%$data) ) {
	die("?",__x("Ongeldig veld: {fld}", fld => $k))
	  unless defined $self->{_fdata}->{$k};
    }

}

sub _getstyle {
    my $self = shift;
    my $t = $self->can(join("__", "STYLE", $self->{_style}, @_));
    return $t ? $t->($self) : undef;
}

sub _checkhdr {
    my ($self) = @_;
    return unless $self->{_needhdr};
    $self->{_needhdr} = 0;
    $self->header;
}

1;
