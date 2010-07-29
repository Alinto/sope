#!/bin/sh
#
# make-osxdmg.sh
#
# Create a MacOSX dmg (disk image) for a given directory.
#

DMG_NAME="$1"
BIN_DIR="$2"
VOLUME_NAME="$3"

REL_DMG="${DMG_NAME}.dmg"

ORG_DIR="$PWD"

EXTRA_SIZE=2048


# ****************************** usage ********************************

function usage() {
  cat <<_ACEOF
make-osxdmg.sh <dmgname> [dirname] [volumename]
_ACEOF
}


# ****************************** validate cmdline args ****************

function defaultArgs() {
  if test "x${BIN_DIR}" = "x"; then
    BIN_DIR="$PWD"
  fi
  if test "x${VOLUME_NAME}" = "x"; then
    VOLUME_NAME="$DMG_NAME"
  fi
}

function validateArgs() {
  if test "x$DMG_NAME" = "x"; then
    usage;
    exit 1
  fi
}


# ****************************** sizing *******************************

function calcSize() {
  SIZE_KB=`du -sk ${BIN_DIR} | awk '{print $1}'`
  SIZE_KB=`expr $SIZE_KB + ${EXTRA_SIZE}`
}


# ****************************** setup disk ***************************

function setupDisk() {
  DST_IMG="$1"
  
  if test -e "${DST_IMG}"; then
    echo -n "  deleting old dmg .."
    rm "${DST_IMG}"
    echo ".. ok."
  fi
  hdiutil create -size ${SIZE_KB}k ${DST_IMG} -layout NONE
  
  DISK=`hdid -nomount ${DST_IMG} | awk '{print $1}'`
  echo "  disk (no mount): $DISK"
  
  newfs_hfs -v "${VOLUME_NAME}" "${DISK}"
  ejectDisk;
  
  DISK=`hdid ${DST_IMG} | awk '{print $1}'`
  echo "  disk: $DISK"
}

function ejectDisk() {
  hdiutil eject "${DISK}"
}

function convertToReadOnlyCompressedImage() {
  SRC_DMG="$1"
  DST_DMG="$2"
  
  if test -e "${DST_DMG}"; then
    echo -n "  deleting old release dmg .."
    rm "${DST_DMG}"
    echo ".. ok."
  fi

  #echo -n "  converting ${SRC_DMG} to readonly/zip ${DST_DMG} .."
  
  # convert .dmg into read-only zlib (-9) compressed release version
  hdiutil convert -format UDZO "${SRC_DMG}" \
          -o ${DST_DMG} -imagekey zlib-level=9
  #echo ".. done."
}

function internetEnableDiskImage() {
  # internet-enable the release .dmg. for details see
  # http://developer.apple.com/ue/files/iedi.html
  hdiutil internet-enable -yes "$1"
}


# ****************************** running ******************************

defaultArgs;
validateArgs;

echo "Building MacOSX DMG ${DMG_NAME}.dmg for $BIN_DIR .."

calcSize;
echo "  size: ${SIZE_KB}K"
echo ""

setupDisk "${DMG_NAME}-build-$$.dmg"
echo ""

echo -n "  coping content to disk .."
cd $BIN_DIR
gnutar cf - . | ( cd "/Volumes/${VOLUME_NAME}" ; gnutar xf - )
cd $ORG_DIR
echo ".. done."
echo ""

# once again eject, to synchronize
ejectDisk;
echo ""

convertToReadOnlyCompressedImage "${DMG_NAME}-build-$$.dmg" "${REL_DMG}"
echo ""
internetEnableDiskImage "${REL_DMG}"
echo ""

# delete src image
echo -n "  deleting temporary build dmg .."
rm -f "${DMG_NAME}-build-$$.dmg"
echo ".. ok."

echo "built dmg:"
ls -la "${REL_DMG}"
