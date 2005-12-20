# RCS Info        : $Id: Html.pm,v 1.2 2005/12/20 20:47:54 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Nov 19 22:03:38 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Dec 17 16:27:55 2005
# Update Count    : 18
# Status          : Unknown, Use with caution!

package main;

our $dbh;

package EB::Report::Grootboek::Html;

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

sub outline {
    my ($self, $type, @args) = @_;

    my ($gbk, $desc, $id, $date, $deb, $crd, $rel) = ('') x 7;
    my $bsk = '';

    my $cc = "c_gbk";
    my $rc = "";

    if ( $type eq 'H1' ) {
	($gbk, $desc) = @args;
	$cc = "c_hd";
	$rc = "r_hd";
    }
    elsif ( $type eq 'H2' ) {
	($desc, $deb, $crd) = @args;
	$cc = "c_bgn";
    }
    elsif ( $type eq 'D' ) {
	($desc, $id, $date, $deb, $crd, $bsk, $rel) = @args;
	$cc = "c_desc";
    }
    elsif ( $type eq 'T2' ) {
	($desc, $deb, $crd) = @args;
	$cc = "c_bgn";
    }
    elsif ( $type eq 'T1' ) {
	($gbk, $desc, $deb, $crd) = @args;
    }
    elsif ( $type eq 'TM' ) {
	($desc, $deb, $crd) = @args;
	$rc = "r_mut";
    }
    elsif ( $type eq 'TG' ) {
	($desc, $deb, $crd) = @args;
	$rc = "r_tot";
    }
    elsif ( $type eq ' ' ) {
    }
    else {
	die("?".__x("Programmafout: verkeerd type in {here}",
		    here => __PACKAGE__ . "::_repline")."\n");
    }

    $rc = " class=\"$rc\"" if $rc;
    $self->{fh}->print
      ("<tr$rc>",
       $self->{design} ? ("<td class=\"h_typ\">", $type, "</td>\n") : (),
       "<td class=\"c_acc\">", html($gbk),  "</td>\n",
       "<td class=\"$cc\">",   html($desc), "</td>\n",
       "<td class=\"c_dat\">", html($date), "</td>\n",
       "<td class=\"c_deb\">", html($deb),  "</td>\n",
       "<td class=\"c_crd\">", html($crd),  "</td>\n",
       "<td class=\"c_bsk\">", html($bsk),  "</td>\n",
       "<td class=\"c_rel\">", html($rel),  "</td>\n",
       "</tr>\n"
      );

}

sub start {
    my ($self, $t1, $t2) = @_;
    my $reptype = "grootboek";
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
       "<th class=\"h_acc\">", html(_T("GrBk")),               "</th>\n",
       "<th class=\"h_gbk\">", html(_T("Grootboek/Boekstuk")), "</th>\n",
       "<th class=\"h_dat\">", html(_T("Datum")),              "</th>\n",
       "<th class=\"h_deb\">", html(_T("Debet")),              "</th>\n",
       "<th class=\"h_crd\">", html(_T("Credit")),             "</th>\n",
       "<th class=\"h_bsk\">", html(_T("Boekstuk")),           "</th>\n",
       "<th class=\"h_rel\">", html(_T("Relatie")),            "</th>\n",
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
