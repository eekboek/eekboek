#!/usr/bin/perl -w

package EB::Report::Text;

use strict;
use warnings;
use EB;

sub new {
    my ($class, $config) = @_;
    $class = ref($class) || $class;
    my $self = bless { _fields => [],
		       _fdata => {},
		     }, $class;

    my $format = "";		# format in progress
    my $width = 0;		# width in progress

    my $needspace;		# need space between next column

    my $addspace = sub {	# add space
	my $w = shift;
	$width += $w;
	$format .= " " x $w;
	$needspace = 0;
    };

    foreach my $col ( @$config ) {
	if ( $col->{name} && $col->{name} =~ /\S/ ) {
	    my $a = { name  => $col->{name},
		      title => $col->{title} || ucfirst(lc(_T($a->{name}))),
		      width => $col->{width} || length($a->{title}),
		      align => $col->{align} || "<",
		      style => $col->{style} || $col->{name},
		    };
	    $self->{_fdata}->{$a->{name}} = $a;
	    push(@{$self->{_fields}}, $a);

	    if ( $needspace ) {
		$addspace->(2);
	    }

	    # Add to format and width,
	    $width += $a->{width};
	    $format .= "%".
	      ( $a->{align} eq "<" ? "-" : "" ) .
	      join(".", ($a->{width}) x 2) .
	      "s";

	    $needspace++;
	}
	elsif ( $col->{style} ) {
	    $self->{_style} = $col->{style};
	}
	elsif ( $col->{width} ) {
	    $addspace->($col->{width});
	}
	else {
	    die("?"._T("Naamloos veld moet een style of width hebben"));
	}
    }

    # Store format and width in object.
    $self->{_format} = $format . "\n";
    $self->{_width}  = $width;

    # Return object.
    $self;
}

sub fields {
    my ($self, @f) = @_;

    my @nf;			# new order of fields
    my $width = 0;		# new width
    my $format = "";		# new format

    foreach my $fld ( @f ) {
	my $a = $self->{_fdata}->{$fld};
	die("?".__x("Onbekend veld: {fld}", fld => $fld)."\n")
	  unless defined($a);
	push(@nf, $a);
	$width += $a->{width};
	if ( $format ) {
	    $format .= "  ";
	    $width += 2;
	}
	$format .= "%".
	  ( $a->{align} eq "<" ? "-" : "" ) .
	  join(".", ($a->{width}) x 2) .
	  "s";
    }
    $self->{_fields} = \@nf;

    # Store format and width in object.
    $self->{_format} = $format . "\n";
    $self->{_width}  = $width;

    # PBP: Return nothing sensible.
    return;
}

sub start {
    my ($self, $t1, $t2, $t3l, $t3r) = @_;
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
    $self->_checkskip(1);	# cancel skips.
}

sub add {
    my ($self, $data) = @_;

    my @values;

    if ( delete($data->{_skip_before}) ) {
	$self->skip;
    }
    my $skipafter = delete($data->{_skip_after});
    my $style = delete($data->{_style});

    $self->_checkhdr;
    $self->_checkskip;

    while ( my($k,$v) = each(%$data) ) {
	die("?",__x("Ongeldig veld: {fld}", fld => $k))
	  unless defined $self->{_fdata}->{$k};
    }

    my @widths;
    foreach my $col ( @{$self->{_fields}} ) {
	my $fname = $col->{name};
	push(@values, defined($data->{$fname}) ? $data->{$fname} : "");
	push(@widths, $col->{width});
    }

    while ( 1 ) {
	my $more = 0;
	my @v;
	foreach my $i ( 0..$#widths ) {
	    if ( length($values[$i]) <= $widths[$i] ) {
		push(@v, $values[$i]);
		$values[$i] = "";
	    }
	    else {
		my $t = substr($values[$i], 0, $widths[$i]);
		if ( substr($values[$i], $widths[$i], 1) eq " " ) {
		    push(@v, $t);
		    substr($values[$i], 0, length($t) + 1, "");
		}
		elsif ( $t =~ /^(.*)([ ]+)/ ) {
		    my $pre = $1;
		    push(@v, $pre);
		    substr($values[$i], 0, length($pre) + length($2), "");
		}
		else {
		    push(@v, $t);
		    substr($values[$i], 0, $widths[$i], "");
		}
		$more++;
	    }
	}
	printf {$self->{fd}} ($self->{_format}, @v);
	last unless $more;
    }

    if ( $skipafter ) {
	$self->skip;
    }
}

sub _checkhdr {
    my ($self) = @_;
    return unless $self->{_needhdr};

    $self->{_needhdr} = 0;

    printf {$self->{fd}} ("%s\n%s\n%-" . ($self->{_width}-31) . "s%31s\n\n" .
			  $self->{_format},
			  _center($self->{_title1}, $self->{_width}),
			  $self->{_title2},
			  $self->{_title3l}, $self->{_title3r},
			  map { $_->{title} } @{$self->{_fields}});
    $self->line;
    $self->_checkskip(1);	# cancel skips.
}

sub _checkskip {
    my ($self, $cancel) = @_;
    return unless $self->{_needskip};
    print {$self->{fd}} ("\n") unless $cancel;
    $self->{_needskip} = 0;
}

sub _center {
    my ($text, $width) = @_;
    (" " x (($width - length($text))/2)) . $text;
}

sub _expand {
    my ($text) = @_;
    $text =~ s/(.)/$1 /g;
    $text =~ s/ +$//;
    $text;
}

sub line {
    my ($self, $count) = @_;
    $count ||= 1;

    $self->_checkhdr;
    $self->_checkskip(1);	# cancel skips.

    while ( $count-- > 0 ) {
	print {$self->{fd}} ("-" x ($self->{_width}), "\n");
    }
}

sub skip {
    my ($self) = @_;

    $self->_checkhdr;
    $self->{_needskip} = 1;
}

unless ( caller ) {
    package main;

    my $r = new EB::Report::Text
      ([
	{ name => "nr",    title => "Nr",    width => 4, align => ">" },
	{ name => "foo",   title => "Foo",   width => 8 },
	{ name => "bar",   title => "Bar",   width => 8 },
	{ width => 4 },
	{ name => "blech", title => "Blech", width => 8, align => ">" },
       ]);

    $r->start("Balans", "Periode: t/m 2005-12-27",
	      "Squirrel Consultancy 2005", "EekBoek 0.24, 2005-12-27 22:08");
    $r->line;
    $r->add ({ nr => 24, foo => "F Blah", bar => "B Blah", blech => 666 });
    $r->add ({ nr => 25, foo => "F Bloh", bar => "B Bloh Blox Blo Blo Blo BLox", blech => 2266 });
    $r->add ({ _skip_before => 1, _skip_after => 1,
	       nr => 23, foo => "F Blih", bar => "B h", blech => 616 });
    $r->line;
    $r->skip;			# will be ignored
    $r->finish;

    $r->fields(qw(foo blech nr));
    $r->start("Balans", "Periode: t/m 2005-12-27",
	      "Squirrel Consultancy 2005", "EekBoek 0.24, 2005-12-27 22:10");
    $r->line;
    $r->add ({ nr => 24, foo => "F Blah", bar => "B Blah", blech => 666 });
    $r->add ({ _skip_after => 1,
	       nr => 25, foo => "F Bloh", bar => "B Bloh Blox Blo Blo Blo BLox", blech => 2266 });
    $r->add ({ _skip_after => 1,
	       nr => 23, foo => "F Blih", bar => "B h", blech => 616 });
    $r->line;
    $r->skip;			# will be ignored
    $r->finish;
}
