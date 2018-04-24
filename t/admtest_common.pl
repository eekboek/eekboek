#! perl

use strict;
use warnings;

our $tag;
my @files;
my @tests;
my $remaining;

BEGIN {
    @files = qw( eekboek.conf
		 schema.dat opening.eb relaties.eb mutaties.eb
		 tests.eb );
    $remaining = 1 + @files + 1 + 2;
    chdir("t") if -d "t";
    if ( chdir($tag) ) {
	@tests = glob("ref/*.txt");
	push( @tests, glob("ref/*.html") );
	push( @tests, glob("ref/*.csv") );
	$remaining += @tests;
    }
}

use Test::More
  $ENV{EB_SKIPDBTESTS} ? (skip_all => "Database tests skipped on request")
  : (tests => $remaining );

use warnings;
use File::Spec;
use File::Copy;
use File::Path qw(remove_tree);

BEGIN { use_ok('IPC::Run3') }
$remaining -= 1;

our $dbdriver;
my $dbddrv;
if ( $dbdriver ) {
    if ( $dbdriver eq "postgres" ) {
	$dbddrv = "DBD::Pg";
    }
    elsif ( $dbdriver eq "sqlite" ) {
	$dbddrv = "DBD::SQLite";
    }
    BAIL_OUT("Unsupported database driver: $dbdriver") unless $dbddrv;
}
else {
    $dbdriver = "";
}

remove_tree("out");
mkdir("out") unless -d "out";
ok( -w "out" && -d "out", "writable output dir" );
$remaining--;

# Verify that the necessary files exist. Copy to work dir.
for ( @files ) {
    my $dst = File::Spec->catfile( "out", $_ );
    copy( $_, $dst );
    ok( -s $dst, "file is present: $_" );
}
$remaining -= @files;
chdir("out");

SKIP: {
    if ( $dbddrv ) {
	eval "require $dbddrv";
	skip("DBI $dbdriver driver ($dbddrv) not installed", $remaining) if $@;
    }

    my @ebcmd = qw(-MEB::Main -e EB::Main->run -- -X -f eekboek.conf --echo);
    push(@ebcmd, "-D", "database:driver=$dbdriver") if $dbdriver;

    unshift(@ebcmd, map { ("-I",
			   "../../$_"
			  ) } grep { /^\w\w/ } reverse @INC);
    unshift(@ebcmd, $^X);

    # Check whether we can contact the database.
    eval {
	if ( $dbdriver eq "postgres" ) {
	    my @ds = DBI->data_sources("Pg");
	    diag("Connect error:\n\t" . ($DBI::errstr||""))
	      if $DBI::errstr;
	    skip("No access to database", $remaining)
	      if $DBI::errstr;
	      # && $DBI::errstr =~ /FATAL:\s*(user|role) .* does not exist/;
	}
    };

    #### PASS 1: Construct from distributed files.
    for my $log ( "init.log" ) {
	ok(syscmd([@ebcmd, qw(--init)], undef, $log), "initialise database");
	checkerr($log);
    }

    report_tests(@ebcmd);

}	# end SKIP

################ subroutines ################

sub report_tests {
    my @ebcmd = @_;

    for my $log ( "tests.log" ) {
	ok(syscmd(\@ebcmd, "tests.eb", $log), "running tests");
	checkerr($log);
	$remaining--;
    }

    foreach my $ref ( @tests ) {
	vfy($ref);
    }
}

sub vfy {
    my ($ref) = @_;
    my $out = $ref; $out =~ s;^ref/;;;
    $ref = File::Spec->catfile( File::Spec->updir, $ref );
    ok( !diff($ref, $out), "verification: $out" );
}

sub diff {
    my ($file1, $file2) = @_;
    my ($str1, $str2);
    local($/);
    open(my $fd1, "<:encoding(utf-8)", $file1) or die("$file1: $!\n");
    $str1 = <$fd1>;
    close($fd1);
    open(my $fd2, "<:encoding(utf-8)", $file2) or die("$file2: $!\n");
    $str2 = <$fd2>;
    close($fd2);
    $str1 =~ s/^EekBoek \d.*Squirrel Consultancy\n//;
    $str1 =~ s/[\n\r]+/\n/;
    $str2 =~ s/[\n\r]+/\n/;
    return 0 if $str1 eq $str2;
    1;
}

sub syscmd {
    my ($cmd, $in, $out, $err) = @_;
    my $fd;
    open( $fd, ">>", $out );
    print $fd "CMD: @$cmd";
    print $fd " < $in" if $in;
    print $fd "\n";
    print $fd "INC: @INC\n";
    $out = $fd;
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
    die("=== admtest afgebroken ===\n") if $fail;
}

1;
