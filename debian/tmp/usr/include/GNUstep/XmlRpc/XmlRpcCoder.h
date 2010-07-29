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

#ifndef __XmlRpc_XmlRpcCoder_H__
#define __XmlRpc_XmlRpcCoder_H__

#import <Foundation/NSObject.h>

@class NSDictionary, NSArray, NSNumber, NSString, NSCalendarDate, NSData;
@class NSMutableArray, NSMutableString, NSTimeZone, NSDate;
@class XmlRpcValue, XmlRpcMethodCall, XmlRpcMethodResponse;

/*"
  The XmlRpcEncoder is used to encode XML-RPC objects. It's pretty much like
  NSArchiver, only for XML-RPC.
  
  Encoder example: 

   NSMutableString *str;                 // asume that exists
   XmlRpcMethodResponse *methodResponse; // asume that exists
   XmlRpcMethodCall     *methodCall;     // asume that exists
 
   coder = [[XmlRpcEncoder alloc] initForWritingWithMutableString:str];
   
   [coder encodeMethodCall:methodCall];

   // or

   [coder encodeMethodResponse:methodResponse];
"*/
@interface XmlRpcEncoder : NSObject
{
  NSMutableString *string;
  
  NSMutableArray  *objectStack;
  NSMutableArray  *objectHasStructStack;
  NSTimeZone      *timeZone;
}

- (id)initForWritingWithMutableString:(NSMutableString *)_string;

- (void)encodeMethodCall:(XmlRpcMethodCall *)_methodCall;
- (void)encodeMethodResponse:(XmlRpcMethodResponse *)_methodResponse;

- (void)encodeStruct:(NSDictionary *)_struct;
- (void)encodeArray:(NSArray *)_array;
- (void)encodeBase64:(NSData *)_data;
- (void)encodeBoolean:(BOOL)_number;
- (void)encodeInt:(int)_number;
- (void)encodeDouble:(double)_number;
- (void)encodeString:(NSString *)_string;
- (void)encodeDateTime:(NSDate *)_date;
- (void)encodeObject:(id)_object;

- (void)encodeStruct:(NSDictionary *)_struct   forKey:(NSString *)_key;
- (void)encodeArray:(NSArray *)_array          forKey:(NSString *)_key;
- (void)encodeBase64:(NSData *)_data           forKey:(NSString *)_key;
- (void)encodeBoolean:(BOOL)_number            forKey:(NSString *)_key;
- (void)encodeInt:(int)_number                 forKey:(NSString *)_key;
- (void)encodeDouble:(double)_number           forKey:(NSString *)_key;
- (void)encodeString:(NSString *)_string       forKey:(NSString *)_key;
- (void)encodeDateTime:(NSDate *)_date         forKey:(NSString *)_key;
- (void)encodeObject:(id)_object               forKey:(NSString *)_key;

- (void)setDefaultTimeZone:(NSTimeZone *)_timeZone;

- (NSTimeZone *)defaultTimeZone;

@end

@class NSMutableSet;

/*"
  The XmlRpcDecoder is used to decode XML-RPC objects. It's pretty much like
  NSUnarchiver, only for XML-RPC.
  
  Decoder example:

   NSString             *xmlRpcString; // asume that exists
   XmlRpcMethodCall     *methodCall     = nil;
   XmlRpcMethodResponse *methodResponse = nil;

   coder = [[XmlRpcDecoder alloc] initForReadingWithString:xmlRpcString];

   methodCall = [coder decodeMethodCall];
   
   // or
   
   methodResponse = [coder decodeMethodResponse];
"*/
@interface XmlRpcDecoder : NSObject
{
  NSData         *data;
  NSMutableArray *valueStack;
   unsigned       nesting;
  NSMutableArray *unarchivedObjects;
  NSMutableSet   *awakeObjects;
  NSTimeZone     *timeZone;
}

- (id)initForReadingWithString:(NSString *)_string;
- (id)initForReadingWithData:(NSData *)_data;

- (XmlRpcMethodCall *)decodeMethodCall;
- (XmlRpcMethodResponse *)decodeMethodResponse;

/* decoding */
- (NSDictionary *)decodeStruct;
- (NSArray *)decodeArray;
- (NSData *)decodeBase64;
- (BOOL)decodeBoolean;
- (int)decodeInt;
- (double)decodeDouble;
- (NSString *)decodeString;
- (NSCalendarDate *)decodeDateTime;
- (id)decodeObject;

- (NSDictionary *)decodeStructForKey:(NSString *)_key;
- (NSArray *)decodeArrayForKey:(NSString *)_key;
- (NSData *)decodeBase64ForKey:(NSString *)_key;
- (BOOL)decodeBooleanForKey:(NSString *)_key;
- (int)decodeIntForKey:(NSString *)_key;
- (double)decodeDoubleForKey:(NSString *)_key;
- (NSString *)decodeStringForKey:(NSString *)_key;
- (NSCalendarDate *)decodeDateTimeForKey:(NSString *)_key;
- (id)decodeObjectForKey:(NSString *)_key;

- (void)setDefaultTimeZone:(NSTimeZone *)_timeZone;
- (NSTimeZone *)defaultTimeZone;

/* operations */
- (void)ensureObjectAwake:(id)_object;
- (void)finishInitializationOfObjects;
- (void)awakeObjects;

@end

@interface NSObject(XmlRpcCoder)

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_decoder;
- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder;

@end

@interface NSObject(XmlRpcDecoderAwakeMethods)

- (void)finishInitializationWithXmlRpcDecoder:(XmlRpcDecoder *)_decoder;
- (void)awakeFromXmlRpcDecoder:(XmlRpcDecoder *)_decoder;

@end


#endif /* __XmlRpc_XmlRpcCoder_H__ */
