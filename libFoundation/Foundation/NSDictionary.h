/* 
   NSDictionary.h

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

#ifndef __NSDictionary_h__
#define __NSDictionary_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSUtilities.h>

@class NSString;
@class NSArray;
@class NSEnumerator;
@class NSURL;

/*
 * NSDictionary class
 */

@interface NSDictionary : NSObject <NSCoding, NSCopying, NSMutableCopying>

/* Creating and Initializing an NSDictionary */

+ (id)allocWithZone:(NSZone*)zone;
+ (id)dictionary;
+ (id)dictionaryWithContentsOfFile:(NSString *)path;
+ (id)dictionaryWithContentsOfURL:(NSURL *)_url;
+ (id)dictionaryWithObjects:(NSArray*)objects forKeys:(NSArray*)keys;
+ (id)dictionaryWithObjects:(id*)objects forKeys:(id*)keys
  count:(unsigned int)count;
+ (id)dictionaryWithObjectsAndKeys:(id)firstObject, ...;
+ (id)dictionaryWithDictionary:(NSDictionary*)aDict;
+ (id)dictionaryWithObject:object forKey:key;
- (id)initWithContentsOfFile:(NSString*)path;
- (id)initWithContentsOfURL:(NSURL *)_url;
- (id)initWithDictionary:(NSDictionary*)dictionary;
- (id)initWithDictionary:(NSDictionary*)dictionary copyItems:(BOOL)flag;
- (id)initWithObjectsAndKeys:(id)firstObject,...;
- (id)initWithObjects:(NSArray*)objects forKeys:(NSArray*)keys;
- (id)initWithObjects:(id*)objects forKeys:(id*)keys
  count:(unsigned int)count;

/* Accessing Keys and Values */

- (NSArray*)allKeys;
- (NSArray*)allKeysForObject:(id)object;
- (NSArray*)allValues;
- (NSEnumerator*)keyEnumerator;
- (NSEnumerator*)objectEnumerator;
- (id)objectForKey:(id)aKey;
- (NSArray*)objectsForKeys:(NSArray*)keys notFoundMarker:notFoundObj;

/* Counting Entries */

- (unsigned int)count;

/* Comparing Dictionaries */

- (BOOL)isEqualToDictionary:(NSDictionary*)other;

/* Storing Dictionaries */

- (NSString*)description;
- (NSString*)descriptionInStringsFileFormat;
- (NSString*)descriptionWithLocale:(NSDictionary*)localeDictionary;
- (NSString*)descriptionWithLocale:(NSDictionary*)localeDictionary
  indent:(unsigned int)level;
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)useAuxiliaryFile;

/* From adopted/inherited protocols */

- (unsigned)hash;
- (BOOL)isEqual:(id)anObject;

@end /* NSDictionary */

/*
 * Extensions to NSDictionary
 */

@interface NSDictionary(NSDictionaryExtensions)

- (id)initWithObjectsAndKeys:(id)firstObject arguments:(va_list)argList;

@end;

/*
 * NSMutableDictionary class
 */

@interface NSMutableDictionary : NSDictionary

+ (id)allocWithZone:(NSZone*)zone;
+ (id)dictionaryWithCapacity:(unsigned int)aNumItems;
- (id)initWithCapacity:(unsigned int)aNumItems;

/* Adding and Removing Entries */

- (void)addEntriesFromDictionary:(NSDictionary*)otherDictionary;
- (void)removeAllObjects;
- (void)removeObjectForKey:(id)theKey;
- (void)removeObjectsForKeys:(NSArray*)keyArray;
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)setDictionary:(NSDictionary*)otherDictionary;

@end /* NSMutableDictionary */

#endif /* __NSDictionary_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
