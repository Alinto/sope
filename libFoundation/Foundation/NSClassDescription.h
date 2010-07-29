/* 
   NSClassDescription.h

   Copyright (C) 2000, MDlink online service center GmbH, Helge Hess
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

#ifndef __NSClassDescription_h__
#define __NSClassDescription_h__

#include <Foundation/NSObject.h>

@class NSArray, NSString;

LF_EXPORT NSString *NSClassDescriptionNeededForClassNotification;

@interface NSClassDescription : NSObject

/* registry */

+ (NSClassDescription *)classDescriptionForClass:(Class)_class;
+ (void)registerClassDescription:(NSClassDescription *)_clazzDesc
  forClass:(Class)_class;
+ (void)invalidateClassDescriptionCache;

/* accessors */

- (NSArray *)attributeKeys;
- (NSArray *)toManyRelationshipKeys;
- (NSArray *)toOneRelationshipKeys;
- (NSString *)inverseForRelationshipKey:(NSString *)_key;

@end

@interface NSObject(ClassDescriptionForwards)

- (NSClassDescription *)classDescription;

- (NSArray *)attributeKeys;
- (NSArray *)toManyRelationshipKeys;
- (NSArray *)toOneRelationshipKeys;
- (NSString *)inverseForRelationshipKey:(NSString *)_key;

@end

#endif /* __NSClassDescription_h__ */
