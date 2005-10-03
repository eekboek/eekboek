# SQLEngine.pm -- 
# RCS Info        : $Id: SQLEngine.pm,v 1.3 2005/10/03 20:16:23 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Sep 28 20:45:55 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Oct  3 22:05:00 2005
# Update Count    : 28
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

my $postgres; BEGIN { $postgres = 1 };

sub process {
    my ($self, $cmd, $copy) = (@_, 0);
    my $sql = "";
    my $dbh = $self->{dbh} || $::dbh;

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
		$dbh->dbh->pg_endcopy if $postgres;
		$copy = 0;
	    }
	    elsif ( $postgres ) {
		# Use PostgreSQL fast load.
		$dbh->dbh->pg_putline($line."\n");
	    }
	    else {
		# Use portable INSERT.
		$dbh->sql_exec($copy,
			       map { $_ eq 't' ? 1 :
				       $_ eq 'f' ? 0 :
					 $_ eq '\\N' ? undef :
					   $_
				       } split(/\t/, $line))->finish;
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
		warn("+ INTERCEPTED:: $sql\n") if $self->{trace};
		$dbh->dbh->begin_work if $dbh->{AutoCommit};
	    }
	    elsif ( $sql =~ /^commit\b/i ) {
		warn("+ INTERCEPTED: $sql\n") if $self->{trace};
		$dbh->dbh->commit;
	    }
	    elsif ( $sql =~ /^rollback\b/i ) {
		warn("+ INTERCEPTED: $sql\n") if $self->{trace};
		$dbh->dbh->rollback;
	    }
	    else {
		# Execute.
		warn("+ $sql\n") if $self->{trace};
		$dbh->dbh->do($sql);
	    }
	    $sql = "";
	}
    }

    die("?".__x("Incompleet SQL commando: {sql}", sql => $sql)."\n") if $sql;
}

1;
