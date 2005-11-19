package EB::Report::HTML;

use strict;
use warnings;
use EB;

use base qw(Exporter);

our @EXPORT = qw(html);

sub html {
    my ($t) = @_;
    $t =~ s/&/&amp;/g;
    $t =~ s/</&lt;/g;
    $t =~ s/>/&gt;/g;
    $t =~ s/\240/&nbsp;/g;
    $t;
}
