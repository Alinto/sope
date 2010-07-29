/* 
   NSClassDescription.m

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

#include <Foundation/NSClassDescription.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSString.h>
#include <common.h>

LF_DECLARE NSString *NSClassDescriptionNeededForClassNotification =
  @"NSClassDescriptionNeededForClass";

@implementation NSClassDescription

static NSMapTable *classToDesc  = NULL; // THREAD

+ (void)initialize
{
  if (classToDesc == NULL) {
    classToDesc = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                   NSObjectMapValueCallBacks,
                                   32);
  }
}

/* registry */

+ (NSClassDescription *)classDescriptionForClass:(Class)_class
{
  NSClassDescription *d;
  
  if ((d = NSMapGet(classToDesc, _class)))
    return d;

  [[NSNotificationCenter defaultCenter]
                         postNotificationName:
                           NSClassDescriptionNeededForClassNotification
                         object:_class];
  
  return NSMapGet(classToDesc, _class);
}

+ (void)registerClassDescription:(NSClassDescription *)_clazzDesc
  forClass:(Class)_class
{
  if (_clazzDesc == nil)
    return;

  if (_class)
    NSMapInsert(classToDesc,  _class, _clazzDesc);
}

+ (void)invalidateClassDescriptionCache
{
  NSResetMapTable(classToDesc);
}

/* accessors */

- (NSArray *)attributeKeys
{
  return nil;
}

- (NSArray *)toManyRelationshipKeys
{
  return nil;
}
- (NSArray *)toOneRelationshipKeys
{
  return nil;
}
- (NSString *)inverseForRelationshipKey:(NSString *)_key
{
  return nil;
}

@end /* NSClassDescription */

@implementation NSObject(ClassDescriptionForwards)

static Class NSClassDescriptionClass = Nil;

- (NSClassDescription *)classDescription
{
  if (NSClassDescriptionClass == Nil)
    NSClassDescriptionClass = [NSClassDescription class];
  
  return [NSClassDescriptionClass classDescriptionForClass:[self class]];
}

- (NSArray *)attributeKeys
{
  return [[self classDescription] attributeKeys];
}

- (NSArray *)toManyRelationshipKeys
{
  return [[self classDescription] toManyRelationshipKeys];
}

- (NSArray *)toOneRelationshipKeys
{
  return [[self classDescription] toOneRelationshipKeys];
}

- (NSString *)inverseForRelationshipKey:(NSString *)_key
{
  return [[self classDescription] inverseForRelationshipKey:_key];
}

@end /* NSObject(ClassDescriptionForwards) */
