# gmake file for MS Windows + CitrusPerl
# Based on 64-bit gmake and CitrusPerl 5.24 with wxWidgets 3.0.

SCRIPT := ..

.ONESHELL :

PP := pp

ebshell.exe :: ebshell.pp
	${PP} --output=ebshell.exe @ebshell.pp ${SCRIPT}/ebshell.pl

# For wxWidgets, explicit libraries are specified in ebwxshell.pp and the
# PATH must be set accordingly.
# To set PATH from the makefile, we need .ONESHELL pseudo target above.

ebwxshell.exe :: ebshell.pp ebwxshell.pp ../common/ebwxshell.pp
	set path=C:\\perl\\vendor\\lib\\Alien\\wxWidgets\\msw_3_0_2_uni_gcc_1_2\\lib;%path%
	${PP} --output=ebwxshell.exe @ebwxshell.pp ${SCRIPT}/ebwxshell.pl

ISC := 	"C:\\Program Files (x86)\\Inno Setup 5\\Compil32.exe"

iss ::	install innosetup.iss
	perl vfix.pl
	${ISC} /cc innosetup.iss

# NOTE: THIS IS FOR TESTING/DEVELOPMENT ONLY.

DST	:= C:\\Users\\Johan\\Documents\\EekBoek

install :: ebshell.exe ebwxshell.exe
	copy ebshell.exe ${DST}
	copy ebwxshell.exe ${DST}
	copy ebinst.bmp ${DST}
	copy ..\..\lib\EB\res\Wx\icons\eb.ico ${DST}

clean ::
	del ebshell.exe ebwxshell.exe *.pp.deps
