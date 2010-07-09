Name: EekBoek-yum
Version: 1.05
Release: 1
Source: http://www.eekboek.nl/eekboek/dl/%{name}-%{version}.tar.gz
BuildArch: noarch
URL: http://www.eekboek.nl/
BuildRoot: %{_tmppath}/rpm-buildroot-%{name}-%{version}-%{release}
Vendor: Squirrel Consultancy
Packager: Johan Vromans <jvromans@squirrel.nl>

Summary: YUM support for EekBoek
License: Artistic
Group: Applications/Productivity
Requires: yum

%description
EekBoek is a bookkeeping package for small and medium-size businesses.
Unlike other accounting software, EekBoek has both a command-line
interface (CLI) and a graphical user-interface (GUI). Furthermore, it
has a complete Perl API to create your own custom applications.
EekBoek is designed for the Dutch/European market and currently
available in Dutch only. An English translation is in the works (help
appreciated).

This package contains settings data for EekBoek installs via yum.

%prep
%setup -q -n %{name}-%{version}

%build

%install

%{__rm} -rf $RPM_BUILD_ROOT

%{__mkdir_p} ${RPM_BUILD_ROOT}/etc/yum.repos.d
%{__install} -m 0644 eekboek.repo ${RPM_BUILD_ROOT}/etc/yum.repos.d
%{__mkdir_p} ${RPM_BUILD_ROOT}/etc/pki/rpm-gpg
%{__install} -m 0644 RPM-GPG-KEY-EekBoek ${RPM_BUILD_ROOT}/etc/pki/rpm-gpg/

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc README 
/etc/yum.repos.d/eekboek.repo
/etc/pki/rpm-gpg/RPM-GPG-KEY-EekBoek

%changelog
* Thu Jul 08 2010 Johan Vromans <jvromans@squirrel.nl> 1.05-1
- Install PGP key in /etc/pki/rpm-gpg.

* Sat Jul 19 2008 Johan Vromans <jvromans@squirrel.nl> 1.04
- Add eekboek-testing repo.

* Fri Aug 04 2006 Johan Vromans <jvromans@squirrel.nl> 1.0-1
- Production.

* Wed Aug 02 2006 Johan Vromans <jvromans@squirrel.nl> 0.92
- New URL. Add Vendor.
