#!/bin/sh

jsfile=$1
mfile=$2

if [ "x${jsfile}" = "x" ]; then
  echo "usage: $0 <jsfile> <mfile>"
  exit 1;
fi
if [ "x${mfile}" = "x" ]; then
  echo "usage: $0 <jsfile> <mfile>"
  exit 1;
fi

if [ ! -f $jsfile ]; then
  echo "$0: file '${jsfile}' can't be found !"
  exit 2;
fi

echo "transforming ${jsfile} to ${mfile} .."

IFS="
"
replaceto='\\"'

SEDCMD=sed
ECHOCMD=echo

BACKPAT="s|\\\\|\\\\\\\\|g"

$ECHOCMD >$mfile "/* automatically generated from ${jsfile}, do not edit ! */"
for i in `cat ${jsfile} | ${SEDCMD} "$BACKPAT" | ${SEDCMD} "s|\\"|$replaceto|g"`; do
  $ECHOCMD -n >>$mfile "@\""
  $ECHOCMD -n >>$mfile "${i}"
  $ECHOCMD >>$mfile "\\n\""
done
