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

#include "config.h"
#include "common.h"
#include "NGStreamCoder.h"
#include "NGStream+serialization.h"

#if APPLE_RUNTIME || NeXT_RUNTIME
#  include <objc/objc-class.h>
#endif

#define FINAL static inline

extern id nil_method(id, SEL, ...);

/*
  Debugging topics:
    encoder
    decoder
*/

typedef unsigned char NGTagType;

#define REFERENCE 128
#define VALUE     127

static unsigned __NGHashPointer(void *table, const void *anObject)
{
    return (unsigned)((long)anObject / 4);
}
static BOOL __NGComparePointers(void *table, 
	const void *anObject1, const void *anObject2)
{
    return anObject1 == anObject2 ? YES : NO;
}
static void __NGRetainObjects(void *table, const void *anObject)
{
    (void)[(NSObject*)anObject retain];
}
static void __NGReleaseObjects(void *table, void *anObject)
{
    [(NSObject*)anObject release];
}
static NSString* __NGDescribePointers(void *table, const void *anObject)
{
    return [NSString stringWithFormat:@"%p", anObject];
}

static NSMapTableKeyCallBacks NGIdentityObjectMapKeyCallbacks = {
  (unsigned(*)(NSMapTable *, const void *))          __NGHashPointer,
  (BOOL(*)(NSMapTable *, const void *, const void *))__NGComparePointers,
  (void (*)(NSMapTable *, const void *anObject))     __NGRetainObjects,
  (void (*)(NSMapTable *, void *anObject))           __NGReleaseObjects,
  (NSString *(*)(NSMapTable *, const void *))        __NGDescribePointers,
  (const void *)NULL
};

static const char *NGCoderSignature = "MDlink NGStreamCoder";
static int        NGCoderVersion    = 1100;

@implementation NGStreamCoder

static NSMapTable *classToAliasMappings = NULL; // archive name => decoded name

+ (void)initialize {
  BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    classToAliasMappings = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            19);
  }
}

+ (id)coderWithStream:(id<NGStream>)_stream {
  return AUTORELEASE([[self alloc] initWithStream:_stream]);
}

- (id)initWithStream:(id<NGStream>)_stream mode:(NGStreamMode)_mode {
  if ((self = [super init])) {
    self->stream = [_stream retain];

    self->classForCoder      = @selector(classForCoder);
    self->replObjectForCoder = @selector(replacementObjectForCoder:);

    if ([self->stream isKindOfClass:[NSObject class]]) {
      self->readIMP = (NGIOSafeReadMethodType)
        [(NSObject*)self->stream methodForSelector:@selector(safeReadBytes:count:)];
      self->writeIMP = (NGIOSafeWriteMethodType)
        [(NSObject*)self->stream methodForSelector:@selector(safeWriteBytes:count:)];
    }

    if (NGCanReadInStreamMode(_mode)) { // setup decoder
      self->inObjects       = NSCreateMapTable(NSIntMapKeyCallBacks,
                                               NSObjectMapValueCallBacks,
                                               119);
      self->inClasses       = NSCreateMapTable(NSIntMapKeyCallBacks,
                                               NSObjectMapValueCallBacks,
                                               19);
      self->inPointers      = NSCreateMapTable(NSIntMapKeyCallBacks,
                                               NSIntMapValueCallBacks,
                                               19);
      self->inClassAlias    = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                               NSObjectMapValueCallBacks,
                                               19);
      self->inClassVersions = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                               NSObjectMapValueCallBacks,
                                               19);
    }

    if (NGCanWriteInStreamMode(_mode)) { // setup encoder
      self->outObjects      = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 119);
      self->outConditionals = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 119);
      self->outPointers     = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
      self->replacements    = NSCreateMapTable(NGIdentityObjectMapKeyCallbacks,
                                               NSObjectMapValueCallBacks,
                                               19);
    }
  }
  return self;
}

- (id)init {
  return [self initWithStream:nil mode:NGStreamMode_undefined];
}
- (id)initWithStream:(id<NGStream>)_stream {
  return [self initWithStream:_stream mode:[_stream mode]];
}

- (void)dealloc {
  // release encoding restreams
  if (self->outObjects) {
    NSFreeHashTable(self->outObjects); self->outObjects = NULL; }
  if (self->outConditionals) {
    NSFreeHashTable(self->outConditionals); self->outConditionals = NULL; }
  if (self->outPointers) {
    NSFreeHashTable(self->outPointers); self->outPointers = NULL; }
  if (self->replacements) {
    NSFreeMapTable(self->replacements); self->replacements = NULL; }

  // release decoding restreams
  if (self->inObjects) {
    NSFreeMapTable(self->inObjects); self->inObjects = NULL; }
  if (self->inClasses) {
    NSFreeMapTable(self->inClasses); self->inClasses = NULL; }
  if (self->inPointers) {
    NSFreeMapTable(self->inPointers); self->inPointers = NULL; }
  if (self->inClassAlias) {
    NSFreeMapTable(self->inClassAlias); self->inClassAlias = NULL; }
  if (self->inClassVersions) {
    NSFreeMapTable(self->inClassVersions); self->inClassVersions = NULL; }

  [self->stream release]; self->stream = nil;
  
  [super dealloc];
}

/* accessors */

- (id<NGStream>)stream {
  return self->stream;
}

- (NSString *)coderSignature {
  return [NSString stringWithCString:NGCoderSignature];
}
- (int)coderVersion {
  return NGCoderVersion;
}

- (unsigned int)systemVersion {
  return self->inArchiverVersion;
}

// misc

FINAL BOOL isBaseType(const char *_type) {
  switch (*_type) {
    case _C_CHR: case _C_UCHR:
    case _C_SHT: case _C_USHT:
    case _C_INT: case _C_UINT:
    case _C_LNG: case _C_ULNG:
    case _C_FLT: case _C_DBL:
      return YES;

    default:
      return NO;
  }
}

FINAL BOOL isReferenceTag(NGTagType _tag) {
  return (_tag & REFERENCE) ? YES : NO;
}

FINAL NGTagType tagValue(NGTagType _tag) {
  return _tag & VALUE; // mask out bit 8
}

FINAL int _archiveIdOfObject(NGStreamCoder *self, id _object) {
  return (_object == nil)
    ? 0
    : (int)_object;
}
FINAL int _archiveIdOfClass(NGStreamCoder *self, Class _class) {
  return _archiveIdOfObject(self, _class);
}


// primitive encoding

FINAL void _writeBytes(NGStreamCoder *self, const void *_bytes, unsigned _len);

FINAL void _writeTag  (NGStreamCoder *self, NGTagType _tag);

FINAL void _writeChar (NGStreamCoder *self, char _value);
FINAL void _writeShort(NGStreamCoder *self, short _value);
FINAL void _writeInt  (NGStreamCoder *self, int _value);
FINAL void _writeLong (NGStreamCoder *self, long _value);
FINAL void _writeFloat(NGStreamCoder *self, float _value);

FINAL void _writeCString(NGStreamCoder *self, const char *_value);
FINAL void _writeObjC(NGStreamCoder *self, const void *_value, const char *_type);

// primitive decoding

FINAL void _readBytes(NGStreamCoder *self, void *_bytes, unsigned _len);

FINAL NGTagType _readTag(NGStreamCoder *self);

FINAL char  _readChar (NGStreamCoder *self);
FINAL short _readShort(NGStreamCoder *self);
FINAL int   _readInt  (NGStreamCoder *self);
FINAL long  _readLong (NGStreamCoder *self);
FINAL float _readFloat(NGStreamCoder *self);

FINAL char *_readCString(NGStreamCoder *self);
FINAL void _readObjC(NGStreamCoder *self, void *_value, const char *_type);

// -------------------- encoding --------------------

- (void)beginEncoding {
  self->traceMode       = NO;
  self->encodingRoot    = YES;
}
- (void)endEncoding {
  NSResetHashTable(self->outObjects);
  NSResetHashTable(self->outConditionals);
  NSResetHashTable(self->outPointers);
  NSResetMapTable(self->replacements);
  self->traceMode      = NO;
  self->encodingRoot   = NO;
}

- (void)writeArchiveHeader {
  if (self->didWriteHeader == NO) {
    _writeCString(self, [[self coderSignature] cString]);
    _writeInt(self, [self coderVersion]);
    self->didWriteHeader = YES;
  }
}
- (void)writeArchiveTrailer {
}

- (void)traceObjectsWithRoot:(id)_root {
  // encoding pass 1

  NS_DURING {
    self->traceMode = YES;

    [self encodeObject:_root];
  }
  NS_HANDLER {
    self->traceMode = NO;
    NSResetHashTable(self->outObjects);
    [localException raise];
  }
  NS_ENDHANDLER;
  self->traceMode = NO;
  NSResetHashTable(self->outObjects);
}

- (void)encodeObjectsWithRoot:(id)_root {
  // encoding pass 2
  [self encodeObject:_root];
}

- (void)encodeRootObject:(id)_object {
  NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:[self zone]] init];
  
  [self beginEncoding];

  NS_DURING {
    /*
     * Prepare for writing the graph objects for which `rootObject' is the root
     * node. The algorithm consists from two passes. In the first pass it
     * determines the nodes so-called 'conditionals' - the nodes encoded *only*
     * with -encodeConditionalObject:. They represent nodes that are not
     * related directly to the graph. In the second pass objects are encoded
     * normally, except for the conditional objects which are encoded as nil.
     */

    // pass1: start tracing for conditionals
    [self traceObjectsWithRoot:_object];

    // pass2: start writing
    [self writeArchiveHeader];
    [self encodeObjectsWithRoot:_object];
    [self writeArchiveTrailer];
  }
  NS_HANDLER {
    [self endEncoding]; // release resources
    [localException raise];
  }
  NS_ENDHANDLER;
  [self endEncoding]; // release resources

  [pool release]; pool = nil;
}

- (void)encodeConditionalObject:(id)_object {
  if (self->traceMode) { // pass 1
    /*
     * This is the first pass of the determining the conditionals
     * algorithm. We traverse the graph and insert into the `conditionals'
     * set. In the second pass all objects that are still in this set will
     * be encoded as nil when they receive -encodeConditionalObject:. An
     * object is removed from this set when it receives -encodeObject:.
     */

    if (_object) {
      if (NSHashGet(self->outObjects, _object))
        // object isn't conditional any more .. (was stored using encodeObject:)
        ;
      else if (NSHashGet(self->outConditionals, _object))
        // object is already stored as conditional
        ;
      else
        // insert object in conditionals set
        NSHashInsert(self->outConditionals, _object);
    }
  }
  else { // pass 2
    BOOL isConditional;

    isConditional = (NSHashGet(self->outConditionals, _object) != nil);

    // If anObject is still in the `conditionals' set, it is encoded as nil.
    [self encodeObject:isConditional ? nil : _object];
  }
}

- (void)_traceObject:(id)_object {
  if (_object == nil) // don't trace nil objects ..
    return;

  if (NSHashGet(self->outObjects, _object) == nil) { // object wasn't traced yet
    // Look-up the object in the `conditionals' set. If the object is
    // there, then remove it because it is no longer a conditional one.
    if (NSHashGet(self->outConditionals, _object)) {
      // object was marked conditional ..
      NSHashRemove(self->outConditionals, _object);
    }

    // mark object as traced
    NSHashInsert(self->outObjects, _object);
      
    if (object_is_instance(_object)) {
      Class archiveClass = Nil;
      id    replacement  = nil;

      replacement = [_object performSelector:self->replObjectForCoder
                             withObject:self];

      if (replacement != _object) {
        NSMapInsert(self->replacements, _object, replacement);
        _object = replacement;
      }
      
      if (object_is_instance(_object)) {
        archiveClass = [_object performSelector:self->classForCoder
                                withObject:self];
      }
        
      [self encodeObject:archiveClass];
      [_object encodeWithCoder:self];
    }
    else {
      // there are no class-variables ..
    }
  }
}
- (void)_encodeObject:(id)_object {
  NGTagType tag;
  int       archiveId = _archiveIdOfObject(self, _object);

  tag = object_is_instance(_object) ? _C_ID : _C_CLASS;
    
  if (_object == nil) { // nil object
#if 0
    NSLog(@"encoding nil reference ..");
#endif
    _writeTag(self, tag | REFERENCE);
    _writeInt(self, archiveId);
  }
  else if (NSHashGet(self->outObjects, _object)) { // object was already written
#if 0
    if (tag == _C_CLASS) {
      NSLog(@"encoding reference to class <%s> ..",
             class_get_class_name(_object));
    }
    else {
      NSLog(@"encoding reference to object 0x%p<%s> ..",
             _object, class_get_class_name(*(Class *)_object));
    }
#endif

    _writeTag(self, tag | REFERENCE);
    _writeInt(self, archiveId);
  }
  else {
    // mark object as written
    NSHashInsert(self->outObjects, _object);

#if 0
    if (tag == _C_CLASS) { // a class object
      NSLog( @"encoding class %s:%i ..",
             class_get_class_name(_object), [_object version]);
    }
    else {
      NSLog(@"encoding object 0x%p<%s> ..",
             _object, class_get_class_name(*(Class *)_object));
    }
#endif
    
    _writeTag(self, tag);
    _writeInt(self, archiveId);

    if (tag == _C_CLASS) { // a class object
      _writeCString(self, class_get_class_name(_object));
      _writeInt(self, [_object version]);
    }
    else {
      Class archiveClass = Nil;
      id    replacement  = nil;

      replacement = NSMapGet(self->replacements, _object);
      if (replacement) _object = replacement;

      /*
      _object      = [_object performSelector:self->replObjectForCoder
                              withObject:self];
      */
      archiveClass = [_object performSelector:self->classForCoder
                              withObject:self]; // class of replacement

      NSAssert(archiveClass, @"no archive class found ..");

      [self encodeObject:archiveClass];
      [_object encodeWithCoder:self];
    }
  }
}

- (void)encodeObject:(id)_object {
  if (self->encodingRoot) {
    [self encodeValueOfObjCType:object_is_instance(_object) ? "@" : "#"
          at:&_object];
  }
  else {
    [self encodeRootObject:_object];
  }
}

- (void)_traceValueOfObjCType:(const char *)_type at:(const void *)_value {
#if 0
  NSLog(@"tracing value of ObjC-type '%s'", _type);
#endif

  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      [self _traceObject:*(id *)_value];
      break;

    case _C_ARY_B: {
      int        count     = atoi(_type + 1); // eg '[15I' => count = 15
      const char *itemType = _type;
      while(isdigit((int)*(++itemType))) ; // skip dimension
      [self encodeArrayOfObjCType:itemType count:count at:_value];
      break;
    }

    case _C_STRUCT_B: { // C-structure begin '{'
      int offset = 0;

      while ((*_type != _C_STRUCT_E) && (*_type++ != '=')); // skip "<name>="
        
      while (YES) {
        [self encodeValueOfObjCType:_type at:((char *)_value) + offset];
            
        offset += objc_sizeof_type(_type);
        _type  =  objc_skip_typespec(_type);
            
        if(*_type != _C_STRUCT_E) { // C-structure end '}'
          int align, remainder;
                    
          align = objc_alignof_type(_type);
          if((remainder = offset % align))
            offset += (align - remainder);
        }
        else
          break;
      }
      break;
    }
  }
}

- (void)_encodeValueOfObjCType:(const char *)_type at:(const void *)_value {
  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      // ?? Write another tag just to be possible to read using the
      // ?? decodeObject method. (Otherwise a lookahead would be required)
      // ?? _writeTag(self, *_type);
      [self _encodeObject:*(id *)_value];
      break;

    case _C_ARY_B: {
      int        count     = atoi(_type + 1); // eg '[15I' => count = 15
      const char *itemType = _type;

      while(isdigit((int)*(++itemType))) ; // skip dimension

      // Write another tag just to be possible to read using the
      // decodeArrayOfObjCType:count:at: method.
      _writeTag(self, _C_ARY_B);
      [self encodeArrayOfObjCType:itemType count:count at:_value];
      break;
    }

    case _C_STRUCT_B: { // C-structure begin '{'
      int offset = 0;

      _writeTag(self, '{');

      while ((*_type != _C_STRUCT_E) && (*_type++ != '=')); // skip "<name>="
        
      while (YES) {
        [self encodeValueOfObjCType:_type at:((char *)_value) + offset];
            
        offset += objc_sizeof_type(_type);
        _type  =  objc_skip_typespec(_type);
            
        if(*_type != _C_STRUCT_E) { // C-structure end '}'
          int align, remainder;
                    
          align = objc_alignof_type(_type);
          if((remainder = offset % align))
            offset += (align - remainder);
        }
        else
          break;
      }
      break;
    }

    case _C_SEL:
      _writeTag(self, _C_SEL);
      _writeCString(self, (*(SEL *)_value) ? sel_get_name(*(SEL *)_value) : NULL);
      break;
      
    case _C_PTR:
      _writeTag(self, *_type);
      _writeObjC(self, *(char **)_value, _type + 1);
      break;
    case _C_CHARPTR:
      _writeTag(self, *_type);
      _writeObjC(self, _value, _type);
      break;
      
    case _C_CHR:    case _C_UCHR:
    case _C_SHT:    case _C_USHT:
    case _C_INT:    case _C_UINT:
    case _C_LNG:    case _C_ULNG:
    case _C_FLT:    case _C_DBL:
      _writeTag(self, *_type);
      _writeObjC(self, _value, _type);
      break;
      
    default:
      NSLog(@"unsupported C type '%s' ..", _type);
      break;
  }
}

- (void)encodeValueOfObjCType:(const char *)_type at:(const void *)_value {
  if (self->traceMode)
    [self _traceValueOfObjCType:_type at:_value];
  else {
    if (self->didWriteHeader == NO)
      [self writeArchiveHeader];
  
    [self _encodeValueOfObjCType:_type at:_value];
  }
}

- (void)encodeArrayOfObjCType:(const char *)_type count:(unsigned int)_count
  at:(const void *)_array {

  if ((self->didWriteHeader == NO) && (self->traceMode == NO))
    [self writeArchiveHeader];

  // array header
  if (self->traceMode == NO) { // nothing is written during trace-mode
    _writeTag(self, _C_ARY_B);
    _writeInt(self, _count);
  }

  // Optimize writing arrays of elementary types. If such an array has to
  // be written, write the type and then the elements of array.

  if ((*_type == _C_ID) || (*_type == _C_CLASS)) { // object array
    int i;

    if (self->traceMode == NO)
      _writeTag(self, *_type); // object array

    for (i = 0; i < _count; i++)
      [self encodeObject:((id *)_array)[i]];
  }
  else if ((*_type == _C_CHR) || (*_type == _C_UCHR)) { // byte array
    if (self->traceMode == NO) {

      // write base type tag
      _writeTag(self, *_type);

      // write buffer
      _writeBytes(self, _array, _count);
    }
  }
  else if (isBaseType(_type)) {
    if (self->traceMode == NO) {
      unsigned offset, itemSize = objc_sizeof_type(_type);
      int      i;

      // write base type tag
      _writeTag(self, *_type);

      // write contents
      for (i = offset = 0; i < _count; i++, offset += itemSize)
        _writeObjC(self, (char *)_array + offset, _type);
    }
  }
  else { // encoded using normal method
    IMP      encodeValue = NULL;
    unsigned offset, itemSize = objc_sizeof_type(_type);
    int      i;

    encodeValue = [self methodForSelector:@selector(encodeValueOfObjCType:at:)];

    for (i = offset = 0; i < _count; i++, offset += itemSize) {
      encodeValue(self, @selector(encodeValueOfObjCType:at:),
                  (char *)_array + offset, _type);
    }
  }
}

// -------------------- decoding --------------------

- (void)decodeArchiveHeader {
  if (self->didReadHeader == NO) {
    char *archiver = _readCString(self);

    self->inArchiverVersion = _readInt(self);

    if (strcmp(archiver, [[self coderSignature] cString])) {
      NSLog(@"WARNING: used a different archiver (signature %s:%i)",
            archiver, [self systemVersion]);
    }
    else if ([self systemVersion] != [self coderVersion]) {
      NSLog(@"WARNING: used a different archiver version "
            @"(archiver=%i, unarchiver=%i)",
            [self systemVersion], [self coderVersion]);
    }

    if (archiver) {
      NGFree(archiver);
      archiver = NULL;
    }
    self->didReadHeader = YES;
  }
}

- (void)beginDecoding {
#if 0
  NSLog(@"start decoding ..");
#endif
  [self decodeArchiveHeader];
}
- (void)endDecoding {
#if 0
  NSLog(@"finish decoding ..");
#endif
  NSResetMapTable(self->inObjects);
  NSResetMapTable(self->inClasses);
  NSResetMapTable(self->inPointers);
  NSResetMapTable(self->inClassAlias);
  NSResetMapTable(self->inClassVersions);
}

- (Class)_decodeClass:(BOOL)_isReference {
  int   archiveId = _readInt(self);
  Class result    = Nil;
  
  if (_isReference) {
    result = (Class)NSMapGet(self->inClasses, (void *)archiveId);
    if (result == Nil) {
      NSLog(@"did not find class for archive-id %i", archiveId);
    }
  }
  else {
    NSString *name   = NULL;
    int      version = 0;

    name    = [NSString stringWithCString:_readCString(self)];
    version = _readInt(self);

    if (name == nil) {
      [NSException raise:NSInconsistentArchiveException
                   format:@"did not find class name"];
    }

    { // check whether the class is to be replaced
      NSString *newName = NSMapGet(self->inClassAlias, name);
      
      if (newName)
        name = newName;
      else {
        newName = NSMapGet(classToAliasMappings, name);
        if (newName)
          name = newName;
      }
    }
    
    result = NSClassFromString(name);
#if 0
    NSLog(@"decoded class %@:%i (result=%@).", name, version, result);
#endif
    
    NSAssert([result version] == version, @"class versions do not match ..");

    NSMapInsert(self->inClasses, (void *)archiveId, result);
  }
  
  NSAssert(result, @"class may not be Nil ..");
  
  return result;
}
- (id)_decodeObject:(BOOL)_isReference {
  // this method returns a retained object !
  int archiveId = _readInt(self);
  id  result    = nil;

  if (archiveId == 0) // nil object or unused conditional object
    return nil;
  
  if (_isReference) {
    result = [(id)NSMapGet(self->inObjects, (void *)archiveId) retain];
  }
  else {
    Class class       = Nil;
    id    replacement = nil;

    // decode class info
    [self decodeValueOfObjCType:"#" at:&class];
    NSAssert(class, @"invalid class ..");
    
    result = [class allocWithZone:self->objectZone];
    NSMapInsert(self->inObjects, (void *)archiveId, result);

    replacement = [result initWithCoder:self];
    if (replacement != result) {

      replacement = [replacement retain];
      NSMapRemove(self->inObjects, result);
      result = replacement;
      NSMapInsert(self->inObjects, (void *)archiveId, result);
      [replacement release];
    }

    replacement = [result awakeAfterUsingCoder:self];
    if (replacement != result) {
      replacement = [replacement retain];
      NSMapRemove(self->inObjects, result);
      result = replacement;
      NSMapInsert(self->inObjects, (void *)archiveId, result);
      [replacement release];
    }
  }
  NSAssert([result retainCount] > 0, @"invalid retain count ..");
  return result;
}

- (id)decodeObject {
  id result = nil;

  [self decodeValueOfObjCType:"@" at:&result];
  
  // result is retained
  return [result autorelease];
}

- (void)decodeValueOfObjCType:(const char *)_type at:(void *)_value {
  BOOL      startedDecoding = NO;
  NGTagType tag             = 0;
  BOOL      isReference     = NO;

  if (self->decodingRoot == NO) {
    self->decodingRoot = YES;
    startedDecoding = YES;
    [self beginDecoding];
  }

  tag         = _readTag(self);
  isReference = isReferenceTag(tag);
  tag         = tagValue(tag);

  switch (tag) {
    case _C_ID:
      NSAssert((*_type == _C_ID) || (*_type == _C_CLASS), @"invalid type ..");
      *(id *)_value = [self _decodeObject:isReference];
      break;
    case _C_CLASS:
      NSAssert((*_type == _C_ID) || (*_type == _C_CLASS), @"invalid type ..");
      *(Class *)_value = [self _decodeClass:isReference];
      break;

    case _C_ARY_B: {
      int        count     = atoi(_type + 1); // eg '[15I' => count = 15
      const char *itemType = _type;

      NSAssert(*_type == _C_ARY_B, @"invalid type ..");

      while(isdigit((int)*(++itemType))) ; // skip dimension

      [self decodeArrayOfObjCType:itemType count:count at:_value];
      break;
    }

    case _C_STRUCT_B: {
      int offset = 0;

      NSAssert(*_type == _C_STRUCT_B, @"invalid type ..");
      
      while ((*_type != _C_STRUCT_E) && (*_type++ != '=')); // skip "<name>="
        
      while (YES) {
        [self decodeValueOfObjCType:_type at:((char *)_value) + offset];
            
        offset += objc_sizeof_type(_type);
        _type  =  objc_skip_typespec(_type);
            
        if(*_type != _C_STRUCT_E) { // C-structure end '}'
          int align, remainder;
                    
          align = objc_alignof_type(_type);
          if((remainder = offset % align))
            offset += (align - remainder);
        }
        else
          break;
      }
      break;
    }

    case _C_SEL: {
      char *name = NULL;
      
      NSAssert(*_type == tag, @"invalid type ..");
      _readObjC(self, &name, @encode(char *));
      *(SEL *)_value = name ? sel_get_any_uid(name) : NULL;
      NGFree(name); name = NULL;
    }

    case _C_PTR:
      _readObjC(self, *(char **)_value, _type + 1); // skip '^'
      break;
      
    case _C_CHARPTR:
    case _C_CHR:    case _C_UCHR:
    case _C_SHT:    case _C_USHT:
    case _C_INT:    case _C_UINT:
    case _C_LNG:    case _C_ULNG:
    case _C_FLT:    case _C_DBL:
      NSAssert(*_type == tag, @"invalid type ..");
      _readObjC(self, _value, _type);
      break;
      
    default:
      NSAssert2(0, @"unsupported tag '%c', type %s ..", tag, _type);
      break;
  }

  if (startedDecoding) {
    [self endDecoding];
    self->decodingRoot = NO;
  }
}

- (void)decodeArrayOfObjCType:(const char *)_type count:(unsigned int)_count
  at:(void *)_array {

  BOOL      startedDecoding = NO;
  NGTagType tag   = _readTag(self);
  int       count = _readInt(self);

  if (self->decodingRoot == NO) {
    self->decodingRoot = YES;
    startedDecoding = YES;
    [self beginDecoding];
  }

#if 0
  NSLog(@"decoding array[%i/%i] of ObjC-type '%s' array-tag='%c'",
         _count, count, _type, tag);
#endif
  
  NSAssert(tag == _C_ARY_B, @"invalid type ..");
  NSAssert(count == _count, @"invalid array size ..");

  // Arrays of elementary types are written optimized: the type is written
  // then the elements of array follow.
  if ((*_type == _C_ID) || (*_type == _C_CLASS)) { // object array
    int i;

#if 0
    NSLog(@"decoding object-array[%i] type='%s'", _count, _type);
#endif

    tag = _readTag(self); // object array
    NSAssert(tag == *_type, @"invalid array element type ..");
      
    for (i = 0; i < _count; i++)
      ((id *)_array)[i] = [self decodeObject];
  }
  else if ((*_type == _C_CHR) || (*_type == _C_UCHR)) { // byte array
    tag = _readTag(self);
    NSAssert((tag == _C_CHR) || (tag == _C_UCHR), @"invalid byte array type ..");

#if 0
    NSLog(@"decoding byte-array[%i] type='%s' tag='%c'",
           _count, _type, tag);
#endif

    // read buffer
    _readBytes(self, _array, _count);
  }
  else if (isBaseType(_type)) {
    unsigned offset, itemSize = objc_sizeof_type(_type);
    int      i;
      
    tag = _readTag(self);
    NSAssert(tag == *_type, @"invalid array base type ..");

    for (i = offset = 0; i < _count; i++, offset += itemSize)
      _readObjC(self, (char *)_array + offset, _type);
  }
  else {
    IMP      decodeValue = NULL;
    unsigned offset, itemSize = objc_sizeof_type(_type);
    int      i;

    decodeValue = [self methodForSelector:@selector(decodeValueOfObjCType:at:)];
    
    for (i = offset = 0; i < count; i++, offset += itemSize) {
      decodeValue(self, @selector(decodeValueOfObjCType:at:),
                  (char *)_array + offset, _type);
    }
  }

  if (startedDecoding) {
    [self endDecoding];
    self->decodingRoot = NO;
  }
}

// Substituting One Class for Another

+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)nameInArchive {
  NSString *className = NSMapGet(classToAliasMappings, nameInArchive);
  return className ? className : nameInArchive;
}
+ (void)decodeClassName:(NSString *)nameInArchive asClassName:(NSString *)trueName {
  NSMapInsert(classToAliasMappings, nameInArchive, trueName);
}

- (NSString *)classNameDecodedForArchiveClassName:(NSString *)_nameInArchive {
  NSString *className = NSMapGet(self->inClassAlias, _nameInArchive);
  return className ? className : _nameInArchive;
}
- (void)decodeClassName:(NSString *)nameInArchive asClassName:(NSString *)trueName {
  NSMapInsert(self->inClassAlias, nameInArchive, trueName);
}

// ******************** primitives ********************

// encoding

FINAL void _writeBytes(NGStreamCoder *self, const void *_bytes, unsigned _len) {
  NSCAssert(self->traceMode == NO, @"nothing can be written during trace-mode ..");
  
  self->writeIMP
    ? self->writeIMP(self->stream, @selector(safeWriteBytes:count:), _bytes, _len)
    : [self->stream safeWriteBytes:_bytes count:_len];
}

FINAL void _writeTag(NGStreamCoder *self, NGTagType _tag) {
  NSCAssert(self, @"invalid self ..");
#if 0
  NSLog(@"write tag '%s%c'",
        isReferenceTag(_tag) ? "&" : "", tagValue(_tag));
#endif
  
  [self->stream serializeChar:_tag];
}

FINAL void _writeChar(NGStreamCoder *self, char _value) {
  [self->stream serializeChar:_value];
}
FINAL void _writeShort(NGStreamCoder *self, short _value) {
  [self->stream serializeShort:_value];
}
FINAL void _writeInt(NGStreamCoder *self, int _value) {
  [self->stream serializeInt:_value];
}
FINAL void _writeLong(NGStreamCoder *self, long _value) {
  [self->stream serializeLong:_value];
}
FINAL void _writeFloat(NGStreamCoder *self, float _value) {
  [self->stream serializeFloat:_value];
}

FINAL void _writeCString(NGStreamCoder *self, const char *_value) {
  [(id)self->stream serializeDataAt:&_value ofObjCType:@encode(char *) context:self];
}

FINAL void _writeObjC(NGStreamCoder *self,
                              const void *_value, const char *_type) {
  if ((_value == NULL) || (_type == NULL))
    return;

  if (self->traceMode) {
    // no need to track base-types in trace-mode
    
    switch (*_type) {
      case _C_ID:
      case _C_CLASS:
      case _C_CHARPTR:
      case _C_ARY_B:
      case _C_STRUCT_B:
      case _C_PTR:
        [(id)self->stream serializeDataAt:_value ofObjCType:_type context:self];
        break;

      default:
        break;
    }
  }
  else {
    [(id)self->stream serializeDataAt:_value ofObjCType:_type context:self];
  }
}

// decoding

FINAL void _readBytes(NGStreamCoder *self, void *_bytes, unsigned _len) {
  self->readIMP
    ? self->readIMP(self->stream, @selector(safeReadBytes:count:), _bytes, _len)
    : [self->stream safeReadBytes:_bytes count:_len];
}

FINAL NGTagType _readTag(NGStreamCoder *self) {
  return [self->stream deserializeChar];
}
FINAL char _readChar(NGStreamCoder *self) {
  return [self->stream deserializeChar];
}
FINAL short _readShort(NGStreamCoder *self) {
  return [self->stream deserializeShort];
}
FINAL int _readInt(NGStreamCoder *self) {
  return [self->stream deserializeInt];
}
FINAL long _readLong (NGStreamCoder *self) {
  return [self->stream deserializeLong];
}
FINAL float _readFloat(NGStreamCoder *self) {
  return [self->stream deserializeFloat];
}

FINAL char *_readCString(NGStreamCoder *self) {
  char *result = NULL;
  [(id)self->stream deserializeDataAt:&result ofObjCType:@encode(char *) context:self];
  return result;
}

FINAL void _readObjC(NGStreamCoder *self, void *_value, const char *_type) {
  [(id)self->stream deserializeDataAt:_value ofObjCType:_type context:(id)self];
}

// NSObjCTypeSerializationCallBack

- (void)serializeObjectAt:(id *)_object ofObjCType:(const char *)_type
  intoData:(NSMutableData *)_data {

  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      if (self->traceMode)
        [self _traceObject:*_object];
      else
        [self _encodeObject:*_object];
      break;
        
    default:
      abort();
      break;
  }
}

- (void)deserializeObjectAt:(id *)_object ofObjCType:(const char *)_type
  fromData:(NSData *)_data atCursor:(unsigned int *)_cursor {

  NGTagType tag             = 0;
  BOOL      isReference     = NO;

  tag         = _readTag(self);
  isReference = isReferenceTag(tag);
  tag         = tagValue(tag);
  
  switch (*_type) {
    case _C_ID:
      NSAssert((*_type == _C_ID) || (*_type == _C_CLASS), @"invalid type ..");
      break;
      *_object = [self _decodeObject:isReference];
      break;
    case _C_CLASS:
      NSAssert((*_type == _C_ID) || (*_type == _C_CLASS), @"invalid type ..");
      *_object = [self _decodeClass:isReference];
      break;
      
    default:
      abort();
      break;
  }
}

@end
