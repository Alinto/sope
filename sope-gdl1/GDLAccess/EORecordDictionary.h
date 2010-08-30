/* 
*/

#ifndef __EORecordDictionary_h__
#define __EORecordDictionary_h__

#import <Foundation/NSDictionary.h>

typedef struct _EORecordDictionaryEntry {
    unsigned hash;
    id       key;
    id       value;
} EORecordDictionaryEntry;

@interface EORecordDictionary : NSDictionary
{
    unsigned char           count;
    EORecordDictionaryEntry entries[1];
}

/* Allocating and Initializing an Dictionary */
- (id)initWithObjects:(id*)objects forKeys:(id*)keys 
  count:(NSUInteger)count;
- (id)initWithDictionary:(NSDictionary*)dictionary;

/* Accessing keys and values */
- (id)objectForKey:(id)aKey;
- (NSUInteger)count;
- (NSEnumerator *)keyEnumerator;

@end /* EORecordDictionary */

#import <Foundation/NSEnumerator.h>

@interface _EORecordDictionaryKeyEnumerator : NSEnumerator
{
    NSDictionary *dict;
    EORecordDictionaryEntry *currentEntry;
    unsigned char count;
}

- (id)initWithDictionary:(EORecordDictionary *)_dict
  firstEntry:(EORecordDictionaryEntry *)_firstEntry
  count:(unsigned char)_count;

- (id)nextObject;

@end

#endif
