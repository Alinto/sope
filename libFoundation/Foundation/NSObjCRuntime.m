/* 
   NSObjCRuntime.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSUtilities.h>

#include <extensions/objc-runtime.h>

/*
 * Objective-C runtime info
 */

LF_DECLARE Class NSClassFromString(NSString *aClassName)
{
    unsigned len = [aClassName cStringLength];
    char  *buf;
    Class clazz;
    if (len == 0) return NULL;
    buf = malloc(len + 1);
    [aClassName getCString:buf]; buf[len] = '\0';
    clazz = objc_lookup_class(buf);
    free(buf);
    return clazz;
}

LF_DECLARE SEL NSSelectorFromString(NSString *aSelectorName)
{
    unsigned len = [aSelectorName cStringLength];
    char *buf;
    SEL  sel;
    if (len == 0) return NULL;
    buf = malloc(len + 1);
    [aSelectorName getCString:buf]; buf[len] = '\0';
    sel = sel_get_any_uid(buf);
    free(buf);
    return sel;
}

LF_DECLARE NSString *NSStringFromClass(Class aClass)
{
    return aClass ?
	[NSString stringWithCStringNoCopy:(char*)class_get_class_name(aClass)
	    freeWhenDone:NO] : nil;
}

LF_DECLARE NSString *NSStringFromSelector(SEL aSelector)
{
    if (aSelector) {
        return [NSString stringWithCStringNoCopy:(char*)sel_get_name(aSelector)
                         freeWhenDone:NO];
    }
    else {
        NSLog(@"WARNING: called %s with NULL-selector !", __PRETTY_FUNCTION__);
        return nil;
    }
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

