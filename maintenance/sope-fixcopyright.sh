#!/bin/sh

BASEDIR=$1
INPAT="$2"

usage() {
    echo "usage: $0 <basedir> <input pattern>";
}

if test "x$BASEDIR" = "x"; then
  echo "error: missing basedir"
  usage;
  exit 1
fi
if test "x$INPAT" = "x"; then
  echo "error: missing input pattern"
  usage;
  exit 1
fi

DRYRUN="no"

SOPE_SIG="This file is part of SOPE."
SOPE_COPYRIGHT="Copyright (C) 2000-2005 SKYRIX Software AG"
SOPE_COPYRIGHT2="Copyright (C) 2002-2005 SKYRIX Software AG"
SOPE_COPYRIGHT4="Copyright (C) 2004-2005 SKYRIX Software AG"

echo "working on files `date +%Y-%m-%d/%H:%M` ..."

for FILE in `find $BASEDIR -type f -name "$INPAT" | grep -v ".o$" | grep -v ".so$" | grep -v "\.svn/" | grep -v ".sax/" | grep -v shared_debug_obj/`; do
    echo -n "  work on $FILE .."
    
    INPUTNAME="$FILE"
    DELFILES=""
    
    # OGo name
    
    grep "This file is part of O" $INPUTNAME >/dev/null
    if test $? = 0; then
	echo -n " PartOf .."
	OUT="${INPUTNAME}.partof"
	sed <$INPUTNAME >$OUT "s/This file is part of.*\$/${SOPE_SIG}/"
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi
    
    head -n 20 $INPUTNAME | grep " OGo" >/dev/null
    if test $? = 0; then
	echo -n " OGo .."
	OUT="${INPUTNAME}.ogo"
	head -n 20  $INPUTNAME | sed "s| OGo| SOPE|g" >$OUT
	tail -n +21 $INPUTNAME >>$OUT
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi

    # copyright
    
    PAT="Copyright.*2000-200[34].*SKYRIX.*\$"
    grep "$PAT" $INPUTNAME >/dev/null
    if test $? = 0; then
	echo -n " (c) .."
	OUT="${INPUTNAME}.copy"
	sed <$INPUTNAME >$OUT "s/${PAT}/${SOPE_COPYRIGHT}/"
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi

    PAT="Copyright.*2002-200[34].*SKYRIX.*\$"
    grep "$PAT" $INPUTNAME >/dev/null
    if test $? = 0; then
	echo -n " (c) .."
	OUT="${INPUTNAME}.copy2"
	sed <$INPUTNAME >$OUT "s/${PAT}/${SOPE_COPYRIGHT2}/"
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi

    PAT="Copyright.* 2004 .*SKYRIX.*\$"
    grep "$PAT" $INPUTNAME >/dev/null
    if test $? = 0; then
	echo -n " (c) .."
	OUT="${INPUTNAME}.copy3"
	sed <$INPUTNAME >$OUT "s/${PAT}/${SOPE_COPYRIGHT4}/"
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi

    # $Id$
    
    PAT="^// .Id.*"
    grep "$PAT" $INPUTNAME >/dev/null
    if test $? = 0; then
	echo -n " Id .."
	OUT="${INPUTNAME}.id"
	grep -v "$PAT" <$INPUTNAME >$OUT
	INPUTNAME="$OUT"
	DELFILES="$DELFILES $OUT"
    fi

    # finish up
    
    if test "$FILE" = "$INPUTNAME"; then
	echo ".. no changes."
    else
	echo ".. done: `basename $INPUTNAME`."
	if test "x$DRYRUN" != "xyes"; then
	    cp $INPUTNAME $FILE
	fi
	for DELFILE in $DELFILES; do rm $DELFILE; done
    fi
done

echo "done: `date +%Y-%m-%d/%H:%M`."
