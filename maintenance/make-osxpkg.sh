#!/bin/sh
#
# make-osxpkg.sh
#
# Create a MacOSX Installer package for a given GNUstep directory. It does so
# by installing the results in a certain directory and then running the
# necessary packaging commands.
#

PKG_NAME="$1"

oldpwd="$PWD"
PKG_BUILD_DIR="$PWD/osxpkgbuild"
PKG_DIR="$PKG_BUILD_DIR/${PKG_NAME}.pkg"
PKG_RSRC_DIR="$PKG_BUILD_DIR/${PKG_NAME}.pkg/Contents/Resources"

# TODO: make that arguments
PKG_MAJOR_VERSION=4
PKG_MINOR_VERSION=5
PKG_SUBMINOR_VERSION=trunk

PKG_VERSION="${PKG_MAJOR_VERSION}.${PKG_MINOR_VERSION}.${PKG_SUBMINOR_VERSION}"
ROOT_DIR="$PKG_BUILD_DIR/root"

CHECK_XML="yes"
PLIST_DT_ID="-//Apple Computer//DTD PLIST 1.0//EN"
PLIST_DT_LOC="http://www.apple.com/DTDs/PropertyList-1.0.dtd"
INSTALLER_FORMAT_KEY="0.10000000149011612"

BACKGROUND_TIFF="../maintenance/package-background.tiff"
LICENSE_FILE="../maintenance/License.rtf"
WELCOME_FILE="../maintenance/Welcome.rtf"

MKDIRS="mkdirhier"
CHMOD="chmod"
CHOWN="chown"
CHGRP="chgrp"
SUDO="sudo"
RM_R="rm -r"


# ****************************** options ******************************

# if we set this to 'yes', we get no 'upgrade' button on "reinstalls"
PKG_IS_RELOCATABLE=no

PKG_INSTALLFAT=yes

# RootAuthorization / AdminAuthorization
PKG_AUTHORIZATION=RootAuthorization


# ****************************** usage ********************************

function usage() {
  cat <<_ACEOF
make-osxpkg.sh <pkgname>
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
  ${MKDIRS} "${ROOT_DIR}/Library/Frameworks"
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


# ****************************** install ******************************

function installIntoTmpDirs() {
  echo -n "  install sources (log in ${PKG_BUILD_DIR}/install.log) .."
  make -s FRAMEWORK_INSTALL_DIR="${ROOT_DIR}/Library/Frameworks" \
    shared=yes frameworks=yes install \
    >${PKG_BUILD_DIR}/install.log 2>&1
  echo ".. done."
}


# ****************************** pax archive **************************

function makePaxArchive() {
  echo -n "  gen archive .."
  cd "${ROOT_DIR}"
  pax -w . | gzip -c >${PKG_DIR}/Contents/Archive.pax.gz

  cd ${PKG_DIR}/Contents/Resources
  ln -s ../Archive.pax.gz "${PKG_NAME}.pax.gz"
  cd "$oldpwd"
  echo ".. done: ${PKG_DIR}/Contents/Archive.pax.gz"
}


# ****************************** bom/sizes ****************************

function generateBoM() {
  echo -n "  gen BoM file .."
  cd "${ROOT_DIR}"
  mkbom . "${PKG_DIR}/Contents/Archive.bom"
  
  cd ${PKG_DIR}/Contents/Resources
  ln -s ../Archive.bom "${PKG_NAME}.bom"
  cd "$oldpwd"
  echo ".. done."
}

function calcSizes() {
  echo -n "  calculate sizes .."
  size_uncompressed="`du -sk $ROOT_DIR | cut -f 1`"
  size_compressed="`du -sk $PKG_DIR | cut -f 1`"
  numfiles="`find $ROOT_DIR | wc -l`"
  numfiles="`echo $numfiles - 1 | bc`"
  echo ".. done (size=${size_compressed}K/${size_uncompressed}K, #$numfiles)."
}

function generateSizes() {
  echo -n "  gen sizes file .."
  cd "${ROOT_DIR}"
  echo "NumFiles       $numfiles"          >${PKG_DIR}/Contents/Archive.sizes
  echo "InstalledSize  $size_uncompressed" >>${PKG_DIR}/Contents/Archive.sizes
  echo "CompressedSize $size_compressed"   >>${PKG_DIR}/Contents/Archive.sizes
  
  cd ${PKG_DIR}/Contents/Resources
  ln -s ../Archive.sizes "${PKG_NAME}.sizes"
  cd "$oldpwd"
  echo ".. done."
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


function genInfoPList() {
  # http://developer.apple.com/documentation/DeveloperTools/Conceptual/
  #   SoftwareDistribution/Concepts/sd_pkg_flags.html
  F="${PKG_DIR}/Contents/Info.plist"
  echo -n "  gen Info.plist: $F .."
  
  echo >$F  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo >>$F "<!DOCTYPE plist PUBLIC \"${PLIST_DT_ID}\" \"${PLIST_DT_LOC}\">"
  echo >>$F "<plist version=\"1.0\">"
  echo >>$F "  <dict>"
  
  plistWriteString >>$F CFBundleGetInfoString "${PKG_NAME} ${PKG_VERSION}"
  plistWriteString >>$F CFBundleIdentifier "org.opengroupware.pkg.${PKG_NAME}"
  plistWriteString >>$F CFBundleName       "${PKG_NAME}"
  plistWriteString >>$F CFBundleShortVersionString "${PKG_VERSION}"
  
  plistWriteString >>$F IFMajorVersion ${PKG_MAJOR_VERSION}
  plistWriteString >>$F IFMinorVersion ${PKG_MINOR_VERSION}
  
  plistWriteDate   >>$F IFPkgBuildDate "`date -u +%Y-%m-%dT%H:%M:%SZ`"
  plistWriteString >>$F IFPkgBuildVersion                 "${PKG_VERSION}"
  plistWriteBool   >>$F IFPkgFlagAllowBackRev             true

  # allowed: AdminAuthorization, RootAuthorization, ??
  plistWriteString >>$F IFPkgFlagAuthorizationAction      ${PKG_AUTHORIZATION}

  plistWriteString >>$F IFPkgFlagBackgroundAlignment      topright
  plistWriteString >>$F IFPkgFlagBackgroundScaling        none
  plistWriteString >>$F IFPkgFlagDefaultLocation          /
  plistWriteBool   >>$F IFPkgFlagFollowLinks              true
  
  if test "x${PKG_INSTALLFAT}" = "xyes"; then
    plistWriteBool   >>$F IFPkgFlagInstallFat             true
  else
    plistWriteBool   >>$F IFPkgFlagInstallFat             false
  fi

  plistWriteInt    >>$F IFPkgFlagInstalledSize            $size_uncompressed
  plistWriteBool   >>$F IFPkgFlagIsRequired               false
  plistWriteBool   >>$F IFPkgFlagOverwritePermissions     false

  if test "x${PKG_IS_RELOCATABLE}" = "xyes"; then
    plistWriteBool   >>$F IFPkgFlagRelocatable            true
  else
    plistWriteBool   >>$F IFPkgFlagRelocatable            false
  fi

  plistWriteString >>$F IFPkgFlagRestartAction            NoRestart
  plistWriteBool   >>$F IFPkgFlagRootVolumeOnly           false
  plistWriteBool   >>$F IFPkgFlagUpdateInstalledLanguages false
  plistWriteBool   >>$F IFPkgFlagUseUserMask              false
  plistWriteReal   >>$F IFPkgFormatVersion "${INSTALLER_FORMAT_KEY}"
  plistWriteInt    >>$F IFPkgPayloadFileCount             $numfiles
  
  echo >>$F "  </dict>"
  echo >>$F "</plist>"
  if test "x$CHECK_XML" = "xyes"; then
    xmllint --noout $F
  fi
  
  echo ".. done."
}


function genBundleVersions() {
  F="${PKG_RSRC_DIR}/BundleVersions.plist"
  echo "  gen bundle versions: $F .."
  
  echo >$F  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo >>$F "<!DOCTYPE plist PUBLIC \"${PLIST_DT_ID}\" \"${PLIST_DT_LOC}\">"
  echo >>$F "<plist version=\"1.0\">"
  echo >>$F "  <dict>"
  

  frameworks=`find "${ROOT_DIR}" -type d -name "*.framework"`
  for frameworkpath in $frameworks; do
    frameworkvfile="`find $frameworkpath -type f -name Version | head -n 1`"
    if test "x$frameworkvfile" != "x"; then
      relfwpath="`echo $frameworkpath | sed sX${ROOT_DIR}/XXg`"
      
      echo >>$F "    <key>${relfwpath}</key>"
      echo >>$F "    <dict>"
      echo >>$F "      <key>BuildVersion</key>"
      echo >>$F "      <string>1</string>" # TODO
      echo >>$F "      <key>CFBundleShortVersionString</key>"
      echo >>$F "      <string>${PKG_VERSION}</string>"
      echo >>$F "      <key>ProjectName</key>"
      echo >>$F "      <string>`basename -s .framework $relfwpath`</string>"
      echo >>$F "      <key>SourceVersion</key>"
      echo >>$F "      <string>${PKG_VERSION}</string>" # TODO
      echo >>$F "    </dict>"
    else
      echo "    Note: no Version file in framework `basename $frameworkpath`"
    fi
  done
  
  echo >>$F "  </dict>"
  echo >>$F "</plist>"
  if test "x$CHECK_XML" = "xyes"; then
    xmllint --noout $F
  fi
  echo "  generated: $F."
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
  
  if test "x${PKG_INSTALLFAT}" = "xyes"; then
    echo >>$F "Install Fat           YES"
  else
    echo >>$F "Install Fat           NO"
  fi
  
  echo >>$F "LibrarySubdirectory   Standard"
  
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


# ****************************** running ******************************

echo "Building MacOSX Installer.app package $PKG_NAME.pkg .."
validateArgs;

ensureSudo;

prepareTmpDirs;
installIntoTmpDirs;
fixUpPermissions;

makePaxArchive;
generateBoM;

calcSizes;
generateSizes;

genInfoPList;
genInfoFile;
genBundleVersions;
genEnDescription;
genPkgInfoFile;
genPkgVersionFile;

copyBackgroundImage;
copyLicenseFile;
copyWelcomeFile;


# debugging, print results
#debugShowResults;


# move results
if test -d "$PKG_DIR"; then
  if test -d "${oldpwd}/${PKG_NAME}.pkg"; then
    rm -rf "${oldpwd}/${PKG_NAME}.pkg"
  fi
  mv "$PKG_DIR" "${oldpwd}/${PKG_NAME}.pkg"
else
  echo "ERROR: did not find package: $PKG_DIR"
fi

#cleanupTmpDirs;
