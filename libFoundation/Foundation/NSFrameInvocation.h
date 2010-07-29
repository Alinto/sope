/* 
   NSFrameInvocation.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>

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

#ifndef __Foundation_NSFrameInvocation_H__
#define __Foundation_NSFrameInvocation_H__

#include <Foundation/NSInvocation.h>

@interface NSFrameInvocation : NSInvocation
{
@private
    arglist_t frame;
    void      *returnValue;
    retval_t  returnFrame;
    BOOL      ownsFrame;
    BOOL      ownsReturnValue;
}

- (void)invokeWithTarget:(id)_target lookupAtClass:(Class)_class;
- (void)superInvokeWithTarget:(id)_target;

@end

#endif /* __Foundation_NSFrameInvocation_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
