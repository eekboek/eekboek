# Html.pm -- 
# RCS Info        : $Id: Html.pm,v 1.11 2006/06/02 13:33:02 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Dec 29 15:46:47 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Jun  2 15:32:16 2006
# Update Count    : 55
# Status          : Unknown, Use with caution!

package main;

our $cfg;

package EB::Report::Reporter::Html;

use strict;
use warnings;
use EB;
use EB::Format qw(datefmt_full);

use base qw(EB::Report::Reporter);

################ API ################

my $html;

sub start {
    my ($self, @args) = @_;
    eval {
	require HTML::Entities;
    };
    $html = $@ ? \&__html : \&_html;
    $self->SUPER::start(@args);
}

sub finish {
    my ($self) = @_;
    $self->SUPER::finish();
    print {$self->{fh}} ("</table>\n");

    my $now = $cfg->val(qw(internal now), iso8601date());
    # Treat empty value as no value.
    $now ||= iso8601date();
    my $ident = $EB::ident;
    $ident = (split(' ', $ident))[0] if $cfg->val(qw(internal now), 0);

    $self->{fh}->print("<p class=\"footer\">",
		       __x("Overzicht aangemaakt op {date} door <a href=\"{url}\">{ident}</a>",
			   ident => $ident, date => datefmt_full($now), url => $EB::url), "</p>\n");
    $self->{fh}->print("</body>\n",
		       "</html>\n");
    close($self->{fh});
}

sub add {
    my ($self, $data) = @_;

    my $style = delete($data->{_style});

    $self->SUPER::add($data);

    return unless %$data;

    $self->_checkhdr;

    print {$self->{fh}} ("<tr", $style ? " class=\"r_$style\"" : (), ">\n");

    foreach my $col ( @{$self->{_fields}} ) {
	my $fname = $col->{name};
	my $value = defined($data->{$fname}) ? $data->{$fname} : "";

	# Examine style mods.
	# No style mods for HTML.
	# if ( $style ) {
	#    if ( my $t = $self->_getstyle($style, $fname) ) {
	#    }
	# }
	print {$self->{fh}} ("<td class=\"c_$fname\">",
			     $value eq "" ? "&nbsp;" : $html->($value),
			     "</td>\n");
    }

    print {$self->{fh}} ("</tr>\n");
}

################ Pseudo-Internal (used by Base class) ################

sub header {
    my ($self) = @_;

    print {$self->{fh}}
      ("<html>\n",
       "<head>\n",
       "<title>", $html->($self->{_title1}), "</title>\n");

    if ( my $style = $self->{_style} ) {
	if ( $style =~ /\W/ ) {
	    print {$self->{fh}}
	      ('<link rel="stylesheet" href="', $style, '">', "\n");
	}
	elsif ( defined $self->{_cssdir} ) {
	    print {$self->{fh}}
	      ('<link rel="stylesheet" href="', $self->{_cssdir},
	       $style, '.css">', "\n");
	}
	elsif ( my $css = findlib("css/".$style.".css") ) {
	    print {$self->{fh}} ('<style type="text/css">', "\n");
	    copy_style($self->{fh}, $css);
	    print {$self->{fh}} ('</style>', "\n");
	}
	else {
	    print {$self->{fh}} ("<!-- ",
				 __x("Geen stylesheet voor {style}",
				     style => $style), " -->\n");
	}
    }

    print {$self->{fh}}
      ("</head>\n",
       "<body>\n",
       "<p class=\"title\">", $html->($self->{_title1}), "</p>\n",
       "<p class=\"subtitle\">", $html->($self->{_title2}), "<br>\n", $html->($self->{_title3l}), "</p>\n",
       "<table class=\"main\">\n");

    print {$self->{fh}} ("<tr class=\"head\">\n");
    foreach ( @{$self->{_fields}} ) {
	print {$self->{fh}} ("<th class=\"h_", $_->{name}, "\">",
			     $html->($_->{title}), "</th>\n");
    }
    print {$self->{fh}} ("</tr>\n");

}

################ Internal methods ################

sub _html {
    HTML::Entities::encode(shift);
}

sub __html {
    my ($t) = @_;
    $t =~ s/&/&amp;/g;
    $t =~ s/</&lt;/g;
    $t =~ s/>/&gt;/g;
    $t =~ s/\240/&nbsp;/g;
    $t =~ s/\x{eb}/&euml;/g;	# for IVP.
    $t;
}

sub copy_style {
    my ($out, $css) = @_;
    my $in;
    unless ( open($in, "<", $css) ) {
	print {$out} ("<!-- stylesheet $css: $! -->\n");
	return;
    }
    print {$out} ("<!-- begin stylesheet $css -->\n");
    while ( <$in> ) {
	if ( /^\s*\@import\s*(["']?)(.*?)\1\s*;/ ) {
	    use File::Basename;
	    my $newcss = join("/", dirname($css), $2);
	    copy_style($out, $newcss);
	}
	else {
	    print {$out} $_;
	}
    }
    close($in);
    print {$out} ("<!-- end   stylesheet $css -->\n");
}

1;
