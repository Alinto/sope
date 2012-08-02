%define apache_modules_dir %{_usr}/lib/httpd/modules
%define apache_conf_dir    %{_sysconfdir}/httpd/conf.d

Summary:      SOPE.
Name:         sope%{sope_major_version}%{sope_minor_version}
Version:      %{sope_version}
Release:      %{sope_release}.%{dist_suffix}.%{sope_buildcount}
Vendor:       http://www.opengroupware.org
Packager:     Wolfgang Sourdeau <wsourdeau@inverse.ca>
License:      GPL
URL:          http://www.opengroupware.org
Group:        Development/Libraries/Objective C
AutoReqProv:  off
Source:       %{sope_source}
Prefix:       /usr
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}-root
BuildPreReq:  gnustep-make gcc-objc postgresql-devel mysql-devel

%description
sope

#########################################
%package xml
Summary:      SOPE libraries for XML processing
Group:        Development/Libraries/Objective C
AutoReqProv:  off

%description xml
The SOPE libraries for XML processing contain:

  * a SAX2 Implementation for Objective-C
  * an attempt to implement DOM on top of SaxObjC
  * an XML-RPC implementation (without a transport layer)

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package xml-devel
Summary:      Development files for the SOPE XML libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml libxml2-devel
AutoReqProv:  off

%description xml-devel
This package contains the development files of the SOPE XML libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#########################################
%package sbjson
Summary:      JSON framework
Group:        Development/Libraries/Objective C
Version:      %{sbjson_version}

%description sbjson
The SBJson library is a high performance JSON library in Objective-C.

Project homepage is: http://code.google.com/p/json-framework/

%package sbjson-devel
Summary:      JSON framework (devel)
Group:        Development/Libraries/Objective C
Version:      %{sbjson_version}

%description sbjson-devel
The SBJson library is a high performance JSON library in Objective-C.

Those are the files required for development.

Project homepage is: http://code.google.com/p/json-framework/

#########################################
%package core
Summary:      Core libraries of the SOPE application server
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml
AutoReqProv:  off

%description core
The SOPE core libraries contain:

  * various Foundation extensions
  * a java.io like stream and socket library

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package core-devel
Summary:      Development files for the SOPE core libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-core
AutoReqProv:  off

%description core-devel
This package contains the header files for the SOPE core
libraries,  which are part of the SOPE application server framework.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#########################################
%package mime
Summary:      SOPE libraries for MIME processing
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml
AutoReqProv:  off

%description mime
The SOPE libraries for MIME processing contain:

  * classes for processing MIME entities
  * a full IMAP4 implementation
  * prototypical POP3 and SMTP processor

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package mime-devel
Summary:      Development files for the SOPE MIME libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-mime
AutoReqProv:  off

%description mime-devel
This package contains the development files of the SOPE
MIME libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#########################################
%package appserver
Summary:      SOPE application server libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-mime
AutoReqProv:  off

%description appserver
The SOPE application server libraries provide:

  * template rendering engine, lots of dynamic elements
  * HTTP client/server
  * XML-RPC client
  * WebDAV server framework
  * session management
  * scripting extensions for Foundation, JavaScript bridge
  * DOM tree rendering library

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package appserver-devel
Summary:      Development files for the SOPE application server libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-appserver
AutoReqProv:  off

%description appserver-devel
This package contains the development files for the SOPE application server
libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#########################################
%package ldap
Summary:      SOPE libraries for LDAP access
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml
AutoReqProv:  off

%description ldap
The SOPE libraries for LDAP access contain an Objective-C wrapper for
LDAP directory services.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package ldap-devel
Summary:      Development files for the SOPE LDAP libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-ldap
AutoReqProv:  off

%description ldap-devel
This package contains the development files of the SOPE
LDAP libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#########################################
%package gdl1
Summary:      GNUstep database libraries for SOPE
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml
AutoReqProv:  off

%description gdl1
This package contains a fork of the GNUstep database libraries used
by the SOPE application server (excluding GDLContentStore).

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-postgresql
Summary:      PostgreSQL connector for SOPE's fork of the GNUstep database environment
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1 postgresql-libs
AutoReqProv:  off

%description gdl1-postgresql
This package contains the PostgreSQL connector for SOPE's fork of the
GNUstep database libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-oracle
Summary:      Oracle connector for SOPE's fork of the GNUstep database environment
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
#Requires:    oracle-instantclient-basic
AutoReqProv:  off

%description gdl1-oracle
This package contains the Oracle connector for SOPE's fork of the
GNUstep database libraries.

%package gdl1-mysql
Summary:      MySQL connector for SOPE's fork of the GNUstep database environment
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description gdl1-mysql
This package contains the MySQL connector for SOPE's fork of the
GNUstep database libraries.


#%package gdl1-sqlite3
#Summary:      SQLite3 connector for SOPE's fork of the GNUstep database environment
#Group:        Development/Libraries/Objective C
#Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
#AutoReqProv:  off
#
#%description gdl1-sqlite3
#This package contains the SQLite3 connector for SOPE's fork of the
#GNUstep database libraries.
#
#SOPE is a framework for developing web applications and services. The
#name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-devel
Summary:      Development files for the GNUstep database libraries
Group:        Development/Libraries/Objective C
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description gdl1-devel
This package contains the header files for SOPE's fork of the GNUstep
database libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

#%package -n mod_ngobjweb
#Summary:      mod_ngobjweb apache module
#Group:        Development/Libraries
#AutoReqProv:  off
#Requires:     %{ngobjweb_requires}
#
#%description -n mod_ngobjweb
#Enables apache to handle HTTP requests for the
#OpenGroupware.org application server.

########################################

%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n SOPE

# ****************************** build ********************************
%build
case %{_target_platform} in
ppc64-*)
  export CC="gcc -m64";;
*)
  export CC="gcc";;
esac

%ifarch x86_64
  ORACLELIB_PATH="/usr/%{_lib}/oracle/11.2/client64/lib/"
%else
  ORACLELIB_PATH="/usr/%{_lib}/oracle/11.2/client/lib/"
%endif

if [ -f /usr/lib/rpm/redhat/config.sub ]
then
  cp /usr/lib/rpm/redhat/{config.sub,config.guess} sope-core/NGStreams/
elif [ -f /usr/lib/rpm/config.sub ]
then
  cp /usr/lib/rpm/{config.sub,config.guess} sope-core/NGStreams/
fi

./configure \
            --enable-debug \
            --disable-strip \
	    --with-gnustep

make CC="$CC" %{sope_makeflags}
cd sope-gdl1/MySQL
make CC="$CC" LDFLAGS="-L/usr/%{_lib}/mysql" %{sope_makeflags}
cd ../Oracle8
make CC="$CC" LDFLAGS="-L$ORACLELIB_PATH" %{sope_makeflags}
export PATH=$PATH:/usr/sbin
#cd ../../sope-appserver/mod_ngobjweb/
#if [ -x /usr/bin/apr-1-config ]
#then
#  aprconfig=/usr/bin/apr-1-config
#else
#  aprconfig=/usr/bin/apr-config
#fi
#make apr=$aprconfig apxs=/usr/sbin/apxs


# ****************************** install ******************************
%install
make %{sope_makeflags} DESTDIR=${RPM_BUILD_ROOT} \
			GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
                       install

cd sope-gdl1/MySQL
make %{sope_makeflags} DESTDIR=${RPM_BUILD_ROOT} \
                        GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
                       install
cd ../Oracle8
make %{sope_makeflags} DESTDIR=${RPM_BUILD_ROOT} \
                        GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
                       install

rm -f ${RPM_BUILD_ROOT}%{_bindir}/otest
rm -fr ${RPM_BUILD_ROOT}%{_libdir}/GNUstep/GDLAdaptors-%{sope_version}/SQLite3.gdladaptor

# rm -f ${RPM_BUILD_ROOT}/usr/GNUstep/System/Tools/Admin/sope-4.9
# export PATH=$PATH:/usr/sbin
#mkdir -p ${RPM_BUILD_ROOT}%{apache_modules_dir}
#cp sope-appserver/mod_ngobjweb/mod_ngobjweb.so ${RPM_BUILD_ROOT}%{apache_modules_dir}/
#
#mkdir -p ${RPM_BUILD_ROOT}%{apache_conf_dir}
#echo "#Here we load the 'mod_ngobjweb.so' module
#
#LoadModule ngobjweb_module %{apache_modules_dir}/mod_ngobjweb.so
#" > ${RPM_BUILD_ROOT}%{apache_conf_dir}/ngobjweb.conf

# rm -f ${RPM_BUILD_ROOT}%{prefix}/Tools/rss2plist1
# rm -f ${RPM_BUILD_ROOT}%{prefix}/Tools/rss2plist2
# rm -f ${RPM_BUILD_ROOT}%{prefix}/Tools/rssparse
# rm -f ${RPM_BUILD_ROOT}%{prefix}/Tools/testqp
# rm -fr ${RPM_BUILD_ROOT}%{prefix}/man/

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files xml
%defattr(-,root,root,-)
%{_libdir}/libDOM*.so.%{sope_version}*
%{_libdir}/libSaxObjC*.so.%{sope_version}*
%{_libdir}/libXmlRpc*.so.%{sope_version}*
%{_libdir}/GNUstep/SaxDrivers-%{sope_version}

%files xml-devel
%defattr(-,root,root,-)
%{_includedir}/DOM
%{_includedir}/SaxObjC
%{_includedir}/XmlRpc
%{_libdir}/libDOM*.so
%{_libdir}/libSaxObjC*.so
%{_libdir}/libXmlRpc*.so

%files sbjson
%defattr(-,root,root,-)
%{_libdir}/libSBJson.so.%{sbjson_major_version}*

%files sbjson-devel
%defattr(-,root,root,-)
%{_includedir}/SBJson
%{_libdir}/libSBJson.so

%files core
%defattr(-,root,root,-)
%{_libdir}/libEOControl*.so.%{sope_version}*
%{_libdir}/libNGExtensions*.so.%{sope_version}*
%{_libdir}/libNGStreams*.so.%{sope_version}*

%files core-devel
%defattr(-,root,root,-)
%{_includedir}/EOControl
%{_includedir}/NGExtensions
%{_includedir}/NGStreams
%{_libdir}/libEOControl*.so
%{_libdir}/libNGExtensions*.so
%{_libdir}/libNGStreams*.so

%files mime
%defattr(-,root,root,-)
%{_libdir}/libNGMime*.so.%{sope_version}*

%files mime-devel
%defattr(-,root,root,-)
%{_includedir}/NGImap4
%{_includedir}/NGMail
%{_includedir}/NGMime
%{_libdir}/libNGMime*.so

%files appserver
%defattr(-,root,root,-)
%{_libdir}/libNGObjWeb*.so.%{sope_version}*
%{_libdir}/libWEExtensions*.so.%{sope_version}*
%{_libdir}/libWOExtensions*.so.%{sope_version}*
%{_libdir}/GNUstep/Libraries/Resources/NGObjWeb/*
%{_libdir}/GNUstep/SoProducts-%{sope_version}
%{_libdir}/GNUstep/WOxElemBuilders-%{sope_version}

%files appserver-devel
%defattr(-,root,root,-)
%{_bindir}/wod
%{_includedir}/NGHttp
%{_includedir}/NGObjWeb
%{_includedir}/WEExtensions
%{_includedir}/WOExtensions
%{_libdir}/libNGObjWeb*.so
%{_libdir}/libWEExtensions*.so
%{_libdir}/libWOExtensions*.so
%{_datadir}/GNUstep/Makefiles

%files ldap
%defattr(-,root,root,-)
%{_libdir}/libNGLdap*.so.%{sope_version}*

%files ldap-devel
%defattr(-,root,root,-)
%{_includedir}/NGLdap
%{_libdir}/libNGLdap*.so

%files gdl1
%defattr(-,root,root,-)
%{_bindir}/connect-EOAdaptor
%{_bindir}/load-EOAdaptor
%{_libdir}/libGDLAccess*.so.%{sope_version}*

%files gdl1-postgresql
%defattr(-,root,root,-)
%{_libdir}/GNUstep/GDLAdaptors-%{sope_version}/PostgreSQL.gdladaptor

%files gdl1-oracle
%defattr(-,root,root,-)
%{_libdir}/GNUstep/GDLAdaptors-%{sope_version}/Oracle8.gdladaptor

%files gdl1-mysql
%defattr(-,root,root,-)
%{_libdir}/GNUstep/GDLAdaptors-%{sope_version}/MySQL.gdladaptor

#%files gdl1-sqlite3
#%defattr(-,root,root,-)
#%{_libdir}/GNUstep/GDLAdaptors-%{sope_version}/SQLite3.gdladaptor

%files gdl1-devel
%defattr(-,root,root,-)
%{_includedir}/GDLAccess
%{_libdir}/libGDLAccess*.so

#%files -n mod_ngobjweb
#%defattr(-,root,root,-)
#%{apache_modules_dir}/mod_ngobjweb.so
#%config %{apache_conf_dir}/ngobjweb.conf

# ********************************* changelog *************************
%changelog
* Thu Aug 02 2012 Jean Raby <jraby@inverse.ca>
- Deduce the oracle lib path from the build arch
* Mon Dec 05 2011 Jean Raby <jraby@inverse.ca>
- updated for oracle-instantclient11.2
* Fri Oct 14 2011 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- adapted to gnustep 1.23 packages, which now uses FHS nomenclature
* Fri Jan 23 2009 Ludovic Marcotte <lmarcotte@inverse.ca>
- we no longer build mod_ngobjweb
* Wed Jul 18 2007 Wolfgang Sourdeau <wsourdeau@inverse.ca>
- repackaged for CentOS 5 and GNUstep
* Mon Jul 10 2006 Frank Reppin <frank@opengroupware.org>
- adjust requires on new libfoundation
* Fri Sep 16 2005 Frank Reppin <frank@opengroupware.org>
- added WEPrototype and its lib to appserver/appserver-devel
* Fri Aug 26 2005 Frank Reppin <frank@opengroupware.org>
- added sope-gdl1-sqlite3 (as comment)
* Thu Apr 21 2005 Frank Reppin <frank@opengroupware.org>
- added sope-gdl1-mysql
* Tue Mar 22 2005 Frank Reppin <frank@opengroupware.org>
- added GDLContentStore to sope-gdl1
- reworked descriptions regarding GDLContentStore
- added new subpackage sope-gdl1-tools
- sope-gdl1 now depends on sope-xml due to -lDOM -lSaxObjC
  used by GDLContentStore
* Fri Jan 28 2005 Frank Reppin <frank@opengroupware.org>
- reworked dependencies
- deal with ld.so.conf in (post|preun) of appserver rather than core
* Tue Jan 25 2005 Frank Reppin <frank@opengroupware.org>
- fix for OGo Bug #1192
* Tue Jan 11 2005 Frank Reppin <frank@opengroupware.org>
- reworked all summaries and descriptions (taken from Debian control
  to be honest :>)
* Tue Nov 16 2004 Frank Reppin <frank@opengroupware.org>
- s^4.5^%{sope_version}^g everywhere bc .rpmmacros knows
  the current version we build for
* Sat Nov 06 2004 Helge Hess <helge.hess@opengroupware.org>
- updated to 4.5 version
* Wed Sep 09 2004 Frank Reppin <frank@opengroupware.org>
- initial build
