/* 
   NSHost.h

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Aleksandr Savostyanov <sav@conextions.com>

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

#ifndef __NSHost_h__
#define __NSHost_h__

#include <Foundation/NSObject.h>

@class NSString, NSArray, NSMutableArray;

@interface NSHost : NSObject 
{
    NSMutableArray *names;
    NSMutableArray *addresses;
}

+ (NSHost *)currentHost;
+ (NSHost *)hostWithName:(NSString *)name;
+ (NSHost *)hostWithAddress:(NSString *)address;

+ (void)setHostCacheEnabled:(BOOL)flag;
+ (BOOL)isHostCacheEnabled;
+ (void)flushHostCache;

- (BOOL)isEqualToHost:(NSHost *)aHost;

- (NSString *)name;
- (NSArray *)names;

- (NSString *)address;
- (NSArray *)addresses;

@end

#endif /* __NSHost_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
