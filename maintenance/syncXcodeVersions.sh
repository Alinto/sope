#!/bin/sh
# syncXcodeVersions

set_dylib_version() {
  # $1 project dir
  # $2 new version number

  PROJECT=$1/project.pbxproj
  DYLIB_VERSION=$2

  if [ "$DYLIB_VERSION" = "" ]; then
    echo "DYLIB_VERSION MUST NOT be empty!"
    exit 6
  fi

  # magic happens here
  sed "s/\(^[ 	]*DYLIB_CURRENT_VERSION =[ 	]*\)\(.*\)\(;.*$\)/\1\"${DYLIB_VERSION}\"\3/" "${PROJECT}" > "${PROJECT}.new"
  OK=`/usr/bin/plutil -lint ${PROJECT}.new | grep OK`
  if [ "${OK}" != "" ]; then
    mv ${PROJECT}.new ${PROJECT}
  else
    echo "ERROR: couldn't set version ($2) on $1!"
    exit 6
  fi
}

set_sope_versions() {
  # $1 project dir
  # $2 MAJOR    number
  # $3 MINOR    number
  # $4 SUBMINOR number

  PROJECT=$1/project.pbxproj
  SOPE_MAJOR=$2
  SOPE_MINOR=$3
  SOPE_SUBMINOR=$4

  # magic happens here
  sed -e "s/\(SOPE_MAJOR_VERSION=\)\([1234567890]*\)/\1${SOPE_MAJOR}/" -e "s/\(SOPE_MINOR_VERSION=\)\([1234567890]*\)/\1${SOPE_MINOR}/" -e "s/\(SOPE_SUBMINOR_VERSION=\)\([1234567890]*\)/\1${SOPE_SUBMINOR}/" -e "s/\(WEP_SUBMINOR_VERSION=\)\([1234567890]*\)/\1${SOPE_SUBMINOR}/" "${PROJECT}" > "${PROJECT}.new"
  mv ${PROJECT}.new ${PROJECT}
}


get_dylib_version () {
  # $1 project dir
  PROJECT=$1/project.pbxproj
  if [ ! -f ${PROJECT} ]; then
    echo ""
    return
  fi

  VERSION_NUM=$(sed -n 's/^[ 	]*DYLIB_CURRENT_VERSION =[ 	]*\(.*\);.*$/\1/p' "${PROJECT}" | sort | uniq)
  VERSION_NUM=${VERSION_NUM#\"}
  VERSION_NUM=${VERSION_NUM%\"}
  echo "${VERSION_NUM}"
}

get_make_version() {
  # traverse path from PROJECT_ROOT down to least found Version file
  # $1 project dir
  PROJECT=$1

  CURRENT_PATH=""
  # split path
  IFS=/
  for p in ${PROJECT}
  do
    CURRENT_PATH="${CURRENT_PATH}${p}/"
    read_version_from_version_file "${CURRENT_PATH}Version"
  done
  echo "\$(SOPE_MAJOR_VERSION).\$(SOPE_MINOR_VERSION).${SUBMINOR_VERSION}"
}

read_version_from_version_file() {
  VERS_FILE=$1
  if [ ! -r "${VERS_FILE}" ]; then
    return
  fi
  # this is always set
  SUBMINOR_VERSION=`sed -n 's/^SUBMINOR_VERSION.*=\(.*\)/\1/p' "${VERS_FILE}"|tail -1l`
  if [ "$SUBMINOR_VERSION" = "" ]; then
    SUBMINOR_VERSION=0
  fi
}


update_project_if_necessary() {
  # $1 project dir

  PROJECT=$1
  PROJECT_NAME=${PROJECT##*/}
  PROJECT_NAME=${PROJECT_NAME%%.xcode}
  
#  echo $PROJECT_NAME
  PROJECT_DYLIB_VERSION=`get_dylib_version "${PROJECT}"`
  if [ "${PROJECT_DYLIB_VERSION}" != "" -a "${PROJECT_DYLIB_VERSION#*SOPE_MAJOR_VERSION*}" != "${PROJECT_DYLIB_VERSION}" ]; then
    PROJECT_MAKE_VERSION=`get_make_version "${PROJECT}"`
    if [ "${PROJECT_DYLIB_VERSION}" != "${PROJECT_MAKE_VERSION}" ]; then
      echo "Updating $PROJECT_NAME: ${PROJECT_DYLIB_VERSION} -> ${PROJECT_MAKE_VERSION}"
      set_dylib_version "${PROJECT}" "${PROJECT_MAKE_VERSION}"
      PROJECT=$1
      SUBMINOR_VERSION=${PROJECT_MAKE_VERSION##*.}
      set_sope_versions "${PROJECT}" "${MAJOR_VERSION}" "${MINOR_VERSION}" "${SUBMINOR_VERSION}"
    fi
  fi
}


##
## MAIN
##

PROJECT_ROOT=.

PROJECTS=`find ${PROJECT_ROOT} -type d -name "*.xcodeproj"`
for PROJECT in $PROJECTS
do
  # skip Recycler contents
  if [ "${PROJECT##*Recycler*}" != "" ]; then
    update_project_if_necessary "${PROJECT}"
  fi
done
