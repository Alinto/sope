/* 
   NSObjectInvocation.h

   Copyright (C) 1999 Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#ifndef __Foundation_NSObjectInvocation_H__
#define __Foundation_NSObjectInvocation_H__

#include <Foundation/NSInvocation.h>

@interface NSObjectInvocation : NSInvocation
{
@private
    BOOL isVoid;
    char argumentCount;
    id   returnValue;
    id   arguments[1];
}

+ (id)allocForArgumentCount:(int)_count zone:(NSZone *)_zone;

- (void)invokeWithTarget:(id)_target lookupAtClass:(Class)_class;
- (void)superInvokeWithTarget:(id)_target;

@end

#endif /* __Foundation_NSObjectInvocation_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
