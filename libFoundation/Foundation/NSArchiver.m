/* 
   NSArchiver.m

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

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

   The code is based on the NSArchiver class done by Ovidiu Predescu which has
   the following Copyright/permission:
   ---
   The basic archiving algorithm is based on libFoundation's NSArchiver by
   Ovidiu Predescu:
   
   NSArchiver.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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
   ---
*/
// $Id: NSArchiver.m 1319 2006-07-14 13:06:21Z helge $

#include <Foundation/NSData.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>
#include <extensions/objc-runtime.h>
#include "NSArchiver.h"
#include "common.h" // for Free

#define ENCODE_AUTORELEASEPOOL 0
#define ARCHIVE_DEBUGGING      0

#define FINAL static inline

typedef unsigned char NSTagType;

#define REFERENCE 128
#define VALUE     127

static NSMapTableKeyCallBacks NSIdentityObjectMapKeyCallbacks = {
  (unsigned(*)(NSMapTable *, const void *))          __NSHashPointer,
  (BOOL(*)(NSMapTable *, const void *, const void *))__NSComparePointers,
  (void (*)(NSMapTable *, const void *anObject))     __NSRetainObjects,
  (void (*)(NSMapTable *, void *anObject))           __NSReleaseObjects,
  (NSString *(*)(NSMapTable *, const void *))        __NSDescribePointers,
  (const void *)NULL
};

FINAL BOOL isBaseType(const char *_type)
{
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

FINAL BOOL isReferenceTag(NSTagType _tag)
{
    return (_tag & REFERENCE) ? YES : NO;
}

FINAL NSTagType tagValue(NSTagType _tag) {
    return _tag & VALUE; // mask out bit 8
}

static const char *NSCoderSignature = "libFoundation NSArchiver";
static int        NSCoderVersion    = 1100;

@implementation NSArchiver

- (id)initForWritingWithMutableData:(NSMutableData *)_data
{
    if ((self = [super init])) {
        self->classForCoder      = @selector(classForCoder);
        self->replObjectForCoder = @selector(replacementObjectForCoder:);
        
        self->outObjects      = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 119);
        self->outConditionals = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 119);
        self->outPointers     = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
        self->replacements    = NSCreateMapTable(NSIdentityObjectMapKeyCallbacks,
                                                 NSObjectMapValueCallBacks,
                                                 19);
        self->outClassAlias   = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                                 NSObjectMapValueCallBacks,
                                                 19);
        self->outKeys         = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                                 NSIntMapValueCallBacks,
                                                 119);

        self->archiveAddress = 1;

        self->data    = RETAIN(_data);
        self->serData = (void *)
            [self->data methodForSelector:@selector(serializeDataAt:ofObjCType:context:)];
        self->addData = (void *)
            [self->data methodForSelector:@selector(appendBytes:length:)];
    }
    return self;
}

- (id)init
{
    return [self initForWritingWithMutableData:[NSMutableData data]];
}

+ (NSData *)archivedDataWithRootObject:(id)_root
{
    NSArchiver *archiver = AUTORELEASE([self new]);
    NSData     *rdata    = nil;
    
    [archiver encodeRootObject:_root];
    rdata = [archiver->data copy];
    return AUTORELEASE(rdata);
}
+ (BOOL)archiveRootObject:(id)_root toFile:(NSString *)_path
{
    NSData *rdata = [self archivedDataWithRootObject:_root];
    return [rdata writeToFile:_path atomically:YES];
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc
{
    RELEASE(self->data);
    
    if (self->outKeys)         NSFreeMapTable(self->outKeys);
    if (self->outObjects)      NSFreeHashTable(self->outObjects);
    if (self->outConditionals) NSFreeHashTable(self->outConditionals);
    if (self->outPointers)     NSFreeHashTable(self->outPointers);
    if (self->replacements)    NSFreeMapTable(self->replacements);
    if (self->outClassAlias)   NSFreeMapTable(self->outClassAlias);
  
    [super dealloc];
}
#endif

// ******************** Getting Data from the NSArchiver ******

- (NSMutableData *)archiverData
{
    return self->data;
}

// ******************** archive id's **************************

FINAL int _archiveIdOfObject(NSArchiver *self, id _object)
{
    if (_object == nil)
        return 0;
#if 0 /* this does not work with 64bit */
    else
        return (int)_object;
#else
    else {
        int archiveId;

        archiveId = (long)NSMapGet(self->outKeys, _object);
        if (archiveId == 0) {
            archiveId = self->archiveAddress;
            NSMapInsert(self->outKeys, _object, (void*)(long)archiveId);
#if ARCHIVE_DEBUGGING
            NSLog(@"mapped 0x%p => %i", _object, archiveId);
#endif
            self->archiveAddress++;
        }

        return archiveId;
    }
#endif
}
FINAL int _archiveIdOfClass(NSArchiver *self, Class _class)
{
    return _archiveIdOfObject(self, _class);
}

// ******************** primitive encoding ********************

FINAL void _writeBytes(NSArchiver *self, const void *_bytes, unsigned _len);

FINAL void _writeTag  (NSArchiver *self, NSTagType _tag);

FINAL void _writeChar (NSArchiver *self, char _value);
FINAL void _writeShort(NSArchiver *self, short _value);
FINAL void _writeInt  (NSArchiver *self, int _value);
FINAL void _writeLong (NSArchiver *self, long _value);
FINAL void _writeFloat(NSArchiver *self, float _value);

FINAL void _writeCString(NSArchiver *self, const char *_value);
FINAL void _writeObjC(NSArchiver *self, const void *_value, const char *_type);

// ******************** complex encoding **********************

- (void)beginEncoding
{
    self->traceMode    = NO;
    self->encodingRoot = YES;
}
- (void)endEncoding
{
#if 0
    NSResetHashTable(self->outObjects);
    NSResetHashTable(self->outConditionals);
    NSResetHashTable(self->outPointers);
    NSResetMapTable(self->outClassAlias);
    NSResetMapTable(self->replacements);
    NSResetMapTable(self->outKeys);
#endif

    self->traceMode      = NO;
    self->encodingRoot   = NO;
}

- (void)writeArchiveHeader
{
    if (self->didWriteHeader == NO) {
        _writeCString(self, NSCoderSignature);
        _writeInt(self, NSCoderVersion);
        self->didWriteHeader = YES;
    }
}
- (void)writeArchiveTrailer
{
}

- (void)traceObjectsWithRoot:(id)_root
{
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

- (void)encodeObjectsWithRoot:(id)_root
{
    // encoding pass 2
    [self encodeObject:_root];
}

- (void)encodeRootObject:(id)_object
{
#if ENCODE_AUTORELEASEPOOL
    NSAutoreleasePool *pool =
        [[NSAutoreleasePool allocWithZone:[self zone]] init];
#endif
    
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

#if ENCODE_AUTORELEASEPOOL
    RELEASE(pool); pool = nil;
#endif
}

- (void)encodeConditionalObject:(id)_object
{
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

- (void)_traceObject:(id)_object
{
    if (_object == nil) // don't trace nil objects ..
        return;

    //NSLog(@"lookup 0x%p in outObjs=0x%p", _object, self->outObjects);
    
    if (NSHashGet(self->outObjects, _object) == nil) {
        //NSLog(@"lookup failed, object wasn't traced yet !");
        
        // object wasn't traced yet
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
                archiveClass = [_object performSelector:self->classForCoder];
            }
            
            [self encodeObject:archiveClass];
            [_object encodeWithCoder:self];
        }
        else {
            // there are no class-variables ..
        }
    }
}
- (void)_encodeObject:(id)_object
{
    NSTagType tag;
    int       archiveId = _archiveIdOfObject(self, _object);

    if (_object == nil) { // nil object or class
        _writeTag(self, _C_ID | REFERENCE);
        _writeInt(self, archiveId);
        return;
    }
    
    tag = object_is_instance(_object) ? _C_ID : _C_CLASS;
    
    if (NSHashGet(self->outObjects, _object)) { // object was already written
        _writeTag(self, tag | REFERENCE);
        _writeInt(self, archiveId);
    }
    else {
        // mark object as written
        NSHashInsert(self->outObjects, _object);

        /*
          if (tag == _C_CLASS) { // a class object
          NGLogT(@"encoder", @"encoding class %s:%i ..",
          class_get_class_name(_object), [_object version]);
          }
          else {
          NGLogT(@"encoder", @"encoding object 0x%p<%s> ..",
          _object, class_get_class_name(*(Class *)_object));
          }
        */
    
        _writeTag(self, tag);
        _writeInt(self, archiveId);

        if (tag == _C_CLASS) { // a class object
            NSString *className;
            unsigned len;
            char *buf;
            
            className = NSStringFromClass(_object);
            className = [self classNameEncodedForTrueClassName:className];
            len = [className cStringLength];
            buf = malloc(len + 4);
            [className getCString:buf]; buf[len] = '\0';
            
            _writeCString(self, buf);
            _writeInt(self, [_object version]);
            if (buf) free(buf);
        }
        else {
            Class archiveClass = Nil;
            id    replacement  = nil;

            replacement = NSMapGet(self->replacements, _object);
            if (replacement) _object = replacement;

            /*
              _object = [_object performSelector:self->replObjectForCoder
              withObject:self];
            */
            archiveClass = [_object performSelector:self->classForCoder];
            
            NSAssert(archiveClass, @"no archive class found ..");

            [self encodeObject:archiveClass];
            [_object encodeWithCoder:self];
        }
    }
}

- (void)encodeObject:(id)_object
{
    if (self->encodingRoot) {
        [self encodeValueOfObjCType:
                object_is_instance(_object) ? "@" : "#"
              at:&_object];
    }
    else {
        [self encodeRootObject:_object];
    }
}

- (void)_traceValueOfObjCType:(const char *)_type at:(const void *)_value
{
    //NSLog(@"_tracing value at 0x%p of type %s", _value, _type);
    
    switch (*_type) {
        case _C_ID:
        case _C_CLASS:
            //NSLog(@"_traceObject 0x%p", *(id *)_value);
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

- (void)_encodeValueOfObjCType:(const char *)_type at:(const void *)_value
{
    //NGLogT(@"encoder", @"encoding value of ObjC-type '%s' at %i",
    //       _type, [self->data length]);
  
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
            NSLog(@"unsupported C type %s ..", _type);
            break;
    }
}

- (void)encodeValueOfObjCType:(const char *)_type
                           at:(const void *)_value
{
    if (self->traceMode) {
        //NSLog(@"trace value at 0x%p of type %s", _value, _type);
        [self _traceValueOfObjCType:_type at:_value];
    }
    else {
        if (self->didWriteHeader == NO)
            [self writeArchiveHeader];
  
        [self _encodeValueOfObjCType:_type at:_value];
    }
}

- (void)encodeArrayOfObjCType:(const char *)_type
                        count:(unsigned int)_count
                           at:(const void *)_array
{

    if ((self->didWriteHeader == NO) && (self->traceMode == NO))
        [self writeArchiveHeader];

    //NGLogT(@"encoder", @"%s array[%i] of ObjC-type '%s'",
    //       self->traceMode ? "tracing" : "encoding", _count, _type);
  
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
            //NGLogT(@"encoder", @"encode byte-array (base='%c', count=%i)", *_type, _count);

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

            /*
              NGLogT(@"encoder",
              @"encode basetype-array (base='%c', itemSize=%i, count=%i)",
              *_type, itemSize, _count);
              */

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

// Substituting One Class for Another

- (NSString *)classNameEncodedForTrueClassName:(NSString *)_trueName
{
    NSString *name = NSMapGet(self->outClassAlias, _trueName);
    return name ? name : _trueName;
}
- (void)encodeClassName:(NSString *)_name intoClassName:(NSString *)_archiveName
{
    NSMapInsert(self->outClassAlias, _name, _archiveName);
}

// ******************** primitive encoding ********************

FINAL void _writeBytes(NSArchiver *self, const void *_bytes, unsigned _len)
{
    NSCAssert(self->traceMode == NO, @"nothing can be written during trace-mode ..");
    self->addData(self->data, @selector(appendBytes:length:), _bytes, _len);
}
FINAL void _writeTag(NSArchiver *self, NSTagType _tag)
{
    unsigned char t = _tag;
    NSCAssert(self, @"invalid self ..");
    _writeBytes(self, &t, sizeof(t));
}
FINAL void _writeChar(NSArchiver *self, char _value)
{
    _writeBytes(self, &_value, sizeof(_value));
}

FINAL void _writeShort(NSArchiver *self, short _value)
{
    self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                  &_value, @encode(short), self);
}
FINAL void _writeInt(NSArchiver *self, int _value)
{
    self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                  &_value, @encode(int), self);
}
FINAL void _writeLong(NSArchiver *self, long _value)
{
    self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                  &_value, @encode(long), self);
}
FINAL void _writeFloat(NSArchiver *self, float _value)
{
    self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                  &_value, @encode(float), self);
}

FINAL void _writeCString(NSArchiver *self, const char *_value)
{
    self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                  &_value, @encode(char *), self);
}

FINAL void _writeObjC(NSArchiver *self, const void *_value, const char *_type)
{
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
                self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                              _value, _type, self);
                break;

            default:
                break;
        }
    }
    else {
        self->serData(self->data, @selector(serializeDataAt:ofObjCType:context:),
                      _value, _type, self);
    }
}

// NSObjCTypeSerializationCallBack

- (void)serializeObjectAt:(id *)_object
               ofObjCType:(const char *)_type
                 intoData:(NSMutableData *)_data
{
    NSAssert(((*_type == _C_ID) || (*_type == _C_CLASS)), @"unexpected type ..");

    if (self->traceMode)
        [self _traceObject:*_object];
    else
        [self _encodeObject:*_object];
}
- (void)deserializeObjectAt:(id *)_object
        ofObjCType:(const char *)_type
        fromData:(NSData *)_data
        atCursor:(unsigned int *)_cursor
{
    [self doesNotRecognizeSelector:_cmd];
}

@end /* NSArchiver */

@implementation NSUnarchiver

static NSMapTable *classToAliasMappings = NULL; // archive name => decoded name

+ (void)initialize
{
    static BOOL isInitialized = NO;
    if (!isInitialized) {
        isInitialized = YES;

        classToAliasMappings = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                                NSObjectMapValueCallBacks,
                                                19);
    }
}
  
- (id)initForReadingWithData:(NSData*)_data
{
    if ((self = [super init])) {
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
        self->data = RETAIN(_data);
        self->deserData = (void *)
            [self->data methodForSelector:
                 @selector(deserializeDataAt:ofObjCType:atCursor:context:)];
        self->getData = (void *)
            [self->data methodForSelector:@selector(deserializeBytes:length:atCursor:)];
    }
    return self;
}

/* Decoding Objects */

+ (id)unarchiveObjectWithData:(NSData*)_data
{
    NSUnarchiver *unarchiver = [[self alloc] initForReadingWithData:_data];
    id           object      = [unarchiver decodeObject];

    RELEASE(unarchiver); unarchiver = nil;
  
    return object;
}
+ (id)unarchiveObjectWithFile:(NSString*)path
{
    NSData *rdata = [NSData dataWithContentsOfFile:path];
    if (!rdata) return nil;
    return [self unarchiveObjectWithData:rdata];
}


#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc
{
    RELEASE(self->data); self->data = nil;
  
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
  
    [super dealloc];
}
#endif

/* Managing an NSUnarchiver */

- (BOOL)isAtEnd
{
    return ([self->data length] <= self->cursor) ? YES : NO;
}

- (void)setObjectZone:(NSZone *)_zone
{
    self->objectZone = _zone;
}
- (NSZone *)objectZone
{
    return self->objectZone;
}

- (unsigned int)systemVersion
{
    return self->inArchiverVersion;
}

// ******************** primitive decoding ********************

FINAL void _readBytes(NSUnarchiver *self, void *_bytes, unsigned _len);

FINAL NSTagType _readTag(NSUnarchiver *self);

FINAL char  _readChar (NSUnarchiver *self);
FINAL short _readShort(NSUnarchiver *self);
FINAL int   _readInt  (NSUnarchiver *self);
FINAL long  _readLong (NSUnarchiver *self);
FINAL float _readFloat(NSUnarchiver *self);

FINAL char *_readCString(NSUnarchiver *self);
FINAL void _readObjC(NSUnarchiver *self, void *_value, const char *_type);

// ******************** complex decoding **********************

- (void)decodeArchiveHeader
{
    if (self->didReadHeader == NO) {
        char *archiver = _readCString(self);

        self->inArchiverVersion = _readInt(self);

        //NGLogT(@"decoder", @"decoding archive archived using '%s':%i ..",
        //       archiver, archiverVersion);

        if (strcmp(archiver, NSCoderSignature)) {
            NSLog(@"WARNING: used a different archiver (signature %s:%i)",
                  archiver, [self systemVersion]);
        }
        else if ([self systemVersion] != NSCoderVersion) {
            NSLog(@"WARNING: used a different archiver version "
                  @"(archiver=%i, unarchiver=%i)",
                  [self systemVersion], NSCoderVersion);
        }

        if (archiver) {
            lfFree(archiver);
            archiver = NULL;
        }
        self->didReadHeader = YES;
    }
}

- (void)beginDecoding
{
    //self->cursor = 0;
    [self decodeArchiveHeader];
}
- (void)endDecoding
{
#if 0
    NSResetMapTable(self->inObjects);
    NSResetMapTable(self->inClasses);
    NSResetMapTable(self->inPointers);
    NSResetMapTable(self->inClassAlias);
    NSResetMapTable(self->inClassVersions);
#endif

    self->decodingRoot = NO;
}

- (Class)_decodeClass:(BOOL)_isReference
{
    int   archiveId = _readInt(self);
    Class result    = Nil;

    if (archiveId == 0) // Nil class or unused conditional class
        return nil;
    
    if (_isReference) {
        NSAssert(archiveId, @"archive id is 0 !");
        
        result = (Class)NSMapGet(self->inClasses, (void *)(long)archiveId);
        if (result == nil)
            result = (id)NSMapGet(self->inObjects, (void *)(long)archiveId);
        if (result == nil) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"did not find referenced class %i.", archiveId];
        }
    }
    else {
        NSString *name   = NULL;
        int      version = 0;
        char     *cname  = _readCString(self);

        if (cname == NULL) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"could not decode class name."];
        }
        
        name    = [NSString stringWithCString:cname];
        version = _readInt(self);
        lfFree(cname); cname = NULL;
        
        if ([name cStringLength] == 0) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"could not allocate memory for class name."];
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

        if (result == Nil) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"class doesn't exist in this runtime."];
        }
        name = nil;

        if ([result version] != version) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"class versions do not match."];
        }

        NSMapInsert(self->inClasses, (void *)(long)archiveId, result);
#if ARCHIVE_DEBUGGING
        NSLog(@"read class %i => 0x%p", archiveId, result);
#endif
    }
  
    NSAssert(result, @"Invalid state, class is Nil.");
  
    return result;
}

- (id)_decodeObject:(BOOL)_isReference
{
    // this method returns a retained object !
    int archiveId = _readInt(self);
    id  result    = nil;

    if (archiveId == 0) // nil object or unused conditional object
        return nil;

    if (_isReference) {
        NSAssert(archiveId, @"archive id is 0 !");
        
        result = (id)NSMapGet(self->inObjects, (void *)(long)archiveId);
        if (result == nil)
            result = (id)NSMapGet(self->inClasses, (void *)(long)archiveId);
        
        if (result == nil) {
            [NSException raise:NSInconsistentArchiveException
                         format:@"did not find referenced object %i.",
			 archiveId];
        }
        result = RETAIN(result);
    }
    else {
        Class class       = Nil;
        id    replacement = nil;

        // decode class info
        [self decodeValueOfObjCType:"#" at:&class];
        NSAssert(class, @"could not decode class for object.");
    
        result = [class allocWithZone:self->objectZone];
        NSMapInsert(self->inObjects, (void *)(long)archiveId, result);
        
#if ARCHIVE_DEBUGGING
        NSLog(@"read object %i => 0x%p", archiveId, result);
#endif

        replacement = [result initWithCoder:self];
        if (replacement != result) {
            /*
              NGLogT(@"decoder",
              @"object 0x%p<%s> replaced by 0x%p<%s> in initWithCoder:",
              result, class_get_class_name(*(Class *)result),
              replacement, class_get_class_name(*(Class *)replacement));
            */

            replacement = RETAIN(replacement);
            NSMapRemove(self->inObjects, (void *)(long)archiveId);
            result = replacement;
            NSMapInsert(self->inObjects, (void *)(long)archiveId, result);
            RELEASE(replacement);
        }

        replacement = [result awakeAfterUsingCoder:self];
        if (replacement != result) {
            /*
              NGLogT(@"decoder",
              @"object 0x%p<%s> replaced by 0x%p<%s> in awakeAfterUsingCoder:",
              result, class_get_class_name(*(Class *)class),
              replacement, class_get_class_name(*(Class *)replacement));
            */
      
            replacement = RETAIN(replacement);
            NSMapRemove(self->inObjects, (void *)(long)archiveId);
            result = replacement;
            NSMapInsert(self->inObjects, (void *)(long)archiveId, result);
            RELEASE(replacement);
        }

        //NGLogT(@"decoder", @"decoded object 0x%p<%@>",
        //       (unsigned)result, NSStringFromClass([result class]));
    }
    
    if (object_is_instance(result)) {
        NSAssert3([result retainCount] > 0,
                  @"invalid retain count %i for id=%i (%@) ..",
                  [result retainCount],
                  archiveId,
                  NSStringFromClass([result class]));
    }
    return result;
}

- (id)decodeObject
{
    id result = nil;

    [self decodeValueOfObjCType:"@" at:&result];
  
    // result is retained
    return AUTORELEASE(result);
}

FINAL void _checkType(char _code, char _reqCode)
{
    if (_code != _reqCode) {
        [NSException raise:NSInconsistentArchiveException
                     format:@"expected different typecode"];
    }
}
FINAL void _checkType2(char _code, char _reqCode1, char _reqCode2)
{
    if ((_code != _reqCode1) && (_code != _reqCode2)) {
        [NSException raise:NSInconsistentArchiveException
                     format:@"expected different typecode"];
    }
}

- (void)decodeValueOfObjCType:(const char *)_type
  at:(void *)_value
{
    BOOL      startedDecoding = NO;
    NSTagType tag             = 0;
    BOOL      isReference     = NO;

    if (self->decodingRoot == NO) {
        self->decodingRoot = YES;
        startedDecoding = YES;
        [self beginDecoding];
    }

    //NGLogT(@"decoder", @"cursor is now %i", self->cursor);
  
    tag         = _readTag(self);
    isReference = isReferenceTag(tag);
    tag         = tagValue(tag);

#if ARCHIVE_DEBUGGING
    NSLog(@"decoder: decoding tag '%s%c' type '%s'",
           isReference ? "&" : "", tag, _type);
#endif

    switch (tag) {
        case _C_ID:
            _checkType2(*_type, _C_ID, _C_CLASS);
            *(id *)_value = [self _decodeObject:isReference];
            break;
        case _C_CLASS:
            _checkType2(*_type, _C_ID, _C_CLASS);
            *(Class *)_value = [self _decodeClass:isReference];
            break;

        case _C_ARY_B: {
            int        count     = atoi(_type + 1); // eg '[15I' => count = 15
            const char *itemType = _type;

            _checkType(*_type, _C_ARY_B);

            while(isdigit((int)*(++itemType))) ; // skip dimension

            [self decodeArrayOfObjCType:itemType count:count at:_value];
            break;
        }

        case _C_STRUCT_B: {
            int offset = 0;

            _checkType(*_type, _C_STRUCT_B);
      
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
      
            _checkType(*_type, tag);

            _readObjC(self, &name, @encode(char *));
            *(SEL *)_value = name ? sel_get_any_uid(name) : NULL;
            lfFree(name); name = NULL;
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
            _checkType(*_type, tag);
            _readObjC(self, _value, _type);
            break;
      
        default:
            [NSException raise:NSInconsistentArchiveException
                         format:@"unsupported typecode %i found.", tag];
            break;
    }

    if (startedDecoding) {
        [self endDecoding];
        self->decodingRoot = NO;
    }
}

- (void)decodeArrayOfObjCType:(const char *)_type
  count:(unsigned int)_count
  at:(void *)_array
{
    BOOL      startedDecoding = NO;
    NSTagType tag   = _readTag(self);
    int       count = _readInt(self);

    if (self->decodingRoot == NO) {
        self->decodingRoot = YES;
        startedDecoding = YES;
        [self beginDecoding];
    }
  
    //NGLogT(@"decoder", @"decoding array[%i/%i] of ObjC-type '%s' array-tag='%c'",
    //       _count, count, _type, tag);
  
    NSAssert(tag == _C_ARY_B, @"invalid type ..");
    NSAssert(count == _count, @"invalid array size ..");

    // Arrays of elementary types are written optimized: the type is written
    // then the elements of array follow.
    if ((*_type == _C_ID) || (*_type == _C_CLASS)) { // object array
        int i;

        //NGLogT(@"decoder", @"decoding object-array[%i] type='%s'", _count, _type);
    
        tag = _readTag(self); // object array
        NSAssert(tag == *_type, @"invalid array element type ..");
      
        for (i = 0; i < _count; i++)
            ((id *)_array)[i] = [self decodeObject];
    }
    else if ((*_type == _C_CHR) || (*_type == _C_UCHR)) { // byte array
        tag = _readTag(self);
        NSAssert((tag == _C_CHR) || (tag == _C_UCHR), @"invalid byte array type ..");

        //NGLogT(@"decoder", @"decoding byte-array[%i] type='%s' tag='%c'",
        //       _count, _type, tag);
    
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

/* Substituting One Class for Another */

+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)nameInArchive
{
    NSString *className = NSMapGet(classToAliasMappings, nameInArchive);
    return className ? className : nameInArchive;
}

+ (void)decodeClassName:(NSString *)nameInArchive
            asClassName:(NSString *)trueName
{
    NSMapInsert(classToAliasMappings, nameInArchive, trueName);
}

- (NSString *)classNameDecodedForArchiveClassName:(NSString *)_nameInArchive
{
    NSString *className = NSMapGet(self->inClassAlias, _nameInArchive);
    return className ? className : _nameInArchive;
}
- (void)decodeClassName:(NSString *)nameInArchive asClassName:(NSString *)trueName
{
    NSMapInsert(self->inClassAlias, nameInArchive, trueName);
}

// ******************** primitive decoding ********************

FINAL void _readBytes(NSUnarchiver *self, void *_bytes, unsigned _len)
{
    self->getData(self->data, @selector(deserializeBytes:length:atCursor:),
                  _bytes, _len, &(self->cursor));
}

FINAL NSTagType _readTag(NSUnarchiver *self)
{
    unsigned char c;
    NSCAssert(self, @"invalid self ..");

    _readBytes(self, &c, sizeof(c));
    if (c == 0) {
        [NSException raise:NSInconsistentArchiveException
                     format:@"found invalid type tag (0)"];
    }
    return (NSTagType)c;
}
FINAL char _readChar(NSUnarchiver *self)
{
    char c;
    _readBytes(self, &c, sizeof(c));
    return c;
}

FINAL short _readShort(NSUnarchiver *self)
{
    short value;
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    &value, @encode(short), &(self->cursor), self);
    return value;
}
FINAL int _readInt(NSUnarchiver *self)
{
    int value;
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    &value, @encode(int), &(self->cursor), self);
    return value;
}
FINAL long _readLong (NSUnarchiver *self)
{
    long value;
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    &value, @encode(long), &(self->cursor), self);
    return value;
}
FINAL float _readFloat(NSUnarchiver *self)
{
    float value;
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    &value, @encode(float), &(self->cursor), self);
    return value;
}

FINAL char *_readCString(NSUnarchiver *self)
{
    char *value = NULL;
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    &value, @encode(char *), &(self->cursor), self);
    return value;
}

FINAL void _readObjC(NSUnarchiver *self, void *_value, const char *_type)
{
    self->deserData(self->data,
                    @selector(deserializeDataAt:ofObjCType:atCursor:context:),
                    _value, _type,
                    &(self->cursor),
                    self);
}

// NSObjCTypeSerializationCallBack

- (void)serializeObjectAt:(id *)_object
  ofObjCType:(const char *)_type
  intoData:(NSMutableData *)_data
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deserializeObjectAt:(id *)_object
  ofObjCType:(const char *)_type
  fromData:(NSData *)_data
  atCursor:(unsigned int *)_cursor
{
    NSTagType tag             = 0;
    BOOL      isReference     = NO;

    tag         = _readTag(self);
    isReference = isReferenceTag(tag);
    tag         = tagValue(tag);

    NSCAssert(((*_type == _C_ID) || (*_type == _C_CLASS)),
              @"unexpected type ..");
  
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
            [NSException raise:NSInconsistentArchiveException
                         format:@"encountered type '%s' in object context",
                           _type];
            break;
    }
}

@end /* NSUnarchiver */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
