#! perl

# $Id: Data.pm,v 1.2 2009/12/22 12:57:06 jv Exp $

use strict;
use warnings;

package EB::Config::Data;

my $data =
    [
       { section => "cpy",
	 tag => "Bedrijfsgegevens",
	 keys =>
	 [
	  { name => "name", tag => "Naam", type => 'string', value => undef },
	  { name => "id", tag => "Administratienummer", type => 'string', value => undef },
	  { name => "address", tag => "Adres", type => 'string', value => undef },
	  { name => "zip", tag => "Postcode", type => 'string', value => undef },
	  { name => "city", tag => "Plaats", type => 'string', value => undef },
	  { name => "taxreg", tag => "Fiscaal nummer", type => 'string', value => undef },
	 ],
       },
       { section => "general",
	 tag => "Algemeen",
	 keys =>
	 [
	  { name => "admdir", tag => "Folder voor administraties", type => 'folder', value => '$HOME/.eekboek/admdir' },
	  { name => "wizard", tag => "Forceer wizard", type => 'bool', value => undef },
	 ],
       },
       { section => "prefs",
	 tag => "Voorkeursinstellingen",
	 keys =>
	 [
	  { name => "journal", tag => "Toon journaalpost na elke boeking", type => 'bool', value => undef },
	 ],
       },
       { section => "Database",
	 keys =>
	 [
	  { name => "name", tag => "Naam", type => 'string', value => undef },
	  { name => "driver", tag => "Driver", type => 'choice', value => undef,
	    choices => [ qw(PostgreSQL SQLite) ],
	    values => [ qw(postgres sqlite) ],
	  },
	  { name => "user", tag => "Gebruikersnaam", type => 'string', value => undef },
	  { name => "password", tag => "Toegangscode", type => 'string', value => undef },
	  { name => "host", tag => "Server systeem", type => 'string', value => undef },
	  { name => "port", tag => "Server poort", type => 'int', value => undef },
	 ],
       },
       { section => "Strategy", tag => "Strategie",
	 keys =>
	 [
	  { name => "round", tag => "Afrondingen", type => 'choice', value => undef,
	    choices => [ qw(IEEE Bankers POSIX) ],
	    values => [ qw(ieee bankers posix) ],
	  },
	  { name => "bkm_multi", tag => "Meervoudig afboeken", type => 'bool', value => undef },
	  { name => "iv_vc", tag => "BTW correcties", type => 'bool', value => undef },
	 ],
       },
       { section => "shell", tag => "Shell",
	 keys =>
	 [
	  { name => "prompt", tag => "Prompt", type => 'string', value => undef },
	  { name => "userdefs", tag => "Eigen uitbreidingen", type => 'string', value => undef },
	 ],
       },
       { section => "Format", tag => "Formaten",
	 keys =>
	 [
	  { name => "numfmt", tag => "Getalformaat", type => 'choice', value => undef,
	    choices => [ "12345,99 (decimaalkomma)",
			 "12345.99 (decimaalpunt)",
			 "12.345,99 (duizendpunt + decimaalkomma)",
			 "12,345.99 (duizendkomma + decimaalpunt)" ],
	    values => [ "12345,99", "12345.99", "12.345,99", "12,345.99" ],
	  },
	  { name => "date", tag => "Datumformaat", type => 'choice', value => undef,
	    choices => [ "2008-05-31 (ISO)", "31-05-2008 (NEN)", "31-05 (NEN, verkort)" ],
	    values => [ "YYYY-MM-DD", "DD-MM-YYYY", "DD-MM" ],
	  },
	 ],
       },
       { section => "text", tag => "Tekstrapporten",
	 keys =>
	 [
	  { name => "numwidth", tag => "Kolombreedte voor getallen", type => 'slider',
	    range => [5, 20, 9], value => undef, }
	 ],
       },
       { section => "html", tag => "HTML rapporten",
	 keys =>
	 [
	  { name => "cssdir", tag => "Style sheets", type => 'folder', value => undef, },
	 ],
       },
       { section => "csv", tag => "CSV rapporten",
	 keys =>
	 [
	  { name => "separator", tag => "Separator", type => 'choice', value => undef,
	    choices => [ ", (komma)", "; (puntkomma)", ": (dubbelpunt)", "Tab", ],
	    values  => [ ",", ";", ":", "\t", ],
	  },
	 ],
       },
       { section => "security", tag => "Beveiliging",
	 keys =>
	 [
	  { name => "override_security_for_vista", tag => "Beveiliging voor MS Vista uitschakelen",
	    type => 'bool', value => undef, },
	 ],
       },
    ];

sub get_data {			# class method
    return bless $data;
}

sub get_name {
    my ($self) = $_;
    "EekBoek";
}

sub get_site_url {
    my ($self) = $_;
    "http://www.eekboek.nl/";
}

sub get_help_url {
    my ($self) = @_;
    $self->get_site_url . "docs/config.html";
}

sub get_topic_help_url {
    my ($self, $section, $key) = @_;
    $self->get_help_url . "#" . join("_", map { lc } $section, $key );
}

unless ( caller ) {
    require YAML;
    # Use Bless to reorder the data a bit.
    foreach ( @$data ) {
	YAML::Bless($_)->keys([qw(section tag keys)]);
	foreach ( @{$_->{keys}} ) {
	    my %h = map { $_ => 1 } keys %$_;
	    delete @h{qw(name tag type value)};
	    YAML::Bless($_)->keys([qw(name tag type value), keys(%h)]);
	}
    }
    warn YAML::Dump($data);
}

1;
