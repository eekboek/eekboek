%define modname EekBoek
%define lcname eekboek
%define modversion 0.59

################ Build Options ################
%define gui 0
%{?_with_gui:    %{expand: %%define gui 1}}
%{?_without_gui: %{expand: %%define gui 0}}

%define dbtests 0
%{?_with_dbtests:    %{expand: %%define dbtests 1}}
%{?_without_dbtests: %{expand: %%define dbtests 0}}
################ End Build Options ################

Name: %modname
Version: %modversion
Release: 1
Source: http://www.squirrel.nl/eekboek/dl/%{name}-%{version}.tar.gz
BuildArch: noarch
URL: http://www.squirrel.nl/eekboek/
BuildRoot: %{_tmppath}/rpm-buildroot-%{name}-%{version}-%{release}
Prefix: %{_prefix}

AutoReqProv: 0

Requires: perl >= 5.8
Requires: perl(Config::IniFiles) >= 2.38
Requires: perl(Term::ReadLine)
Requires: perl(DBI) >= 1.40
Requires: perl(DBD::Pg) >= 1.41

BuildRequires: perl >= 5.8

#Provides: %{name}   = %{version}
#Provides: %{lcname} = %{version}

Summary: Bookkeeping software for small and medium-size businesses
License: Artistic
Group: Applications/Productivity

%description
EekBoek is a bookkeeping package for small and medium-size businesses.
Unlike other accounting software, EekBoek has both a command-line
interface (CLI) and a graphical user-interface (GUI). Furthermore, it
has a complete Perl API to create your own custom applications.
EekBoek is designed for the Dutch/European market and currently
available in Dutch only. An English translation is in the works (help
appreciated).

%if %{gui}
%package gui
Summary: GUI enhancements for %{name}.
Group: Applications/Productivity
AutoReqProv: 0
Requires: %{name} = %{version}
Requires: perl-Wx >= 0.27

%description gui
The wxWidgets extension for %{name}.
%endif

%prep
%setup -q

%build
%{__perl} Build.PL
%{__perl} Build
%if %{dbtests}
%{__perl} Build test
%else
%{__perl} Build test --skipdbtests
%endif
%if %{gui}
%{__install} -m 0755 script/ebgui blib/script/ebgui
%endif

%install

%define ebconf  %{_sysconfdir}/%{lcname}
%define ebshare %{_datadir}/%{name}-%{version}

%{__rm} -rf $RPM_BUILD_ROOT

%{__mkdir_p} ${RPM_BUILD_ROOT}%{ebconf}
%{__install} -m 0644 example/eekboek.conf ${RPM_BUILD_ROOT}%{ebconf}

%{__mkdir_p} ${RPM_BUILD_ROOT}%{ebshare}/lib

find blib/lib -type d -printf "mkdir ${RPM_BUILD_ROOT}%{ebshare}/lib/%%P\n" | sh -x
find blib/lib ! -type d -printf "%{__install} -m 0444 %p ${RPM_BUILD_ROOT}%{ebshare}/lib/%%P\n" | sh -x

%{__mkdir_p} ${RPM_BUILD_ROOT}%{_bindir}

echo "#!%{__perl}" > ${RPM_BUILD_ROOT}%{_bindir}/ebshell

sed -s "s;# use lib qw(EekBoekLibrary;use lib qw(%{ebshare}/lib;" \
	< script/ebshell >> ${RPM_BUILD_ROOT}%{_bindir}/ebshell
%{__chmod} 0755 ${RPM_BUILD_ROOT}%{_bindir}/ebshell

%if %{dbtests}
pg_dump eekboek_sample -x -C -O -f example/sampledb.sql
%endif

%if %{gui}
%{__mkdir_p} ${RPM_BUILD_ROOT}%{ebshare}/script
%{__install} -m 0755 blib/script/ebgui ${RPM_BUILD_ROOT}%{ebshare}/script
%{__mkdir_p} ${RPM_BUILD_ROOT}%{ebshare}/libgui
echo "#!%{__perl}" > ${RPM_BUILD_ROOT}%{_bindir}/ebgui
echo 'my $share = "%{ebshare}";' >> ${RPM_BUILD_ROOT}%{_bindir}/ebgui
echo 'exec $^X "perl", "-Mlib=$share/lib", "-Mlib=$share/libgui", "$share/script/ebgui", @ARGV;' >> ${RPM_BUILD_ROOT}%{_bindir}/ebgui
%{__chmod} 0755 ${RPM_BUILD_ROOT}%{_bindir}/ebgui
%endif

%{__mkdir_p} ${RPM_BUILD_ROOT}%{_mandir}/man1
pod2man blib/script/ebshell > ${RPM_BUILD_ROOT}%{_mandir}/man1/ebshell.1
%{__mkdir_p} ${RPM_BUILD_ROOT}%{_mandir}/man3
pod2man blib/lib/EekBoek.pm > ${RPM_BUILD_ROOT}%{_mandir}/man3/Eekboek.3pm

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc CHANGES README INSTALL QUICKSTART example doc/html TODO
%dir %{_sysconfdir}/%{lcname}
%config(noreplace) %{_sysconfdir}/%{lcname}/eekboek.conf
%dir %{ebshare}
%{ebshare}/lib
%{_bindir}/ebshell
%{_mandir}/man1/*
%{_mandir}/man3/*

%if %{gui}
%files gui
%defattr(-,root,root)
%{ebshare}/libgui
%dir %{ebshare}/script
%{ebshare}/script/ebgui
%{_bindir}/ebgui
%endif

%changelog
* Mon Jun 05 2006 Johan Vromans <jvromans@squirrel.nl> 0.59
- Better script handling.
* Mon Apr 17 2006 Johan Vromans <jvromans@squirrel.nl> 0.56
- Initial provisions for GUI.
* Wed Apr 12 2006 Johan Vromans <jvromans@squirrel.nl> 0.56
- %config(noreplace) for eekboek.conf.
* Tue Mar 28 2006 Johan Vromans <jvromans@squirrel.nl> 0.52
- Perl Independent Install
* Mon Mar 27 2006 Johan Vromans <jvromans@squirrel.nl> 0.52
- Add "--with dbtests" parameter for rpmbuild.
- Resultant rpm may be signed.
* Sun Mar 19 2006 Johan Vromans <jvromans@squirrel.nl> 0.50
- Switch to Build.PL instead of Makefile.PL.
* Mon Jan 30 2006 Johan Vromans <jvromans@squirrel.nl> 0.37
- Add build dep perl(Config::IniFiles).
* Fri Dec 23 2005 Wytze van der Raay <wytze@nlnet.nl> 0.23
- Fixes for x86_64 building problems.
* Wed Dec 12 2005 Johan Vromans <jvromans@squirrel.nl> 0.22
- Change some wordings.
- Add man1.
* Tue Dec 11 2005 Johan Vromans <jvromans@squirrel.nl> 0.21
- Add INSTALL QUICKSTART
* Thu Dec 08 2005 Johan Vromans <jvromans@squirrel.nl> 0.20
- Include doc/html.
* Tue Nov 22 2005 Johan Vromans <jvromans@squirrel.nl> 0.19
- More.
* Sun Nov 20 2005 Jos Vos <jos@xos.nl> 0.17-XOS.0beta1
- Initial version.
