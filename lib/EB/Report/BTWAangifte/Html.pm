# Html.pm -- HTML backend for BTWAangifte
# RCS Info        : $Id: Html.pm,v 1.3 2005/10/08 14:18:17 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Sep 14 14:51:19 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct  8 16:17:28 2005
# Update Count    : 4
# Status          : Unknown, Use with caution!

package EB::BTWAangifte::Html;

use strict;

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    my $self = { $opts };
    bless $self => $class;
}

sub addline {
    my ($self, $ctl, $tag0, $tag1, $sub, $amt) = @_;
    my $span = "";
    my $naps = "";
    if ( $ctl ) {
	if ( $ctl eq 'H1' ) {
	    print("<tr><td colspan=\"4\" class=\"heading\">", html($tag0), "</td></tr>\n");
	    return;
	}
	elsif ( $ctl eq 'H2' ) {
	    print("<tr><td colspan=\"4\" class=\"subheading\">", html($tag0), " ", html($tag1), "</td></tr>\n");
	    return;
	}
	elsif ( $ctl eq 'X' ) {
	    $span = "<span class=\"notice\">";
	    $naps = "</span>";
	    $tag0 = "\240";
	}
	else {
	    die("?".__x("Ongeldige mode '{ctl}' in {pkg}::addline",
			ctl => $ctl,
			pkg => __PACKAGE__ ) . "\n");
	}
    }

    print("<tr><td class=\"c_num\">",   $span, html($tag0), $naps,
	  "</td><td class=\"c_desc\">", $span, html($tag1), $naps,
	  "</td><td class=\"c_col1\">", $span, defined($sub) ? html($sub) : "&nbsp;", $naps,
	  "</td><td class=\"c_col2\">", $span, defined($amt) ? html($amt) : "&nbsp;", $naps,
	  "</td></tr>\n");
}

sub start {
    my ($self, $text) = @_;
    print<<EOD;
<html>
<head>
<title>@{[html($text)]}</title>
<link rel="stylesheet" href="css/btwaangifte.css">
</head>
<body>
EOD
    print("<h1 class=\"btwaangifte\"><span class=\"title\">", html($text), "</span></h1>\n");
    print("<table class=\"btwaangifte\">\n");
}

sub finish {
    my ($self, $notice) = @_;
    print<<EOD;
</table>
EOD

    print("<p class=\"btwaangifte\"><span class=\"notice\">".
	  html($notice) . "</span></p>\n") if $notice;

    print<<EOD;
</body>
</html>
EOD
}

sub html {
    my ($t) = @_;
    $t =~ s/</&lt;/g;
    $t =~ s/>/&gt;/g;
    $t =~ s/&/&amp;/g;
    $t =~ s/\240/&nbsp;/g;
    $t;
}

1;
