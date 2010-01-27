#! perl --			-*- coding: utf-8 -*-

use utf8;

package main;

use strict;
use warnings;

use EekBoek;
use EB;

our $cfg;

package EB::IniWiz;

use EB;
use EB::Tools::MiniAdm;
use File::Basename;
use Encode;

my @adm_dirs;
my @adm_names;
my $runeb;

sub getadm {			# STATIC
    my ( $pkg, $opts ) = @_;
    chdir($opts->{admdir});
    my %h;
    $h{$_} = 1 foreach glob( "*/" . $cfg->std_config );
    $h{$_} = 1 foreach glob( "*/" . $cfg->std_config_alt );
    my @files = keys(%h);
    foreach ( sort @files ) {
	push( @adm_dirs, dirname($_) );
    }

    my $ret = -1;

    if ( @adm_dirs ) {

	print STDERR (__x("Beschikbare administraties in {dir}:",
			  dir => $opts->{admdir}), "\n\n");
	for ( my $i = 0; $i < @adm_dirs; $i++ ) {
	    my $desc = $adm_dirs[$i];
	    if ( open( my $fd, '<:utf8', $adm_dirs[$i]."/opening.eb" ) ) {
		while ( <$fd> ) {
		    next unless /adm_naam\s+"(.+)"/;
		    $desc = $1;
		    last;
		}
		close($fd);
	    }
	    printf STDERR ("%3d: %s\n", $i+1, $desc);
	    push( @adm_names, $desc );
	}
	print STDERR ("\n");
	while ( 1 ) {
	    print STDERR (_T("Uw keuze"),
			  " <1",
			  @adm_dirs > 1 ? "..".scalar(@adm_dirs) : "",
			  _T(", of N om een nieuwe administratie aan te maken>"),
			  ": " );
	    chomp( my $ans = <STDIN> );
	    return -1 if lc($ans) eq 'n';
	    next unless $ans =~ /^\d+$/;
	    next unless $ans && $ans <= @adm_dirs;
	    $ret = $ans;
	    chdir( $adm_dirs[ $ret-1 ] ) || die("chdir");
	    last;
	}
    }
    return $ret;

}

sub run {
    my ( $self, $opts ) = @_;
    my $admdir = $opts->{admdir} || $cfg->val(qw(general admdir), $cfg->user_dir("admdir"));
    $runeb = 1;
    $admdir =~ s/\$([A-Z_]+)/$ENV{$1}/ge;
    if ( $admdir ) {
	mkdir($admdir) unless -d $admdir;
	die("No admdir $admdir: $!") unless -d $admdir;
    }
    $opts->{admdir} = $admdir;
    $runeb = 0;

    my $ret = EB::IniWiz->getadm($opts) if $admdir;

    $ret = EB::IniWiz->runwizard($opts) if $ret < 0;

    $opts->{runeb} = $ret >= 0;

}

sub find_db_drivers {
    my %drivers;

    foreach my $lib ( @INC ) {
	next unless -d "$lib/EB/DB";
	foreach my $drv ( glob("$lib/EB/DB/*.pm") ) {
	    open( my $fd, "<", $drv ) or next;
	    while ( <$fd> ) {
		if ( /sub\s+type\s*{\s*"([^"]+)"\s*;?\s*}/ ) {
		    my $s = $1;
		    my $t = substr($drv,length("$lib/EB/DB/"));
		    $t =~ s/\.pm$//;
		    $drivers{lc($t)} ||= $s;
		    last;
		}
	    }
	    close($fd);
	}
    }
    \%drivers;
}

sub findchoice {
    my ( $choice, $choices ) = @_;
    $choice = lc($choice);
    my $i = 0;
    while ( $i < @$choices ) {
	return $i if lc($choices->[$i]) eq $choice;
	$i++;
    }
    return;
}

sub runwizard {
    my ( $self ) = @_;

    my $year = 1900 + (localtime(time))[5];

    my @ebz = glob( libfile("schema/*.ebz") );
    my @ebz_desc = ( "Lege administratie" );

    my $i = 0;
    foreach my $ebz ( @ebz ) {
	require Archive::Zip;
	my $zip = Archive::Zip->new();
	next unless $zip->read($ebz) == 0;
	my $desc = $zip->zipfileComment;
	if ( $desc =~ /omschrijving:\s+(.*)/i ) {
	    $desc = $1;
	}
	elsif ( $desc =~ /export van (.*) aangemaakt door eekboek/i ) {
	    $desc = $1;
	}
	else {
	    $desc = $1 if $ebz =~ m/([^\\\/]+)\.ebz$/i;
	}
	push( @ebz_desc, $desc);
	$i++;
    }
    unshift (@ebz, undef );	# skeleton

    # Enumerate DB drivers.
    my $drivers = find_db_drivers();
    my @db_drivers;
    foreach ( sort keys %$drivers ) {
	push( @db_drivers, $_ );
    }

    my @btw = qw( qw(Maand Kwartaal Jaar) );

    my $answers = {
		   admname    => "Mijn eerste EekBoek",
		   begindate  => $year,
		   admbtw     => 1,
		   btwperiod  => findchoice( "kwartaal", \@btw ),
		   template   => findchoice( "eekboek voorbeeldadministratie", \@ebz_desc ),
		   dbdriver   => findchoice( "sqlite", \@db_drivers ),
		   dbcreate   => 1,
		  };

    my $queries;
    $queries    = [
		   { code => "admname",
		     text => <<EOD,
Geef een unieke naam voor de nieuwe administratie. Deze wordt gebruikt
voor rapporten en dergelijke.
EOD
		     type => "string",
		     prompt => "Naam",
		     post => sub {
			 my $c = shift;
			 foreach ( @adm_names ) {
			     next unless lc($_) eq lc($c);
			     warn("Er bestaat al een administratie met deze naam.\n");
			     return;
			 }
			 $c = lc($c);
			 $c =~ s/\W+/_/g;
			 $c .= "_" . $answers->{begindate},
			   $answers->{admcode} = $c;
			 return 1;
		     },
		   },
		   { code => "begindate",
		     text => <<EOD,
Geef het boekjaar voor deze administatie. De administatie
begint op 1 januari van het opgegeven jaar.
EOD
		     prompt => "Begindatum",
		     type => "int",
		     range => [ $year-20, $year+10 ],
		     post => sub {
			 my $c = shift;
			 return unless $answers->{admcode};
			 $answers->{admcode} =~ s/_\d\d\d\d$/_$c/;
			 return 1;
		     },
		   },
		   { code => "admcode",
		     text => <<EOD,
Geef een unieke code voor de administratie. Deze wordt gebruikt als
interne naam voor de database en administratiefolders.
De standaardwaarde is afgeleid van de administratienaam en de begindatum.
EOD
		     type => "string",
		     prompt => "Code",
		     pre => sub {
			 return if $answers->{admcode};
			 my $c = $answers->{admname};
			 $c = lc($c);
			 $c =~ s/\W+/_/g;
			 $c .= "_" . $answers->{begindate},
			   $answers->{admcode} = $c;
			 return 1;
		     },
		     post => sub {
			 my $c = shift;
			 foreach ( @adm_dirs ) {
			     next unless lc($_) eq lc($c);
			     warn("Er bestaat al een administratie met code \"$c\".\n");
			     return;
			 }
			 return 1;
		     },
		   },
		   { code => "template",
		     text => <<EOD,
U kunt een van de meegeleverde sjablonen gebruiken voor uw
administratie.
EOD
		     type => "choice",
		     prompt => "Sjabloon",
		     choices => \@ebz_desc,
		     post => sub {
			 my $c = shift;
			 $queries->[4]->{skip} = $c != 0;
			 $queries->[5]->{skip} = $c != 0;
			 return 1;
		     },
		   },
		   { code => "admbtw",
		     prompt => "Moet BTW worden toegepast in deze administratie",
		     type => "bool",
		     post => sub {
			 my $c = shift;
			 $queries->[5]->{skip} = !$c;
			 return 1;
		     },
		   },
		   { code => "btwperiod",
		     prompt => "Aangifteperiode voor de BTW",
		     type => "choice",
		     choices => \@btw,
		   },
		   { code => "dbdriver",
		     text => <<EOD,
Kies het type database dat u wilt gebruiken voor deze
administratie.
EOD
		     type => "choice",
		     prompt => "Database",
		     choices => \@db_drivers,
		   },
		   { code => "dbcreate",
		     text => <<EOD,
Gereed om de administratieve bestanden en de database aan te maken.
EOD
		     prompt => "Doorgaan",
		     type => "bool",
		   },
		  ];

  QL:
    for ( my $i = 0; $i < @$queries; $i++ ) {
	$i = 0 if $i < 0;
	my $q = $queries->[$i];
	next if $q->{skip};
	my $code = $q->{code};
	print STDERR ( "\n" );
	print STDERR ( $q->{text}, "\n" ) if $q->{text};

      QQ:
	while ( 1 ) {

	    $q->{pre}->() if $q->{pre};

	    if ( $q->{choices} ) {
		for ( my $i = 0; $i < @{ $q->{choices} }; $i++ ) {
		    printf STDERR ( "%3d: %s\n",
				    $i+1, $q->{choices}->[$i] );
		}
		print STDERR ("\n");
		$q->{range} = [ 1, scalar(@{ $q->{choices} }) ];
	    }

	    print STDERR ( $q->{prompt} );
	    print STDERR ( " <", $q->{range}->[0], "..",
			   $q->{range}->[1], ">" )
	      if $q->{range};
	    print STDERR ( " [",
			   $q->{type} eq 'choice'
			   ? $answers->{$code}+1
			   : $q->{type} eq 'bool'
			     ? qw(Nee Ja)[$answers->{$code}]
			     : $answers->{$code},
			   "]" )
	      if defined $answers->{$code};
	    print STDERR ( ": " );

	    my $a = decode_utf8( scalar <STDIN> );
	    $a = "-\n" unless defined $a;
	    chomp($a);
	    if ( $a eq '-' ) {
		while ( $i > 0 ) {
		    $i--;
		    redo QL unless $queries->[$i]->{skip};
		}
	    }

	    if ( $q->{type} eq 'string' ) {
		if ( $a eq '' ) {
		    $a = $answers->{$code};
		}
	    }

	    elsif ( $q->{type} eq 'bool' ) {
		if ( $a eq '' ) {
		    $a = $answers->{$code};
		}
		elsif ( $a =~ /^(ja?|ne?e?)$/i ) {
		    $a = $a =~ /^j/i ? 1 : 0;
		}
		else {
		    warn("Antwoordt 'ja' of 'nee' a.u.b.");
		    redo QQ;
		}
	    }

	    elsif ( $q->{type} eq 'int' || $q->{type} eq 'choice' ) {
		if ( $a eq '' ) {
		    $a = $answers->{$code};
		    $a++ if $q->{type} eq 'choice';
		}
		elsif ( $a !~ /^\d+$/
			or
			$q->{range}
			&& ( $a < $q->{range}->[0]
			     || $a > $q->{range}->[1] ) ) {
		    warn("Ongeldig antwoord, het moet een getal",
			 $q->{range} ? " tussen $q->{range}->[0] en $q->{range}->[1]" : "",
			 " zijn\n");
		    redo QQ;
		}
		$a-- if $q->{type} eq 'choice';
	    }

	    else {
		die("Unhandled request type: ", $q->{type}, "\n");
	    }

	    if ( $q->{post} ) {
		redo QQ unless $q->{post}->($a, $answers->{$code});
	    }
	    $answers->{$code} = $a;
	    last QQ if defined $answers->{$code};
	}
    }

    return -1 unless $answers->{dbcreate};

    my %opts;
    $opts{adm_naam} = $answers->{admname};
    $opts{adm_code} = $answers->{admcode};
    $opts{adm_begindatum} = $answers->{begindate};

    $opts{db_naam} = $answers->{admcode};
    $opts{db_driver} = $db_drivers[$answers->{dbdriver}];
    $opts{"has_$_"} = 1
	foreach qw(debiteuren crediteuren kas bank);
    $opts{has_btw} = $answers->{admbtw};

    $opts{"create_$_"} = 1
	foreach qw(config schema relaties opening mutaties database);

    $opts{adm_btwperiode} = @btw[ $answers->{btwperiod} ]
	if $opts{has_btw};

    $opts{template} = @ebz[ $answers->{template} ];

    if ( $opts{adm_code} ) {
	mkdir($opts{adm_code}) unless -d $opts{adm_code};
	chdir($opts{adm_code}) or die("chdir($opts{adm_code}): $!\n");;
    }

    EB::Tools::MiniAdm->sanitize(\%opts);

# warn Dumper \%opts;

    foreach my $c ( qw(config schema relaties opening mutaties database) ) {
	if ( $c eq "database" ) {
	    my $ret;
	    if ( 0 ) {
		my @cmd = ( $^X, "-S", "ebshell", "--init" );
		$ret = system(@cmd);
	    }
	    else {
		undef $cfg;
		EB::Config->init_config( { app => $EekBoek::PACKAGE, %opts } );
		require EB::Main;
		local @ARGV = qw( --init );
		$ret = EB::Main->run;
	    }

	    die(_T("Er is een probleem opgetreden. Raadplaag uw systeembeheerder.")."\n")
	      if $ret;

	}
	else {
	    my $m = "generate_". $c;
	    EB::Tools::MiniAdm->$m(\%opts);
	}
    }

    print STDERR ("\n", _T("De administratie is aangemaakt."),
		  " ", _T("U kunt meteen aan de slag.")."\n\n");

    return 0;
}

1;
