%define apache_modules_dir %{_usr}/lib/apache/modules
%define apache_conf_dir    %{_sysconfdir}/apache/conf/conf.d
%define apache_initscript  %{_sysconfdir}/init.d/apache
%define ngobjweb_requires  apache

Summary:      mod_ngobjweb apache module
Name:         mod_ngobjweb
Version:      %{mod_ngobjweb_version}
Release:      %{mod_ngobjweb_release}.%{mod_ngobjweb_buildcount}%{dist_suffix}
Vendor:       OpenGroupware.org
Packager:     Frank Reppin <frank@opengroupware.org>  
License:      LGPL
URL:          http://sope.opengroupware.org/
Group:        Development/Libraries
AutoReqProv:  off
Requires:     %{ngobjweb_requires}
Source:       %{mod_ngobjweb_source}
Prefix:       %{mod_ngobjweb_prefix}
BuildRoot:    %{_tmppath}/%{name}-%{version}-%{release}-root

%description
Enables apache to handle HTTP requests for the
OpenGroupware.org application server.

%prep
rm -fr ${RPM_BUILD_ROOT}
%setup -q -n sope-mod_ngobjweb

# ****************************** build ********************************
%build
export PATH=$PATH:/usr/sbin
make %{mod_ngobjweb_makeflags} APXS_INCLUDE_DIRS="-I/usr/include/apache"

# ****************************** install ******************************
%install
export PATH=$PATH:/usr/sbin
mkdir -p ${RPM_BUILD_ROOT}%{apache_modules_dir}
cp mod_ngobjweb.so ${RPM_BUILD_ROOT}%{apache_modules_dir}/

mkdir -p ${RPM_BUILD_ROOT}%{apache_conf_dir}
echo "#Here we load the 'mod_ngobjweb.so' module
#
LoadModule ngobjweb_module %{apache_modules_dir}/mod_ngobjweb.so
" > ${RPM_BUILD_ROOT}%{apache_conf_dir}/ngobjweb.conf

# touch ghosts
touch ${RPM_BUILD_ROOT}%{apache_conf_dir}/ogo-webui.conf
touch ${RPM_BUILD_ROOT}%{apache_conf_dir}/ogo-xmlrpcd.conf
touch ${RPM_BUILD_ROOT}%{apache_conf_dir}/ogo-zidestore.conf

# ****************************** post *********************************
%preun
if [ $1 = 0 ]; then
  if [ -f %{apache_conf_dir}/ogo-webui.conf ]; then
    rm -f %{apache_conf_dir}/ogo-webui.conf
  fi
  if [ -f %{apache_conf_dir}/ogo-xmlrpcd.conf ]; then
    rm -f %{apache_conf_dir}/ogo-xmlrpcd.conf
  fi
  if [ -f %{apache_conf_dir}/ogo-zidestore.conf ]; then
    rm -f %{apache_conf_dir}/ogo-zidestore.conf
  fi
  %{apache_initscript} restart >/dev/null 2>&1
fi

# ****************************** trigger ******************************
%triggerin -- ogo-webui-app
if [ $2 = 1 ]; then
echo "# configuration needed to access the OGo webui
#
# explicitly allow access
<DirectoryMatch %{prefix}/share/opengroupware.org-([0-9a-zA-Z]{1}).([0-9a-zA-Z]{1,})/www> 
  Order allow,deny 
  Allow from all 
</DirectoryMatch>
# required aliases
AliasMatch ^/OpenGroupware([0-9a-zA-Z]{1})([0-9a-zA-Z]{1,})\.woa/WebServerResources/(.*) \
           %{prefix}/share/opengroupware.org-\$1.\$2/www/\$3
Alias /ArticleImages %{_var}/lib/opengroupware.org/news
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/OpenGroupware*">
    SetAppPort 20000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-webui.conf

%{apache_initscript} restart >/dev/null 2>&1
fi

%triggerin -- ogo-xmlrpcd
if [ $2 = 1 ]; then
echo "# configuration needed to access the OGo XMLRPCd via http
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/RPC2*">
    SetAppPort 22000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-xmlrpcd.conf

%{apache_initscript} restart >/dev/null 2>&1
fi

%{apache_initscript} restart >/dev/null 2>&1

%triggerin -- ogo-zidestore
if [ $2 = 1 ]; then
echo "# configuration needed to access the OGo ZideStore via http
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/zidestore/*">
    SetAppPort 21000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-zidestore.conf

%{apache_initscript} restart >/dev/null 2>&1
fi

%triggerin -- ogoall
if [ $2 = 1 ]; then
echo "# configuration needed to access the OGo webui
#
# explicitly allow access
<DirectoryMatch %{prefix}/share/opengroupware.org-([0-9a-zA-Z]{1}).([0-9a-zA-Z]{1,})/www> 
  Order allow,deny 
  Allow from all 
</DirectoryMatch>
# required aliases
AliasMatch ^/OpenGroupware([0-9a-zA-Z]{1})([0-9a-zA-Z]{1,})\.woa/WebServerResources/(.*) \
           %{prefix}/share/opengroupware.org-\$1.\$2/www/\$3
Alias /ArticleImages %{_var}/lib/opengroupware.org/news
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/OpenGroupware*">
    SetAppPort 20000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-webui.conf
echo "# configuration needed to access the OGo XMLRPCd via http
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/RPC2*">
    SetAppPort 22000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-xmlrpcd.conf
echo "# configuration needed to access the OGo ZideStore via http
#
# hook up
<IfModule ngobjweb_module.c>
  <LocationMatch "^/zidestore/*">
    SetAppPort 21000
    SetHandler ngobjweb-adaptor
  </LocationMatch>
</IfModule>
" >%{apache_conf_dir}/ogo-zidestore.conf

%{apache_initscript} restart >/dev/null 2>&1
fi

%triggerun -- ogoall
if [ $2 = 0 ]; then
  if [ -f %{apache_conf_dir}/ogo-webui.conf ]; then
    rm -f %{apache_conf_dir}/ogo-webui.conf
  fi
  if [ -f %{apache_conf_dir}/ogo-xmlrpcd.conf ]; then
    rm -f %{apache_conf_dir}/ogo-xmlrpcd.conf
  fi
  if [ -f %{apache_conf_dir}/ogo-zidestore.conf ]; then
    rm -f %{apache_conf_dir}/ogo-zidestore.conf
  fi
  %{apache_initscript} restart >/dev/null 2>&1
fi

%triggerun -- ogo-webui-app
if [ $2 = 0 ]; then
  if [ -f %{apache_conf_dir}/ogo-webui.conf ]; then
    rm -f %{apache_conf_dir}/ogo-webui.conf
  fi
  %{apache_initscript} restart >/dev/null 2>&1
fi

%triggerun -- ogo-xmlrpcd
if [ $2 = 0 ]; then
  if [ -f %{apache_conf_dir}/ogo-xmlrpcd.conf ]; then
    rm -f %{apache_conf_dir}/ogo-xmlrpcd.conf
  fi
  %{apache_initscript} restart >/dev/null 2>&1
fi

%triggerun -- ogo-zidestore
if [ $2 = 0 ]; then
  if [ -f %{apache_conf_dir}/ogo-zidestore.conf ]; then
    rm -f %{apache_conf_dir}/ogo-zidestore.conf
  fi
  %{apache_initscript} restart >/dev/null 2>&1
fi

# ****************************** clean ********************************
%clean
rm -fr ${RPM_BUILD_ROOT}

# ****************************** files ********************************
%files
%defattr(-,root,root,-)
%{apache_modules_dir}/mod_ngobjweb.so
%config %{apache_conf_dir}/ngobjweb.conf
%ghost %{apache_conf_dir}/ogo-webui.conf
%ghost %{apache_conf_dir}/ogo-xmlrpcd.conf
%ghost %{apache_conf_dir}/ogo-zidestore.conf

# ********************************* changelog *************************
%changelog
* Fri Jul 08 2005 Frank Reppin <frank@opengroupware.org>
- updated ogo-webui.conf to 1.1
* Tue Mar 01 2005 Frank Reppin <frank@opengroupware.org>
- drop dependency on ogo-environment
- allow triggers on ogoall package
* Sat Feb 19 2005 Frank Reppin <frank@opengroupware.org>
- replaced common vars with 2 new macros (will make editing safer)
- revisited last commit regarding OGo Bug #1254 and decided
  to use triggers instead (and thus nothing moved into the application RPMS)
- application specific config files get installed/removed based on whether
  the application itself is installed/removed and/or mod_ngobjweb itself gets
  removed or installed
* Fri Feb 18 2005 Frank Reppin <frank@opengroupware.org>
- moved parts to the application RPMS
* Wed Jan 12 2005 Frank Reppin <frank@opengroupware.org>
- initial build
