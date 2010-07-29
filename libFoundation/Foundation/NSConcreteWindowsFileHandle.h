/*
   NSConcreteFileHandle.h

   Copyright (C) 2000 Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>
   Date: Feb 2000
   
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
#ifndef __NSConcreteWindowsFileHandle_h__
#define __NSConcreteWindowsFileHandle_h__

#include <Foundation/NSFileHandle.h>
#include <config.h>

#ifdef HAVE_WINDOWS_H
#  include <windows.h>
#endif

@interface NSConcreteWindowsFileHandle : NSFileHandle
{
    HANDLE handle;
    BOOL   closeOnDealloc;
}

@end

#endif /* __NSConcreteWindowsFileHandle_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
