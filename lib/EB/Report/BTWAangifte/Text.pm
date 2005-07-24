#!/usr/bin/perl -w
my $RCS_Id = '$Id: Text.pm,v 1.1 2005/07/24 19:33:02 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Tue Jul 19 19:01:33 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Jul 24 21:30:21 2005
# Update Count    : 178
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::BTWAangifte::Text;

use strict;

use EB::Globals;
use EB::Finance;

use base qw(EB::BTWAangifte);

sub perform {
    my ($self, $opts) = @_;

    $self->_perform($opts);

    my $data = $self->{data};

    print("BTW Aangifte $self->{periode}",
	  " -- $self->{adm_name}\n\n");

    # Binnenland
    print("Binnenland\n");

    # 1. Door mij verrichte leveringen/diensten
    print("\n1. Door mij verrichte leveringen/diensten\n\n");

    # 1a. Belast met hoog tarief
    outline("1a", "Belast met hoog tarief", $data->{deb_h}, $data->{deb_btw_h});

    # 1b. Belast met laag tarief
    outline("1b", "Belast met laag tarief", $data->{deb_l}, $data->{deb_btw_l});

    # 1c. Belast met ander, niet-nul tarief
    outline("1c", "Belast met ander tarief", $data->{deb_x}, $data->{deb_btw_x});

    # 1d. Belast met 0%/verlegd
    outline("1c", "Belast met 0% / verlegd", $data->{deb_0}, undef);

    # Buitenland
    print("\nBuitenland\n");

    # 3. Door mij verrichte leveringen
    print("\n3. Door mij verrichte leveringen\n\n");

    # 3a. Buiten de EU
    outline("3a", "Buiten de EU", $data->{extra_deb}, undef);

    # 3b. Binnen de EU
    outline("3a", "Binnen de EU", $data->{intra_deb}, undef);

    # 4. Aan mij verrichte leveringen
    print("\n4. Aan mij verrichte leveringen\n\n");

    # 4a. Van buiten de EU
    outline("4a", "Van buiten de EU", $data->{extra_crd}, 0);

    # 4b. Verwervingen van goederen uit de EU.
    outline("4b", "Verwervingen van goederen uit de EU", $data->{intra_crd}, 0);

    # 5 Berekening totaal
    print("\n5 Berekening totaal\n\n");

    # 5a. Subtotaal
    outline("5a", "Subtotaal", undef, $data->{sub0});

    # 5b. Voorbelasting
    outline("5b", "Voorbelasting", undef, $data->{vb});

    # 5c Subtotaal
    outline("5c", "Subtotaal", undef, $data->{sub1});

    outline("xx", "Onbekend", undef, numfmt($data->{onbekend})) if $data->{onbekend};

    if ( $data->{btw_delta} ) {
	warn("!Er is een verschil van ".numfmt($data->{btw_delta}).
	     " tussen de berekende en werkelijk ingehouden BTW.".
	     " Voor de aangifte is de werkelijk ingehouden BTW gebruikt.\n");
    }
}

################ Subroutines ################

sub outline {
    my ($tag0, $tag1, $sub, $amt) = @_;
    printf("%-5s%-40s%10s%10s\n",
	   $tag0, $tag1,
	   defined($sub) ? $sub : "",
	   defined($amt) ? $amt : "");
}

1;
