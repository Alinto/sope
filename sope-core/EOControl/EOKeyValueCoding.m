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

#include "EOKeyValueCoding.h"
#include "EONull.h"
#include "common.h"

#if GNU_RUNTIME

#if __GNU_LIBOBJC__ == 20100911
#  define sel_get_any_uid sel_getUid
#  include <objc/runtime.h>
#else
#  include <objc/encoding.h>
#  include <objc/objc-api.h>
#endif

#endif

static EONull *null = nil;

#if LIB_FOUNDATION_LIBRARY

static id idMethodGetFunc(void* info1, void* info2, id self);
static id idIvarGetFunc(void* info1, void* info2, id self);
static void idMethodSetFunc(void* info1, void* info2, id self, id val);
static void idIvarSetFunc(void* info1, void* info2, id self, id val);
static id charMethodGetFunc(void* info1, void* info2, id self);
static id charIvarGetFunc(void* info1, void* info2, id self);
static void charMethodSetFunc(void* info1, void* info2, id self, id val);
static void charIvarSetFunc(void* info1, void* info2, id self, id val);
static id unsignedCharMethodGetFunc(void* info1, void* info2, id self);
static id unsignedCharIvarGetFunc(void* info1, void* info2, id self);
static void unsignedCharMethodSetFunc(void* info1, void* info2, id self, id val);
static void unsignedCharIvarSetFunc(void* info1, void* info2, id self, id val);
static id shortMethodGetFunc(void* info1, void* info2, id self);
static id shortIvarGetFunc(void* info1, void* info2, id self);
static void shortMethodSetFunc(void* info1, void* info2, id self, id val);
static void shortIvarSetFunc(void* info1, void* info2, id self, id val);
static id unsignedShortMethodGetFunc(void* info1, void* info2, id self);
static id unsignedShortIvarGetFunc(void* info1, void* info2, id self);
static void unsignedShortMethodSetFunc(void* info1, void* info2, id self, id val);
static void unsignedShortIvarSetFunc(void* info1, void* info2, id self, id val);
static id intMethodGetFunc(void* info1, void* info2, id self);
static id intIvarGetFunc(void* info1, void* info2, id self);
static void intMethodSetFunc(void* info1, void* info2, id self, id val);
static void intIvarSetFunc(void* info1, void* info2, id self, id val);
static id unsignedIntMethodGetFunc(void* info1, void* info2, id self);
static id unsignedIntIvarGetFunc(void* info1, void* info2, id self);
static void unsignedIntMethodSetFunc(void* info1, void* info2, id self, id val);
static void unsignedIntIvarSetFunc(void* info1, void* info2, id self, id val);
static id longMethodGetFunc(void* info1, void* info2, id self);
static id longIvarGetFunc(void* info1, void* info2, id self);
static void longMethodSetFunc(void* info1, void* info2, id self, id val);
static void longIvarSetFunc(void* info1, void* info2, id self, id val);
static id unsignedLongMethodGetFunc(void* info1, void* info2, id self);
static id unsignedLongIvarGetFunc(void* info1, void* info2, id self);
static void unsignedLongMethodSetFunc(void* info1, void* info2, id self, id val);
static void unsignedLongIvarSetFunc(void* info1, void* info2, id self, id val);
static id longLongMethodGetFunc(void* info1, void* info2, id self);
static id longLongIvarGetFunc(void* info1, void* info2, id self);
static void longLongMethodSetFunc(void* info1, void* info2, id self, id val);
static void longLongIvarSetFunc(void* info1, void* info2, id self, id val);
static id unsignedLongLongMethodGetFunc(void* info1, void* info2, id self);
static id unsignedLongLongIvarGetFunc(void* info1, void* info2, id self);
static void unsignedLongLongMethodSetFunc(void* info1, void* info2, id self, id val);
static void unsignedLongLongIvarSetFunc(void* info1, void* info2, id self, id val);
static id floatMethodGetFunc(void* info1, void* info2, id self);
static id floatIvarGetFunc(void* info1, void* info2, id self);
static void floatMethodSetFunc(void* info1, void* info2, id self, id val);
static void floatIvarSetFunc(void* info1, void* info2, id self, id val);
static id doubleMethodGetFunc(void* info1, void* info2, id self);
static id doubleIvarGetFunc(void* info1, void* info2, id self);
static void doubleMethodSetFunc(void* info1, void* info2, id self, id val);
static void doubleIvarSetFunc(void* info1, void* info2, id self, id val);

static Class NumberClass = Nil;
static Class StringClass = Nil;

@implementation NSObject(EOKeyValueCoding)

/*
 *  Types
 */

typedef struct _KeyValueMethod {
  NSString*   key;
  Class       class;
} KeyValueMethod;

typedef struct _GetKeyValueBinding {
  /* info1, info2, self */
  id (*access)(void *, void *, id);
  void *info1;
  void *info2;
} GetKeyValueBinding;

typedef struct _SetKeyValueBinding {
  /* info1, info2, self, val */
  void (*access)(void *, void *, id, id);
  void *info1;
  void *info2;
} SetKeyValueBinding;

/*
 * Globals
 */

static NSMapTable* getValueBindings = NULL;
static NSMapTable* setValueBindings = NULL;
static BOOL keyValueDebug = NO;
static BOOL keyValueInit  = NO;

/*
 *  KeyValueMapping
 */

static GetKeyValueBinding* newGetBinding(NSString* key, id instance)
{
  GetKeyValueBinding *ret = NULL;
  void *info1 = NULL;
  void *info2 = NULL;
  id (*fptr)(void*, void*, id) = NULL;

  // Lookup method name [-(type)key]
  {
    Class      class = [instance class];
    unsigned   clen  = [key cStringLength];
    char       *cbuf;
    const char *ckey;
    SEL        sel;
    struct objc_method* mth;
    
    cbuf = malloc(clen + 1);
    [key getCString:cbuf]; cbuf[clen] = '\0';
    ckey = cbuf;
    sel = sel_get_any_uid(ckey);
    
    if (sel && (mth = class_get_instance_method(class, sel)) &&
        method_get_number_of_arguments(mth) == 2) {
      switch(*objc_skip_type_qualifiers(mth->method_types)) {
        case _C_ID:
          fptr = (id (*)(void*, void*, id))idMethodGetFunc;
          break;
        case _C_CHR:
          fptr = (id (*)(void*, void*, id))charMethodGetFunc;
          break;
        case _C_UCHR:
          fptr = (id (*)(void*, void*, id))unsignedCharMethodGetFunc;
          break;
        case _C_SHT:
          fptr = (id (*)(void*, void*, id))shortMethodGetFunc;
          break;
        case _C_USHT:
          fptr = (id (*)(void*, void*, id))unsignedShortMethodGetFunc;
          break;
        case _C_INT:
          fptr = (id (*)(void*, void*, id))intMethodGetFunc;
          break;
        case _C_UINT:
          fptr = (id (*)(void*, void*, id))unsignedIntMethodGetFunc;
          break;
        case _C_LNG:
          fptr = (id (*)(void*, void*, id))longMethodGetFunc;
          break;
        case _C_ULNG:
          fptr = (id (*)(void*, void*, id))unsignedLongMethodGetFunc;
          break;
        case 'q':
          fptr = (id (*)(void*, void*, id))longLongMethodGetFunc;
          break;
        case 'Q':
          fptr = (id (*)(void*, void*, id))unsignedLongLongMethodGetFunc;
          break;
        case _C_FLT:
          fptr = (id (*)(void*, void*, id))floatMethodGetFunc;
          break;
        case _C_DBL:
          fptr = (id (*)(void*, void*, id))doubleMethodGetFunc;
          break;
      }
      if (fptr) {
        info1 = (void*)(mth->method_imp);
        info2 = (void*)(mth->method_name);
      }
    }
    if (cbuf != NULL) free(cbuf);
  }
        
  // Lookup ivar name
  if (fptr == NULL) {
    Class class = [instance class];
    unsigned   clen;
    char       *cbuf;
    const char *ckey;
    int i;
    
    clen = [key cStringLength];
    cbuf = malloc(clen + 1);
    [key getCString:cbuf]; cbuf[clen] = '\0';
    ckey = cbuf;
    
    while (class != Nil) {
      for (i = 0; class->ivars && i < class->ivars->ivar_count; i++) {
        if (!Strcmp(ckey, class->ivars->ivar_list[i].ivar_name)) {
          switch(*objc_skip_type_qualifiers(class->ivars->ivar_list[i].ivar_type)) {
            case _C_ID:
              fptr = (id (*)(void*, void*, id))idIvarGetFunc;
              break;
            case _C_CHR:
              fptr = (id (*)(void*, void*, id))charIvarGetFunc;
              break;
            case _C_UCHR:
              fptr = (id (*)(void*, void*, id))unsignedCharIvarGetFunc;
              break;
            case _C_SHT:
              fptr = (id (*)(void*, void*, id))shortIvarGetFunc;
              break;
            case _C_USHT:
              fptr = (id (*)(void*, void*, id))unsignedShortIvarGetFunc;
              break;
            case _C_INT:
              fptr = (id (*)(void*, void*, id))intIvarGetFunc;
              break;
            case _C_UINT:
              fptr = (id (*)(void*, void*, id))unsignedIntIvarGetFunc;
              break;
            case _C_LNG:
              fptr = (id (*)(void*, void*, id))longIvarGetFunc;
              break;
            case _C_ULNG:
              fptr = (id (*)(void*, void*, id))unsignedLongIvarGetFunc;
              break;
            case 'q':
              fptr = (id (*)(void*, void*, id))longLongIvarGetFunc;
              break;
            case 'Q':
              fptr = (id (*)(void*, void*, id))unsignedLongLongIvarGetFunc;
              break;
            case _C_FLT:
              fptr = (id (*)(void*, void*, id))floatIvarGetFunc;
              break;
            case _C_DBL:
              fptr = (id (*)(void*, void*, id))doubleIvarGetFunc;
              break;
          }
          if (fptr) {
            info2 = (void *)(unsigned long)
	      (class->ivars->ivar_list[i].ivar_offset);
            break;
          }
        }
      }
      class = class->super_class;
    }
    if (cbuf != NULL) free(cbuf);
  }
    
  // Make binding and insert into map
  if (fptr) {
    KeyValueMethod     *mkey;
    GetKeyValueBinding *bin;
        
    mkey = Malloc(sizeof(KeyValueMethod));
    bin  = Malloc(sizeof(GetKeyValueBinding));
    mkey->key   = [key copy];
    mkey->class = [instance class];
    
    bin->access = fptr;
    bin->info1 = info1;
    bin->info2 = info2;
        
    NSMapInsert(getValueBindings, mkey, bin);
    ret = bin;
  }
    
  // If no way to access value warn
  if (!ret && keyValueDebug)
    NSLog(@"cannnot get key `%@' for instance of class `%@'",
          key, NSStringFromClass([instance class]));
    
  return ret;
}

static SetKeyValueBinding* newSetBinding(NSString* key, id instance)
{
  SetKeyValueBinding *ret = NULL;
  void *info1 = NULL;
  void *info2 = NULL;
  void (*fptr)(void*, void*, id, id) = NULL;
    
  // Lookup method name [-(void)setKey:(type)arg]
  {
    Class      class = [instance class];
    unsigned   clen  = [key cStringLength];
    char       *cbuf;
    const char *ckey;
    SEL        sel;
    struct objc_method* mth;
    char  sname[clen + 7];

    cbuf = malloc(clen + 1);
    [key getCString:cbuf]; cbuf[clen] = '\0';
    ckey = cbuf;
    
    // Make sel from name
    Strcpy(sname, "set");
    Strcat(sname, ckey);
    Strcat(sname, ":");
    sname[3] = islower((int)sname[3]) ? toupper((int)sname[3]) : sname[3];
    sel = sel_get_any_uid(sname);
        
    if (sel && (mth = class_get_instance_method(class, sel)) &&
        method_get_number_of_arguments(mth) == 3 &&
        *objc_skip_type_qualifiers(mth->method_types) == _C_VOID) {
      char* argType = (char*)(mth->method_types);
                
      argType = (char*)objc_skip_argspec(argType);    // skip return
      argType = (char*)objc_skip_argspec(argType);    // skip self
      argType = (char*)objc_skip_argspec(argType);    // skip SEL
                
      switch(*objc_skip_type_qualifiers(argType)) {
        case _C_ID:
          fptr = (void (*)(void*, void*, id, id))idMethodSetFunc;
          break;
        case _C_CHR:
          fptr = (void (*)(void*, void*, id, id))charMethodSetFunc;
          break;
        case _C_UCHR:
          fptr = (void (*)(void*, void*, id, id))unsignedCharMethodSetFunc;
          break;
        case _C_SHT:
          fptr = (void (*)(void*, void*, id, id))shortMethodSetFunc;
          break;
        case _C_USHT:
          fptr = (void (*)(void*, void*, id, id))unsignedShortMethodSetFunc;
          break;
        case _C_INT:
          fptr = (void (*)(void*, void*, id, id))intMethodSetFunc;
          break;
        case _C_UINT:
          fptr = (void (*)(void*, void*, id, id))unsignedIntMethodSetFunc;
          break;
        case _C_LNG:
          fptr = (void (*)(void*, void*, id, id))longMethodSetFunc;
          break;
        case _C_ULNG:
          fptr = (void (*)(void*, void*, id, id))unsignedLongMethodSetFunc;
          break;
        case 'q':
          fptr = (void (*)(void*, void*, id, id))longLongMethodSetFunc;
          break;
        case 'Q':
          fptr = (void (*)(void*, void*, id, id))unsignedLongLongMethodSetFunc;
          break;
        case _C_FLT:
          fptr = (void (*)(void*, void*, id, id))floatMethodSetFunc;
          break;
        case _C_DBL:
          fptr = (void (*)(void*, void*, id, id))doubleMethodSetFunc;
          break;
      }
      if (fptr) {
        info1 = (void*)(mth->method_imp);
        info2 = (void*)(mth->method_name);
      }
    }
    if (cbuf) free(cbuf);
  }    
  // Lookup ivar name
  if (!fptr) {
    Class class = [instance class];
    unsigned   clen  = [key cStringLength];
    char       *cbuf;
    const char *ckey;
    int i;

    cbuf = malloc(clen + 1);
    [key getCString:cbuf]; cbuf[clen] = '\0';
    ckey = cbuf;
        
    while (class) {
      for (i = 0; class->ivars && i < class->ivars->ivar_count; i++) {
        if (!Strcmp(ckey, class->ivars->ivar_list[i].ivar_name)) {
          switch(*objc_skip_type_qualifiers(class->ivars->ivar_list[i].ivar_type)) {
            case _C_ID:
              fptr = (void (*)(void*, void*, id, id))idIvarSetFunc;
              break;
            case _C_CHR:
              fptr = (void (*)(void*, void*, id, id))charIvarSetFunc;
              break;
            case _C_UCHR:
              fptr = (void (*)(void*, void*, id, id))unsignedCharIvarSetFunc;
              break;
            case _C_SHT:
              fptr = (void (*)(void*, void*, id, id))shortIvarSetFunc;
              break;
            case _C_USHT:
              fptr = (void (*)(void*, void*, id, id))unsignedShortIvarSetFunc;
              break;
            case _C_INT:
              fptr = (void (*)(void*, void*, id, id))intIvarSetFunc;
              break;
            case _C_UINT:
              fptr = (void (*)(void*, void*, id, id))unsignedIntIvarSetFunc;
              break;
            case _C_LNG:
              fptr = (void (*)(void*, void*, id, id))longIvarSetFunc;
              break;
            case _C_ULNG:
              fptr = (void (*)(void*, void*, id, id))unsignedLongIvarSetFunc;
              break;
            case 'q':
              fptr = (void (*)(void*, void*, id, id))longLongIvarSetFunc;
              break;
            case 'Q':
              fptr = (void (*)(void*, void*, id, id))unsignedLongLongIvarSetFunc;
              break;
            case _C_FLT:
              fptr = (void (*)(void*, void*, id, id))floatIvarSetFunc;
              break;
            case _C_DBL:
              fptr = (void (*)(void*, void*, id, id))doubleIvarSetFunc;
              break;
          }
          if (fptr != NULL) {
            info2 = (void *)(unsigned long)
	      (class->ivars->ivar_list[i].ivar_offset);
            break;
          }
        }
      }
      class = class->super_class;
    }
    if (cbuf) free(cbuf);
  }
    
  // Make binding and insert into map
  if (fptr) {
    KeyValueMethod     *mkey;
    SetKeyValueBinding *bin;
        
    mkey = Malloc(sizeof(KeyValueMethod));
    bin  = Malloc(sizeof(SetKeyValueBinding));
    mkey->key = [key copy];
    mkey->class = [instance class];
    
    bin->access = fptr;
    bin->info1 = info1;
    bin->info2 = info2;
        
    NSMapInsert(setValueBindings, mkey, bin);
    ret = bin;
  }
  // If no way to access value warn
  if (!ret && keyValueDebug)
    NSLog(@"cannnot set key `%@' for instance of class `%@'",
          key, NSStringFromClass([instance class]));
  
  return ret;
}

/*
 * MapTable initialization
 */

static unsigned keyValueMapHash(NSMapTable* table, KeyValueMethod* map) {
  return [map->key hash] + (((unsigned long)(map->class)) >> 4L);
}

static BOOL keyValueMapCompare(NSMapTable* table,
                               KeyValueMethod* map1, KeyValueMethod* map2)
{
  return (map1->class == map2->class) && [map1->key isEqual:map2->key];
}

static void mapRetainNothing(NSMapTable* table, KeyValueMethod* map) {
}

static void keyValueMapKeyRelease(NSMapTable* table, KeyValueMethod* map) {
  [map->key release];
  Free(map);
}

static void keyValueMapValRelease(NSMapTable* table, void* map) {
  Free(map);
}

static NSString* keyValueMapDescribe(NSMapTable* table, KeyValueMethod* map) {
  if (StringClass == Nil) StringClass = [NSString class];
  return [StringClass stringWithFormat:@"%@:%@",
                   NSStringFromClass(map->class), map->key];
}

static NSString* describeBinding(NSMapTable* table, GetKeyValueBinding* bin) {
  if (StringClass == Nil) StringClass = [NSString class];
  return [StringClass stringWithFormat:@"%08x:%08x", bin->info1, bin->info2];
}

static NSMapTableKeyCallBacks keyValueKeyCallbacks = {
  (unsigned(*)(NSMapTable *, const void *))keyValueMapHash,
  (BOOL(*)(NSMapTable *, const void *, const void *))keyValueMapCompare,
  (void (*)(NSMapTable *, const void *anObject))mapRetainNothing,
  (void (*)(NSMapTable *, void *anObject))keyValueMapKeyRelease,
  (NSString *(*)(NSMapTable *, const void *))keyValueMapDescribe,
  (const void *)NULL
}; 

const NSMapTableValueCallBacks keyValueValueCallbacks = {
  (void (*)(NSMapTable *, const void *))mapRetainNothing,
  (void (*)(NSMapTable *, void *))keyValueMapValRelease,
  (NSString *(*)(NSMapTable *, const void *))describeBinding
}; 

static void initKeyValueBindings(void)
{
  getValueBindings = NSCreateMapTable(keyValueKeyCallbacks, 
                                      keyValueValueCallbacks, 31);
  setValueBindings = NSCreateMapTable(keyValueKeyCallbacks, 
                                      keyValueValueCallbacks, 31);
  keyValueInit = YES;
}

/* 
 * Access Methods 
 */

static inline void removeAllBindings(void) {
  NSResetMapTable(getValueBindings);
  NSResetMapTable(setValueBindings);
}

static inline id getValue(NSString* key, id instance) {
  KeyValueMethod     mkey = { key, [instance class] };
  GetKeyValueBinding *bin;
  id value = nil;
  
  if (NumberClass == Nil)
    NumberClass = [NSNumber class];
  
  // Check Init
  if (!keyValueInit)
    initKeyValueBindings();
    
  // Get existing binding
  bin = (GetKeyValueBinding *)NSMapGet(getValueBindings, &mkey);
    
  // Create new binding
  if (bin == NULL)
    bin = newGetBinding(key, instance);
    
  // Get value if binding is ok
  if (bin)
    value = bin->access(bin->info1, bin->info2, instance);
    
  return value;
}

static inline BOOL setValue(NSString* key, id instance, id value)
{
  KeyValueMethod mkey = {key, [instance class]};
  SetKeyValueBinding* bin;

  if (NumberClass == Nil)
    NumberClass = [NSNumber class];
    
  // Check Init
  if (!keyValueInit)
    initKeyValueBindings();
    
  // Get existing binding
  bin = (SetKeyValueBinding *)NSMapGet(setValueBindings, &mkey);
    
  // Create new binding
  if (bin == NULL)
    bin = newSetBinding(key, instance);
    
  // Get value if binding is ok
  if (bin)
    bin->access(bin->info1, bin->info2, instance, value);
    
  return (bin != NULL);
}

+ (BOOL)accessInstanceVariablesDirectly {
  return NO;
}

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  NSDictionary *ui;

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       self, @"EOTargetObjectUserInfoKey",
		       [self class],
		       @"EOTargetObjectClassUserInfoKey",
		       _key, @"EOUnknownUserInfoKey",
		     nil];
  [[NSException exceptionWithName:@"EOUnknownKeyException"
		reason:@"called -takeValue:forKey: with unknown key"
		userInfo:ui] raise];
}

- (id)handleQueryWithUnboundKey:(NSString *)_key {
  NSDictionary *ui;

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       self, @"EOTargetObjectUserInfoKey",
		       _key, @"EOUnknownUserInfoKey",
		     nil];
  [[NSException exceptionWithName:@"EOUnknownKeyException"
		reason:@"called -valueForKey: with unknown key"
		userInfo:ui] raise];
  return nil;
}

- (void)unableToSetNullForKey:(NSString *)_key {
  [NSException raise:@"NSInvalidArgumentException" 
	       format:
		  @"EOKeyValueCoding cannot set EONull value for key %@,"
		  @"in instance of %@ class.",
		  _key, NSStringFromClass([self class])];
}

+ (void)flushAllKeyBindings {
  removeAllBindings();
}
- (void)flushKeyBindings {
  // EOF 1.1 method
  removeAllBindings();
}

- (void)setKeyValueCodingWarnings:(BOOL)aFlag {
  keyValueDebug = aFlag;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dictionary {
  NSEnumerator *keyEnum;
  id key;

  if (null == nil) null = [EONull null];
  keyEnum = [dictionary keyEnumerator];
    
  while ((key = [keyEnum nextObject])) {
    id value;
    
    value = [dictionary objectForKey:key];

    /* automagically convert EONull to nil */
    if (value == null) value = nil;
    
    [self takeValue:value forKey:key];
    
#if 0 // this doesn't support overridden methods ...
    if (!setValue(key, self, value)) {
      [self handleTakeValue:value forUnboundKey:key];
    }
#endif
  }
}

- (NSDictionary *)valuesForKeys:(NSArray *)keys {
  static Class  NSDictionaryClass = Nil;
  int n = [keys count];

  if (NSDictionaryClass == Nil)
    NSDictionaryClass = [NSDictionary class];
  if (null == nil)
    null = [EONull null];
  
  if (n == 0)
    return [NSDictionaryClass dictionary];
  else if (n == 1) {
    NSString *key;
    id value;
    
    key   = [keys objectAtIndex:0];
    //value = getValue(key, self);
    value = [self valueForKey:key];

    /* automagically convert 'nil' to EONull */
    if (value == nil) value = null;
    
    return [NSDictionaryClass dictionaryWithObject:value forKey:key];
  }
  else {
    id newKeys[n];
    id newVals[n];
    int i;
        
    for (i = 0; i < n; i++) {
      id key;
      id val;
      
      key = [keys objectAtIndex:i];
      //val = getValue(key, self);
      val = [self valueForKey:key];

      /* automagically convert 'nil' to EONull */
      if (val == nil) val = null;
      
      newKeys[i] = key;
      newVals[i] = val;
    }
    
    return [NSDictionaryClass dictionaryWithObjects:newVals
                              forKeys:newKeys
                              count:n];
  }
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (!setValue(_key, self, _value)) {
    //NSLog(@"ERROR(%s): couldn't take value for key %@", key);
    [self handleTakeValue:_value forUnboundKey:_key];
  }
}

- (id)valueForKey:(NSString *)key {
  id val;
  
  if ((val = getValue(key, self)) != nil)
    return val;
  
  return nil;
}

/* stored values */

+ (BOOL)useStoredAccessor {
  return YES;
}

- (void)takeStoredValue:(id)_value forKey:(NSString *)_key {
  if ([[self class] useStoredAccessor]) {
    BOOL ok = YES;

    /* this should be different */
    
    ok = setValue(_key, self, _value);
    if (!ok) [self handleTakeValue:_value forUnboundKey:_key];
  }
  else
    [self takeValue:_value forKey:_key];
}

- (id)storedValueForKey:(NSString *)_key {
  if ([[self class] useStoredAccessor]) {
    id val;

    /* this should be different */
    
    if ((val = getValue(_key, self)))
      return val;

    /* val = [self handleQueryWithUnboundKey:_key] */
    
    return nil;
  }
  else
    return [self valueForKey:_key];
}

@end /* NSObject(EOKeyValueCoding) */

@implementation NSObject(EOKeyPathValueCoding)

- (void)takeValue:(id)_value forKeyPath:(NSString *)_keyPath {
  NSArray *keyPath;
  unsigned i, count;
  id target;

  keyPath = [_keyPath componentsSeparatedByString:@"."];
  count = [keyPath count];

  if (count < 2)
    [self takeValue:_value forKey:_keyPath];
  else {

    target = self;
    for (i = 0; i < (count - 1) ; i++) {
      if ((target = [target valueForKey:[keyPath objectAtIndex:i]]) == nil)
        /* nil component */
        return;
    }
  
    [target takeValue:_value forKey:[keyPath lastObject]];
  }
}
- (id)valueForKeyPath:(NSString *)_keyPath {
#if 1
  const unsigned char *buf;
  unsigned int  i, start, len;
  id value;

  if ((len = [_keyPath cStringLength]) == 0)
    return [self valueForKey:_keyPath];
  
  if (StringClass == Nil) StringClass = [NSString class];
  value = self;
  
  buf = (const unsigned char *)[_keyPath cString];
  if (index((const char *)buf, '.') == NULL)
    /* no point contained .. */
    return [self valueForKey:_keyPath];
  
  for (i = start = 0; i < len; i++) {
    if (buf[i] == '.') {
      /* found a pt */
      NSString *key;
      
      key = (start < i)
        ? [[StringClass alloc] initWithCString:(const char *)&(buf[start]) 
			       length:(i - start)]
        : (id)@"";
      
      value = [value valueForKey:key];
      [key release]; key = nil;
      
      if (value == nil)
        return nil;
      
      start = (i + 1); /* next part is after the pt */
    }
  }
  /* check last part */
  {
    NSString *key;
    id v;
    
    key = (start < i)
      ? [[StringClass alloc] initWithCString:(const char *)&(buf[start]) 
			     length:(i - start)]
      : (id)@"";
    v = [value valueForKey:key];
    [key release]; key = nil;
    return v;
  }
#else
  /* naive implementation */
  NSEnumerator *keyPath;
  NSString *key;
  id value;
  
  value   = self;
  keyPath = [[_keyPath componentsSeparatedByString:@"."] objectEnumerator];
  while ((key = [keyPath nextObject]) && (value != nil))
    value = [value valueForKey:key];
  return value;
#endif
}

@end /* NSObject(EOKeyPathValueCoding) */

@implementation NSArray(EOKeyValueCoding)

- (id)computeSumForKey:(NSString *)_key {
  unsigned i, cc = [self count];
  id       (*objAtIdx)(id, SEL, unsigned int);
  double   sum;

  if (cc == 0) return [NSNumber numberWithDouble:0.0];

  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];
    
  for (i = 0, sum = 0.0; i < cc; i++) {
    register id o;
      
    o = objAtIdx(self, @selector(objectAtIndex:), i);
    o = [o valueForKey:_key];
    sum += [o doubleValue];
  }
  return [NSNumber numberWithDouble:sum];
}

- (id)computeAvgForKey:(NSString *)_key {
  unsigned cc = [self count];
  NSNumber *sum;

  if (cc == 0) return nil;
  
  sum = [self computeSumForKey:_key];
  return [NSNumber numberWithDouble:([sum doubleValue] / (double)cc)];
}

- (id)computeCountForKey:(NSString *)_key {
  return [NSNumber numberWithUnsignedInt:[self count]];
}

- (id)computeMaxForKey:(NSString *)_key {
  unsigned i, cc = [self count];
  id       (*objAtIdx)(id, SEL, unsigned int);
  double   max;

  if (cc == 0) return nil;
    
  objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];

  max = [[objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key]
                                                       doubleValue];
  for (i = 1; i < cc; i++) {
    register double ov;
      
    ov = [[objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key]
                                                        doubleValue];
    if (ov > max) max = ov;
  }
  return [NSNumber numberWithDouble:max];
}

- (id)computeMinForKey:(NSString *)_key {
  unsigned i, cc = [self count];
  id       (*objAtIdx)(id, SEL, unsigned int);
  double   min;

  if (cc == 0) return nil;
  
  objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];
  
  min = [[objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key]
                                                       doubleValue];
  for (i = 1; i < cc; i++) {
    register double ov;
      
    ov = [[objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key]
                                                        doubleValue];
    if (ov < min) min = ov;
  }
  return [NSNumber numberWithDouble:min];
}

- (id)valueForKey:(NSString *)_key {
  if ([_key hasPrefix:@"@"]) {
    /* process a computed function */
    const char *keyStr;
    char       *bufPtr;
    unsigned   keyLen = [_key cStringLength];
    char       *kbuf, *buf;
    SEL        sel;

    kbuf = malloc(keyLen + 4);
    buf  = malloc(keyLen + 20);
    [_key getCString:kbuf];
    keyStr = kbuf;
    bufPtr = buf;
    strcpy(buf, "compute");       bufPtr += 7;
    *bufPtr = toupper(keyStr[1]); bufPtr++;
    strncpy(&(buf[8]), &(keyStr[2]), keyLen - 2); bufPtr += (keyLen - 2);
    strcpy(bufPtr, "ForKey:");
    if (kbuf) free(kbuf);
    
    sel = sel_get_any_uid(buf);
    if (buf) free(buf);
    
    return sel != NULL ? [self performSelector:sel withObject:_key] : nil;
  }
  else {
    /* process the _key in a map function */
    unsigned i, cc = [self count];
    id objects[cc];
    id (*objAtIdx)(id, SEL, unsigned int);

#if DEBUG
    if ([_key isEqualToString:@"count"]) {
      NSLog(@"WARNING(%s): USED -valueForKey(@\"count\") ON NSArray, YOU"
            @"PROBABLY WANT TO USE @count INSTEAD !",
            __PRETTY_FUNCTION__);
      return [self valueForKey:@"@count"];
    }
#endif
    
    objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];
    
    for (i = 0; i < cc; i++) {
      register id o;
      
      o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
      
      if (o)
        objects[i] = o;
      else {
        if (null == nil) null = [EONull null];
        objects[i] = null;
      }
    }
    
    // TODO: possibly this checks fails on OSX
    return [self isKindOfClass:[NSMutableArray class]]
      ? [NSMutableArray arrayWithObjects:objects count:cc]
      : [NSArray arrayWithObjects:objects count:cc];
  }
}

@end /* NSArray(EOKeyValueCoding) */


@implementation NSDictionary(EOKeyValueCoding)

- (NSDictionary *)valuesForKeys:(NSArray *)keys {
  int n = [keys count];

  if (n == 0)
    return [NSDictionary dictionary];
  else if (n == 1) {
    NSString *key = [keys objectAtIndex:0];

    return [NSDictionary dictionaryWithObject:[self objectForKey:key]
                         forKey:key];
  }
  else {
    NSMutableArray *newKeys, *newVals;
    int i;
        
    newKeys = [NSMutableArray arrayWithCapacity:n];
    newVals = [NSMutableArray arrayWithCapacity:n];
    
    for (i = 0; i < n; i++) {
      id key = [keys objectAtIndex:i];
      id val = [self objectForKey:key];
      
      if (val) {
        [newKeys addObject:key];
        [newVals addObject:val];
      }
    }
    
    return [NSDictionary dictionaryWithObjects:newVals forKeys:newKeys];
  }
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  //#warning takeValue:forKey: is ignored in NSDictionaries !
  // ignore
  //[self handleTakeValue:_value forUnboundKey:_key];
}

- (id)valueForKey:(NSString *)_key {
  id obj;
  
  if (_key == nil) // TODO: warn about nil key?
    return nil;
  if ((obj = [self objectForKey:_key]) == nil)
    return nil;
  
  if (null == nil) null = [[NSNull null] retain];
  if (obj == null)
    return nil;
    
  return obj;
}

@end /* NSDictionary(EOKeyValueCoding) */

@implementation NSMutableDictionary(EOKeyValueCoding)

- (void)takeValuesFromDictionary:(NSDictionary*)dictionary {
  [self addEntriesFromDictionary:dictionary];
}

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (_value == nil) _value = [NSNull null];
  [self setObject:_value forKey:_key];
}

@end /* NSMutableDictionary(EOKeyValueCoding) */

/*
 *  Accessor functions
 */

/* ACCESS to keys of id type. */

static id idMethodGetFunc(void *info1, void *info2, id self) {
  id (*fptr)(id, SEL) = (id(*)(id, SEL))info1;
  id val = fptr(self, (SEL)info2);
  return val;
}
static id idIvarGetFunc(void *info1, void *info2, id self) {
  id *ptr = (id *)((char *)self + (unsigned long)info2);
  return *ptr;
}

static void idMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, id) = (void(*)(id, SEL, id))info1;
  fptr(self, (SEL)info2, val);
}

static void idIvarSetFunc(void* info1, void* info2, id self, id val)
{
  id *ptr = (id *)((char*)self + (unsigned long)info2);
  ASSIGN(*ptr, val);
}

/* ACCESS to keys of char type. */

static id charMethodGetFunc(void* info1, void* info2, id self)
{
  char (*fptr)(id, SEL) = (char(*)(id, SEL))info1;
  char val = fptr(self, (SEL)info2);
  return [NumberClass numberWithChar:val];
}

static id charIvarGetFunc(void* info1, void* info2, id self)
{
  char *ptr = (char *)((char *)self + (unsigned long)info2);
  return [NumberClass numberWithChar:*ptr];
}

static void charMethodSetFunc(void *info1, void *info2, id self, id val)
{
  void (*fptr)(id, SEL, char) = (void(*)(id, SEL, char))info1;
  fptr(self, (SEL)info2, [val charValue]);
}

static void charIvarSetFunc(void *info1, void *info2, id self, id val)
{
  char *ptr = (char *)((char *)self + (unsigned long)info2);
  *ptr = [val charValue];
}


/* ACCESS to keys of unsigned char type. */

static id unsignedCharMethodGetFunc(void* info1, void* info2, id self)
{
  unsigned char (*fptr)(id, SEL) = (unsigned char(*)(id, SEL))info1;
  unsigned char val = fptr(self, (SEL)info2);
  return [NumberClass numberWithUnsignedChar:val];
}

static id unsignedCharIvarGetFunc(void* info1, void* info2, id self)
{
  unsigned char *ptr = (unsigned char *)((char *)self + (unsigned long)info2);
  return [NumberClass numberWithUnsignedChar:*ptr];
}

static void unsignedCharMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, unsigned char) = (void(*)(id, SEL, unsigned char))info1;
  fptr(self, (SEL)info2, [val unsignedCharValue]);
}

static void unsignedCharIvarSetFunc(void* info1, void* info2, id self, id val)
{
  unsigned char *ptr = (unsigned char *)((char *)self + (unsigned long)info2);
  *ptr = [val unsignedCharValue];
}


/* ACCESS to keys of short type. */

static id shortMethodGetFunc(void* info1, void* info2, id self)
{
  short (*fptr)(id, SEL) = (short(*)(id, SEL))info1;
  short val = fptr(self, (SEL)info2);
  return [NumberClass numberWithShort:val];
}

static id shortIvarGetFunc(void* info1, void* info2, id self)
{
  short *ptr = (short *)((char *)self + (unsigned long)info2);
  return [NumberClass numberWithShort:*ptr];
}

static void shortMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, short) = (void(*)(id, SEL, short))info1;
  fptr(self, (SEL)info2, [val shortValue]);
}

static void shortIvarSetFunc(void* info1, void* info2, id self, id val)
{
  short *ptr = (short *)((char *)self + (unsigned long)info2);
  *ptr = [val shortValue];
}


/* ACCESS to keys of unsigned short type. */

static id unsignedShortMethodGetFunc(void* info1, void* info2, id self)
{
  unsigned short (*fptr)(id, SEL) = (unsigned short(*)(id, SEL))info1;
  unsigned short val = fptr(self, (SEL)info2);
  return [NumberClass numberWithUnsignedShort:val];
}

static id unsignedShortIvarGetFunc(void* info1, void* info2, id self)
{
  unsigned short *ptr = (unsigned short*)((char *)self + (unsigned long)info2);
  return [NumberClass numberWithUnsignedShort:*ptr];
}

static void unsignedShortMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, unsigned short) = (void(*)(id, SEL, unsigned short))info1;
  fptr(self, (SEL)info2, [val unsignedShortValue]);
}

static void unsignedShortIvarSetFunc(void* info1, void* info2, id self, id val)
{
  unsigned short *ptr = (unsigned short*)((char *)self + (unsigned long)info2);
  *ptr = [val unsignedShortValue];
}


/* ACCESS to keys of int type. */

static id intMethodGetFunc(void* info1, void* info2, id self)
{
  int (*fptr)(id, SEL) = (int(*)(id, SEL))info1;
  int val = fptr(self, (SEL)info2);
  return [NumberClass numberWithInt:val];
}

static id intIvarGetFunc(void *info1, void *info2, id self)
{
  int *ptr = (int *)((char *)self + (unsigned long)info2);
  return [NumberClass numberWithInt:*ptr];
}

static void intMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, int) = (void(*)(id, SEL, int))info1;
  fptr(self, (SEL)info2, [val intValue]);
}

static void intIvarSetFunc(void* info1, void* info2, id self, id val)
{
  int *ptr = (int *)((char *)self + (unsigned long)info2);
  *ptr = [val intValue];
}


/* ACCESS to keys of unsigned int type. */

static id unsignedIntMethodGetFunc(void* info1, void* info2, id self)
{
  unsigned int (*fptr)(id, SEL) = (unsigned int(*)(id, SEL))info1;
  unsigned int val = fptr(self, (SEL)info2);
  return [NumberClass numberWithUnsignedInt:val];
}

static id unsignedIntIvarGetFunc(void* info1, void* info2, id self)
{
  unsigned int* ptr = (unsigned int*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithUnsignedInt:*ptr];
}

static void unsignedIntMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, unsigned int) = (void(*)(id, SEL, unsigned int))info1;
  fptr(self, (SEL)info2, [val unsignedIntValue]);
}

static void unsignedIntIvarSetFunc(void* info1, void* info2, id self, id val)
{
  unsigned int* ptr = (unsigned int*)((char*)self + (unsigned long)info2);
  *ptr = [val unsignedIntValue];
}


/* ACCESS to keys of long type. */

static id longMethodGetFunc(void* info1, void* info2, id self)
{
  long (*fptr)(id, SEL) = (long(*)(id, SEL))info1;
  long val = fptr(self, (SEL)info2);
  return [NumberClass numberWithLong:val];
}

static id longIvarGetFunc(void* info1, void* info2, id self)
{
  long* ptr = (long*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithLong:*ptr];
}

static void longMethodSetFunc(void* info1, void* info2, id self, id val)
{
  void (*fptr)(id, SEL, long) = (void(*)(id, SEL, long))info1;
  fptr(self, (SEL)info2, [val longValue]);
}

static void longIvarSetFunc(void* info1, void* info2, id self, id val)
{
  long* ptr = (long*)((char*)self + (unsigned long)info2);
  *ptr = [val longValue];
}


/* unsigned long type */

static id unsignedLongMethodGetFunc(void* info1, void* info2, id self) {
  unsigned long (*fptr)(id, SEL) = (unsigned long(*)(id, SEL))info1;
  unsigned long val = fptr(self, (SEL)info2);
  return [NumberClass numberWithUnsignedLong:val];
}

static id unsignedLongIvarGetFunc(void* info1, void* info2, id self) {
  unsigned long* ptr = (unsigned long*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithUnsignedLong:*ptr];
}

static void unsignedLongMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, unsigned long) = (void(*)(id, SEL, unsigned long))info1;
  fptr(self, (SEL)info2, [val unsignedLongValue]);
}

static void unsignedLongIvarSetFunc(void* info1, void* info2, id self, id val) {
  unsigned long* ptr = (unsigned long*)((char*)self + (unsigned long)info2);
  *ptr = [val unsignedLongValue];
}


/* long long type */

static id longLongMethodGetFunc(void* info1, void* info2, id self) {
  long long (*fptr)(id, SEL) = (long long(*)(id, SEL))info1;
  long long val = fptr(self, (SEL)info2);
  return [NumberClass numberWithLongLong:val];
}

static id longLongIvarGetFunc(void* info1, void* info2, id self) {
  long long* ptr = (long long*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithLongLong:*ptr];
}

static void longLongMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, long long) = (void(*)(id, SEL, long long))info1;
  fptr(self, (SEL)info2, [val longLongValue]);
}

static void longLongIvarSetFunc(void* info1, void* info2, id self, id val) {
  long long* ptr = (long long*)((char*)self + (unsigned long)info2);
  *ptr = [val longLongValue];
}


/* unsigned long long type */

static id unsignedLongLongMethodGetFunc(void* info1, void* info2, id self) {
  unsigned long long (*fptr)(id, SEL) = (unsigned long long(*)(id, SEL))info1;
  unsigned long long val = fptr(self, (SEL)info2);
  return [NumberClass numberWithUnsignedLongLong:val];
}

static id unsignedLongLongIvarGetFunc(void* info1, void* info2, id self) {
  unsigned long long* ptr = (unsigned long long*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithUnsignedLongLong:*ptr];
}

static void unsignedLongLongMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, unsigned long long) = (void(*)(id, SEL, unsigned long long))info1;
  fptr(self, (SEL)info2, [val unsignedLongLongValue]);
}

static void unsignedLongLongIvarSetFunc(void* info1, void* info2, id self, id val) {
  unsigned long long* ptr = (unsigned long long*)((char*)self + (unsigned long)info2);
  *ptr = [val unsignedLongLongValue];
}


/* float */

static id floatMethodGetFunc(void* info1, void* info2, id self) {
  float (*fptr)(id, SEL) = (float(*)(id, SEL))info1;
  float val = fptr(self, (SEL)info2);
  return [NumberClass numberWithFloat:val];
}

static id floatIvarGetFunc(void* info1, void* info2, id self) {
  float* ptr = (float*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithFloat:*ptr];
}

static void floatMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, float) = (void(*)(id, SEL, float))info1;
  fptr(self, (SEL)info2, [val floatValue]);
}

static void floatIvarSetFunc(void* info1, void* info2, id self, id val) {
  float* ptr = (float*)((char*)self + (unsigned long)info2);
  *ptr = [val floatValue];
}


/* double */

static id doubleMethodGetFunc(void* info1, void* info2, id self) {
  double (*fptr)(id, SEL) = (double(*)(id, SEL))info1;
  double val = fptr(self, (SEL)info2);
  return [NumberClass numberWithDouble:val];
}

static id doubleIvarGetFunc(void* info1, void* info2, id self) {
  double* ptr = (double*)((char*)self + (unsigned long)info2);
  return [NumberClass numberWithDouble:*ptr];
}

static void doubleMethodSetFunc(void* info1, void* info2, id self, id val) {
  void (*fptr)(id, SEL, double) = (void(*)(id, SEL, double))info1;
  fptr(self, (SEL)info2, [val doubleValue]);
}

static void doubleIvarSetFunc(void* info1, void* info2, id self, id val) {
  double* ptr = (double*)((char*)self + (unsigned long)info2);
  *ptr = [val doubleValue];
}

#else /* NeXT_Foundation_LIBRARY */

@implementation NSArray(EOKeyValueCoding)

- (id)computeSumForKey:(NSString *)_key {
  static Class    NSDecimalNumberClass;
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *sum;

  if (NSDecimalNumberClass == Nil)
    NSDecimalNumberClass = [NSDecimalNumber class];

  sum = [NSDecimalNumber zero];
  if (cc == 0) return sum;

  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];

  for (i = 0; i < cc; i++) {
    register id o;
    
    o = objAtIdx(self, @selector(objectAtIndex:), i);
    o = [o valueForKey:_key];

    if (![o isKindOfClass:NSDecimalNumberClass])
      o = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:[o doubleValue]];
    sum = [sum decimalNumberByAdding:o];
  }
  return sum;
}

- (id)computeAvgForKey:(NSString *)_key {
  unsigned        cc = [self count];
  NSDecimalNumber *sum, *div;
    
  if (cc == 0) return nil;
  
  sum = [self computeSumForKey:_key];
  div = (NSDecimalNumber *)[NSDecimalNumber numberWithUnsignedInt:cc];
  return [sum decimalNumberByDividingBy:div];
}

- (id)computeCountForKey:(NSString *)_key {
  return [NSNumber numberWithUnsignedInt:[self count]];
}

- (id)computeMaxForKey:(NSString *)_key {
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *max;
  
  if (cc == 0) return nil;

  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];
  max      = [objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key];

  for (i = 1; i < cc; i++) {
    register id o;
      
    o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
    if ([max compare:o] == NSOrderedAscending)
      max = o;
  }
  return max;
}

- (id)computeMinForKey:(NSString *)_key {
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *min;
  
  if (cc == 0) return nil;
  
  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];
  min      = [objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key];

  for (i = 1; i < cc; i++) {
    register id o;
    
    o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
    if ([min compare:o] == NSOrderedDescending)
      min = o;
  }
  return min;
}

- (id)valueForKey:(NSString *)_key {
  if (null == nil) null = [[EONull null] retain];
  
  if ([_key hasPrefix:@"@"]) {
    /* process a computed function */
    const char *keyStr;
    char       *bufPtr;
    unsigned   keyLen = [_key cStringLength];
    char       *kbuf, *buf;
    SEL        sel;

    kbuf = malloc(keyLen + 1);
    buf  = malloc(keyLen + 16);
    [_key getCString:kbuf];
    keyStr = kbuf;
    bufPtr = buf;
    strcpy(buf, "compute");       bufPtr += 7;
    *bufPtr = toupper(keyStr[1]); bufPtr++;
    strncpy(&(buf[8]), &(keyStr[2]), keyLen - 2); bufPtr += (keyLen - 2);
    strcpy(bufPtr, "ForKey:");
    if (kbuf) free(kbuf);

#if NeXT_RUNTIME
    sel = sel_getUid(buf);
#else    
    sel = sel_get_any_uid(buf);
#endif
    if (buf) free(buf);
    
    return sel != NULL ? [self performSelector:sel withObject:_key] : nil;
  }
  else {
    /* process the _key in a map function */
    unsigned i, cc = [self count];
    NSArray  *result;
    id *objects;
    id (*objAtIdx)(id, SEL, unsigned int);

#if DEBUG
    if ([_key isEqualToString:@"count"]) {
      NSLog(@"WARNING(%s): USED -valueForKey(@\"count\") ON NSArray, YOU"
            @"PROBABLY WANT TO USE @count INSTEAD !",
            __PRETTY_FUNCTION__);
      return [self valueForKey:@"@count"];
    }
#endif
    
    if (cc == 0) return [NSArray array];
    
    objects = calloc(cc + 2, sizeof(id));
    objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];
    
    for (i = 0; i < cc; i++) {
      register id o;
      
      o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
      objects[i] = o ? o : (id)null;
    }
    
    result = [NSArray arrayWithObjects:objects count:cc];
    if (objects) free(objects);
    return result;
  }
}

@end /* NSArray(EOKeyValueCoding) */

#endif /* !NeXT_Foundation_LIBRARY */
