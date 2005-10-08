# RCS Info        : $Id: GenBase.pm,v 1.1 2005/10/08 20:38:15 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct  8 16:40:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct  8 21:43:34 2005
# Update Count    : 5
# Status          : Unknown, Use with caution!

package EB::Report::GenBase;

use strict;
use EB;

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    my $self = { $opts };
    bless $self => $class;

    # Output.
    if ( $opts->{output} ) {
	open(my $fh, ">", $opts->{output})
	  or die("?".__x("Fout tijdens aanmaken {file}: {err}",
			 file => $opts->{output}, err => $!)."\n");
	$self->{fh} = $fh;
    }
    else {
	$self->{fh} = *STDOUT;
    }

    # Pagesize
    $self->{page} = defined($opts->{page}) ? $opts->{page} : 999999;

    $self;
}

# API.
sub start {}
sub outline {}
sub finish {}

1;
