/* 
   NSSortDescriptor.h

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

#ifndef __NSSortDescriptor_H__
#define __NSSortDescriptor_H__

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>

@class NSString;

@interface NSSortDescriptor : NSObject < NSCoding, NSCopying >
{
  NSString *key;
  SEL      selector;
  struct {
      int isAscending:1;
      int reserved:31;
  } sdFlags;
}

- (id)initWithKey:(NSString *)_key ascending:(BOOL)_asc selector:(SEL)_sortsel;
- (id)initWithKey:(NSString *)_key ascending:(BOOL)_asc;

/* accessors */

- (NSString *)key;
- (SEL)selector;
- (BOOL)ascending;

/* operations */

- (id)reversedSortDescriptor;
- (NSComparisonResult)compareObject:(id)_obj1 toObject:(id)_obj2;

@end

@interface NSArray(NSSortDescriptorSort)

- (NSArray *)sortedArrayUsingDescriptors:(NSArray *)_descs;

@end

@interface NSMutableArray(NSSortDescriptorSort)

- (void)sortUsingDescriptors:(NSArray *)_descs;

@end

#endif /* __NSSortDescriptor_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
