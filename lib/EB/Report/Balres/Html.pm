# Html.pm -- HTML backend for Balans/Result
# RCS Info        : $Id: Html.pm,v 1.1 2005/11/19 22:05:47 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Sep 14 14:51:19 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Nov 19 23:01:10 2005
# Update Count    : 75
# Status          : Unknown, Use with caution!

package main;

our $dbh;

package EB::Report::Balres::Html;

use strict;
use EB;
use EB::Finance;
use EB::Report::HTML;

use base qw(EB::Report::GenBase);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

my $flip;

sub addline {
    my ($self, $type) = (shift, shift);
    my $acc = $type eq 'V' || $type eq 'T' ? "" : shift;
    my ($desc, $deb, $crd) = @_;

    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd ) {
	$_ = $_ ? numfmt($_) : '&nbsp;';
    }

    my $dc = "c_desc";
    my $rc = "";
    if ( $type =~ /^D(\d+)/ ) {
	$dc .= $1;
    }
    elsif ( $type =~ /^H(\d+)/ ) {
	$dc = "c_vrd" . $1;
	$rc = "r_vrd" . $1;
    }
    elsif ( $type =~ /^T(\d+)/ ) {
	$dc = "c_tot" . $1;
	$rc = "r_tot" . $1;
    }
    elsif ( $type eq 'V' ) {
	$dc = "c_vw";
	$rc = "r_vw";
    }
    elsif ( $type eq 'H' ) {
	$dc = "c_vw";
	$rc = "r_vrd";
    }
    elsif ( $type eq 'T' ) {
	$rc = "r_tot";
    }
#    else {
#	die("?".__x("Ongeldige mode '{ctl}' in {pkg}::addline",
#		    ctl => $type,
#		    pkg => __PACKAGE__ ) . "\n");
#    }

    $self->{fh}->print(
#		       "<tr class=\"", $flip ? "r_o" : "r_e", "\">\n",
		       "<tr class=\"$rc\">\n",
		       $self->{design} ? "<td class=\"c_typ\">$type</td>\n" : "",
		       "<td class=\"c_anr\">", $acc||'&nbsp;', "</td>\n",
		       "<td class=\"$dc\">", html($desc), "</td>\n",
		       "<td class=\"c_deb\">", $deb, "</td>\n",
		       "<td class=\"c_crd\">", $crd, "</td>\n",
		       "</tr>\n");
    $flip = !$flip;

}

sub start {
    my ($self, $t1, $t2) = @_;
    my $reptype = $self->{balans} < 0 ? "opbalans" :
      $self->{balans} ? "balans" : "result";
    my $adm;
    if ( $self->{boekjaar} ) {
	$adm = $dbh->lookup($self->{boekjaar},
			    qw(Boekjaren bky_code bky_name));
    }
    else {
	$adm = $dbh->adm("name");
    }

    $self->{fh}->print
      ("<html>\n",
       "<head>\n",
       "<title>", html($t1), "</title>\n",
       '<link rel="stylesheet" href="css/', $self->{style} || $reptype, '.css">', "\n",
       "</head>\n",
       "<body>\n",
       "<p class=\"title\">", html($t1), "</p>\n",
       "<p class=\"subtitle\">", html($adm), "<br>\n", html($t2), "</p>\n",
       "<table class=\"main\">\n");

    $self->{fh}->print
      ("<tr>",
       $self->{design} ? ("<th class=\"h_typ\">", html(_T("Type")), "</th>\n") : (),
       "<th class=\"h_anr\">", html(_T("RekNr")), "</th>\n",
       "<th class=\"h_desc\">", html($self->{detail} >= 0 ? _T("Verdichting/Grootboekrekening") : _T("Grootboekrekening")), "</th>\n",
       "<th class=\"h_deb\">", html(_T("Debet")), "</th>\n",
       "<th class=\"h_crd\">", html(_T("Credit")), "</th>\n",
       "</tr>\n"
      );
}

sub finish {
    my ($self) = @_;
    $self->{fh}->print("</table>\n");

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

1;
