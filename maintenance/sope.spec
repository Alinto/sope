%define lfmaj 1
%define lfmin 1

Summary:      SOPE.
Name:         sope%{sope_major_version}%{sope_minor_version}
Version:      %{sope_version}
Release:      %{sope_release}.%{sope_buildcount}%{dist_suffix}
Vendor:       http://www.opengroupware.org
Packager:     Frank Reppin <frank@opengroupware.org>  
License:      GPL
URL:          http://www.opengroupware.org
Group:        Development/Libraries
AutoReqProv:  off
Source:       %{sope_source}
Prefix:       %{sope_prefix}
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}-root
BuildPreReq:  ogo-gnustep_make

%description
sope

#########################################
%package xml
Summary:      SOPE libraries for XML processing
Group:        Development/Libraries
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
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-xml libxml2-devel
AutoReqProv:  off

%description xml-devel
This package contains the development files of the SOPE XML libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package xml-tools
Summary:      Tools (domxml/saxxml/xmln)
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml
AutoReqProv:  off

%description xml-tools
This package contains some tools:

  * saxxml    - parse a file using SAX and print out the XML
  * xmln      - convert a given file to PYX using a SAX handler
  * domxml    - parse a file into a DOM and print out the XML

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package core
Summary:      Core libraries of the SOPE application server
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml libfoundation%{lfmaj}%{lfmin}
AutoReqProv:  off

%description core
The SOPE core libraries contain:

  * various Foundation extensions
  * a java.io like stream and socket library

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package core-devel
Summary:      Development files for the SOPE core libraries
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-core
AutoReqProv:  off

%description core-devel
This package contains the header files for the SOPE core
libraries,  which are part of the SOPE application server framework.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package mime
Summary:      SOPE libraries for MIME processing
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml libfoundation%{lfmaj}%{lfmin}
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
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-mime
AutoReqProv:  off

%description mime-devel
This package contains the development files of the SOPE
MIME libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package appserver
Summary:      SOPE application server libraries
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-mime libfoundation%{lfmaj}%{lfmin}
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
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-appserver
AutoReqProv:  off

%description appserver-devel
This package contains the development files for the SOPE application server
libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package appserver-tools
Summary:      Tools shipped with the SOPE application server
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-appserver
AutoReqProv:  off

%description appserver-tools
This package contains some tools shipped with the SOPE application
server framework, which are mostly useful for development and debugging
of SOPE applications.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package ldap
Summary:      SOPE libraries for LDAP access
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml libfoundation%{lfmaj}%{lfmin}
AutoReqProv:  off

%description ldap
The SOPE libraries for LDAP access contain an Objective-C wrapper for
LDAP directory services.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package ldap-devel
Summary:      Development files for the SOPE LDAP libraries
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-ldap
AutoReqProv:  off

%description ldap-devel
This package contains the development files of the SOPE
LDAP libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package ldap-tools
Summary:      Tools (ldap2dsml/ldapchkpwd/ldapls)
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-ldap
AutoReqProv:  off

%description ldap-tools
This package contains some tools:

  * ldap2dsml   - return the output of an LDAP server as DSML
                  (directory service markup language)
  * ldapchkpwd  - checks whether a login/password combo would be authenticated
  * ldapls      - an 'ls' for LDAP directories

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package ical
Summary:      SOPE libraries for iCal handling
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-xml sope%{sope_major_version}%{sope_minor_version}-core libfoundation%{lfmaj}%{lfmin}
AutoReqProv:  off

%description ical
The SOPE libraries for iCal handling contain classes for iCalendar and
vCard objects.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package ical-devel
Summary:      Development files for the SOPE iCal libraries
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-ical
AutoReqProv:  off

%description ical-devel
This package contains the development files of the SOPE iCal libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
#########################################
%package gdl1
Summary:      GNUstep database libraries for SOPE
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-core sope%{sope_major_version}%{sope_minor_version}-xml libfoundation%{lfmaj}%{lfmin}
AutoReqProv:  off

%description gdl1
This package contains a fork of the GNUstep database libraries used
by the SOPE application server.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-postgresql
Summary:      PostgreSQL connector for SOPE's fork of the GNUstep database environment
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off
%if %{?_postgresql_server_is_within_postgresql:1}%{!?_postgresql_server_is_within_postgresql:0}
Requires: postgresql
%else
Requires: postgresql-server
%endif

%description gdl1-postgresql
This package contains the PostgreSQL connector for SOPE's fork of the
GNUstep database libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-mysql
Summary:      MySQL connector for SOPE's fork of the GNUstep database environment
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description gdl1-mysql
This package contains the MySQL connector for SOPE's fork of the
GNUstep database libraries.

#%package gdl1-sqlite3
#Summary:      SQLite3 connector for SOPE's fork of the GNUstep database environment
#Group:        Development/Libraries
#Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
#AutoReqProv:  off
#
#%description gdl1-sqlite3
#This package contains the SQLite3 connector for SOPE's fork of the
#GNUstep database libraries.
#
#SOPE is a framework for developing web applications and services. The
#name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-tools
Summary:      Tools (gcs_cat/gcs_gensql/gcs_ls/gcs_mkdir/gcs_recreatequick)
Group:        Development/Libraries
Requires:     sope%{sope_major_version}%{sope_minor_version}-gdl1
AutoReqProv:  off

%description gdl1-tools
Various tools around the GDL.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.

%package gdl1-devel
Summary:      Development files for the GNUstep database libraries
Group:        Development/Libraries
Requires:     ogo-gnustep_make sope%{sope_major_version}%{sope_minor_version}-gdl1 postgresql-devel
AutoReqProv:  off

%description gdl1-devel
This package contains the header files for SOPE's fork of the GNUstep
database libraries.

SOPE is a framework for developing web applications and services. The
name "SOPE" (SKYRiX Object Publishing Environment) is inspired by ZOPE.
########################################
%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n sope

# ****************************** build ********************************
%build
./configure --prefix=${RPM_BUILD_ROOT}%{prefix} \
            --enable-debug \
            --gsmake=%{prefix}/OGo-GNUstep

make %{sope_makeflags}

cd sope-gdl1/MySQL
make %{sope_makeflags}

# ****************************** install ******************************
%install
mkdir -p ${RPM_BUILD_ROOT}%{prefix}/lib

make %{sope_makeflags} INSTALL_ROOT_DIR=${RPM_BUILD_ROOT} \
                       GNUSTEP_INSTALLATION_DIR=${RPM_BUILD_ROOT}%{prefix} \
                       install

cd sope-gdl1/MySQL
make %{sope_makeflags} INSTALL_ROOT_DIR=${RPM_BUILD_ROOT} \
                       GNUSTEP_INSTALLATION_DIR=${RPM_BUILD_ROOT}%{prefix} \
                       install

rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/rss2plist1
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/rss2plist2
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/rssparse
rm -f ${RPM_BUILD_ROOT}%{prefix}/bin/testqp
rm -fr ${RPM_BUILD_ROOT}%{prefix}/man/

rm -fr ${RPM_BUILD_ROOT}%{prefix}/lib/sope-%{sope_major_version}.%{sope_minor_version}/dbadaptors/SQLite3.gdladaptor

# ****************************** post *********************************
%post appserver
if [ $1 = 1 ]; then
  if [ -d %{_sysconfdir}/ld.so.conf.d ]; then
    echo "%{prefix}/lib" > %{_sysconfdir}/ld.so.conf.d/sope%{sope_major_version}%{sope_minor_version}.conf
  elif [ ! "`grep '%{prefix}/lib' %{_sysconfdir}/ld.so.conf`" ]; then
    echo "%{prefix}/lib" >> %{_sysconfdir}/ld.so.conf
  fi
  /sbin/ldconfig
fi

# ****************************** postun *********************************
%postun appserver
if [ $1 = 0 ]; then
  if [ -e %{_sysconfdir}/ld.so.conf.d/sope%{sope_major_version}%{sope_minor_version}.conf ]; then
    rm -f %{_sysconfdir}/ld.so.conf.d/sope%{sope_major_version}%{sope_minor_version}.conf
  fi
  /sbin/ldconfig
fi

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files xml
%defattr(-,root,root,-)
%{prefix}/lib/libDOM*.so.%{sope_libversion}*
%{prefix}/lib/libSaxObjC*.so.%{sope_libversion}*
%{prefix}/lib/libXmlRpc*.so.%{sope_libversion}*
%{prefix}/lib/sope-%{sope_libversion}/saxdrivers/libxmlSAXDriver.sax
%{prefix}/lib/sope-%{sope_libversion}/saxdrivers/STXSaxDriver.sax

%files xml-tools
%defattr(-,root,root,-)
%{prefix}/bin/domxml
%{prefix}/bin/saxxml
%{prefix}/bin/xmln

%files xml-devel
%defattr(-,root,root,-)
%{prefix}/include/DOM
%{prefix}/include/SaxObjC
%{prefix}/include/XmlRpc
%{prefix}/lib/libDOM*.so
%{prefix}/lib/libSaxObjC*.so
%{prefix}/lib/libXmlRpc*.so

%files core
%defattr(-,root,root,-)
%{prefix}/lib/libEOControl*.so.%{sope_libversion}*
%{prefix}/lib/libNGExtensions*.so.%{sope_libversion}*
%{prefix}/lib/libNGStreams*.so.%{sope_libversion}*

%files core-devel
%defattr(-,root,root,-)
%{prefix}/include/EOControl
%{prefix}/include/NGExtensions
%{prefix}/include/NGStreams
%{prefix}/lib/libEOControl*.so
%{prefix}/lib/libNGExtensions*.so
%{prefix}/lib/libNGStreams*.so

%files mime
%defattr(-,root,root,-)
%{prefix}/lib/libNGMime*.so.%{sope_libversion}*

%files mime-devel
%defattr(-,root,root,-)
%{prefix}/include/NGImap4
%{prefix}/include/NGMail
%{prefix}/include/NGMime
%{prefix}/lib/libNGMime*.so

%files appserver
%defattr(-,root,root,-)
%{prefix}/lib/libNGObjWeb*.so.%{sope_libversion}*
%{prefix}/lib/libNGXmlRpc*.so.%{sope_libversion}*
%{prefix}/lib/libSoOFS*.so.%{sope_libversion}*
%{prefix}/lib/libWEExtensions*.so.%{sope_libversion}*
%{prefix}/lib/libWEPrototype*.so.%{sope_libversion}*
%{prefix}/lib/libWOExtensions*.so.%{sope_libversion}*
%{prefix}/lib/libWOXML*.so.%{sope_libversion}*
%{prefix}/share/sope-%{sope_libversion}/ngobjweb/DAVPropMap.plist
%{prefix}/share/sope-%{sope_libversion}/ngobjweb/Defaults.plist
%{prefix}/share/sope-%{sope_libversion}/ngobjweb/Languages.plist
%{prefix}/lib/sope-%{sope_libversion}/products/SoCore.sxp
%{prefix}/lib/sope-%{sope_libversion}/products/SoOFS.sxp
%{prefix}/lib/sope-%{sope_libversion}/wox-builders/WEExtensions.wox
%{prefix}/lib/sope-%{sope_libversion}/wox-builders/WEPrototype.wox
%{prefix}/lib/sope-%{sope_libversion}/wox-builders/WOExtensions.wox


%files appserver-tools
%defattr(-,root,root,-)
%{prefix}/sbin/sope-%{sope_major_version}.%{sope_minor_version}
%{prefix}/bin/xmlrpc_call

%files appserver-devel
%defattr(-,root,root,-)
%{prefix}/bin/wod
%{prefix}/include/NGHttp
%{prefix}/include/NGObjWeb
%{prefix}/include/NGXmlRpc
%{prefix}/include/SoOFS
%{prefix}/include/WEExtensions
%{prefix}/include/WOExtensions
%{prefix}/include/WOXML
%{prefix}/lib/libNGObjWeb*.so
%{prefix}/lib/libNGXmlRpc*.so
%{prefix}/lib/libSoOFS*.so
%{prefix}/lib/libWEExtensions*.so
%{prefix}/lib/libWEPrototype*.so
%{prefix}/lib/libWOExtensions*.so
%{prefix}/lib/libWOXML*.so
%{prefix}/OGo-GNUstep/Library/Makefiles/Additional/ngobjweb.make
%{prefix}/OGo-GNUstep/Library/Makefiles/woapp.make
%{prefix}/OGo-GNUstep/Library/Makefiles/wobundle.make

%files ldap
%defattr(-,root,root,-)
%{prefix}/lib/libNGLdap*.so.%{sope_libversion}*

%files ldap-tools
%defattr(-,root,root,-)
%{prefix}/bin/ldap2dsml
%{prefix}/bin/ldapchkpwd
%{prefix}/bin/ldapls

%files ldap-devel
%defattr(-,root,root,-)
%{prefix}/include/NGLdap
%{prefix}/lib/libNGLdap*.so

%files ical
%defattr(-,root,root,-)
%{prefix}/lib/libNGiCal*.so.%{sope_libversion}*
%{prefix}/share/sope-%{sope_libversion}/saxmappings/NGiCal.xmap
%{prefix}/lib/sope-%{sope_libversion}/saxdrivers/versitSaxDriver.sax

%files ical-devel
%defattr(-,root,root,-)
%{prefix}/include/NGiCal
%{prefix}/lib/libNGiCal*.so

%files gdl1
%defattr(-,root,root,-)
%{prefix}/bin/connect-EOAdaptor
%{prefix}/bin/load-EOAdaptor
%{prefix}/lib/libGDLAccess*.so.%{sope_libversion}*

%files gdl1-postgresql
%defattr(-,root,root,-)
%{prefix}/lib/sope-%{sope_libversion}/dbadaptors/PostgreSQL.gdladaptor

%files gdl1-mysql
%defattr(-,root,root,-)
%{prefix}/lib/sope-%{sope_libversion}/dbadaptors/MySQL.gdladaptor

#%files gdl1-sqlite3
#%defattr(-,root,root,-)
#%{prefix}/lib/sope-%{sope_libversion}/dbadaptors/SQLite3.gdladaptor

%files gdl1-tools
%defattr(-,root,root,-)
%{prefix}/bin/gcs_cat
%{prefix}/bin/gcs_gensql
%{prefix}/bin/gcs_ls
%{prefix}/bin/gcs_mkdir
%{prefix}/bin/gcs_recreatequick

%files gdl1-devel
%defattr(-,root,root,-)
%{prefix}/include/GDLAccess
%{prefix}/lib/libGDLAccess*.so

# ********************************* changelog *************************
%changelog
* Thu Sep 27 2007 Helge Hess <helge@opengroupware.org>
- removed GDLContentStore
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
