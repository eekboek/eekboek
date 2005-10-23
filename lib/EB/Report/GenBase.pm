# RCS Info        : $Id: GenBase.pm,v 1.6 2005/10/23 19:28:04 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct  8 16:40:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct 22 21:37:06 2005
# Update Count    : 57
# Status          : Unknown, Use with caution!

package main;

our $dbh;

package EB::Report::GenBase;

use strict;
use EB;
use IO::File;

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    my $self = { %$opts };
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

    # Short options, like --html.
    for ( qw(html csv text) ) {
	$gen = $_ if $opts->{$_};
    }

    # Override by explicit --gen-XXX option(s).
    foreach ( keys(%$opts) ) {
	next unless /^gen-(.*)$/;
	$gen = $1;
    }

    # Infer from filename extension.
    my $t;
    if ( !defined($gen) && ($t = $opts->{output}) && $t =~ /\.([^.]+)$/ ) {
	my $ext = lc($1);
	$ext = $extmap{$ext} || $ext;
	$gen = $ext;
    }

    # Fallback to text.
    $gen ||= "text";

    # Build class and package name.
    my $class = (ref($self)||$self) . "::" . ucfirst($gen);
    my $pkg = $class;
    $pkg =~ s;::;/;g;;
    $pkg .= ".pm";

    # Try to load backend.
    eval { require $pkg } unless do { no strict 'refs'; exists ${$class."::"}{new} };
    die("?".__x("Onbekend uitvoertype: {gen}\n{err}",
		gen => $gen, err => $@)."\n") if $@;
    my $be = $class->new($opts);

    # Handle output redirection.
    if ( $opts->{output} && $opts->{output} ne '-' ) {
	$be->{fh} = IO::File->new($opts->{output}, "w")
	  or die("?".__x("Fout tijdens aanmaken {file}: {err}",
			 file => $opts->{output}, err => $!)."\n");
    }
    else {
	$be->{fh} = IO::File->new_from_fd(fileno(STDOUT), "w");
    }

    # Handle pagesize.
    $be->{fh}->format_lines_per_page($be->{page} = defined($opts->{page}) ? $opts->{page} : 999999);

    if ( $opts->{per} ) {
	die(_T("--per sluit --periode uit")."\n") if $opts->{periode};
	die(_T("--per sluit --boekjaar uit")."\n") if defined $opts->{boekjaar};
	$be->{periode} = [$opts->{per},$opts->{per}];
	$be->{per_end} = $opts->{per};
	$be->{periodex} = 1;
    }
    elsif ( $opts->{periode} ) {
	die(_T("--periode sluit --boekjaar uit")."\n") if defined $opts->{boekjaar};
	$be->{periode} = $opts->{periode};
	$be->{per_begin} = $opts->{periode}->[0];
	$be->{per_end} = $opts->{periode}->[1];
	$be->{periodex} = 2;
    }
    elsif ( defined($opts->{boekjaar}) || defined($opts->{d_boekjaar}) ) {
	my $bky = $opts->{boekjaar};
	$bky = $opts->{d_boekjaar} unless defined $bky;
	my $rr = $dbh->do("SELECT bky_begin, bky_end".
			  " FROM Boekjaren".
			  " WHERE bky_code = ?", $bky);
	die("?",__x("Onbekend boekjaar: {bky}", bky => $bky)."\n"), return unless $rr;
	my ($begin, $end) = @$rr;
	$be->{periode} = [$begin, $end];
	$be->{per_begin} = $begin;
	$be->{per_end} = $end;
	$be->{periodex} = 3;
    }
    else {
	$be->{periode} = [ $dbh->adm("begin"),
			   iso8601date() ];
	$be->{per_begin} = $opts->{periode}->[0];
	$be->{per_end} = $opts->{periode}->[1];
	$be->{periodex} = 0;
    }

    if ( $be->{per_end} gt iso8601date() ) {
	$be->{periode}->[1] = $be->{per_end} = iso8601date();
    }

    # Return instance.
    $be;
}

my %bec;

sub backend_options {
    my (undef, $self, $opts) = @_;

    my $pkg = ref($self) || $self;
    $pkg =~ s;::;/;g;;
    return @{$bec{$pkg}} if $bec{$pkg};

    # Always assume a text backend.
    my %be = ( text => 1 );
    my @opts = qw(output=s page=i);

    # Find files.
    foreach my $lib ( @INC ) {
	my @files = glob("$lib/$pkg/*.pm");
	next unless @files;
	# warn("=> be_opt: found ", scalar(@files), " files in $lib/$pkg\n");
	foreach ( @files ) {
	    next unless m;/([^/]+)\.pm$;;
	    # Actually, we should check whether the class implements the
	    # GenBase API, but we can't do that without preloading all
	    # backends.
	    $be{lc($1)}++;
	}
    }

    # Short --XXX for known backends.
    foreach ( qw(html csv text) ) {
	push(@opts, $_) if $be{$_};
    }
    # Explicit --gen-XXX for all backends.
    push(@opts, map { +"gen-$_"} keys %be);
    # Cache.
    $bec{$pkg} = [@opts];

    @opts;			# better be list context
}

1;
