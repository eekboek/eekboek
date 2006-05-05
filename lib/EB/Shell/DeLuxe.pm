#!/usr/bin/perl

my $RCS_Id = '$Id: DeLuxe.pm,v 1.12 2006/05/05 15:35:11 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri May  5 16:20:56 2006
# Update Count    : 230
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;

package EB::Shell::DeLuxe;

use strict;
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

    my $self = $class->SUPER::new($opts);
    $self->{$_} = $opts->{$_} foreach keys(%$opts);

    if ( $opts->{command} ) {
	$self->{readline} = \&readline_command;
    }
    elsif ( $opts->{interactive} ) {
	$self->{readline} = \&readline_interactive;
    }
    else {
	$self->{readline} = sub { $self->readline_file(*STDIN) };
    }
    $self->{inputstack} = [];
    $self->{unicode} = $cfg->unicode;
    $self;
}

sub readline_interactive {
    my ($self, $prompt) = @_;
    return $self->term->readline($prompt);
}

use Encode;

sub readline_file {
    my ($self, $fd) = @_;
    # binmode($fd, ":utf8") conflicts with UNICODE checking.
    #binmode($fd, ":utf8") if $cfg->unicode;
    my $line;
    my $pre = "";
    while ( 1 ) {
	$line = <$fd>;
	return unless $line;

	if ( $line =~ /^#\s*content-type:\s+text;\s*charset\s*=\s*(\S+)\s*$/i ) {
	    my $charset = lc($1);
	    if ( $charset =~ /^(?:latin[19]|iso-?8859[-.]15?)$/i ) {
		$self->{unicode} = 0;
		next;
	    }
	    if ( $charset =~ /^(?:unicode|utf-?8)$/i ) {
		$self->{unicode} = 1;
		next;
	    }
	}

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
    push(@{$self->{inputstack}}, [$self->{readline}, $self->{unicode}]);
    $self->{readline} = sub { shift->readline_file($file) };
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
	($self->{readline}, $self->{unicode}) = @{pop(@{$self->{inputstack}})};
    }
    return $ret;
}

1;

__END__

=head1 NAME

EB::Shell::DeLuxe - A generic class to build line-oriented command interpreters.

=head1 SYNOPSIS

  package My::Shell;

  use base qw(EB::Shell::DeLuxe);

  sub do_greeting {
      return "Hello!"
  }

=head1 DESCRIPTION

EB::Shell::DeLuxe is a base class designed for building command line
programs.  It inherits from L<EB::Shell::Base>.

=head2 Features

EB::Shell::DeLuxe extends EB::Shell::Base with the following features:

=over 4

=item Reading commands from files

This implements batch processing in the style of "sh < commands.sh".

All commands are read from the standard input, and processing
terminates after the last command has been read.

Commands read this way can be backslash-continued.

=item Single command execution

This implements command execution in the style of "sh -c 'command'".

One single command is executed.

=back

=head1 METHODS

=over 4

=item new

The constructor is called C<new>.  C<new> should be called with a
reference to a hash of name => value parameters:

  my $opts = { OPTION_1 => $one,
	       OPTION_2 => $two };

  my $shell = EB::Shell::DeLuxe->new($opts);

EB::Shell::DeLuxe extends the options of EB::Shell::Base with:

=over 4

=item interactive

Controls whether this instance is interactive, i.e, uses ReadLine to
read commands.

Defaults to true unless the standard input is not a terminal.

=item command

Controls whether this instance executes a single command, that is
contained in @ARGV;

  @ARGV = ( "exec", "this", "command" );
  my $opts = { command => 1 };
  my $shell = EB::Shell::DeLuxe->new($opts);
  $shell->run;

=item prompt

The prompt for commands.

=item echo

If true, commands read from the standard input are echoed with the
value of this option as a prefix. Valid for non-interactive use only.

=back

=head1 AUTHOR

Johan Vromans E<lt>jvromans@squirrel.nl<gt>

=head1 COPYRIGHT

Copyright (C) 2005,2006 Squirrel Consultancy. All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

