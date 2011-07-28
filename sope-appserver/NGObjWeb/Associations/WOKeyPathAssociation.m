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

#include "WOKeyPathAssociation.h"
#include <NGObjWeb/WOComponent.h>
#include "NSObject+WO.h"
#include "common.h"
#include <string.h>

#if __GNU_LIBOBJC__ == 20100911
#define METHOD_NULL NULL
#define object_is_instance(XXX) (XXX != nil)
#define class_get_class_method    class_getClassMethod
#define class_get_instance_method class_getInstanceMethod
#define sel_get_uid               sel_getUid
#define method_get_imp			  method_getImplementation	
typedef struct objc_method      *Method_t;

#endif

#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  include <objc/objc.h>
#  include <objc/objc-api.h>
#  define object_is_instance(XXX) (XXX != nil)
#if defined(APPLE_RUNTIME)
#  include <objc/objc-class.h>
#  define object_is_instance(XXX) \
    ((XXX != nil) && CLS_ISCLASS(*((Class *)XXX)))
#endif

#define method_get_imp            method_getImplementation  
#  define METHOD_NULL NULL
#  define sel_get_uid               sel_getUid
#  define class_get_class_method    class_getClassMethod
#  define class_get_instance_method class_getInstanceMethod

#  define __CLS_INFO(cls)         ((cls)->info)
#  ifndef __CLS_ISINFO
#    define __CLS_ISINFO(cls, mask) ((__CLS_INFO(cls) & mask) == mask)
#  endif
#  ifndef CLS_ISCLASS
#    define CLS_ISCLASS(cls) ((cls) && __CLS_ISINFO(cls, CLS_CLASS))
#  endif
#endif

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
bool _CFDictionaryIsMutable(CFDictionaryRef dict);
#endif


/*
  WOKeyPathAssociation

  This is an association class for so called keypaths. It uses extensive 
  caching to reuse calculated method pointers.

  Note the -kvcIsPreferredInKeyPath method. It is used whether -valueForKey: 
  and -takeValue:forKey: has preference or the objects methods. In usual cases
  it can be assumed that -valueForKey has the preference, but not in the case 
  of

    WOSession, WOComponent, WOApplication, WOContext

  which use -valueForKey: as a fallback. Since -valueForKey: is defined as a
  category on NSObject it eliminates the caching scheme used.
*/

// TODO: properly use logging framework for debug messages
#if DEBUG
// #define HEAVY_DEBUG 1
// #define USE_EXCEPTION_HANDLERS 1
#endif

#if USE_EXCEPTION_HANDLERS
#  warning using local exception handlers in associations, slows down templates
#endif

typedef enum {
  WOKeyType_unknown = 0,
  WOKeyType_kvc     = 1,
  WOKeyType_method  = 2,
  WOKeyType_ivar    = 3,
  WOKeyType_binding = 4
} WOKeyType;

typedef union {
  void           *ivar;
  IMP            method; // real method or takeValue:ForKey:
  char           (*cmethod) (id, SEL);
  unsigned char  (*ucmethod)(id, SEL);
  int            (*imethod) (id, SEL);
  unsigned int   (*uimethod)(id, SEL);
  long long      (*llmethod) (id, SEL);
  unsigned long long (*ullmethod)(id, SEL);
  short          (*smethod) (id, SEL);
  unsigned short (*usmethod)(id, SEL);
  const char *   (*strmethod)(id, SEL);
  float          (*fmethod)(id, SEL);
  double         (*dmethod)(id, SEL);
} WOGetMethodType;

typedef union {
  IMP  method; // real method or takeValue:ForKey:
  void (*omethod)  (id, SEL, id);
  void (*cmethod)  (id, SEL, char);
  void (*ucmethod) (id, SEL, unsigned char);
  void (*imethod)  (id, SEL, int);
  void (*uimethod) (id, SEL, unsigned int);
  void (*llmethod) (id, SEL, long long);
  void (*ullmethod) (id, SEL, unsigned long long);
  void (*smethod)  (id, SEL, short);
  void (*usmethod) (id, SEL, unsigned short);
  void (*strmethod)(id, SEL, const char *);
  void (*fmethod)  (id, SEL, float);
  void (*dmethod)  (id, SEL, double);
} WOSetMethodType;

typedef struct {
  unsigned char   *ckey;
  short           keyLen:12;
  short           isFault:1;
  WOKeyType       type:3;
  id              object;
  Class           isa;
  WOGetMethodType access;
  union {
    NSString *key; // for valueForKey:
    struct {
      SEL get; // get method selector
    } sel;
  } extra;
  unsigned char retType;
} WOKeyPathComponent;

typedef union {
  id             object;
  const char     *cstr;
  int            sint;
  unsigned int   uint;
  long long      llong;
  unsigned long long ullong;
  short          ss;
  unsigned short us;
  unsigned char  c;
  float          flt;
  double         dbl;
} WOReturnValueHolder;

#define intNumObj(__VAL__) \
  (__VAL__==0?inum0:(__VAL__==1?inum1:[NumberClass numberWithInt:__VAL__]))

#define uintNumObj(__VAL__) \
  (__VAL__ ==0 ? uinum0 : \
  (__VAL__==1?uinum1:[NumberClass numberWithUnsignedInt:__VAL__]))

@implementation WOKeyPathAssociation

+ (int)version {
  return 2;
}

static Class NumberClass = Nil;
static Class StringClass = Nil;
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
static Class NSCFDictionaryClass = Nil;
#endif
static int debugOn = -1;

#define IS_NUMSTR(__VAL__)  (__VAL__>=0 && __VAL__<50)
#define IS_UNUMSTR(__VAL__) (__VAL__<50)
static NSString *numStrings[] = {
  @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",
  @"10", @"11", @"12", @"13", @"14", @"15", @"16", @"17", @"18", @"19",
  @"20", @"21", @"22", @"23", @"24", @"25", @"26", @"27", @"28", @"29",
  @"30", @"31", @"32", @"33", @"34", @"35", @"36", @"37", @"38", @"39",
  @"40", @"41", @"42", @"43", @"44", @"45", @"46", @"47", @"48", @"49"
};
static NSNumber *inum0  = nil, *inum1  = nil;
static NSNumber *uinum0 = nil, *uinum1 = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;

  if (isInitialized) return;
  isInitialized = YES;
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  
  debugOn = [[[NSUserDefaults standardUserDefaults]
                              objectForKey:@"WODebugKeyPathAssociation"]
                              boolValue] ? 1 : 0;
  
  NumberClass = [NSNumber class];
  StringClass = [NSString class];
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
  NSCFDictionaryClass = NSClassFromString(@"NSCFDictionary");
#endif

  inum0  = [[NumberClass numberWithInt:0] retain];
  inum1  = [[NumberClass numberWithInt:1] retain];
  uinum0 = [[NumberClass numberWithUnsignedInt:0] retain];
  uinum1 = [[NumberClass numberWithUnsignedInt:1] retain];
}

static inline WOKeyPathComponent *
_getComponent(register WOKeyPathAssociation *self, register unsigned _idx)
{
  return (WOKeyPathComponent *)
    (self->keyPath + (_idx * sizeof(WOKeyPathComponent)));
}

static inline void _freeKeyPathComponent(WOKeyPathComponent *info) {
  if (info->ckey) {
    free(info->ckey);
    info->ckey = NULL;
  }
  if ((info->type == WOKeyType_kvc) || (info->type == WOKeyType_binding)) {
    [info->extra.key release];
    info->extra.key = nil;
  }
  info->object = nil;
  info->isa    = Nil;
}

static inline void
_parseKeyPath(WOKeyPathAssociation *self,NSString *_keyPath)
{
  unsigned keyLen = [_keyPath cStringLength];
  char *buf;
  char *cstr;
  char *tmp;

  buf = malloc(keyLen + 1);
  cstr = buf;
  tmp = (char *)cstr;
  [_keyPath getCString:buf]; buf[keyLen] = '\0';
  
  // get number of components
  self->size = 1;
  while (*tmp) {
    if (*tmp == '.') (self->size)++;
    tmp++;
  }
  
  self->keyPath = calloc(self->size, sizeof(WOKeyPathComponent));
  
  // transfer components
  {
    unsigned char pos;

    tmp = (char *)cstr;
    for (pos = 0; pos < self->size; pos++) {
      WOKeyPathComponent *info = _getComponent(self, pos);
      
      // goto end or next '.'
      while ((*tmp != '\0') && (*tmp != '.'))
        tmp++;
      
      info->keyLen = (tmp - cstr);
      info->ckey   = malloc(info->keyLen + 4);
      memcpy(info->ckey, cstr, info->keyLen);
      info->ckey[info->keyLen] = '\0';

      NSCAssert(strlen((char *)info->ckey) > 0, @"invalid ckey ..");
      NSCAssert((int)strlen((char *)info->ckey) == (int)info->keyLen, 
                @"size and content differ");
      
      info->object = nil;
      info->isa    = Nil;
      info->type   = WOKeyType_unknown;
      
      cstr = tmp + 1;
      tmp  = (char *)cstr;
    }
  }
  free(buf);
}
  
- (id)initWithKeyPath:(NSString *)_keyPath {
  if ([_keyPath length] < 1) {
    self = [self autorelease];
    self = nil;
    [self errorWithFormat:
            @"passed invalid keypath (%@) to association !", _keyPath];
    return nil;
  }
  if ((self = [super init])) {
    _parseKeyPath(self, _keyPath);
  }
  return self;
}
- (id)init {
  [self errorWithFormat:@"keypaths can not be created using 'init' .."];
  [NSException raise:@"InvalidUseOfMethodException"
               format:@"keypaths can not be created using 'init'"];
  return nil;
}

- (void)dealloc {
  if (self->keyPath != NULL) {
    int cnt;
    
    for (cnt = 0; cnt < self->size; cnt++)
      _freeKeyPathComponent(_getComponent(self, cnt));
    
    free(self->keyPath);
  }
  [super dealloc];
}

/* accessors */

- (NSString *)keyPath {
  register unsigned char pos;
  char     *buffer;
  unsigned len;

  // get size
  len = self->size; // size-1 '.' chars and the '\0' char
  for (pos = 0; pos < self->size; pos++) {
    WOKeyPathComponent *info = _getComponent(self, pos);
    len += info->keyLen;
  }
  buffer = malloc(len + 4);
  
  // transfer contents
  for (pos = 0, len = 0; pos < self->size; pos++) {
    WOKeyPathComponent *info = _getComponent(self, pos);

    if (pos != 0) {
      buffer[len] = '.';
      len++;
    }
    memcpy(&(buffer[len]), info->ckey, info->keyLen);
    len += info->keyLen;
  }
  buffer[len] = '\0';

  return [[[StringClass alloc] initWithCStringNoCopy:buffer
			       length:len
			       freeWhenDone:YES]
	                       autorelease];
}
- (id)initWithString:(NSString *)_s {
  return [self initWithKeyPath:_s];
}

/* value */

static inline void _fillInfo(WOKeyPathAssociation *self, id object,
                             WOKeyPathComponent *info) 
{
  Class clazz      = [object class];
  BOOL  needRefill = NO;
  
  if (info->isFault)
    needRefill = YES;
  else if (info->type == WOKeyType_unknown) // first invocation of 'value'
    needRefill = YES;
  else if ((info->object == nil) || (object == nil))
    needRefill = YES;
  else if (info->isa != clazz)
    needRefill = YES;
  else if (info->object != object)
    needRefill = YES;
  
  if (!needRefill)
    // object is the same, can use cached representation
    return;

  {
#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
	struct objc_method *method = NULL;
#else
    Method_t method = METHOD_NULL;
#endif
    
    if ((info->type == WOKeyType_kvc) || (info->type == WOKeyType_binding)) {
      /* release old key */
      [info->extra.key release];
      info->extra.key = nil;
    }
    
    info->type    = WOKeyType_unknown;
    info->retType = _C_ID;
    
    if (*(info->ckey) == '^') { /* a binding key */
      method = class_get_instance_method(clazz, @selector(valueForBinding:));
      info->type = WOKeyType_binding;
      info->extra.key =
        [[StringClass alloc] initWithCString:(char *)(info->ckey + 1)];
    }
    else {
      if (object != nil) {
        if (object_is_instance(object)) {
	  /*
	    kvcIsPreferredInKeyPath means that for some objects the keys will
	    be probed first. The prominent example is NSDictionary, if you
	    say valueForKey:@"count" you want to resolve to the 'count' key
	    stored in the dictionary, NOT to the -count method of the
	    NSDictionary class.
	  */
          if ([object kvcIsPreferredInKeyPath]) {
            method = class_get_instance_method(clazz, @selector(valueForKey:));
            
            if (method != METHOD_NULL) {
              info->type      = WOKeyType_kvc;
              info->extra.key = 
		[[StringClass alloc] initWithCString:(char *)info->ckey];
            }
            else {
              info->extra.sel.get = sel_get_uid((char *)info->ckey);
              method = class_get_instance_method(clazz, info->extra.sel.get);
              if (method != METHOD_NULL)
                info->type = WOKeyType_method;
            }
          }
          else {
            info->extra.sel.get = sel_get_uid((char *)info->ckey);
            method = class_get_instance_method(clazz, info->extra.sel.get);
            
            if (method != METHOD_NULL)
              info->type = WOKeyType_method;
            else {
              method =
                class_get_instance_method(clazz, @selector(valueForKey:));
              if (method != METHOD_NULL) {
                info->type      = WOKeyType_kvc;
                info->extra.key = 
		  [[StringClass alloc] initWithCString:(char *)info->ckey];
              }
            }
          }
        }
        else { /* object is a class */
          method = class_get_class_method(object, @selector(valueForKey:));
          if (method != METHOD_NULL) {
            info->type      = WOKeyType_kvc;
            info->extra.key = 
	      [[StringClass alloc] initWithCString:(char *)info->ckey];
          }
          else {
            info->extra.sel.get = sel_get_uid((char *)info->ckey);
            method =
              class_get_class_method(*(Class *)object, info->extra.sel.get);
            if (method != METHOD_NULL) {
              info->type = WOKeyType_method;
            }
          }
        }
      }
    }
    info->object  = object;
    info->isa     = [object class];
    info->isFault = [object isFault];
    
    if (method != METHOD_NULL) {
      info->access.method = method_get_imp(method);
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
      info->retType = *(method_getTypeEncoding(method));
#else
	  info->retType = *(method->method_types);
#endif
    }

#if HEAVY_DEBUG
    [self logWithFormat:@"type is %i, key is '%s'", info->type, info->ckey];
#endif
  }
}

- (NSException *)handleGetException:(NSException *)_exception  {
  static NSString *excKey    = @"exception";
  static NSString *kpKey     = @"keyPath";
  static NSString *assocKey  = @"association";
  static NSString *excName   = @"WOKeyPathException";
  static NSString *excReason = @"could not get value for a keypath component";
  NSException  *e;
  NSDictionary *ui;
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                       _exception,     excKey,
                       [self keyPath], kpKey,
                       self,           assocKey,
                     nil];
  
  e = [[NSException alloc] initWithName:excName
                           reason:excReason
                           userInfo:ui];
  return e;
}

static WOReturnValueHolder _getComponentValue(WOKeyPathAssociation *self,
                                              id object,
                                              WOKeyPathComponent *info)
{
  WOReturnValueHolder retValue;
  
#if DEBUG
  NSCAssert1(info, @"%s: missing info !", __PRETTY_FUNCTION__);
#endif
  
  _fillInfo(self, object, info);
  
  // execute
  if (info->type == WOKeyType_method) {
#if HEAVY_DEBUG
    [self logWithFormat:@"get key %s of keyPath %@\n"
	  @"  from: 0x%p[%@]\n"
	  @"  via method (ret %c)", 
	  info->ckey, [self keyPath], object, 
	  NSStringFromClass([object class]), info->retType];
#endif
#if USE_EXCEPTION_HANDLERS
    NS_DURING {
#endif
      if ((info->retType == _C_ID) || (info->retType == _C_CLASS)) {
        retValue.object = info->access.method(object, info->extra.sel.get);
#if HEAVY_DEBUG
	[self logWithFormat:@"  got result 0x%p[%@]: %@", retValue.object,
	      NSStringFromClass([retValue.object class]),
	      retValue.object];
#endif
      }
      else {
        switch (info->retType) {
          case _C_ID:
          case _C_CLASS:
            retValue.object = info->access.method(object, info->extra.sel.get);
            break;
          case _C_VOID:
            retValue.object = object;
            break;
            
          case _C_CHR:
          case _C_UCHR:
            retValue.c = info->access.ucmethod(object, info->extra.sel.get);
            break;
          
          case _C_INT:
            retValue.sint = info->access.imethod(object, info->extra.sel.get);
            break;
          case _C_UINT:
            retValue.uint = info->access.uimethod(object, info->extra.sel.get);
            break;

          case _C_LNG_LNG:
            retValue.llong = info->access.llmethod(object, info->extra.sel.get);
            break;
          case _C_ULNG_LNG:
            retValue.ullong = info->access.ullmethod(object, info->extra.sel.get);
            break;

          case _C_SHT:
            retValue.ss = info->access.smethod(object, info->extra.sel.get);
            break;
          case _C_USHT:
            retValue.us = info->access.usmethod(object, info->extra.sel.get);
            break;

          case _C_FLT:
            retValue.flt = info->access.fmethod(object, info->extra.sel.get);
            break;
        
          case _C_DBL:
            retValue.dbl = info->access.dmethod(object, info->extra.sel.get);
            break;

          case _C_CHARPTR:
            retValue.cstr = info->access.strmethod(object, info->extra.sel.get);
            break;

          default:
            [self errorWithFormat:@"unsupported type '%c' !", info->retType];
            [NSException raise:@"WORuntimeException"
                         format:
                         @"in WOKeyPathAssociation %@: unsupported type '%c'",
                         self, info->retType];
            break;
        }
      }
#if USE_EXCEPTION_HANDLERS
    }
    NS_HANDLER
      [[self handleGetException:localException] raise];
    NS_ENDHANDLER;
#endif
  }
  else if (info->type == WOKeyType_kvc) {
#if HEAVY_DEBUG
    [self logWithFormat:@"get keyPath %@ from %@ via KVC",
	    [self keyPath], object];
#endif
#if 0
    NSLog(@"ckey:      %s", info->ckey);
    NSLog(@"key-class: %s", (*(Class *)info->extra.key)->name);
    NSLog(@"key:       %@", info->extra.key);
#endif

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector collectGarbages];
#endif
    
    retValue.object =
      info->access.method(object, @selector(valueForKey:), info->extra.key);
  }
  else if (info->type == WOKeyType_binding) {
#if HEAVY_DEBUG
    [self logWithFormat:@"get keyPath %@ from %@ via binding", 
	    [self keyPath], object];
#endif
    
    retValue.object =
      info->access.method(object, @selector(valueForBinding:), info->extra.key);
  }
  else { // unknown || ivar
#if HEAVY_DEBUG
    [self logWithFormat:@"unknown info type for keyPath %@ from %@ !!",
          [self keyPath], object];
#endif
    retValue.object = nil;
  }

  return retValue;
}

static inline id _objectify(unsigned char _type, WOReturnValueHolder *_value) {
  id result = nil;

  //[self logWithFormat:@"shall convert value of type '%c'", _type];
  
  switch (_type) {
    case _C_ID:
    case _C_CLASS:
      result = _value->object;
      break;
      
    case _C_VOID:
      result = _value->object;
      break;
      
    case _C_CHR:
    case _C_UCHR:
      result = [NumberClass numberWithUnsignedChar:_value->c];
      break;
      
    case _C_INT:
      result = intNumObj(_value->sint);
      break;
    case _C_UINT:
      result = uintNumObj(_value->uint);
      break;
    case _C_LNG_LNG:
      result = [NumberClass numberWithLongLong:_value->llong];
      break;
    case _C_ULNG_LNG:
      result = [NumberClass numberWithUnsignedLongLong:_value->llong];
      break;
    case _C_SHT:
      result = [NumberClass numberWithShort:_value->ss];
      break;
    case _C_USHT:
      result = [NumberClass numberWithUnsignedShort:_value->us];
      break;
    case _C_FLT:
      result = [NumberClass numberWithFloat:_value->flt];
      break;
    case _C_DBL:
      result = [NumberClass numberWithDouble:_value->dbl];
      break;

    case _C_CHARPTR:
      result = _value->cstr
        ? [StringClass stringWithCString:_value->cstr]
        : nil;
      break;
            
    default:
      NSLog(@"%s: unsupported type '%c' !", __PRETTY_FUNCTION__, _type);
      [NSException raise:@"WORuntimeException"
                   format:@"in WOKeyPathAssociation: unsupported type '%c'",
                     _type];
      break;
  }

  // NSLog(@"made %@[0x%p].", NSStringFromClass([result class]), result);
  
  return result;
}

static inline id
_getValueN(WOKeyPathAssociation *self, unsigned _count, id root)
{
  register unsigned cnt;
  id object = root;

  for (cnt = 0; (cnt < _count) && (object != nil); cnt++) {
    WOKeyPathComponent  *info;
    WOReturnValueHolder retValue;
    
    info     = _getComponent(self, cnt);
#if DEBUG
    NSCAssert1(info, @"%s: missing info !", __PRETTY_FUNCTION__);
#endif
    retValue = _getComponentValue(self, object, info);
    
    object = (info->type == WOKeyType_method)
      ? _objectify(info->retType, &retValue)
      : retValue.object;
  }

  //NSLog(@"object %@ for keyPath %@", object, [self keyPath]);

  return object;
}

static inline id _getValue(WOKeyPathAssociation *self, id root) {
  return _getValueN(self, self->size, root);
}

static id _getOneValue(WOKeyPathAssociation *self, id root) {
  WOKeyPathComponent  *info;
  WOReturnValueHolder retValue;

  info     = (WOKeyPathComponent *)self->keyPath;
  retValue = _getComponentValue(self, root, info);

  return (info->type == WOKeyType_method)
    ? _objectify(info->retType, &retValue)
    : retValue.object;
}

static inline void _getSetSelName(register unsigned char *buf,
                                  register const unsigned char *_key,
                                  register unsigned _len) {
  buf[0] = 's';
  buf[1] = 'e';
  buf[2] = 't';

  switch (_len) {
    case 0: break;

    case 1:
      buf[3] = _key[0];
      break;
    case 2:
      buf[3] = _key[0]; buf[4] = _key[1];
      break;
    case 3:
      buf[3] = _key[0]; buf[4] = _key[1]; buf[5] = _key[2];
      break;
    case 4:
      buf[3] = _key[0]; buf[4] = _key[1]; buf[5] = _key[2];
      buf[6] = _key[3]; break;
    case 5:
      buf[3] = _key[0]; buf[4] = _key[1]; buf[5] = _key[2];
      buf[6] = _key[3]; buf[7] = _key[4];
      break;
    case 6:
      buf[3] = _key[0]; buf[4] = _key[1]; buf[5] = _key[2];
      buf[6] = _key[3]; buf[7] = _key[4]; buf[8] = _key[5];
      break;
      
    default:
      memcpy(&(buf[3]), _key, _len);
      break;
  }
  buf[3] = toupper(buf[3]);
  buf[_len + 3] = ':';
  buf[_len + 4] = '\0';
}
static inline SEL _getSetSel(register const unsigned char *_key,
                             register unsigned _len) {
  unsigned char buf[259];
  _getSetSelName(buf, _key, _len);
  return sel_get_uid((char *)buf);
}

static BOOL _setValue(WOKeyPathAssociation *self, id _value, id root) {
  WOKeyPathComponent *info;
  id object = root;
  
  if (self->size > 1)
    object = _getValueN(self, self->size - 1, root);

  if (object == nil) // nothing to set ..
    return YES; // receiver == nil isn't an error condition

  info = _getComponent(self, self->size - 1);
  NSCAssert(info->keyLen < 255, @"keysize to big ..");

  _fillInfo(self, object, info);

  if (info->type == WOKeyType_method) { // determine set-selector
    SEL setSel = _getSetSel(info->ckey, info->keyLen);
      
    if (![object respondsToSelector:setSel]) {
#if 0
      [self errorWithFormat:@"Could not set value for key '%s', "
              @"object %@ doesn't respond to %@.",
              info->ckey, object,
              setSel ? NSStringFromSelector(setSel) : @"<NULL>"];
#endif
      return NO;
    }
    
    /* object responds to the selector */
    {
      WOSetMethodType sm;

      if ((sm.method = [object methodForSelector:setSel]) != NULL) {
        switch (info->retType) {
          case _C_CLASS:
          case _C_ID:
            sm.omethod(object, setSel, _value);
            break;

          case _C_CHR:
            sm.cmethod(object, setSel,
                       [(id<NGBaseTypeValues>)_value charValue]);
            break;
          case _C_UCHR:
            sm.ucmethod(object, setSel, [_value unsignedCharValue]);
            break;

          case _C_SHT:
            sm.smethod(object, setSel, [_value shortValue]);
            break;
          case _C_USHT:
            sm.usmethod(object, setSel, [_value unsignedShortValue]);
            break;
            
          case _C_INT:
            sm.imethod(object, setSel, [_value intValue]);
            break;
          case _C_UINT:
            sm.uimethod(object, setSel, [_value unsignedIntValue]);
            break;

          case _C_LNG_LNG:
            sm.llmethod(object, setSel, [_value longLongValue]);
            break;
          case _C_ULNG_LNG:
            sm.ullmethod(object, setSel, [_value unsignedLongLongValue]);
            break;

          case _C_FLT:
            sm.fmethod(object, setSel, [_value floatValue]);
            break;
        
          case _C_DBL:
            sm.dmethod(object, setSel, [_value doubleValue]);
            break;

          case _C_CHARPTR:
            if (_value == nil)
              sm.strmethod(object, setSel, NULL);
            else {
              unsigned clen;
              if ((clen = [_value cStringLength]) == 0)
                sm.strmethod(object, setSel, "");
              else {
                char *buf;
                buf = malloc(clen + 4);
                [_value getCString:buf]; buf[clen] = '\0';
                sm.strmethod(object, setSel, buf);
		if (buf != NULL) free(buf);
              }
            }
            break;
            
          default:
            [self errorWithFormat:
		    @"cannot set type '%c' yet (key=%s, method=%@) ..",
                    info->retType, info->ckey,
                    NSStringFromSelector(setSel)];
            [NSException raise:@"WORuntimeException"
                         format:
                           @"in WOKeyPathAssociation %@: "
                           @"cannot set type '%c' yet (key=%s, method=%@)",
                           self, info->retType, info->ckey,
                           NSStringFromSelector(setSel)];
            return NO;
        }
        return YES;
      }
      else {
        [self logWithFormat:@"did not find method %@ in object %@",
              NSStringFromSelector(setSel), object];
        return NO;
      }
    }
  }
  else if (info->type == WOKeyType_kvc) { // takeValue:forKey:..
    NSCAssert(info->extra.key, @"no key object set ..");

    /*
      The following check is necessary because starting with Cocoa Foundation
      v10.3? mutable and immutable dictionary objects are the same class :-(
      
      To make it worse the _CFDictionaryIsMutable is a private function which
      might vanish ...
    */
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
    if([object isKindOfClass:NSCFDictionaryClass] &&
       !_CFDictionaryIsMutable((CFDictionaryRef)object))
        return NO;
#endif

    /*
      TODO(hh): Maybe this needs improvement. For non-dictionary like objects
                (eg WOComponents) this code does the method scanning twice,
		first we scan the object for method 'key', then the Foundation
		KVC again scans for the 'key' method prior falling back to
		handleUnknownKey stuff ...
    */
    
#if GNUSTEP_BASE_LIBRARY && ((GNUSTEP_BASE_MAJOR_VERSION >= 1) && \
			     (GNUSTEP_BASE_MINOR_VERSION >= 11))
    // TODO: also do this for OSX 10.4? probably
    [object setValue:_value forKey:info->extra.key];
#else
    [object takeValue:_value forKey:info->extra.key];
#endif
    return YES;
  }
  else if (info->type == WOKeyType_binding) { // setValue:forBinding:
    NSCAssert(info->extra.key, @"no key object set ..");
    [object setValue:_value forBinding:info->extra.key];
    return YES;
  }
  else {
    // TODO: use errorWithFormat?
    [self logWithFormat:@"Could not set value for key '%s'.", info->ckey];
    return NO;
  }
}

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  if (debugOn)
    [self logWithFormat:@"set value %@ component %@", _value, _component];
  
  // we do not check the return value, because a set is allowed to fail
  // (in SOPE ;-) [if there is no accessor, a backsync is just ignored]
#if 1
  _setValue(self, _value, _component);
#else
  if (!_setValue(self, _value, _component)) {
    [self logWithFormat:@"could not set value %@ component %@",
	  _value, _component];
  }
#endif
}
- (id)valueInComponent:(WOComponent *)_component {
#if DEBUG
  volatile id result;
  if (debugOn)
    [self logWithFormat:@"get value in component %@", _component];
  
#if USE_EXCEPTION_HANDLERS
  NS_DURING {
#endif
    result = (self->size > 1)
      ? _getValue(self, _component)
      : _getOneValue(self, _component);
#if USE_EXCEPTION_HANDLERS
  }
  NS_HANDLER {
    fprintf(stderr, "during evaluation of keypath %s:\n  %s\n",
            [[self description] cString],
            [[localException description] cString]);
    fflush(stderr);
    [localException raise];
  }
  NS_ENDHANDLER;
#endif
  
  return result;
  
#else /* !DEBUG */
  if (debugOn)
    [self logWithFormat:@"get value in component %@", _component];
  
  return (self->size > 1)
    ? _getValue(self, _component)
    : _getOneValue(self, _component);
#endif
}

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return YES;
}

/* special values */

- (void)setUnsignedIntValue:(unsigned int)_value
  inComponent:(WOComponent *)_wo
{
  WOKeyPathComponent *info;
  
  if (debugOn)
    [self logWithFormat:@"set uint value %i in component %@", _value, _wo];
  
  if (self->size > 1) {
    _setValue(self, uintNumObj(_value), _wo);
    return;
  }

  info = (WOKeyPathComponent *)self->keyPath;
  NSCAssert(info->keyLen < 255, @"keysize to big ..");
    
  _fillInfo(self, _wo, info);
    
  if (info->type == WOKeyType_method) { /* determine set-selector */
    if (info->retType == _C_CHR || info->retType == _C_UCHR ||
	info->retType == _C_INT || info->retType == _C_UINT ||
	info->retType == _C_LNG_LNG || info->retType == _C_ULNG_LNG) {
      SEL             setSel;
      WOSetMethodType sm;
        
      setSel = _getSetSel(info->ckey, info->keyLen);
      sm.method = [_wo methodForSelector:setSel];
      NSAssert1(sm.method, @"didn't find method for key %s", info->ckey);
        
      switch (info->retType) {
          case _C_CHR: {
            if (((int)_value < -126) || ((int)_value > 127))
              [self errorWithFormat:
		      @"value (%i) out of range for char!", _value];
            sm.cmethod(_wo, setSel, (char)_value);
            break;
          }
          case _C_UCHR: {
            if ((_value < 0) || (_value > 255))
              [self errorWithFormat:
		      @"value (%i) out of range for uchar!", _value];
            sm.ucmethod(_wo, setSel, (unsigned char)_value);
            break;
          }
          case _C_INT: {
            sm.imethod(_wo, setSel, (int)_value);
            break;
          }
          case _C_UINT: {
            sm.uimethod(_wo, setSel, (unsigned int)_value);
            break;
          }
          case _C_LNG_LNG: {
            sm.llmethod(_wo, setSel, (long long)_value);
            break;
          }
          case _C_ULNG_LNG: {
            sm.ullmethod(_wo, setSel, (unsigned long long)_value);
            break;
          }

          default:
            [NSException raise:@"WORuntimeException"
                         format:
                           @"in WOKeyPathAssociation %@: "
                           @"does not handle type %c",
                           self, info->retType];
            break;
      }
    }
    else {
      // usual setValue
        _setValue(self, uintNumObj(_value), _wo);
    }
    return;
  }

  if (info->type == WOKeyType_kvc) { // takeValue:forKey:..
    NSCAssert(info->extra.key, @"no key object set ..");
    [_wo takeValue:uintNumObj(_value) forKey:info->extra.key];
    return;
  }
  if (info->type == WOKeyType_binding) { // setValue:forBinding:
    NSCAssert(info->extra.key, @"no key object set ..");
    [_wo setValue:uintNumObj(_value) forBinding:info->extra.key];
    return;
  }
  
  [self errorWithFormat:@"Could not set value for key '%s'.", info->ckey];
}
- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component {
  WOKeyPathComponent  *info;
  WOReturnValueHolder retValue;
    
  if (debugOn)
    [self logWithFormat:@"get uint value in component %@", _component];
  
  if (self->size > 1)
    return [_getValue(self, _component) unsignedIntValue];

  info     = (WOKeyPathComponent *)self->keyPath;
  retValue = _getComponentValue(self, _component, info);

  if (info->type == WOKeyType_method) {
    switch (info->retType) {
      case _C_UINT: return retValue.uint;
      case _C_INT:  return retValue.sint;
      case _C_ULNG_LNG: return (unsigned int) retValue.ullong;
      case _C_LNG_LNG:  return (signed int) retValue.llong;
      case _C_UCHR: return retValue.c;
      case _C_CHR:  return retValue.c;
      case _C_SHT:  return retValue.ss;
      case _C_USHT: return retValue.us;
    }
    return [_objectify(info->retType, &retValue) unsignedIntValue];
  }

#if 0
  [self logWithFormat:@"ret value object for key '%s' is 0x%p",
	info->ckey, retValue.object];
  [self logWithFormat:@"ret value object class is %@", 
	[retValue.object class]];
#endif
  return [retValue.object unsignedIntValue];
}

- (void)setIntValue:(int)_value inComponent:(WOComponent *)_wo {
  WOKeyPathComponent *info;
  
  if (debugOn)
    [self logWithFormat:@"set int value %i in component %@", _value, _wo];
  
  if (self->size > 1) {
    _setValue(self, intNumObj(_value), _wo);
    return;
  }

  info = (WOKeyPathComponent *)self->keyPath;
  NSCAssert(info->keyLen < 255, @"keysize to big ..");
    
  _fillInfo(self, _wo, info);
    
  if (info->type == WOKeyType_method) { // determine set-selector
      if (info->retType == _C_CHR || info->retType == _C_UCHR ||
          info->retType == _C_INT || info->retType == _C_UINT ||
          info->retType == _C_LNG_LNG || info->retType == _C_ULNG_LNG) {
        SEL             setSel;
        WOSetMethodType sm;
        
        setSel = _getSetSel(info->ckey, info->keyLen);
        sm.method = [_wo methodForSelector:setSel];
        NSAssert1(sm.method, @"didn't find method for key %s", info->ckey);
        
        switch (info->retType) {
          case _C_CHR: {
            if (((int)_value < -126) || ((int)_value > 127))
              [self errorWithFormat:
		      @"value (%i) out of range for char !", _value];
            sm.cmethod(_wo, setSel, (char)_value);
            break;
          }
          case _C_UCHR: {
            if ((_value < 0) || (_value > 255))
              [self errorWithFormat:
		      @"value (%i) out of range for uchar!", _value];
            sm.ucmethod(_wo, setSel, (unsigned char)_value);
            break;
          }
          case _C_INT: {
            sm.imethod(_wo, setSel, (int)_value);
            break;
          }
          case _C_UINT: {
            sm.uimethod(_wo, setSel, (unsigned int)_value);
            break;
          }
          case _C_LNG_LNG: {
            sm.llmethod(_wo, setSel, (long long)_value);
            break;
          }
          case _C_ULNG_LNG: {
            sm.ullmethod(_wo, setSel, (unsigned long long)_value);
            break;
          }

          default:
            [NSException raise:@"WORuntimeException"
                         format:
                           @"in WOKeyPathAssociation %@: "
                           @"does not handle type %c",
                           self, info->retType];
            break;
        }
      }
      else {
        // usual setValue
        _setValue(self, intNumObj(_value), _wo);
      }
      return;
  }

  if (info->type == WOKeyType_kvc) { // takeValue:forKey:
    NSCAssert(info->extra.key, @"no key object set ..");
    [_wo takeValue:intNumObj(_value) forKey:info->extra.key];
    return;
  }
  
  if (info->type == WOKeyType_binding) { // setValue:forBinding:
    NSCAssert(info->extra.key, @"no key object set ..");
    [_wo setValue:intNumObj(_value) forBinding:info->extra.key];
    return;
  }

  [self errorWithFormat:@"Could not set value for key '%s'.", info->ckey];
}
- (int)intValueInComponent:(WOComponent *)_component {
  WOKeyPathComponent  *info;
  WOReturnValueHolder retValue;

  if (debugOn)
    [self logWithFormat:@"get int value in component %@", _component];
  
  if (self->size > 1)
    return [_getValue(self, _component) intValue];

  info     = (WOKeyPathComponent *)self->keyPath;
  retValue = _getComponentValue(self, _component, info);

  if (info->type != WOKeyType_method)
    return [retValue.object intValue];

  switch (info->retType) {
    case _C_UINT: return retValue.uint;
    case _C_INT:  return retValue.sint;
    case _C_ULNG_LNG: return (unsigned int) retValue.ullong;
    case _C_LNG_LNG:  return (signed int) retValue.llong;
    case _C_UCHR: return retValue.c;
    case _C_CHR:  return retValue.c;
    case _C_SHT:  return retValue.ss;
    case _C_USHT: return retValue.us;
    default:      return [_objectify(info->retType, &retValue) intValue];
  }
}

- (void)setBoolValue:(BOOL)_value inComponent:(WOComponent *)_wo {
  WOKeyPathComponent *info;
  
  if (debugOn)
    [self logWithFormat:@"set bool value %i in component %@", _value, _wo];
  
  if (self->size > 1) {
    _setValue(self, [NumberClass numberWithBool:_value], _wo);
    return;
  }

  info = (WOKeyPathComponent *)self->keyPath;
  NSCAssert(info->keyLen < 255, @"keysize to big ..");
    
  _fillInfo(self, _wo, info);
    
  if (info->type == WOKeyType_method) { // determine set-selector
      if (info->retType == _C_CHR || info->retType == _C_UCHR ||
          info->retType == _C_INT || info->retType == _C_UINT ||
          info->retType == _C_LNG_LNG || info->retType == _C_ULNG_LNG) {
        SEL             setSel;
        WOSetMethodType sm;
        
        setSel = _getSetSel(info->ckey, info->keyLen);
        sm.method = [_wo methodForSelector:setSel];
        NSAssert1(sm.method, @"didn't find method for key %s", info->ckey);
        
        switch (info->retType) {
          case _C_CHR: {
            sm.cmethod(_wo, setSel, (char)_value);
            break;
          }
          case _C_UCHR: {
            sm.ucmethod(_wo, setSel, (unsigned char)_value);
            break;
          }
          case _C_INT: {
            sm.imethod(_wo, setSel, (int)_value);
            break;
          }
          case _C_UINT: {
            sm.uimethod(_wo, setSel, (unsigned int)_value);
            break;
          }
          case _C_LNG_LNG:
            sm.llmethod(_wo, setSel, (long long)_value);
            break;
          case _C_ULNG_LNG:
            sm.ullmethod(_wo, setSel, (unsigned long long)_value);
            break;

          default:
            [NSException raise:@"WORuntimeException"
                         format:
                           @"in WOKeyPathAssociation %@: "
                           @"does not handle type %c",
                           self, info->retType];
            break;
        }
      }
      else {
        // usual setValue
        _setValue(self, [NumberClass numberWithBool:_value], _wo);
      }
  }
  else if (info->type == WOKeyType_kvc) { // takeValue:forKey:
      NSCAssert(info->extra.key, @"no key object set ..");
      [_wo takeValue:[NumberClass numberWithBool:_value]
           forKey:info->extra.key];
  }
  else if (info->type == WOKeyType_binding) { // setValue:forBinding:
      NSCAssert(info->extra.key, @"no key object set ..");
      [_wo setValue:[NumberClass numberWithBool:_value]
           forBinding:info->extra.key];
  }
  else
    [self errorWithFormat:@"Could not set value for key '%s'.", info->ckey];
}
- (BOOL)boolValueInComponent:(WOComponent *)_component {
  if (debugOn)
    [self logWithFormat:@"get bool value in component %@", _component];
  
  if (self->size > 1)
    return [_getValue(self, _component) boolValue];
  else {
    WOKeyPathComponent  *info;
    WOReturnValueHolder retValue;

    info     = (WOKeyPathComponent *)self->keyPath;
    retValue = _getComponentValue(self, _component, info);

    if (info->type == WOKeyType_method) {
      switch (info->retType) {
        case _C_UINT: return retValue.uint;
        case _C_INT:  return retValue.sint;
        case _C_ULNG_LNG: return (retValue.ullong != 0);
        case _C_LNG_LNG:  return (retValue.llong != 0);
        case _C_UCHR: return retValue.c;
        case _C_CHR:  return retValue.c;
        case _C_SHT:  return retValue.ss;
        case _C_USHT: return retValue.us;

        default:
          return [_objectify(info->retType, &retValue) boolValue];
      }
    }
    else
      return [retValue.object boolValue];
  }
}

- (void)setStringValue:(NSString *)_value inComponent:(WOComponent *)_wo {
  if (debugOn)
    [self logWithFormat:@"set string value '%@' in component %@", _value, _wo];
  
  _setValue(self, _value, _wo);
}
- (NSString *)stringValueInComponent:(WOComponent *)_component {
  WOKeyPathComponent  *info;
  WOReturnValueHolder retValue;
  
  if (debugOn)
    [self logWithFormat:@"get string value in component %@", _component];
  
  if (self->size > 1)
    return [_getValue(self, _component) stringValue];

  info     = (WOKeyPathComponent *)self->keyPath;
  retValue = _getComponentValue(self, _component, info);

  if (info->type != WOKeyType_method)
    return [retValue.object stringValue];

  switch (info->retType) {
    case _C_UINT:
      if (IS_UNUMSTR(retValue.uint)) return numStrings[retValue.uint];
      return [StringClass stringWithFormat:@"%u", retValue.uint];
    case _C_INT:
      if (IS_NUMSTR(retValue.sint)) return numStrings[retValue.sint];
      return [StringClass stringWithFormat:@"%d", retValue.sint];
    case _C_ULNG_LNG:
      if (IS_NUMSTR(retValue.ullong)) return numStrings[retValue.ullong];
      return [StringClass stringWithFormat:@"%ull", retValue.ullong];
    case _C_LNG_LNG:
      if (IS_NUMSTR(retValue.llong)) return numStrings[retValue.llong];
      return [StringClass stringWithFormat:@"%ll", retValue.llong];
    case _C_UCHR:
      if (IS_UNUMSTR(retValue.c)) return numStrings[retValue.c];
      return [StringClass stringWithFormat:@"%d", (int)retValue.c];
    case _C_CHR:
      if (IS_NUMSTR((signed char)retValue.c)) return numStrings[retValue.c];
      return [StringClass stringWithFormat:@"%d", (int)retValue.c];
    case _C_SHT:
      if (IS_NUMSTR(retValue.ss)) return numStrings[retValue.ss];
      return [StringClass stringWithFormat:@"%d", (int)retValue.ss];
    case _C_USHT:
      if (IS_UNUMSTR(retValue.us)) return numStrings[retValue.us];
      return [StringClass stringWithFormat:@"%d", (int)retValue.us];
    
#if 0      
    case _C_FLT:
      return [StringClass stringWithFormat:@"%0.7g", retValue.flt];
#endif
    default:
      return [_objectify(info->retType, &retValue) stringValue];
  }
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:[self keyPath]];
}
- (id)initWithCoder:(NSCoder *)_coder {
  return [self initWithKeyPath:[_coder decodeObject]];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* keypath associations are immutable */
  return [self retain];
}

/* description */

- (NSString *)loggingPrefix {
  return [StringClass stringWithFormat:@"|assoc=%@|", [self keyPath]];
}

- (NSString *)description {
  return [StringClass stringWithFormat:@"<%@[0x%p]: keyPath=%@>",
                        NSStringFromClass([self class]), self,
                        [self keyPath]];
}

@end /* WOKeyPathAssociation */
