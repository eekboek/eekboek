#! perl
# $Id: 31_expr.t,v 1.2 2009/10/28 22:29:36 jv Exp $

use strict;
use warnings;

use EB::Config;
use EB;
EB::Config->init_config( { app => "Test", nostdconf => 1 } );
require EB::Format;
EB::Format->import;

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
