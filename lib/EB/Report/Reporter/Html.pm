# Html.pm -- 
# RCS Info        : $Id: Html.pm,v 1.2 2005/12/31 16:46:31 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Dec 29 15:46:47 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Dec 31 17:45:59 2005
# Update Count    : 24
# Status          : Unknown, Use with caution!
#!/usr/bin/perl -w

package EB::Report::Reporter::Html;

use strict;
use warnings;
use EB;

use base qw(EB::Report::Reporter);

################ API ################

sub start {
    my ($self, @args) = @_;
    $self->SUPER::start(@args);
}

sub finish {
    my ($self) = @_;
    $self->SUPER::finish();
    print {$self->{fh}} ("</table>\n");

    my $now = $ENV{EB_SQL_NOW} || iso8601date();
    my $ident = $EB::ident;
    $ident = (split(' ', $ident))[0] if $ENV{EB_SQL_NOW};

    $self->{fh}->print("<p class=\"footer\">",
		       __x("Overzicht aangemaakt op {date} door <a href=\"{url}\">{ident}</a>",
			   ident => $ident, date => $now, url => $EB::url), "</p>\n");
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
			     $value eq "" ? "&nbsp;" : _html($value),
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
       "<title>", _html($self->{_title1}), "</title>\n",
       '<link rel="stylesheet" href="css/', $self->{_style}, '.css">', "\n",
       "</head>\n",
       "<body>\n",
       "<p class=\"title\">", _html($self->{_title1}), "</p>\n",
       "<p class=\"subtitle\">", _html($self->{_title2}), "<br>\n", _html($self->{_title3l}), "</p>\n",
       "<table class=\"main\">\n");

    print {$self->{fh}} ("<tr class=\"head\">\n");
    foreach ( @{$self->{_fields}} ) {
	print {$self->{fh}} ("<th class=\"h_", $_->{name}, "\">",
			     _html($_->{title}), "</th>\n");
    }
    print {$self->{fh}} ("</tr>\n");

}

################ Internal methods ################

sub _html {
    my ($t) = @_;
    $t =~ s/&/&amp;/g;
    $t =~ s/</&lt;/g;
    $t =~ s/>/&gt;/g;
    $t =~ s/\240/&nbsp;/g;
    $t;
}

1;
