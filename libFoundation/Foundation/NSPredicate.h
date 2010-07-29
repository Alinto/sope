/* 
   NSPredicate.h

   Copyright (C) 2005, Helge Hess
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

#ifndef __NSPredicate_H__
#define __NSPredicate_H__

#include <Foundation/NSObject.h>

@interface NSPredicate : NSObject < NSCoding, NSCopying >
{
}

/* evaluation */

- (BOOL)evaluateWithObject:(id)_object;

@end

@interface NSPredicate(Parsing)
+ (NSPredicate *)predicateWithFormat:(NSString *)_format,...;
+ (NSPredicate *)predicateWithFormat:(NSString *)_format 
  argumentArray:(NSArray *)_arguments;
@end

#include <Foundation/NSArray.h>

@interface NSArray(NSPredicate)
- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)_predicate;
@end

@interface NSMutableArray(NSPredicate)
- (void)filterArrayUsingPredicate:(NSPredicate *)_predicate;
@end

#endif /* __NSPredicate_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
