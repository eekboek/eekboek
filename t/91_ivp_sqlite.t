#! perl

# $Id: 91_ivp_sqlite.t,v 1.9 2008/02/27 10:51:54 jv Exp $  -*-perl-*-

use strict;
use warnings;

use Test::More
  $ENV{EB_SKIPDBTESTS} ? (skip_all => "Database tests skipped on request")
  : (tests => 43);

use warnings;
BEGIN { use_ok('IPC::Run3') }
BEGIN { use_ok('EB::Config', qw(ivp)) }
BEGIN { use_ok('EB') }
BEGIN { use_ok('File::Copy') }

my $dbdriver = $ENV{EB_DBDRIVER};
if ( !$dbdriver && $0 =~ /\d+_ivp_(.+).t/ ) {
    $dbdriver = $1;
}

my $dbddrv;
if ( !$dbdriver ) {
    $dbdriver = "postgres";
    $dbddrv = "DBD::Pg";
}
elsif ( $dbdriver eq "sqlite" ) {
    $dbddrv = "DBD::SQLite";
}
else {
    BAIL_OUT("Unsupported database driver: $dbdriver");
}

SKIP: {

eval "require $dbddrv";
skip("DBI $dbdriver driver ($dbddrv) not installed", 39) if $@;

chdir("t") if -d "t";
chdir("ivp") if -d "ivp";
my $f;
for ( qw(opening.eb relaties.eb mutaties.eb schema.dat) ) {
    ok(1, $_), next if -s $_;
    if ( $f = findlib("examples/$_") and -s $f ) {
	copy($f, $_);
    }
    ok(-s $_, $_);
}
for ( qw(ivp.conf opening.eb relaties.eb mutaties.eb reports.eb schema.dat ) ) {
    die("=== IVP configuratiefout: $_ ===\n") unless -s $_;
}

# Cleanup old files.
unlink(<*.sql>);
unlink(<*.log>);
unlink(<*.txt>);
unlink(<*.html>);
unlink(<*.csv>);

my @ebcmd = qw(-MEB::Main -e run -- -X -f ivp.conf --echo);
push(@ebcmd, "-D", "database:driver=$dbdriver") if $dbdriver;

unshift(@ebcmd, map { ("-I",
		       "../../$_"
		      ) } grep { /^\w\w/ } reverse @INC);
unshift(@ebcmd, $^X);

my $fail;

for my $log ( "createdb.log" ) {
    ok(syscmd([@ebcmd, qw(--createdb --schema=schema -c)], undef, $log), "createdb");
    checkerr($log);
}

for my $log ( "relaties.log" ) {
    ok(syscmd(\@ebcmd, "relaties.eb", $log), "relaties");
    checkerr($log);
}

for my $log ( "opening.log" ) {
    ok(syscmd(\@ebcmd, "opening.eb", $log), "openen administratie");
    checkerr($log);
}

for my $log ( "mutaties.log" ) {
    ok(syscmd(\@ebcmd, "mutaties.eb", $log), "mutaties");
    checkerr($log);
}

for my $log ( "reports.log" ) {
    ok(syscmd(\@ebcmd, "reports.eb", $log), "reports");
    checkerr($log);
}

# Verify: balans in varianten.
vfy([@ebcmd, qw(-c balans)           ], "balans.txt");
vfy([@ebcmd, qw(-c balans --detail=0)], "balans0.txt");
vfy([@ebcmd, qw(-c balans --detail=1)], "balans1.txt");
vfy([@ebcmd, qw(-c balans --detail=2)], "balans2.txt");
vfy([@ebcmd, qw(-c balans --verdicht)], "balans2.txt");
vfy([@ebcmd, qw(-c balans --opening) ], "obalans.txt");

# Verify: verlies/winst in varianten.
vfy([@ebcmd, qw(-c result)           ], "result.txt");
vfy([@ebcmd, qw(-c result --detail=0)], "result0.txt");
vfy([@ebcmd, qw(-c result --detail=1)], "result1.txt");
vfy([@ebcmd, qw(-c result --detail=2)], "result2.txt");
vfy([@ebcmd, qw(-c result --verdicht)], "result2.txt");

# Verify: Journaal.
vfy([@ebcmd, qw(-c journaal)            ], "journaal.txt");
# Verify: Journaal van dagboek.
vfy([@ebcmd, qw(-c journaal postbank)   ], "journaal-postbank.txt");
# Verify: Journaal van boekstuk.
vfy([@ebcmd, qw(-c journaal postbank:24)], "journaal-postbank24.txt");

# Verify: Proef- en Saldibalans in varianten.
vfy([@ebcmd, qw(-c proefensaldibalans)           ], "proef.txt");
vfy([@ebcmd, qw(-c proefensaldibalans --detail=0)], "proef0.txt");
vfy([@ebcmd, qw(-c proefensaldibalans --detail=1)], "proef1.txt");
vfy([@ebcmd, qw(-c proefensaldibalans --detail=2)], "proef2.txt");
vfy([@ebcmd, qw(-c proefensaldibalans --verdicht)], "proef2.txt");

# Verify: Grootboek in varianten.
vfy([@ebcmd, qw(-c grootboek)           ], "grootboek.txt");
vfy([@ebcmd, qw(-c grootboek --detail=0)], "grootboek0.txt");
vfy([@ebcmd, qw(-c grootboek --detail=1)], "grootboek1.txt");
vfy([@ebcmd, qw(-c grootboek --detail=2)], "grootboek2.txt");

# Verify: Crediteuren/Debiteuren.
vfy([@ebcmd, qw(-c crediteuren)         ], "crdrept.txt");
vfy([@ebcmd, qw(-c debiteuren)          ], "debrept.txt");

# Verify: BTW aangifte.
vfy([@ebcmd, qw(-c btwaangifte j)], "btw.txt");

# Verify: HTML generatie.
vfy([@ebcmd, qw(-c balans --detail=2 --gen-html)            ], "balans2.html");
vfy([@ebcmd, qw(-c balans --detail=2 --gen-html --style=xxx)], "balans2xxx.html");
vfy([@ebcmd, qw(-c btwaangifte j)], "btw.html");

# Verify: CSV generatie.
vfy([@ebcmd, qw(-c balans --detail=2 --gen-csv)], "balans2.csv");

}	# end SKIP section

################ subroutines ################

sub vfy {
    my ($cmd, $ref) = @_;
    my @c = @$cmd;
    while ( shift(@c) ne "-c" ) { }
    ok(!diff($ref), "@c --output=$ref");
}

sub vfyxx {
    my ($cmd, $ref) = @_;
    syscmd($cmd, undef, $ref);
    ok(!diff($ref), $ref);
}

use Encode;
sub diff {
    my ($file1, $file2) = @_;
    $file2 = "ref/$file1" unless $file2;
    my ($str1, $str2);
    local($/);
    open(my $fd1, "<", $file1) or die("$file1: $!\n");
    $str1 = <$fd1>;
    close($fd1);
    open(my $fd2, "<:encoding(iso-8859-1)", $file2) or die("$file2: $!\n");
    $str2 = <$fd2>;
    close($fd2);
    $str1 =~ s/^EekBoek \d.*Squirrel Consultancy\n//;
    $str1 =~ s/[\n\r]+/\n/;
    $str2 =~ s/[\n\r]+/\n/;
    return 0 if $str1 eq $str2;

    # If we're running in a Unicode environment, the data may be utf-8.
    $str2 = encode("utf8", $str2);
    if ( $str1 eq $str2 ) {
	diag("Data is UTF-8: $file1");
	return 0;
    }
    1;
}

sub syscmd {
    my ($cmd, $in, $out, $err) = @_;
    $in = \undef unless defined($in);
    $err = $out if @_ < 4;
    #warn("+ @$cmd\n");
    run3($cmd, $in, $out, $err);
    printf STDERR ("Exit status 0x%x\n", $?) if $?;
    $? == 0;
}

sub checkerr {
    my $fail;
    unless ( -s $_[0] ) {
	warn("$_[0]: Bestand ontbreekt, of is leeg\n");
	$fail++;
    }
    open(my $fd, "<", $_[0]) or die("$_[0]: $!\n");
    while ( <$fd> ) {
	next unless /(^\?|^ERROR| at .* line \d+)/;
	warn($_);
	$fail++;
    }
    close($fd);
    die("=== IVP afgebroken ===\n") if $fail;
}

1;
