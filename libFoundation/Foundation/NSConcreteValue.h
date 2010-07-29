/* 
   NSConcreteValue.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#ifndef __NSConcreteValue_h__
#define __NSConcreteValue_h__

#include <Foundation/NSValue.h>
#include <Foundation/NSGeometry.h>

@interface NSConcreteValue : NSValue

+ allocForType:(const char*)type zone:(NSZone*)zone;
- (id)initValue:(const void*)value withObjCType:(const char*)type;

@end

@interface NSConcreteObjCValue : NSConcreteValue
{
    char* objctype;
    char  data[0];
}
@end

@interface NSNonretainedObjectValue : NSConcreteValue
{
    id data;
}
@end

@interface NSPointerValue : NSConcreteValue
{
    void *data;
}
@end

@interface NSRectValue : NSConcreteValue
{
    NSRect data;
}
@end

@interface NSSizeValue : NSConcreteValue
{
    NSSize data;
}
@end

@interface NSPointValue : NSConcreteValue
{
    NSPoint data;
}
@end

#endif /* __NSConcreteValue_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
