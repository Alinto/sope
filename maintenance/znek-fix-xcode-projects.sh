#!/bin/sh
# znek's fixes for Xcode projects

TMPFILE=/tmp/znek-fix-xcode-projects_$$

fixProject()
{
  # $1 - xcode project

  PROJ=$1

# 1. Replace /Local/BuildArea (my build area) with /Library/Frameworks
  cat ${PROJ} | sed -e 's;/Local/BuildArea;/Library/Frameworks;g' > ${TMPFILE}
  mv ${TMPFILE} ${TMPFILE}_1

# 2. build filter for frameworks
   FILTER=""
   for f in SaxObjC DOM XmlRpc EOControl EOCoreData NGExtensions NGHttp NGObjWeb NGStreams NGXmlRpc SoObjects WebDAV SoOFS NGImap4 NGMail NGMime SOPEX WEExtensions WOExtensions WOXML GDLAccess NGLdap NGiCal
   do
     FILTER="${FILTER} -e s;/Library/Frameworks/${f}.framework;\"\$(USER_LIBRARY_DIR)/EmbeddedFrameworks/Wrapper/${f}.framework\";g"
   done
  cat ${TMPFILE}_1 | sed ${FILTER} > ${TMPFILE}
  rm -f ${TMPFILE}_1
  diff -q ${TMPFILE} ${PROJ} > /dev/null 2>&1
  if [ ! $? -eq 0 ]; then
    cp ${TMPFILE} ${PROJ}
    echo "${PROJ} fixed"
  fi
  rm -f ${TMPFILE}
}

PROJECTS=`find . -name "*.pbxproj"`
for p in ${PROJECTS}
do
  fixProject "$p"
done