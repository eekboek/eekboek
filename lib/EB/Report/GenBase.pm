# RCS Info        : $Id: GenBase.pm,v 1.2 2005/10/09 20:27:22 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct  8 16:40:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Oct  9 22:19:12 2005
# Update Count    : 27
# Status          : Unknown, Use with caution!

package EB::Report::GenBase;

use strict;
use EB;

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    my $self = { $opts };
    bless $self => $class;
}

# API.
sub _oops   { warn("?Package ".ref($_[0])." did not implement '$_[1]' method\n") }
sub start   { shift->_oops('start')   }
sub outline { shift->_oops('outline') }
sub finish  { shift->_oops('finish')  }

# Class methods

sub backend {
    my (undef, $self, $opts) = @_;

    my %extmap = ( txt => "text", htm => "html" );

    my $gen;
    for ( qw(html csv text) ) {
	$gen = $_ if $opts->{$_};
    }

    $gen = $opts->{gen} if defined $opts->{gen};

    my $t;
    if ( !defined($gen) && ($t = $opts->{output}) && $t =~ /\.([^.]+)$/ ) {
	my $ext = lc($1);
	$ext = $extmap{$ext} || $ext;
	$gen = $ext;
    }
    $gen ||= "text";

    my $class = ref($self) . "::" . ucfirst($gen);
    my $pkg = $class;
    $pkg =~ s;::;/;g;;
    $pkg .= ".pm";

    eval { require $pkg } unless do { no strict 'refs'; exists ${$class."::"}{new} };
    die("?".__x("Onbekend uitvoertype: {gen}\n{err}",
		gen => $gen, err => $@)."\n") if $@;
    my $be = $class->new($opts);

    # Output.
    if ( $opts->{output} && $opts->{output} ne '-' ) {
	open(my $fh, ">", $opts->{output})
	  or die("?".__x("Fout tijdens aanmaken {file}: {err}",
			 file => $opts->{output}, err => $!)."\n");
	$be->{fh} = $fh;
    }
    else {
	$be->{fh} = *STDOUT;
    }

    # Pagesize
    $be->{page} = defined($opts->{page}) ? $opts->{page} : 999999;

    $be;
}

1;
