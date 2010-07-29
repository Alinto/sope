/* 
   Foundation.h

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

#ifndef __Foundation_h__
#define __Foundation_h__

// ANSI C headers

#include <math.h>
#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <float.h>
#include <limits.h>
#include <locale.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// OpenStep Foundation headers

#include <Foundation/NSAccount.h>
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSClassDescription.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDateFormatter.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSFormatter.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSKeyValueCoding.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSNumberFormatter.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSSerialization.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSUndoManager.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSZone.h>

#define HAVE_NSNull             1
#define HAVE_NSClassDescription 1
#define HAVE_NSKeyValueCoding   1

#endif /* __Foundation_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
