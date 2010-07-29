/* 
   NSCompoundPredicate.h

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

#ifndef __NSCompoundPredicate_H__
#define __NSCompoundPredicate_H__

#include <Foundation/NSPredicate.h>

@class NSArray;

typedef enum {
    NSNotPredicateType = 0,
    NSAndPredicateType,
    NSOrPredicateType
} NSCompoundPredicateType;

@interface NSCompoundPredicate : NSPredicate
{
    NSCompoundPredicateType type;
    NSArray *subs;
}

+ (NSPredicate *)andPredicateWithSubpredicates:(NSArray *)_subs;
+ (NSPredicate *)orPredicateWithSubpredicates:(NSArray *)_subs;
+ (NSPredicate *)notPredicateWithSubpredicates:(NSArray *)_subs;
- (id)initWithType:(NSCompoundPredicateType)_type subpredicates:(NSArray *)_s;

/* accessors */

- (NSCompoundPredicateType)compoundPredicateType;
- (NSArray *)subpredicates;

@end

#endif /* __NSCompoundPredicate_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
