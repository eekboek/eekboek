#! perl

# Exact.pm -- Import vanuit Exact export zoals DaviAccount die maakt.
# RCS Info        : $Id: Exact.pm,v 1.1 2008/02/07 13:27:46 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Sep  3 15:23:31 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  7 14:26:58 2008
# Update Count    : 4
# Status          : Unknown, Use with caution!

package main;

our $dbh;
our $config;

package EB::Import::Exact;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

1;
