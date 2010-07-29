#!/bin/sh

FWPREFIX="/Library/Frameworks"

FW="
SaxObjC.framework
DOM.framework
XmlRpc.framework

EOControl.framework
EOCoreData.framework
NGExtensions.framework
NGStreams.framework

GDLAccess.framework

NGLdap.framework
NGMime.framework
NGMail.framework
NGImap4.framework
NGiCal.framework

NGObjWeb.framework
NGXmlRpc.framework
WEExtensions.framework
WOExtensions.framework
WOXML.framework
SoOFS.framework

sope-xml.framework
sope-core.framework
sope-mime.framework
sope-appserver.framework
sope-ical.framework
sope-ldap.framework
sope-gdl1.framework

SOPEX.framework
"

for i in $FW; do
  if test "x$i" != "x"; then
    if test -d "${FWPREFIX}/${i}"; then
      echo -n "deleting $i .."
      rm -rf "${FWPREFIX}/${i}"
      echo ".. done."
    else
      echo "not installed: ${i}"
    fi
  fi
done
