# SQLEngine.pm -- 
# RCS Info        : $Id: SQLEngine.pm,v 1.6 2006/01/16 10:48:39 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Sep 28 20:45:55 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jan 16 11:44:44 2006
# Update Count    : 47
# Status          : Unknown, Use with caution!

package EB::Tools::SQLEngine;

use EB;
use strict;

sub new {
    my ($class, @args) = @_;
    $class = ref($class) || $class;
    bless { _cb => {}, @args } => $class;
}

sub callback($%) {
    my ($self, %vec) = @_;
    return unless %vec;
    while ( my($k,$v) = each(%vec) ) {
	$self->{_cb}->{$k} = $v;
    }
}

# Basic SQL processor. Not very advanced, but does the job.
# Note that COPY status will not work across different \i providers.
# COPY status need to be terminated on the same level it was started.

# If we have PostgreSQL and it is of a suitable version, we can use
# fast loading.
my $postgres;

sub process {
    my ($self, $cmd, $copy) = (@_, 0);
    my $sql = "";
    my $dbh = $self->{dbh} || $::dbh->dbh;

    # Check Pg version.
    unless ( defined($postgres) ) {
	$postgres = ($DBD::Pg::VERSION||0) >= 1.41;
	warn("%Not using PostgreSQL fast load. DBD::Pg::VERSION = ",
	     ($DBD::Pg::VERSION||0), "\n") unless $postgres;
    }

    foreach my $line ( split(/\n/, $cmd) ) {

	# Detect \i provider (include).
	if ( $line =~ /^\\i\s+(.*).sql/ ) {
	    my $call = $self->{_cb}->{$1};
	    die("?".__x("SQLEngine: No callback for {cb}",
			cb => $1)."\n") unless $call;
	    $self->process($call->(), $copy);
	    next;
	}

	# Handle COPY status.
	if ( $copy ) {
	    if ( $line eq "\\." ) {
		# End COPY.
		$dbh->pg_endcopy if $postgres;
		$copy = 0;
	    }
	    elsif ( $postgres ) {
		# Use PostgreSQL fast load.
		$dbh->pg_putline($line."\n");
	    }
	    else {
		# Use portable INSERT.
		my @args = map { $_ eq 't' ? 1 :
				   $_ eq 'f' ? 0 :
				     $_ eq '\\N' ? undef :
				       $_
				   } split(/\t/, $line);
		my $s = $copy;
		my @a = map {
		    !defined($_) ? "NULL" :
		      /^[0-9]+$/ ? $_ : $dbh->quote($_)
		  } @args;
		$s =~ s/\?/shift(@a)/eg;
		warn("++ $s;\n");
		my $sth = $dbh->prepare($copy);
		$sth->execute(@args);
		$sth->finish;
	    }
	    next;
	}

	# Ordinary lines.
	# Strip comments.
	$line =~ s/--.*$//m;
	# Ignore empty lines.
	next unless $line =~ /\S/;
	# Trim whitespace.
	$line =~ s/\s+/ /g;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	# Append to command string.
	$sql .= $line . " ";

	# Execute if trailing ;
	if ( $line =~ /(.+);$/ ) {

	    # Check for COPY/
	    if ( $sql =~ /^copy\s(\S+)\s+(\([^\051]+\))/i ) {
		if ( $postgres ) {
		    # Use PostgreSQL fast load.
		    $copy = 1;
		}
		else {
		    # Prepare SQL statement.
		    $copy = "INSERT INTO $1 $2 VALUES (" .
		      join(",", map { "?" } split(/,/, $2)) . ")";
		    $sql = "";
		    next;
		}
	    }

	    # Intercept transaction commands. Must be handled by DBI calls.
	    if ( $sql =~ /^begin\b/i ) {
		warn("++ INTERCEPTED:: $sql\n") if $self->{trace};
		$dbh->begin_work if $dbh->{AutoCommit};
	    }
	    elsif ( $sql =~ /^commit\b/i ) {
		warn("++ INTERCEPTED: $sql\n") if $self->{trace};
		$dbh->commit;
	    }
	    elsif ( $sql =~ /^rollback\b/i ) {
		warn("++ INTERCEPTED: $sql\n") if $self->{trace};
		$dbh->rollback;
	    }
	    else {
		# Execute.
		warn("++ $sql\n") if $self->{trace};
		$dbh->do($sql);
	    }
	    $sql = "";
	}
    }

    die("?".__x("Incompleet SQL commando: {sql}", sql => $sql)."\n") if $sql;
}

1;
