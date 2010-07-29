#!/bin/sh

pgname="$1"
actname=`echo "$pgname"|sed "s|Page|Action|g"`

mfile="$pgname.m"
woxfile="$pgname.wox"

echo "#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>

@interface $pgname : WOComponent
{
}

@end

@interface $actname : WODirectAction
@end

#include \"common.h\"

@implementation $pgname

- (void)dealloc {
  [super dealloc];
}

/* accessors */

/* actions */

@end /* $pgname */

@implementation $actname
@end /* $actname */
" >$mfile

echo "<?xml version='1.0' standalone='yes'?>

<var:component className='iCalPortalFrame' title='localizedTitle'
               xmlns='http://www.w3.org/1999/xhtml'
               xmlns:var='http://www.skyrix.com/od/binding'
               xmlns:const='http://www.skyrix.com/od/constant'>

  Page: $pgname

</var:component>
" >$woxfile
