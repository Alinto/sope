#!/bin/sh
#
# make-osxmpkg.sh
#
# Create a MacOSX Installer *multi* package for SOPE.
#

PKG_NAME="$1"

oldpwd="$PWD"
PKG_BUILD_DIR="$PWD/osxpkgbuild"
PKG_DIR="$PKG_BUILD_DIR/${PKG_NAME}.mpkg"
PKG_RSRC_DIR="$PKG_BUILD_DIR/${PKG_NAME}.mpkg/Contents/Resources"

# TODO: make that arguments
PKG_MAJOR_VERSION=4
PKG_MINOR_VERSION=5
PKG_SUBMINOR_VERSION=trunk

PKG_VERSION="${PKG_MAJOR_VERSION}.${PKG_MINOR_VERSION}.${PKG_SUBMINOR_VERSION}"
ROOT_DIR="$PKG_BUILD_DIR/Packages"

CHECK_XML="yes"
PLIST_DT_ID="-//Apple Computer//DTD PLIST 1.0//EN"
PLIST_DT_LOC="http://www.apple.com/DTDs/PropertyList-1.0.dtd"
INSTALLER_FORMAT_KEY="0.10000000149011612"

BACKGROUND_TIFF="maintenance/package-background.tiff"
LICENSE_FILE="maintenance/License.rtf"
WELCOME_FILE="maintenance/Welcome.rtf"

MKDIRS="mkdirhier"
CHMOD="chmod"
CHOWN="chown"
CHGRP="chgrp"
SUDO="sudo"
RM_R="rm -r"


# ****************************** options ******************************

# if we set this to 'yes', we get no 'upgrade' button on "reinstalls"
PKG_IS_RELOCATABLE=no

# RootAuthorization / AdminAuthorization
PKG_AUTHORIZATION=RootAuthorization


# ****************************** usage ********************************

function usage() {
  cat <<_ACEOF
make-osxmpkg.sh <pkgname>
_ACEOF
}


# ****************************** validate cmdline args ****************

function validateArgs() {
  if test "x$PKG_NAME" = "x"; then
    usage;
    exit 1
  fi
}


# ****************************** prepare/cleanup tmpfiles *************

function prepareTmpDirs() {
  if test -d $PKG_BUILD_DIR; then
    echo -n "  deleting old builddir: $PKG_BUILD_DIR .."
    ${SUDO} ${RM_R} $PKG_BUILD_DIR
    echo ".. done."
  fi

  echo -n "  preparing temporary builddir .."
  ${MKDIRS} "${PKG_BUILD_DIR}"
  ${MKDIRS} "${PKG_DIR}"
  ${MKDIRS} "${PKG_RSRC_DIR}"
  ${MKDIRS} "${PKG_RSRC_DIR}/English.lproj"
  ${MKDIRS} "${ROOT_DIR}"
  echo ".. done: $PKG_BUILD_DIR."
}

function fixUpPermissions() {
  echo -n "  fixing permissions in builddir (requires sudo) .."
  ${SUDO} ${CHOWN} -R root  "${ROOT_DIR}"
  ${SUDO} ${CHGRP} -R admin "${ROOT_DIR}"
  ${SUDO} ${CHMOD} -R 755   "${ROOT_DIR}"
  ${SUDO} ${CHMOD} u+t   "${ROOT_DIR}"
  ${SUDO} ${CHMOD} u+t   "${ROOT_DIR}/Library"
  echo ".. done."
}

function cleanupTmpDirs() {
  if test -d $PKG_BUILD_DIR; then
    echo -n "  deleting builddir: $PKG_BUILD_DIR .."
    rm -r $PKG_BUILD_DIR
    echo ".. done."
  fi
}


# ****************************** info files ***************************

function plistWriteString() {
  echo "    <key>$1</key>"
  echo "    <string>$2</string>"
}
function plistWriteInt() {
  echo "    <key>$1</key>"
  echo "    <integer>`echo $2`</integer>"
}
function plistWriteReal() {
  echo "    <key>$1</key>"
  echo "    <real>`echo $2`</real>"
}
function plistWriteDate() {
  echo "    <key>$1</key>"
  echo "    <date>$2</date>"
}
function plistWriteBool() {
  echo "    <key>$1</key>"
  echo "    <$2/>"
}

function genSubPkgEntry {
  echo "      <dict>"
  echo "        <key>IFPkgFlagPackageLocation</key>"
  echo "        <string>$1</string>"
  echo "        <key>IFPkgFlagPackageSelection</key>"
  echo "        <string>$2</string>"
  echo "      </dict>"
}

function genInfoPList() {
  # http://developer.apple.com/documentation/DeveloperTools/Conceptual/
  #   SoftwareDistribution/Concepts/sd_pkg_flags.html
  F="${PKG_DIR}/Contents/Info.plist"
  echo -n "  gen Info.plist: $F .."
  
  echo >$F  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo >>$F "<!DOCTYPE plist PUBLIC \"${PLIST_DT_ID}\" \"${PLIST_DT_LOC}\">"
  echo >>$F "<plist version=\"1.0\">"
  echo >>$F "  <dict>"

  plistWriteString >>$F IFMajorVersion ${PKG_MAJOR_VERSION}
  plistWriteString >>$F IFMinorVersion ${PKG_MINOR_VERSION}

  plistWriteDate   >>$F IFPkgBuildDate "`date -u +%Y-%m-%dT%H:%M:%SZ`"
  plistWriteString >>$F IFPkgBuildVersion                 "${PKG_VERSION}"
  #plistWriteBool   >>$F IFPkgFlagAllowBackRev             true

  # allowed: AdminAuthorization, RootAuthorization, ??
  plistWriteString >>$F IFPkgFlagAuthorizationAction      ${PKG_AUTHORIZATION}
  
  plistWriteString >>$F IFPkgFlagBackgroundAlignment      topright
  plistWriteString >>$F IFPkgFlagBackgroundScaling        none
  plistWriteString >>$F IFPkgFlagDefaultLocation          /
  #plistWriteBool   >>$F IFPkgFlagFollowLinks              true

  #plistWriteBool   >>$F IFPkgFlagInstallFat               true

  #plistWriteBool   >>$F IFPkgFlagIsRequired               false
  #plistWriteBool   >>$F IFPkgFlagOverwritePermissions     false

  if test "x${PKG_IS_RELOCATABLE}" = "xyes"; then
    plistWriteBool   >>$F IFPkgFlagRelocatable            true
  else
    plistWriteBool   >>$F IFPkgFlagRelocatable            false
  fi
  
  plistWriteString >>$F IFPkgFlagRestartAction            NoRestart
  plistWriteBool   >>$F IFPkgFlagRootVolumeOnly           false
  plistWriteBool   >>$F IFPkgFlagUpdateInstalledLanguages false
  #plistWriteBool   >>$F IFPkgFlagUseUserMask              false
  plistWriteReal   >>$F IFPkgFormatVersion "${INSTALLER_FORMAT_KEY}"
  
  plistWriteString >>$F IFPkgFlagComponentDirectory "../Packages"
  
  # generate sub-package list
  echo >>$F "    <key>IFPkgFlagPackageList</key>"
  echo >>$F "    <array>"
  for i in sope-xml sope-core sope-mime sope-appserver; do
    genSubPkgEntry >>$F $i.pkg required
  done
  for i in sope-ical sope-ldap sope-gdl1 sopex; do
    genSubPkgEntry >>$F $i.pkg selected
  done
  echo >>$F "    </array>"
  
  # close plist
  echo >>$F "  </dict>"
  echo >>$F "</plist>"
  if test "x$CHECK_XML" = "xyes"; then
    xmllint --noout $F
  fi
  
  echo ".. done."
}

function genVersionPList() {
  # http://developer.apple.com/documentation/DeveloperTools/Conceptual/
  #   SoftwareDistribution/Concepts/sd_pkg_flags.html
  F="${PKG_DIR}/Contents/version.plist"
  echo -n "  gen version.plist: $F .."
  
  echo >$F  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo >>$F "<!DOCTYPE plist PUBLIC \"${PLIST_DT_ID}\" \"${PLIST_DT_LOC}\">"
  echo >>$F "<plist version=\"1.0\">"
  echo >>$F "  <dict>"

  # TODO: find out about BuildVersion
  plistWriteString >>$F BuildVersion               4
  
  plistWriteString >>$F CFBundleShortVersionString "${PKG_VERSION}"
  plistWriteString >>$F ProjectName                "${PKG_NAME}"
  plistWriteString >>$F SourceVersion ${PKG_MAJOR_VERSION}${PKG_MINOR_VERSION}000
  
  # close plist
  echo >>$F "  </dict>"
  echo >>$F "</plist>"
  if test "x$CHECK_XML" = "xyes"; then
    xmllint --noout $F
  fi
  
  echo ".. done."
}

function genEnDescription() {
  F="${PKG_RSRC_DIR}/English.lproj/Description.plist"
  echo -n "  gen description plist: $F .."
  
  echo >$F  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo >>$F "<!DOCTYPE plist PUBLIC \"${PLIST_DT_ID}\" \"${PLIST_DT_LOC}\">"
  echo >>$F "<plist version=\"1.0\">"
  echo >>$F "  <dict>"
  
  plistWriteString >>$F IFPkgDescriptionDescription "${PKG_NAME}"
  plistWriteString >>$F IFPkgDescriptionTitle       "${PKG_NAME}"
  plistWriteString >>$F IFPkgDescriptionVersion     "${PKG_VERSION}"
  
  echo >>$F "  </dict>"
  echo >>$F "</plist>"
  if test "x$CHECK_XML" = "xyes"; then
    xmllint --noout $F
  fi
  echo ".. done."
}

function genInfoFile() {
  F="${PKG_RSRC_DIR}/English.lproj/${PKG_NAME}.info"
  echo -n "  gen info file: $F .."
  
  echo >$F  "Title                 ${PKG_NAME}"
  echo >>$F "Version               ${PKG_VERSION}"
  echo >>$F "Description           ${PKG_VERSION}"
  
  # TODO: find documentation for this one
  # echo >>$F "PackageLocation      ../Packages"
  echo >>$F "FastInstall          NO"
  
  echo >>$F "Require Reboot        NO"  # TODO: consolidate
  echo >>$F "OverwritePermissions  NO"  # TODO: consolidate
  echo >>$F "UseUserMask           NO"  # TODO: consolidate
  echo >>$F "RootVolumeOnly        NO"  # TODO: consolidate

  if test "x${PKG_AUTHORIZATION}" = "x"; then
    echo >>$F "NeedsAuthorization    NO"
  else
    # need to check Admin/Root?
    echo >>$F "NeedsAuthorization    YES"
  fi
  
  echo >>$F "DefaultLocation       /"   # TODO: consolidate
  
  if test "x${PKG_IS_RELOCATABLE}" = "xyes"; then
    echo >>$F "Relocatable           YES"
  else
    echo >>$F "Relocatable           NO"
  fi
  
  #echo >>$F "Install Fat           YES" # TODO: consolidate
  echo >>$F "LibrarySubdirectory   Standard"

  GIOLDDIR="$PWD"  
  cd "${PKG_RSRC_DIR}/English.lproj/"
  ln -s "${PKG_NAME}.info" Install.info
  cd "$GIOLDDIR"
  echo ".. done."
}


function genPkgInfoFile() {
  F="${PKG_DIR}/Contents/PkgInfo"
  echo -n "  gen PkgInfo: $F .."
  echo >$F "pmkrpkg1"
  echo ".. done."
}

function genPkgVersionFile() {
  F="${PKG_RSRC_DIR}/package_version"
  echo -n "  gen package_version: $F .."
  echo >$F  "major: ${PKG_MAJOR_VERSION}"
  echo >>$F "minor: ${PKG_MINOR_VERSION}"
  echo ".. done."
}

function genRequiredPkgs() {
  F="${PKG_RSRC_DIR}/Install.list"
  echo -n "  gen Install.list (requirements): $F .."
  echo >$F  "BSD.pkg:required"
  echo >>$F "BSDSDK.pkg:required"
  echo >>$F "DeveloperTools.pkg:required"
  echo ".. done."
}


# ****************************** resources ****************************

function copyBackgroundImage() {
  if test -f "${BACKGROUND_TIFF}"; then
    cp "${BACKGROUND_TIFF}" "${PKG_RSRC_DIR}/background.tiff"
  else
    echo "ERROR: did not find background image: ${BACKGROUND_TIFF}"
  fi
}

function copyLicenseFile() {
  if test -f "${LICENSE_FILE}"; then
    cp "${LICENSE_FILE}" "${PKG_RSRC_DIR}/English.lproj/License.rtf"
  else
    echo "ERROR: did not find file: ${LICENSE_FILE}"
  fi
}
function copyWelcomeFile() {
  if test -f "${WELCOME_FILE}"; then
    cp "${WELCOME_FILE}" "${PKG_RSRC_DIR}/English.lproj/Welcome.rtf"
  else
    echo "ERROR: did not find file: ${WELCOME_FILE}"
  fi
}


# ****************************** debugging ****************************

function debugShowResults() {
  echo ""
  echo "prepared contents:"
  find -s $PKG_BUILD_DIR \
  | sed "sX${PKG_BUILD_DIR}/X  Xg"
}


# ****************************** sudo *********************************

function ensureSudo() {
  # this will bring up the 'sudo' authentication
  if test "x$USER" != "xroot"; then
    echo "We need to run some commands using 'sudo', so please enter your "
    echo "credentials when being asked for them (unless you already did so)"
    sudo touch /tmp/osx-pkg-sudo-tmp
    sudo rm    /tmp/osx-pkg-sudo-tmp
  fi
}


# ****************************** sudo *********************************

function copyPackages() {
  for i in */*.pkg; do
    cp -R $i "${ROOT_DIR}"/
  done
}


# ****************************** running ******************************

echo "Building SOPE MacOSX Installer.app multipackage $PKG_NAME.mpkg .."
validateArgs;

ensureSudo;

prepareTmpDirs;
copyPackages;

genInfoPList;
genVersionPList;
genEnDescription;
genInfoFile;
genPkgInfoFile;
genRequiredPkgs;
genPkgVersionFile;

copyBackgroundImage;
copyLicenseFile;
copyWelcomeFile;


# debugging, print results
debugShowResults;


#cleanupTmpDirs;
