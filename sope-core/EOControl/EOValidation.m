/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "EOClassDescription.h"
#include "EOKeyValueCoding.h"
#include "EONull.h"
#include "common.h"

#if __GNU_LIBOBJC__ == 20100911
#  define sel_get_any_uid sel_getUid
#endif

#if !LIB_FOUNDATION_LIBRARY

@interface NSException(UsedSetUI) /* does Jaguar allow -setUserInfo: ? */
- (void)setUserInfo:(NSDictionary *)_ui;
@end

#endif

@implementation NSClassDescription(EOValidation)

- (NSException *)validateObjectForDelete:(id)_object {
  return nil;
}
- (NSException *)validateObjectForSave:(id)_object {
  return nil;
}
- (NSException *)validateValue:(id *)_value forKey:(NSString *)_key {
  return nil;
}

@end /* NSClassDescription(EOValidation) */

@implementation NSObject(EOValidation)

- (NSException *)validateForDelete {
  return [[self classDescription] validateObjectForDelete:self];
}

- (NSException *)validateForInsert {
  return [self validateForSave];
}
- (NSException *)validateForUpdate {
  return [self validateForSave];
}

- (NSException *)validateForSave {
  NSException    *e;
  NSMutableArray *exceptions;
  NSArray        *properties;
  unsigned int i, count;
  id (*validate)(id, SEL, id *, NSString *);
  id (*objAtIdx)(id, SEL, unsigned int idx);
  id (*valForKey)(id, SEL, NSString *);
  
  exceptions = nil;

  /* first ask class description to validate object */
  
  if ((e = [[self classDescription] validateObjectForSave:self])) {
    if (exceptions == nil) exceptions = [NSMutableArray array];
    [exceptions addObject:e];
  }
  
  /* then process all properties */
  
  if ((properties = [self allPropertyKeys]) == nil)
    properties = [NSArray array];
  
  validate  = (void *)[self methodForSelector:@selector(validateValue:forKey:)];
  valForKey = (void *)[self methodForSelector:@selector(valueForKey:)];
  objAtIdx  = (void *)[properties methodForSelector:@selector(objectAtIndex:)];
  
  for (i = 0, count = [properties count]; i < count; i++) {
    NSString *key;
    id value, orgValue;
    
    key      = objAtIdx(properties, @selector(objectAtIndex:), i);
    orgValue = value = valForKey(self, @selector(valueForKey:), key);
    
    if ((e = validate(self, @selector(validateValue:forKey:), &value, key))) {
      /* validation of property failed */
      if (exceptions == nil) exceptions = [NSMutableArray array];
      [exceptions addObject:e];
    }
    else if (orgValue != value) {
      /* the value was changed during validation */
      [self takeValue:value forKey:key];
    }
  }
  
  if ((count = [exceptions count]) == 0) {
    return nil;
  }
  else if (count == 1) {
    return [exceptions objectAtIndex:0];
  }
  else {
    NSException *master;
    NSMutableDictionary *ui;

    master = [exceptions objectAtIndex:0];
    [exceptions removeObjectAtIndex:0];
    ui = [[master userInfo] mutableCopy];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    [ui setObject:exceptions forKey:@"EOAdditionalExceptions"];
    [master setUserInfo:ui];
    [ui release]; ui = nil;
    return master;
  }
}

- (NSException *)validateValue:(id *)_value forKey:(NSString *)_key {
  NSException *e;
  
  if ((e = [[self classDescription] validateValue:_value forKey:_key]))
    return e;
  
  /* should invoke key-specific methods, eg -validateBlah: */
  
  {
    /* construct 'validate'(8) + key + ':'(1) */
    unsigned len;
    char *buf;
    SEL  sel;

    len = [_key cStringLength];
    buf = malloc(len + 14);
    strcpy(buf, "validate");
    [_key getCString:&buf[8]];
    strcat(buf, ":");
    buf[8] = toupper(buf[8]);
    
#if NeXT_RUNTIME
    sel = sel_getUid(buf);
#else
    sel = sel_get_any_uid(buf);
#endif
    if (sel) {
      if ([self respondsToSelector:sel]) {
        if (buf) free(buf);
        return [self performSelector:sel withObject:*_value];
      }
    }
    if (buf) free(buf);
  }
  return nil;
}

@end /* NSObject(EOValidation) */
