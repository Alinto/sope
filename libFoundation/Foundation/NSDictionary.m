/* 
   NSDictionary.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <stdarg.h>
#include <stdio.h>

#include <Foundation/common.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSNull.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/PropertyListParser.h>

#include "NSConcreteDictionary.h"
#include "NSObject+PropLists.h"


@interface __KeyValueDescription : NSObject
{
@public
    NSString* keyDescription;
    NSString* valueDescription;
}
@end /* __KeyValueDescription */

@implementation __KeyValueDescription
- (NSComparisonResult)compare:(__KeyValueDescription*)other
{
    return [keyDescription compare:other->keyDescription];
}
@end /* __KeyValueDescription */


/*
 * NSDictionary class
 */

@implementation NSDictionary

/* Creating and Initializing an NSDictionary */

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject( (self == [NSDictionary class]) ? 
			     [NSConcreteHashDictionary class] : (Class)self,
			     0, zone);
}
+ (id)allocWithZone:(NSZone *)_zone forCapacity:(unsigned)_capacity {
    if (self == [NSDictionary class]) {
        switch (_capacity) {
            case 0:
                return NSAllocateObject([NSConcreteEmptyDictionary class],
                                        0, _zone);
            case 1:
                return NSAllocateObject([NSConcreteSingleObjectDictionary class],
                                        0, _zone);
            default:
#if defined(SMALL_NSDICTIONARY_SIZE)
                if (_capacity <= SMALL_NSDICTIONARY_SIZE) {
                    return NSAllocateObject([NSConcreteSmallDictionary class],
                                            sizeof(NSSmallDictionaryEntry) *
                                            _capacity,
                                            _zone);
                }
                else
                    return NSAllocateObject([NSConcreteHashDictionary class],
                                            0, _zone);
#else
                return NSAllocateObject([NSConcreteHashDictionary class], 0, _zone);
#endif
        }
    }
    else
        return NSAllocateObject(self, 0, _zone);
}

+ (id)dictionary
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:0]
                              initWithDictionary:nil]);
}

+ (id)dictionaryWithContentsOfFile:(NSString*)path
{
    volatile id plist = nil;

    NSString *format = @"%@: file=%@, caught exception %@ with reason %@ ";
    
    NS_DURING {
        plist = NSParsePropertyListFromFile(path);

        if (![plist isKindOfClass:[NSDictionary class]])
            plist = nil;
        else if (![plist isKindOfClass:[NSMutableDictionary class]])
            plist = AUTORELEASE([plist mutableCopy]);
    }
    NS_HANDLER {
        NSLog(format, self, path,
              [localException name], [localException reason]);
        plist = nil;
    }
    NS_ENDHANDLER;

    return plist;
}
+ (id)dictionaryWithContentsOfURL:(NSURL *)_url
{
    id plist;
    
    if ([_url isFileURL])
        return [self dictionaryWithContentsOfFile:[_url path]];
    
    plist = [[NSString stringWithContentsOfURL:_url] propertyList];
    if (![plist isKindOfClass:[NSDictionary class]])
        return nil;
    return plist;
}

+ (id)dictionaryWithObjects:(NSArray*)objects forKeys:(NSArray*)keys
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:[keys count]]
                              initWithObjects:objects forKeys:keys]);
}

+ (id)dictionaryWithObjects:(id*)objects forKeys:(id*)keys
  count:(unsigned int)count;
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:count]
                           initWithObjects:objects forKeys:keys count:count]);
}

+ (id)dictionaryWithObjectsAndKeys:(id)firstObject, ...
{
    id dict = [self alloc];
    va_list va;
    
    va_start(va, firstObject);
    dict = [dict initWithObjectsAndKeys:firstObject arguments:va];
    va_end(va);
    
    return AUTORELEASE(dict);
}

+ (id)dictionaryWithDictionary:(NSDictionary*)aDict
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:[aDict count]]
                              initWithDictionary:aDict]);
}

+ (id)dictionaryWithObject:object forKey:key
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:1]
                           initWithObjects:&object forKeys:&key count:1]);
}

- (id)initWithContentsOfFile:(NSString *)fileName
{
    NSDictionary *plist;
    
    if ((plist = [NSDictionary dictionaryWithContentsOfFile:fileName])) {
        return [self initWithDictionary:plist];
    }
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}
- (id)initWithContentsOfURL:(NSURL *)_url
{
    NSDictionary *plist;
    
    if ((plist = [NSDictionary dictionaryWithContentsOfURL:_url])) {
        return [self initWithDictionary:plist];
    }
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}

- (id)initWithDictionary:(NSDictionary*)dictionary copyItems:(BOOL)flag
{
    NSEnumerator* keye = [dictionary keyEnumerator];
    unsigned count = [dictionary count];

    id *keys   = Calloc(count, sizeof(id));
    id *values = Calloc(count, sizeof(id));
    id key;
    
    count = 0;
    while ((key = [keye nextObject])) {
	keys[count] = key;
	values[count] = [dictionary objectForKey:key];
	if (flag) {
	    keys[count]   = AUTORELEASE([keys[count]   copyWithZone:NULL]);
	    values[count] = AUTORELEASE([values[count] copyWithZone:NULL]);
	}
	count++;
    }
    
    self = [self initWithObjects:values forKeys:keys count:count];
    
    lfFree(keys);   key = NULL;
    lfFree(values); values = NULL;
    return self;
}

- (id)initWithDictionary:(NSDictionary*)dictionary
{
    return [self initWithDictionary:dictionary copyItems:NO];
}

- (id)initWithObjectsAndKeys:(id)firstObject,...
{
    va_list va;
    
    va_start(va, firstObject);
    self = [self initWithObjectsAndKeys:firstObject arguments:va];
    va_end(va);
    
    return self;
}

- (id)initWithObjects:(NSArray *)objects forKeys:(NSArray *)keys
{
    unsigned int i, count = [objects count];
    id *mkeys;
    id *mobjs;
    
    if (count != [keys count]) {
	[[[InvalidArgumentException alloc] initWithReason:
		@"NSDictionary initWithObjects:forKeys must \
		    have both arguments of the same size"] raise];
    }
    mkeys = Calloc(count, sizeof(id));
    mobjs = Calloc(count, sizeof(id));
    
    for (i = 0; i < count; i++) {
	mkeys[i] = [keys    objectAtIndex:i];
	mobjs[i] = [objects objectAtIndex:i];
    }
    
    self = [self initWithObjects:mobjs forKeys:mkeys count:count];
    
    lfFree(mkeys); mkeys = NULL;
    lfFree(mobjs); mobjs = NULL;
    return self;
}

- (id)initWithObjects:(id *)objects forKeys:(id *)keys 
  count:(unsigned int)count
{
    [self subclassResponsibility:_cmd];
    return self;
}

/* Accessing Keys and Values */

static NSArray *emptyArray = nil;

- (NSArray *)allKeys
{
    id array;
    id *objs;
    id keys = [self keyEnumerator];
    id key;
    unsigned int index = 0, lcount;

    if ((lcount = [self count]) == 0) {
	if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
	return emptyArray;
    }
    
    objs = Calloc(lcount, sizeof(id));
    {
        while ((key = [keys nextObject]))
            objs[index++] = key;
    
        array = AUTORELEASE([[NSArray alloc] initWithObjects:objs count:index]);
    }
    lfFree(objs);
    return array;
}

- (NSArray *)allKeysForObject:(id)object
{
    id array;
    id *objs;
    id keys = [self keyEnumerator];
    id key;
    unsigned int index = 0, lcount;
    
    if ((lcount = [self count]) == 0) {
	if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
	return emptyArray;
    }
    
    objs = Calloc(lcount, sizeof(id));
    {
        while ((key = [keys nextObject])) {
            if ([object isEqual:[self objectForKey:key]])
                objs[index++] = key;
        }
	
        array = AUTORELEASE([[NSArray alloc] initWithObjects:objs count:index]);
    }
    lfFree(objs);
    return array;
}

- (NSArray *)allValues
{
    id array;
    id *objs;
    id keys = [self objectEnumerator];
    id obj;
    unsigned int index = 0, lcount;

    if ((lcount = [self count]) == 0) {
	if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
	return emptyArray;
    }
    
    objs = Calloc(lcount, sizeof(id));
    {
        while ((obj = [keys nextObject]))
            objs[index++] = obj;
    
        array = AUTORELEASE([[NSArray alloc] initWithObjects:objs count:index]);
    }
    lfFree(objs);
    return array;
}

- (NSEnumerator *)keyEnumerator
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSEnumerator*)objectEnumerator
{
    return AUTORELEASE([[_NSDictionaryObjectEnumerator alloc]
                           initWithDictionary:self]);
}

- (id)objectForKey:(id)aKey;
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSArray *)objectsForKeys:(NSArray *)keys notFoundMarker:(id)notFoundObj
{
    unsigned count, i;
    id  *objs;
    id  ret;

    if ((count = [keys count]) == 0) {
	if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
	return emptyArray;
    }
    
    objs = Calloc(count, sizeof(id));
    {
        for (i = 0; i < count; i++) {
            id ret;
            
            ret = [keys objectAtIndex:i];
#if DEBUG
            NSAssert1(ret, @"got no key for index %d", i);
#endif
            ret = [self objectForKey:ret];
            objs[i] = ret ? ret : notFoundObj;
        }
        
        ret = AUTORELEASE([[NSArray alloc] initWithObjects:objs count:count]);
    }
    lfFree(objs);
    return ret;
}

/* Counting Entries */

- (unsigned int)count;
{
    [self subclassResponsibility:_cmd];
    return 0;
}

/*
 * Comparing Dictionaries
 */

- (BOOL)isEqualToDictionary:(NSDictionary*)other
{
    id keys, key;
    if( other == self )
	return YES;
    if ([self count] != [other count] || other == nil)
	return NO;
    keys = [self keyEnumerator];
    while ((key = [keys nextObject]))
	if ([[self objectForKey:key] isEqual:[other objectForKey:key]]==NO)
	    return NO;
    return YES;
}

/* Storing Dictionaries */

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent
{
    return [self descriptionWithLocale:_locale indent:_indent];
}

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
  indent:(unsigned int)indent;
{
    static NSNull  *null = nil;
    id             key, value;
    NSEnumerator   *enumerator;
    unsigned       indent1 = indent + 4;
    NSMutableArray *keyDescriptions;
    SEL sel;
    IMP imp;
    __KeyValueDescription *descHolder;
    NSMutableString *description, *indentation;
#if !LIB_FOUNDATION_BOEHM_GC
    NSAutoreleasePool *pool = nil;
#endif
    
    if(![self count])
	return @"{}";
    
    if (null == nil) null = [[NSNull null] retain];
    
    description = [NSMutableString stringWithCString:"{\n"];
    indentation = [NSString stringWithFormat:
                              [NSString stringWithFormat:@"%%%dc", indent1], ' '];
#if !LIB_FOUNDATION_BOEHM_GC
    pool = [[NSAutoreleasePool alloc] init];
#endif

    enumerator = [self keyEnumerator];
    keyDescriptions = [NSMutableArray arrayWithCapacity:[self count]];

    while ((key = [enumerator nextObject])) {
	descHolder = [__KeyValueDescription alloc];
	value = [self objectForKey:key];

#if DEBUG
        NSAssert3(value, @"got no value for key %@ in 0x%p<%@>",
                  key, self, NSStringFromClass([self class]));
#endif
        descHolder->keyDescription =
            [key propertyListStringWithLocale:locale indent:indent1];
	
	if (value == null) {
#if DEBUG
	    NSLog(@"WARNING(%s): "
		  @"encoding NSNull in property list for key %@ !",
		  __PRETTY_FUNCTION__, key);
#endif
	    descHolder->valueDescription = @"\"\"";
	}
	else {
	    descHolder->valueDescription =
		[value propertyListStringWithLocale:locale indent:indent1];
	}
	
#if DEBUG && 0        
	NSAssert2([descHolder->keyDescription isKindOfClass:[NSString class]],
                  @"key-desc is class %@ (k=%@), should be NSString",
                  NSStringFromClass([descHolder->keyDescription class]),
                  key);
        
	NSAssert2([descHolder->valueDescription isKindOfClass:[NSString class]],
                  @"value-desc is class %@ (v=%@), should be NSString",
                  NSStringFromClass([descHolder->valueDescription class]),
                  value);
#endif
	[keyDescriptions addObject:descHolder];
	RELEASE(descHolder);
    }
    
    [keyDescriptions sortUsingSelector:@selector(compare:)];

    sel = @selector(appendString:);
    imp = [description methodForSelector:sel];
    NSAssert(imp != NULL, @"got no IMP for -appendString ...");
    
    enumerator = [keyDescriptions objectEnumerator];
    while((descHolder = [enumerator nextObject])) {
	(*imp)(description, sel, indentation);
	(*imp)(description, sel, descHolder->keyDescription);
	(*imp)(description, sel, @" = ");
	(*imp)(description, sel, descHolder->valueDescription);
	(*imp)(description, sel, @";\n");
    }
    (*imp)(description, sel, indent
	    ? [NSMutableString stringWithFormat:
			[NSString stringWithFormat:@"%%%dc}", indent], ' ']
	    : [NSMutableString stringWithCString:"}"]);

    RELEASE(pool);

    return description;
}

- (NSString *)descriptionInStringsFileFormat
{
    static Class NSStringClass = Nil;
    id key, value;
    NSMutableArray* keys;
    NSEnumerator* enumerator;
    NSMutableString* description = AUTORELEASE([NSMutableString new]);
    CREATE_AUTORELEASE_POOL(pool);
    
    if (NSStringClass == Nil) NSStringClass = [NSString class];
    keys = AUTORELEASE([[self allKeys] mutableCopy]);
    [keys sortUsingSelector:@selector(compare:)];
    
    enumerator = [keys objectEnumerator];
    while((key = [enumerator nextObject])) {
	value = [self objectForKey:key];
	
	NSAssert([key   isKindOfClass:NSStringClass], @"key is not a string !");
	NSAssert([value isKindOfClass:NSStringClass], @"value is not a string !");
	
	[description appendString:[key stringRepresentation]];
	[description appendString:@" = "];
	[description appendString:[value stringRepresentation]];
	[description appendString:@";\n"];
    }
    RELEASE(pool);

    return description;
}

- (NSString *)descriptionWithLocale:(NSDictionary*)locale
{
    return [self descriptionWithLocale:locale indent:0];
}

- (NSString *)description
{
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString *)stringRepresentation
{
    return [self descriptionWithLocale:nil indent:0];
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    NSString *description;
    
    description = [self description];
    
    return [description writeToFile:path atomically:useAuxiliaryFile];
}

/* From adopted/inherited protocols */

- (unsigned)hash
{
    return [self count];
}

- (BOOL)isEqual:(id)anObject
{
    if ([anObject isKindOfClass:[NSDictionary class]] == NO)
	return NO;
    return [self isEqualToDictionary:anObject];
}

- (id)copyWithZone:(NSZone*)zone
{
    return (NSShouldRetainWithZone(self, zone))
	? RETAIN(self)
        : [[NSDictionary allocWithZone:zone]
                         initWithDictionary:self copyItems:NO];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[NSMutableDictionary allocWithZone:zone]
                                 initWithDictionary:self];
}

- (Class)classForCoder
{
    return [NSDictionary class];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    int count = [self count];
    NSEnumerator* enumerator = [self keyEnumerator];
    id key, value;

    [aCoder encodeValueOfObjCType:@encode(int) at:&count];
    while((key = [enumerator nextObject])) {
	value = [self objectForKey:key];
	[aCoder encodeObject:key];
	[aCoder encodeObject:value];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    int count;

    [aDecoder decodeValueOfObjCType:@encode(int) at:&count];
    if (count > 0) {
        id  *keys, *values;
        int i;
        
        keys   = Calloc(count, sizeof(id));
        values = Calloc(count, sizeof(id));
        
        for(i = 0; i < count; i++) {
            keys[i]   = [aDecoder decodeObject];
            values[i] = [aDecoder decodeObject];
        }

        self = [self initWithObjects:values forKeys:keys count:count];

        lfFree(keys);   keys   = NULL;
        lfFree(values); values = NULL;
    }
    else {
        self = [self init];
    }
    return self;
}

@end /* NSDictionary */

/*
 * Extensions to NSDictionary
 */

@implementation NSDictionary(NSDictionaryExtensions)

- (id)initWithObjectsAndKeys:(id)firstObject arguments:(va_list)argList
{
    id      object;
    id      *ka, *oa;
    va_list va;
    int     count = 0;
    
    lfCopyVA(va, argList);
    
    for (object = firstObject; object; object = va_arg(va,id)) {
	if (!va_arg(va,id)) {
	    [[[InvalidArgumentException alloc] 
		 initWithReason:@"Nil key to be added in dictionary"] raise];
	}
	count++;
    }
    
    ka = Calloc(count, sizeof(id));
    oa = Calloc(count, sizeof(id));
    
    for (count=0, object=firstObject; object; object=va_arg(argList,id)) {
	ka[count] = va_arg(argList,id);
	oa[count] = object;
	count++;
    }

    self = [self initWithObjects:oa forKeys:ka count:count];

    lfFree(ka); ka = NULL;
    lfFree(oa); oa = NULL;
    return self;
}

@end /* NSDictionaryExtensions(NSDictionaryExtensions) */

/*
 * NSMutableDictionary class
 */

@implementation NSMutableDictionary

/* Creating and Initializing an NSDictionary */

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject( (self == [NSMutableDictionary class]) 
			     ? [NSConcreteMutableDictionary class]
			     : (Class)self, 0, zone);
}
+ (id)allocWithZone:(NSZone *)zone forCapacity:(unsigned)_capacity {
    return NSAllocateObject( (self == [NSMutableDictionary class]) 
			     ?  [NSConcreteMutableDictionary class] 
			     : (Class)self, 0, zone);
}

+ (id)dictionaryWithCapacity:(unsigned int)aNumItems
{
    return AUTORELEASE([[self allocWithZone:NULL forCapacity:aNumItems]
                              initWithCapacity:aNumItems]);
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    return [[NSDictionary allocWithZone:zone]
	initWithDictionary:self copyItems:NO];
}

/* Adding and Removing Entries */

- (void)addEntriesFromDictionary:(NSDictionary*)otherDictionary
{
    id nodes = [otherDictionary keyEnumerator];
    id key;
    
    while ((key = [nodes nextObject]))
	[self setObject:[otherDictionary objectForKey:key] forKey:key];
}

- (void)removeAllObjects
{
    id keys = [self keyEnumerator];
    id key;

    while ((key=[keys nextObject]))
	[self removeObjectForKey:key];
}

- (void)removeObjectForKey:(id)theKey
{
    [self subclassResponsibility:_cmd];
}

- (void)removeObjectsForKeys:(NSArray*)keyArray
{
    unsigned int index, count = [keyArray count];
    for (index = 0; index<count; index++)
	[self removeObjectForKey:[keyArray objectAtIndex:index]];
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
    [self subclassResponsibility:_cmd];
}

- (void)setDictionary:(NSDictionary*)otherDictionary
{
    [self removeAllObjects];
    [self addEntriesFromDictionary:otherDictionary];
}

- (Class)classForCoder
{
    return [NSMutableDictionary class];
}

@end /* NSMutableDictionary */

/*
 * NSDictionary Enumerator classes
 */

@implementation _NSDictionaryObjectEnumerator

- (id)initWithDictionary:(NSDictionary*)_dict
{
    self->dict = RETAIN(_dict);
    self->keys = RETAIN([_dict keyEnumerator]);
    return self;
}

- (void)dealloc
{
    RELEASE(self->dict);
    RELEASE(self->keys);
    [super dealloc];
}

- (id)nextObject
{
    return [dict objectForKey:[keys nextObject]];
}

@end /* _NSDictionaryObjectEnumerator */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

