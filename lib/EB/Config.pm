#! perl

# Config.pm -- Configuration files.
# RCS Info        : $Id: Config.pm,v 1.14 2008/02/18 10:31:19 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Jan 20 17:57:13 2006
# Last Modified By: Johan Vromans
# Last Modified On: Mon Feb 18 11:07:50 2008
# Update Count    : 88
# Status          : Unknown, Use with caution!

package main;

our $cfg;
our $dbh;

package EB::Config;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.14 $ =~ /(\d+)/g;

use EB::Config::IniFiles;
use File::Spec;

my $unicode;

sub init_config {
    my ($app) = @_;

    $app = lc($app);

    # Pre-parse @ARGV for "-f configfile".
    my $extraconf;
    my $skipconfig = 0;
    my $i = 0;
    while ( $i < @ARGV ) {
	if ( $ARGV[$i] eq "-f" || $ARGV[$i] eq "-config" || $ARGV[$i] eq "--config" ) {
	    if ( $i+1 < @ARGV ) {
		$extraconf = $ARGV[$i+1];
		splice(@ARGV, $i, 2);
		last;
	    }
	}
	elsif ( $ARGV[$i] =~ /^-f(.+)/ || $ARGV[$i] =~ /--?config=(.+)/ ) {
	    $extraconf = $1;
	    splice(@ARGV, $i, 1);
	    last;
	}
	elsif ( $ARGV[$i] eq "-X" || $ARGV[$i] =~ /^--?no-?config$/ ) {
	    $skipconfig++;
	    splice(@ARGV, $i, 1);
	    next;
	}
	$i++;
    }

    # Load configs.
    my $cfg;
    for my $dir ( "/etc/$app/",
		  glob("~/.$app") . "/",
		  ".",
		  undef		# placeholder for extraconf
		 ) {
	my $file;
	if ( !defined($dir) ) {
	    last unless $extraconf;
	    $file = $extraconf;
	    if ( -d $file ) {
		my $f = File::Spec->catfile($file, "$app.conf");
		if ( -e $f ) {
		    $file = $f;
		}
		else {
		    $file = File::Spec->catfile($file, ".$app.conf");
		}
	    }
	    die("$file: $!\n") unless -f $file;
	}
	else {
	    next if $skipconfig;
	    $file = $dir . "$app.conf";
	}
	next unless -s $file;
	#warn("Config: $file\n");
	$cfg = EB::Config::IniFiles::Wrapper->new
	  ( -file => $file, -nocase => 1,
	    $EB::Config::IniFiles::VERSION >= 2.39 ? (-allowcode => 0) : (),
	    $cfg ? (-import => $cfg) : () );
	unless ( $cfg ) {
	    # Too early for localisation.
	    die(join("\n", @Config::IniFiles::errors)."\n");
	}
    }

    # Make sure we have an object, even if no config files.
    $cfg ||= EB::Config::IniFiles::Wrapper->new;

    $i = 0;
    while ( $i < @ARGV ) {
	if ( $ARGV[$i] eq "-D" &&
	     $i+1 < @ARGV && $ARGV[$i+1] =~ /^(\w+(?:::\w+)*)::?(\w+)=(.*)/ ) {
	    $cfg->newval($1, $2, $3);
	    splice(@ARGV, $i, 2);
	}
	elsif ( $ARGV[$i] =~ /^--define=(\w+(?:::\w+)*)::?(\w+)=(.*)/ ) {
	    $cfg->newval($1, $2, $3);
	    splice(@ARGV, $i, 1);
	}
	$i++;
    }

    $ENV{EB_LANG} = $cfg->val('locale','lang',
			      $ENV{EB_LANG}||$ENV{LANG}||
			      ($^O =~ /^(ms)?win/i ? "nl_NL.utf8" : "nl_NL"));

    $cfg->_plug(qw(locale       lang         EB_LANG));
    unless ( defined($cfg->val(qw(locale unicode), undef)) ) {
	$cfg->newval(qw(locale unicode),
		     ($^O =~ /^(ms)?win/i)
		     || ($cfg->val(qw(locale lang)) =~ /\.utf-?8$/i)
		     || 0);
    }
    $unicode = $cfg->val(qw(locale unicode));

    $cfg->_plug(qw(database     name         EB_DB_NAME));

    if ( my $db = $cfg->val(qw(database name), undef) ) {
	$db =~ s/^eekboek_//;
	$cfg->newval(qw(database     name), $db);
	$cfg->newval(qw(database fullname), "eekboek_".$db);
	$ENV{EB_DB_NAME} = $db;
    }

    $cfg->_plug(qw(database     host         EB_DB_HOST));
    $cfg->_plug(qw(database     port         EB_DB_PORT));
    $cfg->_plug(qw(database     user         EB_DB_USER));
    $cfg->_plug(qw(database     password     EB_DB_PASSWORD));

    $cfg->_plug(qw(csv          separator    EB_CSV_SEPARATOR));

    $cfg->_plug(qw(internal     now          EB_SQL_NOW));

    $cfg->_plug("internal sql", qw(trace     EB_SQL_TRACE));
    $cfg->_plug("internal sql", qw(prepstats EB_SQL_PREP_STATS));
    $cfg->_plug("internal sql", qw(replayout EB_SQL_REP_LAYOUT));

    if ( $cfg->val(__PACKAGE__, "showfiles", 0) ) {
	warn("Config files:\n  ",
	     $cfg->{imported}
	     ? join("\n  ", @{$cfg->{imported}}, $cfg->{cf})
	     : $cfg->{cf}, "\n");
    }

    return $cfg;
}

sub import {
    my ($self, $app) = @_;
    $cfg = init_config($app);
}

package EB::Config::IniFiles::Wrapper;

use base qw(EB::Config::IniFiles);
use constant ATTR_PREF => __PACKAGE__."::"."pref";

sub _plug {
    my ($self, $section, $parameter, $env) = @_;
    $self->newval($section, $parameter, $ENV{$env})
      if $ENV{$env} && !$self->val($section, $parameter, undef);
}

sub prefer {
    my ($self, $pref) = @_;
    $self->{ATTR_PREF} = $pref;
}

sub val {
    my ($self, $section, $parameter, $default) = @_;
    my $res;
    if ( my $pref = $self->{ATTR_PREF} ) {
	$res = $self->SUPER::val("$pref $section", $parameter);
    }
    $res = $self->SUPER::val($section, $parameter, $default)
      unless defined $res;
    Carp::cluck("=> missing config: \"$section\" \"$parameter\"\n")
      unless defined $res || @_ > 3;
    $res;
}

sub unicode {
    $unicode;
}

1;
