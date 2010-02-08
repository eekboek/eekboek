#! perl --			-*- coding: utf-8 -*-

use utf8;

# RCS Id          : $Id: DeLuxe.pm,v 1.25 2010/02/08 13:58:39 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Feb  8 14:58:04 2010
# Update Count    : 283
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;

package EB::Shell::DeLuxe;

use strict;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.25 $ =~ /(\d+)/g;

use base qw(EB::Shell::Base);
use EB;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $opts = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };

    $opts->{interactive} = 0 if $opts->{command};
    $opts->{interactive} = -t unless defined $opts->{interactive};

    unless ( $opts->{interactive} ) {
	no strict 'refs';
	*{"init_rl"}  = sub {};
	*{"histfile"} = sub {};
	*{"print"}    = sub { shift; CORE::print @_ };
    }
    else {
	no strict 'refs';
	*{"init_rl"}  = sub { shift->SUPER::init_rl(@_) };
	*{"histfile"} = sub { shift->SUPER::histfile(@_) };
	*{"print"}    = sub { shift->SUPER::print(@_) };
    }

    my $self = $class->SUPER::new($opts);
    $self->{$_} = $opts->{$_} foreach keys(%$opts);

    if ( $opts->{command} ) {
	$self->{readline} = \&readline_command;
    }
    elsif ( $opts->{interactive} ) {
	$self->{readline} = \&readline_interactive;
    }
    else {
	$self->{readline} = sub { $self->readline_file(sub { <STDIN> }) };
    }
    $self->{inputstack} = [];
    $self->{errexit} = $opts->{errexit};
    $self;
}

sub readline_interactive {
    my ($self, $prompt) = @_;
    return $self->term->readline($prompt);
}

use Encode;

sub readline_file {
    my ($self, $rl) = @_;
    my $line;
    my $pre = "";
    while ( 1 ) {
	$line = $rl->();
	unless ( $line ) {
	    warn("?"._T("Vervolgregel ontbreekt in de invoer.")."\n") if $pre;
	    return;
	}

	if ( $line =~ /^\# \s*
		       content-type: \s*
                       text (?: \s* \/ \s* plain)? \s* ; \s*
                       charset \s* = \s* (\S+) \s* $/ix ) {

	    my $charset = lc($1);
	    if ( $charset =~ /^(?:utf-?8)$/i ) {
		next;
	    }
	    die("?"._T("Invoer moet Unicode (UTF-8) zijn.")."\n");
	}

=begin thismustbefixed

	if ( $self->{unicode} xor $cfg->unicode  ) {
	    my $s = $line;
	    eval {
		if ( $cfg->unicode ) {
		    $line = decode($self->{unicode} ? 'utf8' : 'latin1', $s, 1);
		}
		else {
		    Encode::from_to($line, 'utf8', 'latin1', 1);
		}
	    };
	    if ( $@ ) {
		warn("?".__x("Geen geldige {cs} tekens in regel {line} van de invoer",
			     cs => $self->{unicode} ? "UTF-8" : "Latin1",
			     line => $.)."\n".$line."\n");
		next;
	    }
	}

=cut

	my $s = $line;
	my $t = "".$line;
	eval {
	    $line = decode('utf8', $s, 1);
	};
	if ( $@ ) {
	    warn("?".__x("Geen geldige UTF-8 tekens in regel {line} van de invoer",
			 line => $.)."\n".$t."\n");
	    next;
	}

	if ( $self->{echo} ) {
	    my $pr = $self->{echo};
	    $pr =~ s/\>/>>/ if $pre;
	    print($pr, $line);
	}
	unless ( $line =~ /\S/ ) {
	    # Empty line will stop \ continuation.
	    return $pre if $pre ne "";
	    next;
	}
	next if $line =~ /^\s*#/;
	chomp($line);
	$line =~ s/\s+#.+$//;
	if ( $line =~ /(^.*)\\$/ ) {
	    $line = $1;
	    $line =~ s/\s+$/ /;
	    $pre .= $line;
	    next;
	}
	return $pre.$line;
    }

}

sub attach_file {
    my ($self, $file) = @_;
    push( @{ $self->{inputstack} }, [ $self->{readline} ] );
    $self->{readline} = sub { shift->readline_file(sub { <$file> }) };
}

sub attach_lines {
    my ($self, $lines) = @_;
    push( @{ $self->{inputstack} }, [ $self->{readline} ] );
    my @lines = @$lines;
    $self->{readline} = sub {
	shift->readline_file(sub {
				 shift(@lines);
			     })
    };
}

sub readline_command {
    my ($self, $prompt) = @_;
    return undef unless @ARGV;
    return shift(@ARGV) if @ARGV == 1;
    my $line = "";
    while ( @ARGV ) {
	my $word = shift(@ARGV);
	$word =~ s/('|\\)/\\$1/g;
	$line .= " " if $line ne "";
	$line .= "'" . $word . "'";
    }
    return $line;
}

sub readline {
    my ($self, $prompt) = @_;
    my $ret;
    while ( !defined($ret = $self->{readline}->($self, $prompt)) ) {
	return unless @{$self->{inputstack}};
	( $self->{readline} ) = @{pop(@{$self->{inputstack}})};
    }
    # Command parsing gets stuck on leading blanks.
    $ret =~ s/^\s+//;
    $ret =~ s/\s+$//;
    return $ret;
}

1;
