#!/usr/bin/perl -w
use strict;

use EB::DB;

my $postgres = 1;		# PostgreSQL

my $verbose = 0;
my $trace = 0;

our $dbh = DBI::->connect($ENV{EBDB} || "dbi:Pg:dbname=eekboek")
  or die("Cannot connect to database: $DBI::errstr\n");

foreach my $table ( $dbh->tables ) {
    next unless $table =~ /^public\.(.*)/;
    $table = $1;
    my $sth = $dbh->column_info(undef, undef, $table);
    $sth->execute;
    my @columns;
    while ( $_ = $sth->fetchrow_hashref ) {
	while(my ($key,$value) = each(%$_)) {
	    next unless $key eq "COLUMN_NAME";
	    push(@columns, $value);
	}
    }
    print("# Table: $table -- ", join(" ", @columns), "\n");
    print("\$sth = \$dbh->sql_exec(\"SELECT ", join(", ", @columns), "\".\n\" FROM $table\".\n);\n");
    print("my (\$", join(", \$", @columns), ") = \@\$rr;\n");
}
