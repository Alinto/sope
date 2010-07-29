Summary:      Implementation of the OpenStep specification.
Name:         libfoundation%{libf_major_version}%{libf_minor_version}
Version:      %{libf_version}
Release:      %{libf_release}.%{libf_buildcount}%{dist_suffix}
Vendor:       OpenGroupware.org
Packager:     Frank Reppin <frank@opengroupware.org>  
License:      libFoundation license
URL:          http://www.opengroupware.org
Group:        Development/Libraries
AutoReqProv:  off
Source:       %{libf_source}
Prefix:       %{libf_prefix}
Requires:     libobjc
Conflicts:    libfoundation
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}-root

%description
libFoundation is a library that provides an almost complete
implementation of the OpenStep specification plus many other extensions
that can be found in the Apple's MacOS X Foundation library.

%package devel
Summary:      Development files for libFoundation.
Group:        Development/Libraries
Requires:     ogo-gnustep_make libfoundation%{libf_major_version}%{libf_minor_version}
AutoReqProv:  off
Conflicts:    libfoundation-devel

%description devel
This package contains the development files of libFoundation.

libFoundation is a library that provides an almost complete
implementation of the OpenStep specification plus many other extensions
that can be found in the Apple's MacOS X Foundation library.

%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n libfoundation

# ****************************** build ********************************
%build
source %{prefix}/OGo-GNUstep/Library/Makefiles/GNUstep.sh
export CFLAGS=-Wno-import
./configure
make %{libf_makeflags} all

# ****************************** install ******************************
%install
source %{prefix}/OGo-GNUstep/Library/Makefiles/GNUstep.sh
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/OGo-GNUstep/Library/Makefiles/Additional

make %{libf_makeflags} INSTALL_ROOT_DIR=${RPM_BUILD_ROOT} \
                       GNUSTEP_INSTALLATION_DIR=${RPM_BUILD_ROOT}%{prefix} \
                       FHS_INSTALL_ROOT=${RPM_BUILD_ROOT}%{prefix} \
                       install

rm -f ${RPM_BUILD_ROOT}%{prefix}/Library/Headers/libFoundation/extensions/exceptions/FoundationException.h
rm -f ${RPM_BUILD_ROOT}%{prefix}/Library/Headers/libFoundation/extensions/exceptions/GeneralExceptions.h
rm -f ${RPM_BUILD_ROOT}%{prefix}/Library/Headers/libFoundation/extensions/exceptions/NSCoderExceptions.h


# ****************************** post *********************************
%post
if [ $1 = 1 ]; then
  if [ -d %{_sysconfdir}/ld.so.conf.d ]; then
    echo "%{prefix}/lib" > %{_sysconfdir}/ld.so.conf.d/libfoundation.conf
  elif [ ! "`grep '%{prefix}/lib' %{_sysconfdir}/ld.so.conf`" ]; then
    echo "%{prefix}/lib" >> %{_sysconfdir}/ld.so.conf
  fi
  /sbin/ldconfig
fi

# ****************************** postun *********************************
%postun
if [ $1 = 0 ]; then
  if [ -e %{_sysconfdir}/ld.so.conf.d/libfoundation.conf ]; then
    rm -f %{_sysconfdir}/ld.so.conf.d/libfoundation.conf
  fi
  /sbin/ldconfig
fi

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files
%defattr(-,root,root,-)
%{prefix}/bin/Defaults
%{prefix}/lib/libFoundation*.so.%{libf_version}
%{prefix}/lib/libFoundation*.so.%{libf_major_version}.%{libf_minor_version}
%{prefix}/share/libFoundation/CharacterSets
%{prefix}/share/libFoundation/Defaults
%{prefix}/share/libFoundation/TimeZoneInfo

%files devel
%defattr(-,root,root,-)
%{prefix}/OGo-GNUstep/Library/Makefiles/Additional/libFoundation.make
%{prefix}/include/lfmemory.h
%{prefix}/include/real_exception_file.h
%{prefix}/include/Foundation
%{prefix}/include/extensions
%{prefix}/lib/libFoundation*.so

# ********************************* changelog *************************
%changelog
* Thu Apr 19 2007 Frank Reppin <frank@opengroupware.org>
- add missing requires (libobjc)
* Wed Mar 16 2005 Frank Reppin <frank@opengroupware.org>
- conflicts: libfoundation (the former name of the package)
* Tue Jan 18 2005 Frank Reppin <frank@opengroupware.org>
- dealt with http://bugzilla.opengroupware.org/bugzilla/show_bug.cgi?id=1182
* Wed Sep 09 2004 Frank Reppin <frank@opengroupware.org>
- initial build
