/*
   UnixSignalHandler.h

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: November 1997

   Based on a similar class written by Mircea Oancea in July 1995.

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

#if LIB_FOUNDATION_LIBRARY

#include <Foundation/UnixSignalHandler.h>

#else

#ifndef __UnixSignalHandler_h__
#define __UnixSignalHandler_h__

#if defined(__MINGW32__)
#  include <signal.h>
#else
#  include <sys/types.h>
#  include <signal.h>
#endif
#import <Foundation/NSObject.h>

@class UnixSignalHandlerList;

@interface UnixSignalHandler : NSObject
{
  UnixSignalHandlerList *signalHandlers[NSIG];
  unsigned int          currentSigmask;
  BOOL                  signalsPending;
}

+ sharedHandler;

- (void)addObserver:(id)observer
  selector:(SEL)selector
  forSignal:(int)signalNumber
  immediatelyNotifyOnSignal:(BOOL)flag;
- (void)removeObserver:(id)observer;
- (void)removeObserver:(id)observer
  forSignal:(int)signalNumber;

/* Blocking or enabling signals */
- (void)blockAllSignals;
- (void)enableAllSignals;
- (void)blockSignal:(int)signum;
- (void)enableSignal:(int)signum;

- (void)waitForSignal:(int)signum;

- (BOOL)signalsPending;

@end


#endif /* __UnixSignalHandler_h__ */

#endif

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
