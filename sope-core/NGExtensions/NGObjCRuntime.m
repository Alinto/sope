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

#include "NGObjCRuntime.h"
#include "NGMemoryAllocation.h"
#include <objc/objc.h>
#include <objc/objc-api.h>
#include <stdlib.h>
#include "common.h"

#if NeXT_RUNTIME || APPLE_RUNTIME
#  include <objc/objc-class.h>
#  include <objc/objc-runtime.h>
typedef struct objc_method_list *MethodList_t;
typedef struct objc_ivar_list   *IvarList_t;
typedef struct objc_method      *Method_t;
#else
#  include <objc/encoding.h>
#endif

#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSEnumerator.h>

#define GCC_VERSION (__GNUC__ * 10000 \
                     + __GNUC_MINOR__ * 100 \
                     + __GNUC_PATCHLEVEL__)

#if GNUSTEP_BASE_LIBRARY
/* this is a hack for the extensions 0.8.6 library */

void class_add_behavior(Class class, Class behavior) {
  extern void behavior_class_add_class (Class class, Class behavior);
  behavior_class_add_class(class, behavior);
}

#endif

@interface _NGMethodNameEnumerator : NSEnumerator
{
  Class        clazz;
  BOOL         includeSuperclassMethods;
  NSMutableSet *names;

  struct objc_method_list *methods; // current method list
  unsigned i; // current index in current method list
#if APPLE_RUNTIME || NeXT_RUNTIME
  void     *iter; // runtime iterator
#endif
}

- (id)initWithClass:(Class)_clazz includeSuperclassMethods:(BOOL)_flag;
- (id)nextObject;

@end

#if NeXT_RUNTIME || APPLE_RUNTIME

static __inline__ unsigned NGGetSizeOfType(char *ivarType) {
  // TODO: add more types ...
  switch (*ivarType) { 
    /* the Apple runtime has no func to calc a type size ?! */
  case '@': return sizeof(id);
  case ':': return sizeof(SEL);
  case 'c': return sizeof(signed char);
  case 's': return sizeof(signed short);
  case 'i': return sizeof(signed int);
  case 'C': return sizeof(unsigned char);
  case 'S': return sizeof(unsigned short);
  case 'I': return sizeof(unsigned int);
  default:  return 0xDEAFBEAF;
  }
}

#endif

@implementation NSObject(NGObjCRuntime)

static NSArray *emptyArray = nil;

static unsigned countMethodSpecs(SEL _selector, va_list *va)
     __attribute__((unused));

static unsigned countMethodSpecs(SEL _selector, va_list *va) {
  SEL      selector;
  NSString *signature;
  IMP      imp;
  unsigned count;
  
  selector  = _selector;
  signature = nil;
  imp       = NULL;
  if (selector)  signature = va_arg(*va, id);
  if (signature) imp       = va_arg(*va, IMP);
  
  count = 0;
  while ((selector != NULL) && (signature != nil) && (imp != NULL)) {
    count++;
    
    if ((selector  = va_arg(*va, SEL))            == NULL) break;
    if ((signature = (id)va_arg(*va, NSString *)) == nil)  break;
    if ((imp       = (IMP)va_arg(*va, IMP))       == NULL) break;
  }
  return count;
}

static void
fillMethodListWithSpecs(MethodList_t methods, SEL _selector, va_list *va)
{
  /* takes triple: SEL, signature, IMP */
  SEL      selector;
  NSString *signature;
  IMP      imp;
  unsigned count;
  
  selector  = _selector;
  signature = selector  ? va_arg(*va, NSString *) : (NSString *)nil;
  imp       = signature ? va_arg(*va, IMP) : NULL;
  count     = 0;
  while ((selector != NULL) && (signature != nil) && (imp != NULL)) {
    unsigned   len;
    char       *types;
#if GNU_RUNTIME
    const char *selname;
#endif
    
    /* allocate signature buffer */
    len = [signature cStringLength];
    types = malloc(len + 4);
    [signature getCString:types];
    types[len] = 0;
    
#if APPLE_RUNTIME || NeXT_RUNTIME
    count = methods->method_count;
    methods->method_list[count].method_name  = selector;
    methods->method_list[count].method_types = types;
    methods->method_list[count].method_imp   = imp;
    methods->method_count++;
#else
    /* determine selector name */
    selname  = sel_get_name(selector);

    /* fill structure */
    methods->method_list[count].method_name  = (SEL)selname;
    methods->method_list[count].method_types = types;
    methods->method_list[count].method_imp   = imp;
    count++;
#endif
    
    /* go to next method spec */
    if ((selector  = va_arg(*va, SEL))        == NULL) break;
    if ((signature = va_arg(*va, NSString *)) == nil)  break;
    if ((imp       = va_arg(*va, IMP))        == NULL) break;
  }
#if GNU_RUNTIME
  methods->method_count = count;
  methods->method_next  = NULL;
#endif
}

+ (unsigned)instanceSize {
  return ((Class)self)->instance_size;
}

/* adding methods */

+ (void)addMethodList:(MethodList_t)_methods {
  if (_methods == NULL)            return;
  if (_methods->method_count == 0) return;

#if NeXT_RUNTIME
  class_addMethods(self, _methods);
#else
  {
    extern void class_add_method_list (Class class, MethodList_t list);
    class_add_method_list(self, _methods);
  }
#endif
}

+ (void)addClassMethodList:(MethodList_t)_methods {
  if (_methods == NULL)            return;
  if (_methods->method_count == 0) return;
#if NeXT_RUNTIME
  class_addMethods(((Class)self)->isa, _methods);
#else
  {
    extern void class_add_method_list (Class class, MethodList_t list);
    class_add_method_list(((Class)self)->class_pointer, _methods);
  }
#endif
}

+ (void)addMethods:(SEL)_selector, ... {
  /* takes triples (sel, type, imp) finished by nil */
  MethodList_t methods;
  va_list      va;
  unsigned     count;
  
  va_start(va, _selector);
  count = countMethodSpecs(_selector, &va);
  va_end(va);
  if (count == 0) return;

#if NeXT_RUNTIME || APPLE_RUNTIME
  methods = malloc(sizeof(struct objc_method_list) +
                   ((count + 1) * sizeof(struct objc_method)));
  methods->method_count = 0;

  va_start(va, _selector);
  fillMethodListWithSpecs(methods, _selector, &va);
  va_end(va);
  
  [self addMethodList:methods];
#else
  methods = malloc(sizeof(MethodList) + (count + 2) * sizeof(Method));
  NSAssert(methods, @"could not allocate methodlist");
  
  va_start(va, _selector);
  fillMethodListWithSpecs(methods, _selector, &va);
  va_end(va);
  
  [self addMethodList:methods];
#endif
}

+ (void)addClassMethods:(SEL)_selector, ... {
  /* takes triples finished by nil */
  MethodList_t methods;
  va_list      va;
  unsigned     count;
  
  va_start(va, _selector);
  count = countMethodSpecs(_selector, &va);
  va_end(va);
  if (count == 0) return;
  
#if NeXT_RUNTIME
  methods = malloc(sizeof(struct objc_method_list) +
                   ((count + 1) * sizeof(struct objc_method)));
  methods->method_count = 0;

  va_start(va, _selector);
  fillMethodListWithSpecs(methods, _selector, &va);
  va_end(va);
  
  [self addClassMethodList:methods];
#else
  methods = malloc(sizeof(MethodList) + count * sizeof(Method));
  NSAssert(methods, @"couldn't allocate methodlist");
  
  va_start(va, _selector);
  fillMethodListWithSpecs(methods, _selector, &va);
  va_end(va);
  
  [self addClassMethodList:methods];
#endif
}

+ (NSEnumerator *)methodNameEnumerator {
  return [[[_NGMethodNameEnumerator alloc]
                                    initWithClass:self
                                    includeSuperclassMethods:NO]
                                    autorelease];
}
+ (NSEnumerator *)hierachyMethodNameEnumerator {
  return [[[_NGMethodNameEnumerator alloc]
                                    initWithClass:self
                                    includeSuperclassMethods:YES]
                                    autorelease];
}

/* subclassing */

+ (Class)subclass:(NSString *)_className
  ivarsList:(IvarList_t)_ivars
{
#if NeXT_RUNTIME
  [(NSObject *)self doesNotRecognizeSelector:_cmd];
  return Nil;
#else
  // TODO: do we really need a symtab? PyObjC does not seem to require that
  Module_t module;
  Class    newMetaClass, newClass;
  unsigned nameLen;
  char     *name, *moduleName, *metaName;
  int      instanceSize, i;
  
  /* define names */
  
  nameLen = [_className cStringLength];
  name    = malloc(nameLen + 3);
  [_className getCString:name];
  
  moduleName = name;
  metaName   = name;

  /* calc instance size */

  // printf("calc isize ..\n");

  for (i = 0, instanceSize = ((Class)self)->instance_size;
       i < _ivars->ivar_count; i++) {
    unsigned typeAlign, typeLen;
    
    // printf("ivar %s\n", _ivars->ivar_list[i].ivar_name);
    // printf("  type %s\n", _ivars->ivar_list[i].ivar_type);
    
    typeAlign = objc_alignof_type(_ivars->ivar_list[i].ivar_type);
    typeLen   = objc_sizeof_type(_ivars->ivar_list[i].ivar_type);
    
    /* check if offset is aligned */
    if ((instanceSize % typeAlign) != 0) {
      /* add alignment size */
      instanceSize += (typeAlign - (instanceSize % typeAlign));
    }
    instanceSize += typeLen;
  }
  
  /* allocate structures */
  
  newMetaClass = malloc(sizeof(struct objc_class));
  newClass     = malloc(sizeof(struct objc_class));
  NSCAssert(newMetaClass, @"could not allocate new meta class structure");
  NSCAssert(newClass,     @"could not allocate new class structure");
  
  // printf("setup meta ..\n");
  
  /* init meta class */
  newMetaClass->super_class    = (Class)((Class)self)->class_pointer->name;
  newMetaClass->class_pointer  = newMetaClass->super_class->class_pointer;
  newMetaClass->name           = metaName;
  newMetaClass->version        = 0;
  newMetaClass->info           = _CLS_META;
  newMetaClass->instance_size  = newMetaClass->super_class->instance_size;
  newMetaClass->methods        = NULL;
  newMetaClass->dtable         = NULL;
  newMetaClass->subclass_list  = NULL;
  newMetaClass->sibling_class  = NULL;
  newMetaClass->protocols      = NULL;
  newMetaClass->gc_object_type = NULL;
  
  // printf("setup class ..\n");
  /* init class */
  newClass->super_class    = (Class)((Class)self)->name;
  newClass->class_pointer  = newMetaClass;
  newClass->name           = name;
  newClass->version        = 0;
  newClass->info           = _CLS_CLASS;
  newClass->instance_size  = instanceSize;
  newClass->methods        = NULL;
  newClass->dtable         = NULL;
  newClass->subclass_list  = NULL;
  newClass->sibling_class  = NULL;
  newClass->protocols      = NULL;
  newClass->gc_object_type = NULL;
  newClass->ivars          = _ivars;
  
  /* allocate module */
  
  module = malloc(sizeof(Module));
  NSCAssert(module, @"could not allocate module !");
  memset(module, 0, sizeof(Module));
  module->version = 8;
  module->size    = sizeof(Module);
  module->name    = moduleName;

  /* allocate symtab with one entry */
  module->symtab = malloc(sizeof(Symtab) + (2 * sizeof(void *)));
  module->symtab->sel_ref_cnt = 0;
  module->symtab->refs        = 0; // ptr to array of 'struct objc_selector'
  module->symtab->cls_def_cnt = 1;
  module->symtab->cat_def_cnt = 0;
  module->symtab->defs[0] = newClass;
  module->symtab->defs[1] = NULL;

  /* execute module */
  {
#if GCC_VERSION < 30400
    extern void __objc_exec_class(Module_t module); // is thread-safe
    extern void __objc_resolve_class_links();
#else
    void __objc_exec_class(void* module);
    void __objc_resolve_class_links();
#endif
    
    /*
      This is the main entry function in the GNU runtime. It does a LOT of
      work, including the setup of global hashes if missing. Some things (like
      the global hashes) are not relevant for us, since the runtime itself is
      already up.
      This function uses the internal lock for runtime modifications.

      The method does with the runtime lock applied (2.95.3):
      - setup globals
      - registers typed selectors for symtab->refs
      - walks over all classes
        - adds the class to the hash
        - registers the selectors of the class
        - registers the selectors of the metaclass
        - install dtable's (just assigns NULL?)
        - registers instance methods as class methods for root classes
        - inits protocols
        - add superclasses to unresolved-classes
      - walks over all categories
      - register uninitialized statics
      - walk over unclaimed categories
      - walk over unclaimed protocols
      - send the +load message
      
      Actually this function just calls __objc_exec_module(), don't know why
      we call this one instead.
    */
    // printf("execute class\n");
    __objc_exec_class(module);
    
    //printf("resolve links\n");
    __objc_resolve_class_links();
  }
  
  return NSClassFromString(_className);
#endif
}

+ (Class)subclass:(NSString *)_className
  ivarNames:(NSString **)_ivarNames
  ivarTypes:(NSString **)_ivarTypes
  ivarCount:(unsigned)ivarCount
{
  unsigned currentSize;
  
  currentSize = ((Class)self)->instance_size;
  
#if NeXT_RUNTIME || APPLE_RUNTIME
  {
    /* some tricks for Apple inspired by PyObjC, long live OpenSource ;-) */
    IvarList_t        ivars;
    struct objc_class *clazz;
    struct objc_class *metaClazz;
    struct objc_class *rootClazz;
    
    /* build ivars */
    
    ivars = NULL;
    if (ivarCount > 0) {
      unsigned i;
      
      ivars = calloc(sizeof(struct objc_ivar_list) +
		     (ivarCount) * sizeof(struct objc_ivar), sizeof(char));
      
      for (i = 0; i < ivarCount; i++) {
	NSString *n, *t;
	Ivar     var;
	char     *ivarName, *ivarType;
	int      ivarOffset;
	unsigned len, typeAlign, typeLen;

	n = _ivarNames[i];
	t = _ivarTypes[i];
	
	len = [n cStringLength];
	ivarName = malloc(len + 2);
	[n getCString:ivarName];
	ivarName[len] = '\0';
	
	len = [t cStringLength];
	ivarType = malloc(len + 2);
	[t getCString:ivarType];
	ivarType[len] = '\0';
	
	/* calc ivarOffset */
	typeAlign = 0; // TODO: alignment?!
	
	typeLen = NGGetSizeOfType(ivarType);
	NSAssert1(typeLen != 0xDEAFBEAF, 
		  @"does not support ivars of type '%s'", ivarType);
	ivarOffset = currentSize;
	
	var  = ivars->ivar_list + ivars->ivar_count;
	ivars->ivar_count++;
	
	var->ivar_name   = ivarName;
	var->ivar_offset = ivarOffset;
	var->ivar_type   = ivarType;
	
	/* adjust current size */
	currentSize = ivarOffset + typeLen;
      }
    }
  
    // TODO: move the following to a subclass method
    
    /* determine root class */
    
    for (rootClazz = self; rootClazz->super_class != NULL; )
      rootClazz = rootClazz->super_class;

    /* setup meta class */
    
    metaClazz = calloc(1, sizeof(struct objc_class));
    metaClazz->isa           = rootClazz->isa; // root-meta is the metameta
    metaClazz->name          = strdup([_className cString]);
    metaClazz->info          = CLS_META;
    metaClazz->super_class   = ((struct objc_class *)self)->isa;
    metaClazz->instance_size = ((struct objc_class *)self)->isa->instance_size;
    metaClazz->ivars         = NULL;
    metaClazz->protocols     = NULL;
    
    /* setup class */
    
    clazz = calloc(1, sizeof(struct objc_class));
    clazz->isa           = metaClazz; /* hook up meta class */
    clazz->name          = strdup([_className cString]);
    clazz->info          = CLS_CLASS;
    clazz->super_class   = self;
    clazz->instance_size = currentSize;
    clazz->ivars         = ivars;
    clazz->protocols     = NULL;

#if 0
    NSLog(@"instance size: %d, ivar-count: %d",
	  currentSize, ivars->ivar_count);
#endif
    
    /* setup method lists */
    
    metaClazz->methodLists = calloc(1, sizeof(struct objc_method_list *));
    clazz->methodLists     = calloc(1, sizeof(struct objc_method_list *));
    
    /* Note: MacOSX specific, Radar #3317376, hint taken from PyObjC */
    metaClazz->methodLists[0] = (struct objc_method_list *)-1;
    clazz->methodLists[0]     = (struct objc_method_list *)-1;
    
    /* add to runtime (according to PyObjC not reversible?) */
    objc_addClass(clazz);
    return NSClassFromString(_className);
  }
#else
  {
    unsigned i;
    IvarList_t ivars;
  
    ivars = malloc(sizeof(IvarList) + (sizeof(struct objc_ivar) * ivarCount));
    ivars->ivar_count = ivarCount;
    
    for (i = 0; i < ivarCount; i++) {
      NSString *n, *t;
      char     *ivarName, *ivarType;
      int      ivarOffset;
      unsigned len, typeAlign, typeLen;

      n = _ivarNames[i];
      t = _ivarTypes[i];
    
      len = [n cStringLength];
      ivarName = malloc(len + 2);
      [n getCString:ivarName];
      ivarName[len] = '\0';
    
      len = [t cStringLength];
      ivarType = malloc(len + 2);
      [t getCString:ivarType];
      ivarType[len] = '\0';
    
      /* calc ivarOffset */
      typeAlign  = objc_alignof_type(ivarType);
      typeLen    = objc_sizeof_type(ivarType);
      ivarOffset = currentSize;
    
      /* check if offset is aligned */
      if ((ivarOffset % typeAlign) != 0) {
	/* align offset */
	len = (typeAlign - (ivarOffset % typeAlign));
	ivarOffset += len;
      }

      /* adjust current size */
      currentSize = ivarOffset + typeLen;
    
      ivars->ivar_list[ivarCount].ivar_name   = ivarName;
      ivars->ivar_list[ivarCount].ivar_type   = ivarType;
      ivars->ivar_list[ivarCount].ivar_offset = ivarOffset;
    }
  
    return [self subclass:_className ivarsList:ivars];
  }
#endif
}

+ (Class)subclass:(NSString *)_className
  ivars:(NSString *)_name1,...
{
  va_list  va; /* contains: name1, type1, name2, type2, ... */
  unsigned ivarCount;
  NSString *n, *t;
  NSString **ivarNames = NULL;
  NSString **ivarTypes = NULL;
  Class    clazz;
  
  /* determine number of args */
  
  va_start(va, _name1);
  for (n = _name1, t = va_arg(va, NSString *), ivarCount = 0;
       (n != nil && t != nil);
       n = va_arg(va, NSString *), t = va_arg(va, NSString *))
    ivarCount++;
  va_end(va);
  
  /* collect args */
  
  if (ivarCount > 0) {
    ivarNames = calloc(ivarCount, sizeof(NSString *));
    ivarTypes = calloc(ivarCount, sizeof(NSString *));
    va_start(va, _name1);
    for (n = _name1, t = va_arg(va, NSString *), ivarCount = 0;
	 (n != nil && t != nil);
	 n = va_arg(va, NSString *), t = va_arg(va, NSString *)) {
      ivarNames[ivarCount] = n;
      ivarTypes[ivarCount] = t;
      ivarCount++;
    }
    va_end(va);
  }
  
  /* call primary method */
  
  clazz = [self subclass:_className 
		ivarNames:ivarNames ivarTypes:ivarTypes ivarCount:ivarCount];
  
  if (ivarNames != NULL) free(ivarNames);
  if (ivarTypes != NULL) free(ivarTypes);
  return clazz;
}

/* instance variables */

+ (NSArray *)instanceVariableNames {
  NSArray  *result;
  NSString **names;
  int i;
  
  if (((Class)self)->ivars == NULL || ((Class)self)->ivars->ivar_count == 0) {
    if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
    return emptyArray;
  }

  names = calloc(((Class)self)->ivars->ivar_count + 2, sizeof(NSString *));
  
  for (i = 0; i < ((Class)self)->ivars->ivar_count; i++) {
    register unsigned char *ivarName;
    
    ivarName = (void *)(((Class)self)->ivars->ivar_list[i].ivar_name);
    if (ivarName == NULL) {
      NSLog(@"WARNING(%s): ivar without name! (idx=%d)", 
	    __PRETTY_FUNCTION__, i);
      continue;
    }
    
#if !LIB_FOUNDATION_LIBRARY
    names[i] = [NSString stringWithCString:(char *)ivarName];
#else
    names[i] = [NSString stringWithCStringNoCopy:(char *)ivarName
			 freeWhenDone:NO];
#endif
  }
  
  result = [NSArray arrayWithObjects:names
		    count:((Class)self)->ivars->ivar_count];
  if (names) free(names);
  return result;
}
+ (NSArray *)allInstanceVariableNames {
  NSMutableArray *varNames;
  Class c;

  varNames = [NSMutableArray arrayWithCapacity:32];
  for (c = self; c != Nil; c = [c superclass])
    [varNames addObjectsFromArray:[c instanceVariableNames]];

  return [[varNames copy] autorelease];
}

+ (BOOL)hasInstanceVariableWithName:(NSString *)_ivarName {
  Class    c;
  unsigned len = [_ivarName cStringLength];
  char     *ivarName;
  
  if (len == 0)
    return NO;
  
  ivarName = malloc(len + 1);
  [_ivarName getCString:ivarName]; ivarName[len] = '\0';
  
  for (c = self; c != Nil; c = [c superclass]) {
    int i;
    
    for (i = 0; i < c->ivars->ivar_count; i++) {
      if (strcmp(ivarName, c->ivars->ivar_list[i].ivar_name) == 0) {
        free(ivarName);
        return YES;
      }
    }
  }
  free(ivarName);
  return NO;
}

+ (NSString *)signatureOfInstanceVariableWithName:(NSString *)_ivarName {
  Class    c;
  unsigned len = [_ivarName cStringLength];
  char     *ivarName;
  
  if (len == 0)
    return nil;

  ivarName = malloc(len + 1);
  [_ivarName getCString:ivarName]; ivarName[len] = '\0';
  
  for (c = self; c != Nil; c = [c superclass]) {
    int i;

    for (i = 0; i < c->ivars->ivar_count; i++) {
      if (strcmp(ivarName, c->ivars->ivar_list[i].ivar_name) == 0) {
        /* found matching ivar name */
        if (ivarName) free(ivarName);
#if !LIB_FOUNDATION_LIBRARY
        return [NSString stringWithCString:
                           (char *)(c->ivars->ivar_list[i].ivar_type)];
#else
        return [NSString stringWithCStringNoCopy:
                           (char *)(c->ivars->ivar_list[i].ivar_type)
                         freeWhenDone:NO];
#endif
      }
    }
  }
  if (ivarName) free(ivarName);
  return nil;
}


+ (unsigned)offsetOfInstanceVariableWithName:(NSString *)_ivarName {
  Class    c;
  unsigned len = [_ivarName cStringLength];
  char     *ivarName;
  
  if (len == 0)
    return NSNotFound;

  ivarName = malloc(len + 3);
  [_ivarName getCString:ivarName]; ivarName[len] = '\0';
  
  for (c = self; c != Nil; c = [c superclass]) {
    int i;

    for (i = 0; i < c->ivars->ivar_count; i++) {
      if (strcmp(ivarName, c->ivars->ivar_list[i].ivar_name) == 0) {
        /* found matching ivar name */
        free(ivarName);
        return c->ivars->ivar_list[i].ivar_offset;
      }
    }
  }
  free(ivarName);
  return NSNotFound;
}

@end /* NSObject(NGObjCRuntime) */

@implementation _NGMethodNameEnumerator

- (id)initWithClass:(Class)_clazz includeSuperclassMethods:(BOOL)_flag {
  if (_clazz == Nil) {
    [self release];
    return nil;
  }

  self->names = [[NSMutableSet alloc] initWithCapacity:200];
  self->clazz                    = _clazz;
  self->includeSuperclassMethods = _flag;

#if NeXT_RUNTIME
  self->iter    = 0;
  self->methods = class_nextMethodList(self->clazz, &(self->iter));
#else
  self->methods = _clazz->methods;
  self->i       = 0;
#endif
  return self;
}

- (void)dealloc {
  [self->names release];
  [super dealloc];
}

- (id)nextObject {
  if (self->clazz == nil)
    return nil;

  if (self->methods == NULL) {
    /* methods of current class are done .. */
    if (!self->includeSuperclassMethods)
      return nil;

    /* loop, maybe there are classes without a method-list ? */
    while (self->methods == NULL) {
      if ((self->clazz = [self->clazz superclass]) == Nil)
        /* no more superclasses */
        return nil;
      
#if NeXT_RUNTIME
      self->iter = 0;
      self->methods = class_nextMethodList(self->clazz, &(self->iter));
#else
      self->methods = self->clazz->methods;
#endif
    }
    self->i = 0;
  }
  
#if DEBUG
  NSAssert(self->methods, @"missing method-list !");
#endif
  
  while (self->i >= (unsigned)self->methods->method_count) {
#if NeXT_RUNTIME || APPLE_RUNTIME
    self->methods = class_nextMethodList(self->clazz, &(self->iter));
#else
    self->methods = self->methods->method_next;
#endif
    if (self->methods == NULL)
      break;
    self->i = 0;
  }
  
  if (self->methods == NULL) {
    /* recurse to next super class */
    return self->includeSuperclassMethods
      ? [self nextObject]
      : nil;
  }

  /* get name .. */
  {
    Method_t m;
    NSString *name;

    m = &(self->methods->method_list[self->i]);
    self->i++;
    
    NSAssert(m, @"missing method structure !");
    name = NSStringFromSelector(m->method_name);
    NSAssert(name, @"couldn't get method name !");
    
    if ([self->names containsObject:name]) {
      /* this name was already delivered from a subclass, take next */
      return [self nextObject];
    }

    [self->names addObject:name];
    
    return name;
  }
}

@end /* _NGMethodNameEnumerator */

#if GNU_RUNTIME

@interface NGObjCClassEnumerator : NSEnumerator
{
  void *state;
}
@end

@implementation NGObjCClassEnumerator

- (id)nextObject {
  return objc_next_class(&(self->state));
}

@end /* NGObjCClassEnumerator */

#endif /* GNU_RUNTIME */
