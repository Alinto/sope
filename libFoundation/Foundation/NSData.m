/* 
   NSData.m

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
*/

#include <Foundation/common.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>

#include "byte_order.h"
#include "NSConcreteData.h"
#include <Foundation/NSUtilities.h>

@implementation NSData

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject(((self == [NSData class]) ? 
			     [NSConcreteData class] : (Class)self), 0, zone);
}

+ (id)data
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithBytes:NULL length:0]);
}

+ (id)dataWithBytes:(const void*)bytes
    length:(unsigned int)length
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithBytes:bytes length:length]);
}

+ (id)dataWithBytesNoCopy:(void*)bytes
    length:(unsigned int)length
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithBytesNoCopy:bytes 
                           length:length]);
}

+ (id)dataWithContentsOfFile:(NSString*)path
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithContentsOfFile:path]);
}
+ (id)dataWithContentsOfURL:(NSURL *)_url
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithContentsOfURL:_url]);
}

+ (id)dataWithContentsOfMappedFile:(NSString*)path
{
    NSPosixFileDescriptor* descriptor;
    NSRange range = {0, 0};
    
    descriptor = AUTORELEASE([[NSPosixFileDescriptor alloc]
                                 initWithPath:path]);
    range.length = [descriptor fileLength];    

    return [descriptor mapFileRange:range];
}

+ (id)dataWithData:(NSData *)aData
{
    return AUTORELEASE([[self alloc] initWithData:aData]);
}

- (id)initWithBytes:(const void*)bytes
    length:(unsigned int)length
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (id)initWithBytesNoCopy:(void*)bytes
    length:(unsigned int)length
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (id)initWithContentsOfFile:(NSString*)_path
{
    char     *bytes = NULL;
    unsigned len;

    if ((bytes = NSReadContentsOfFile(_path, 0, &len))) {
        return [self initWithBytesNoCopy:bytes length:len];
    }
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}
- (id)initWithContentsOfURL:(NSURL *)_url
{
    if ([_url isFileURL])
        return [self initWithContentsOfFile:[_url path]];
    
    return [self initWithData:[_url resourceDataUsingCache:NO]];
}

- (id)initWithContentsOfMappedFile:(NSString*)path
{
#if defined(__MINGW32__)
    return [self initWithContentsOfFile:path];
#else
    NSPosixFileDescriptor* descriptor;
    NSRange range = {0, 0};
    
    descriptor = AUTORELEASE([[NSPosixFileDescriptor alloc]
                                 initWithPath:path]);
    range.length = [descriptor fileLength];    

    RELEASE(self); self = nil;
    self = [descriptor mapFileRange:range];
    return RETAIN(self);
#endif
}

- (id)initWithData:(NSData *)data
{
    return [self initWithBytes:[data bytes] length:[data length]];
}

- (id)initWithBytesNoCopy:(void *)_bytes length:(unsigned)_length 
  freeWhenDone:(BOOL)_freeMemory
{
    // new in OSX 10.2
    // TODO: inefficient for freemem==NO case
    return (_freeMemory)
        ? [self initWithBytesNoCopy:_bytes length:_length]
        : [self initWithBytes:_bytes length:_length];
}

/* copying */

- (id)copy
{
    return [self copyWithZone:NSDefaultMallocZone()];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSData allocWithZone:zone] initWithData:self];
}

- (id)mutableCopy
{
    return [self mutableCopyWithZone:NSDefaultMallocZone()];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[NSMutableData allocWithZone:zone] initWithData:self];
}

- (const void*)bytes
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (NSString*)description
{
    unsigned     i;
    unsigned int length       = [self length];
    const char   *bytes       = [self bytes];
    unsigned int final_length = 4 + 2 * length + 1 + length / 4;
    char         *description = MallocAtomic(final_length);
    char         *temp        = description + 1;

    description[0] = 0;
    Strcat(description, "<");
    for(i = 0; i < length; i++, temp += 2) {
	if (i % 4 == 0)
	    *temp++ = ' ';
	sprintf (temp, "%02X", (unsigned char)((char*)bytes)[i]);
    }
    strcat(temp, " >");
    *(temp += 2) = 0;
    return [NSString stringWithCStringNoCopy:description freeWhenDone:YES];
}

- (void)getBytes:(void*)buffer
{
    memcpy(buffer, [self bytes], [self length]);
}

- (void)getBytes:(void*)buffer
  length:(unsigned int)_length
{
    if(_length > [self length])
	[[RangeException new] raise];
    else memcpy(buffer, [self bytes], _length);
}

- (void)getBytes:(void*)buffer
  range:(NSRange)aRange
{
    unsigned int length = [self length];

    if(aRange.location > length
	    || aRange.length > length
	    || aRange.location + aRange.length > length)
	[[RangeException new] raise];
    else
        memcpy(buffer, [self bytes] + aRange.location, aRange.length);
}

- (NSData *)subdataWithRange:(NSRange)aRange
{
    return AUTORELEASE([[NSConcreteDataRange
                            allocWithZone:[self zone]]
                           initWithData:self range:aRange]);
}

- (unsigned)hash
{
    return hashjb([self bytes], [self length]);
}

- (BOOL)isEqualToData:(NSData*)other
{
    if([self length] == [other length])
	return memcmp([self bytes], [other bytes], [self length]) == 0;
    else return NO;
}

- (BOOL)isEqual:(id)anObject
{
    if([anObject isKindOfClass:[NSData class]])
	return [self isEqualToData:anObject];
    else return NO;
}

- (unsigned int)length
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (BOOL)writeToFile:(NSString*)path
  atomically:(BOOL)useAuxiliaryFile
{
    return writeToFile(path, self, useAuxiliaryFile);
}

- (unsigned int)deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor
{
    return *cursor;
}

- (void)deserializeBytes:(void*)buffer
  length:(unsigned int)bytes
  atCursor:(unsigned int*)cursor
{
    NSRange range = { *cursor, bytes };
    [self getBytes:buffer range:range];
    *cursor += bytes;
}

- (void)deserializeDataAt:(void*)data
  ofObjCType:(const char*)type
  atCursor:(unsigned int*)cursor
  context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if(!type || !data)
	return;

    switch(*type) {
	case _C_ID: {
	    [callback deserializeObjectAt:data ofObjCType:type
		    fromData:self atCursor:cursor];
	    break;
	}
	case _C_CHARPTR: {
	    volatile int len = [self deserializeIntAtCursor:cursor];

	    /* This statement, by taking the address of `type', forces the
		compiler to not allocate `type' into a register */
	    *(void**)data = &type;

	    if(len == -1) {
		*(const char**)data = NULL;
		return;
	    }

	    *(char**)data = MallocAtomic(len + 1);
            (*(char **)data)[len] = 0;
	    TRY {
		[self deserializeBytes:*(char**)data
				length:len
			      atCursor:cursor];
	    } END_TRY
	    OTHERWISE {
		lfFree (*(char**)data);
		RERAISE;
	    } END_CATCH
    
	    break;
	}
	case _C_ARY_B: {
	    int i, count, offset, itemSize;
	    const char *itemType;
	    
	    count = Atoi(type + 1);
	    itemType = type;
	    while (isdigit(*++itemType))
		;
	    itemSize = objc_sizeof_type(itemType);
		
	    for(i = offset = 0; i < count; i++, offset += itemSize) {
		[self deserializeDataAt:(char*)data + offset
		      ofObjCType:itemType
		      atCursor:cursor
		      context:callback];
	    }
	    break;
	}
	case _C_STRUCT_B: {
	    int offset = 0;
	    int align, rem;

	    while(*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	    while(1) {
		[self deserializeDataAt:((char*)data) + offset
			ofObjCType:type
			atCursor:cursor
			context:callback];
		offset += objc_sizeof_type(type);
		type = objc_skip_typespec(type);
		if(*type != _C_STRUCT_E) {
		    align = objc_alignof_type(type);
		    if((rem = offset % align))
			offset += align - rem;
		}
		else break;
	    }
	    break;
        }
        case _C_PTR: {
	    *(char**)data = Malloc(objc_sizeof_type(++type));
	    TRY {
		[self deserializeDataAt:*(char**)data
			ofObjCType:type
			atCursor:cursor
			context:callback];
	    } END_TRY
	    OTHERWISE {
		lfFree (*(char**)data);
		RERAISE;
	    } END_CATCH

	    break;
        }
	case _C_CHR:
	case _C_UCHR: {
	    [self deserializeBytes:data
		  length:sizeof(unsigned char)
		  atCursor:cursor];
	    break;
	}
        case _C_SHT:
	case _C_USHT: {
	    [self deserializeBytes:data
		  length:sizeof(unsigned short)
		  atCursor:cursor];
	    break;
	}
        case _C_INT:
	case _C_UINT: {
	    [self deserializeBytes:data
		  length:sizeof(unsigned int)
		  atCursor:cursor];
	    break;
	}
        case _C_LNG:
	case _C_ULNG: {
	    [self deserializeBytes:data
		  length:sizeof(unsigned long)
		  atCursor:cursor];
	    break;
	}
        case _C_FLT: {
	    [self deserializeBytes:data
		  length:sizeof(float)
		  atCursor:cursor];
	    break;
	}
        case _C_DBL: {
	    [self deserializeBytes:data
		  length:sizeof(double)
		  atCursor:cursor];
	    break;
	}
        default:
	    [[[UnknownTypeException alloc] initForType:type] raise];
    }
}

- (int)deserializeIntAtCursor:(unsigned int*)cursor
{
    unsigned int ni, result;

    [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:cursor];
    result = network_int_to_host (ni);
    return result;
}

- (int)deserializeIntAtIndex:(unsigned int)index
{
    unsigned int ni, result;

    [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:&index];
    result = network_int_to_host (ni);
    return result;
}

- (void)deserializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atCursor:(unsigned int*)cursor
{
    unsigned i;

    [self deserializeBytes:&intBuffer
	  length:numInts * sizeof(unsigned int)
	  atCursor:cursor];
    for (i = 0; i < numInts; i++)
	intBuffer[i] = network_int_to_host (intBuffer[i]);
}

- (void)deserializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atIndex:(unsigned int)index
{
    unsigned i;

    [self deserializeBytes:&intBuffer
		    length:numInts * sizeof(int)
		    atCursor:&index];
    for (i = 0; i < numInts; i++)
	intBuffer[i] = network_int_to_host (intBuffer[i]);
}

- (Class)classForCoder
{
    return [NSData class];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    const char* bytes = [self bytes];
    unsigned int length = [self length];

    [aCoder encodeValueOfObjCType:@encode(unsigned int) at:&length];
    [aCoder encodeArrayOfObjCType:@encode(char) count:length at:bytes];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    char* bytes;
    unsigned int length;

    [aDecoder decodeValueOfObjCType:@encode(unsigned int) at:&length];
    bytes = MallocAtomic (length);
    [aDecoder decodeArrayOfObjCType:@encode(char) count:length at:bytes];
    return [self initWithBytesNoCopy:bytes length:length];
}

@end /* NSData */


@implementation NSMutableData

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject(((self == [NSMutableData class]) ? 
			     [NSConcreteMutableData class] : (Class)self), 
			    0, zone);
}

+ (id)dataWithCapacity:(unsigned int)numBytes
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithCapacity:numBytes]);
}

+ (id)dataWithLength:(unsigned int)length
{
    return AUTORELEASE([[self allocWithZone:NSDefaultMallocZone()]
                           initWithLength:length]);
}

- (id)initWithCapacity:(unsigned int)capacity
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (id)initWithLength:(unsigned int)length
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSData*)subdataWithRange:(NSRange)aRange
{
    char* buffer = MallocAtomic(aRange.length);

    [self getBytes:buffer range:aRange];
    return AUTORELEASE([[NSData alloc]
                           initWithBytesNoCopy:buffer length:aRange.length]);
}

- (void)increaseLengthBy:(unsigned int)extraLength
{
    [self subclassResponsibility:_cmd];
}

- (void*)mutableBytes
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (void)setLength:(unsigned int)length
{
    [self subclassResponsibility:_cmd];
}

- (void)appendBytes:(const void*)_bytes
    length:(unsigned int)_length
{
    [self subclassResponsibility:_cmd];
}

- (void)appendData:(NSData*)other
{
    [self appendBytes:[other bytes] length:[other length]];
}

- (void)replaceBytesInRange:(NSRange)aRange
    withBytes:(const void*)bytes
{
    unsigned int length = [self length];

    if(aRange.location > length
		|| aRange.length > length
		|| aRange.location + aRange.length > length)
	[[RangeException new] raise];
    else {
	char* mBytes = [self mutableBytes];
	memcpy(mBytes + aRange.location, bytes, aRange.length);
    }
}

- (void)setData:(NSData*)aData
{
    [self setLength:[aData length]];
    [self replaceBytesInRange:NSMakeRange(0, [self length])
	withBytes:[aData bytes]];
}

- (void)resetBytesInRange:(NSRange)aRange
{
    unsigned int length = [self length];

    if(aRange.location > length
		|| aRange.length > length
		|| aRange.location + aRange.length > length)
	[[RangeException new] raise];
    else {
	char* mBytes = [self mutableBytes];
	memset(mBytes + aRange.location, 0, aRange.length); 
    }
}

- (void)serializeAlignedBytesLength:(unsigned int)length
{
}

- (void)serializeDataAt:(const void*)data
  ofObjCType:(const char*)type
  context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if(!data || !type)
	    return;

    switch(*type) {
        case _C_ID: {
	    [callback serializeObjectAt:(id*)data
			ofObjCType:type
			intoData:self];
	    break;
	}
        case _C_CHARPTR: {
	    int len;

	    if(!*(void**)data) {
		[self serializeInt:-1];
		return;
	    }

	    len = Strlen(*(void**)data);
	    [self serializeInt:len];
	    [self appendBytes:*(void**)data length:len];

	    break;
	}
        case _C_ARY_B: {
            int i, offset, itemSize, count = Atoi(type + 1);
            const char *itemType = type;
	    
            while (isdigit(*++itemType))
		;
	    itemSize = objc_sizeof_type(itemType);

	    for (i = offset = 0; i < count; i++, offset += itemSize) {
		[self serializeDataAt:(char*)data + offset
		      ofObjCType:itemType
		      context:callback];
	    }
	    break;
        }
        case _C_STRUCT_B: {
            int offset = 0;
            int align, rem;

            while(*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
            while(1) {
                [self serializeDataAt:((char*)data) + offset
			ofObjCType:type
			context:callback];
                offset += objc_sizeof_type(type);
                type = objc_skip_typespec(type);
                if(*type != _C_STRUCT_E) {
                    align = objc_alignof_type(type);
                    if((rem = offset % align))
                        offset += align - rem;
                }
                else break;
            }
            break;
        }
	case _C_PTR:
	    [self serializeDataAt:*(char**)data
		    ofObjCType:++type context:callback];
	    break;
        case _C_CHR:
	case _C_UCHR:
	    [self appendBytes:data length:sizeof(unsigned char)];
	    break;
	case _C_SHT:
	case _C_USHT: {
	    [self appendBytes:data length:sizeof(unsigned short)];
	    break;
	}
	case _C_INT:
	case _C_UINT: {
	    [self appendBytes:data length:sizeof(unsigned int)];
	    break;
	}
	case _C_LNG:
	case _C_ULNG: {
	    [self appendBytes:data length:sizeof(unsigned long)];
	    break;
	}
	case _C_FLT: {
	    [self appendBytes:data length:sizeof(float)];
	    break;
	}
	case _C_DBL: {
	    [self appendBytes:data length:sizeof(double)];
	    break;
	}
	default:
	    [[[UnknownTypeException alloc] initForType:type] raise];
    }
}

- (void)serializeInt:(int)value
{
    unsigned int ni = host_int_to_network (value);
    [self appendBytes:&ni length:sizeof(unsigned int)];
}

- (void)serializeInt:(int)value atIndex:(unsigned int)index
{
    unsigned int ni = host_int_to_network (value);
    NSRange range = { index, sizeof(int) };
    [self replaceBytesInRange:range withBytes:&ni];
}

- (void)serializeInts:(int*)intBuffer count:(unsigned int)numInts
{
    unsigned i;
    SEL selector = @selector (serializeInt:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i]);
}

- (void)serializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atIndex:(unsigned int)index
{
    unsigned i;
    SEL selector = @selector (serializeInt:atIndex:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i], index++);
}

- (Class)classForCoder
{
    return [NSMutableData class];
}

@end /* NSMutableData */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
