#! perl
# $Id: 31_expr.t,v 1.3 2009/10/28 22:43:05 jv Exp $

use strict;
use warnings;

use EB::Config ( { app => "Test", nostdconf => 1 } );
use EB;
use EB::Format;

my @tests;
BEGIN {
    @tests =
      (
       '12345+98765'	 => '11111000',
       '3*2'		 => '600',
       '4.12+5,25'	 => '937',
       '+123+123'	 => '24600',
       '-123+123'	 => '0',
       '123.45*0.1253'	 => '1547',
      );
}

use Test::More tests => @tests/2;

# Test numers (amount) parsing.
while ( @tests ) {
    my $amt = shift(@tests);
    my $exp = shift(@tests);

    my $res = amount($amt);
    $res = '<undef>' unless defined $res;

    is($res, $exp, "amount $amt");
}
