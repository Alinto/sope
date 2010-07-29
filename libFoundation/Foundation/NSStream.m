/* 
   NSStream.m

   Copyright (C) 2003 SKYRIX Software AG, Helge Hess.
   All rights reserved.
   
   Author: Helge Hess <helge.hess@opengroupware.org>
   
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

#include <Foundation/NSStream.h>
#include <common.h>

@implementation NSStream

+ (void)getStreamsToHost:(NSHost *)_host port:(int)_port 
  inputStream:(NSInputStream **)_in
  outputStream:(NSOutputStream **)_out
{
    // TODO
    if (_in) *_in = nil;
    if (_in) *_in = nil;
    [self notImplemented:_cmd];
}

/* accessors */

- (void)setDelegate:(id)_delegate
{
    [self subclassResponsibility:_cmd];
}
- (id)delegate
{
    return nil;
}

- (NSError *)streamError
{
    return nil;
}
- (NSStreamStatus)streamStatus
{
    return NSStreamStatusError;
}

/* properties */

- (BOOL)setProperty:(id)_value forKey:(NSString *)_key
{
    return NO;
}
- (id)propertyForKey:(NSString *)_key
{
    return nil;
}

/* operations */

- (void)open
{
}
- (void)close
{
}

/* runloop */

- (void)scheduleInRunLoop:(NSRunLoop *)_runloop forMode:(NSString *)_mode 
{
    [self subclassResponsibility:_cmd];
}
- (void)removeFromRunLoop:(NSRunLoop *)_runloop forMode:(NSString *)_mode 
{
    [self subclassResponsibility:_cmd];
}

@end /* NSStream */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
