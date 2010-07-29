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

#include "NGMimePartGenerator.h"
#include "NGMimeHeaderFieldGenerator.h"
#include "NGMimeBodyGenerator.h"
#include "NGMimeJoinedData.h"
#include <NGMime/NGMimeType.h>
#include "common.h"

@implementation NGMimePartGenerator

static NSProcessInfo *Pi = nil;
static BOOL       debugOn = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"NGMimeGeneratorDebugEnabled"];
  if (debugOn)
    NSLog(@"WARNING[%@]: NGMimeGeneratorDebugEnabled is enabled!", self);
  
  if (Pi == nil)
    Pi = [[NSProcessInfo processInfo] retain];
}

+ (id)mimePartGenerator {
  return [[[self alloc] init] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    self->part        = nil;
    self->delegate    = nil;
    self->appendBytes = NULL;
  }
  return self;
}

- (void)dealloc {
  [self->result release];
  [self->part   release];
  self->appendBytes = NULL;
  [super dealloc];
}

/* setting the delegate */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;

  self->delegateRespondsTo.generatorGenerateDataForHeaderField =
    [self->delegate respondsToSelector:
         @selector(mimePartGenerator:generateDataForHeaderField:value:)];
  
  self->delegateRespondsTo.generatorGeneratorForBodyOfPart =
    [self->delegate respondsToSelector:
         @selector(mimePartGenerator:generatorForBodyOfPart:)];
  
  self->delegateRespondsTo.generatorGenerateDataForBodyOfPart =
    [self->delegate respondsToSelector:
    @selector(mimePartGenerator:generateDataForBodyOfPart:additionalHeaders:)];
}

- (id)delegate {
  return self->delegate;
}

- (BOOL)prepareForGenerationOfPart:(id<NGMimePart>)_part {
  ASSIGN(self->part, _part);
  
  if (self->result) {
    [self->result release];
    self->result = nil;
  }
  self->result = (self->useMimeData)
    ? [[NGMimeJoinedData alloc] init]
    : [[NSMutableData alloc] initWithCapacity:4096];
  
  if ([self->result respondsToSelector:@selector(methodForSelector:)]) {
    self->appendBytes = (void(*)(id,SEL,const void *, unsigned))
                        [self->result methodForSelector:
                                          @selector(appendBytes:length:)];
  }
  else
    self->appendBytes = NULL;
  return YES;
}

- (BOOL)generatePrefix {
  return YES;
}

- (void)generateSuffix {
}

- (id<NGMimeHeaderFieldGenerator>)generatorForHeaderField:(NSString *)_name {
  return [NGMimeHeaderFieldGeneratorSet defaultRfc822HeaderFieldGeneratorSet];
}

- (NSData *)generateDataForHeaderField:(NSString *)_headerField
  value:(id)_value
{
  NSData *data;

  if (self->delegateRespondsTo.generatorGenerateDataForHeaderField) {
    data = [self->delegate mimePartGenerator:self
                           generateDataForHeaderField:_headerField
                           value:_value];
  }
  else {
    data = [[self generatorForHeaderField:_headerField]
                  generateDataForHeaderFieldNamed:_headerField
                  value:_value];
  }
  return data;
}

- (BOOL)isMultiValueCommaHeaderField:(NSString *)_headerField {
  /* 
     This is used by NGMimeMessageGenerator to encode multivalue To/Cc/Bcc
     in a single line.
  */
  return NO;
}

- (BOOL)appendHeaderField:(NSString *)_field values:(NSEnumerator *)_values
  toData:(NSMutableData *)_data
{
  /* returns whether data was generated */
  const unsigned char *fcname;
  id       value  = nil;
  unsigned len;
  BOOL     isMultiValue, isFirst;
  
  /* get field name and strip leading spaces */
  fcname = (const unsigned char *)[_field cStringUsingEncoding:NSISOLatin1StringEncoding];
  for (len = [_field lengthOfBytesUsingEncoding:NSISOLatin1StringEncoding];
       len > 0; fcname++, len--) {
    if (*fcname != ' ')
      break;
  }
  
  isMultiValue = [self isMultiValueCommaHeaderField:_field];
  isFirst      = YES;
  while ((value = [_values nextObject]) != nil) {
    NSData *data;
    
    if ((data = [self generateDataForHeaderField:_field value:value]) == nil)
      continue;
    
    if (isMultiValue) {
      if (isFirst) {
	[_data appendBytes:fcname length:len];
	[_data appendBytes:": " length:2];
	isFirst = NO;
      }
      else
	[_data appendBytes:", " length:2];
      
      [_data appendData:data];
    }
    else {
      [_data appendBytes:fcname length:len];
      [_data appendBytes:": " length:2];
      [_data appendData:data];
      [_data appendBytes:"\r\n" length:2];
    }
  }
  if (!isFirst && isMultiValue) [_data appendBytes:"\r\n" length:2];
  return isFirst;
}

- (NSData *)generateHeaderData:(NGHashMap *)_additionalHeaders {
  NSEnumerator     *headerFieldNames = nil;
  NSString         *headerFieldName  = nil;
  NGMutableHashMap *addHeaders       = nil;
  NSMutableData    *data;
  
  data = (self->useMimeData)
    ? [[[NGMimeJoinedData alloc] init] autorelease]
    : [NSMutableData dataWithCapacity:2048];
  
  headerFieldNames = [self->part headerFieldNames];
  addHeaders       = [_additionalHeaders mutableCopy];
  
  while ((headerFieldName = [headerFieldNames nextObject]) != nil) {
    NSEnumerator *enumerator;
    BOOL         reset;
    
    if ([[_additionalHeaders objectsForKey:headerFieldName] count] > 0) {
      enumerator = [addHeaders objectEnumeratorForKey:headerFieldName];
      reset = YES;
    }
    else {
      reset = NO;
      enumerator = [self->part valuesOfHeaderFieldWithName:headerFieldName];
    }
    
    [self appendHeaderField:headerFieldName values:enumerator toData:data];
    
    if (reset) [addHeaders removeAllObjectsForKey:headerFieldName];
  }
  
  headerFieldNames = [addHeaders keyEnumerator];
  while ((headerFieldName = [headerFieldNames nextObject]) != nil) {
    [self appendHeaderField:headerFieldName
	  values:[addHeaders objectEnumeratorForKey:headerFieldName]
	  toData:data];
  }
  [addHeaders release]; addHeaders = nil;
  return data;
}

- (NGMimeType *)defaultContentTypeForPart:(id<NGMimePart>)_part {
  static NGMimeType *octetStreamType = nil;
  if (octetStreamType == nil)
    octetStreamType = [[NGMimeType mimeType:@"application/octet-stream"] copy];
  return octetStreamType;
}

- (id<NGMimeBodyGenerator>)defaultBodyGenerator {
  id<NGMimeBodyGenerator> gen;

  gen = [[[NGMimeBodyGenerator alloc] init] autorelease];
  [(id)gen setUseMimeData:self->useMimeData];
  return gen;
}

- (id<NGMimeBodyGenerator>)generatorForBodyOfPart:(id<NGMimePart>)_part {
  id<NGMimeBodyGenerator> bodyGen      = nil;
  NGMimeType              *contentType = nil;
  NSString                *type        = nil;
  
  if (self->delegateRespondsTo.generatorGeneratorForBodyOfPart) {
    bodyGen = [self->delegate mimePartGenerator:self
                   generatorForBodyOfPart:self->part];
  }
  
  if (bodyGen == nil) {
    contentType = [_part contentType];
    if (contentType == nil)
      contentType = [self defaultContentTypeForPart:_part];
    
    if (contentType == nil) {
      [self logWithFormat:@"WARNING(%s): no content-type",__PRETTY_FUNCTION__];
      return nil;
    }
    type = [contentType type];
    
    if ([type isEqualToString:NGMimeTypeMultipart]) {
      bodyGen = [[[NGMimeMultipartBodyGenerator alloc] init] autorelease];
    }
    else if ([type isEqualToString:NGMimeTypeText]) {
      bodyGen = [[[NGMimeTextBodyGenerator alloc] init] autorelease];
    }
    else if (([type isEqualToString:NGMimeTypeMessage]) &&
             [[contentType subType] isEqualToString:@"rfc822"]) {
      bodyGen = [[[NGMimeRfc822BodyGenerator alloc] init] autorelease];
    }
  }
  [(id)bodyGen setUseMimeData:self->useMimeData];
  return bodyGen;
}

- (NSData *)generateBodyData:(NGMutableHashMap *)_additionalHeaders {
  NSData                  *data   = nil;
  id<NGMimeBodyGenerator> bodyGen = nil;
  id body;
  
  /* ask delegate whether it wants to deal with the part */
  
  if (self->delegateRespondsTo.generatorGenerateDataForBodyOfPart) {
    data = [self->delegate mimePartGenerator:self
                           generateDataForBodyOfPart:self->part
                           additionalHeaders:_additionalHeaders];
    return data;
  }

  /* lookup generator object or use default generator */

  bodyGen = [self generatorForBodyOfPart:self->part];
  if (bodyGen == nil) { /* no generator for body */
    bodyGen = [self defaultBodyGenerator];
    if (debugOn) {
      [self debugWithFormat:@"Note: using default generator %@ for part: %@",
	      bodyGen, self->part];
    }
  }
  
  [(id)bodyGen setUseMimeData:self->useMimeData];
  
  /* generate */
    
  if (bodyGen != nil) {
    data = [bodyGen generateBodyOfPart:self->part
                    additionalHeaders:_additionalHeaders
                    delegate:self->delegate];
    return data;
  }
  
  /* fallback, try to encode NSString and NSData objects */
  
  body = [self->part body];        
  [self logWithFormat:@"WARNING(%s): class has no defaultBodyGenerator", 
	__PRETTY_FUNCTION__];
  
  if ([body isKindOfClass:[NSData class]])
    data = body;
  else if ([body isKindOfClass:[NSString class]])
    data = [body dataUsingEncoding: NSISOLatin1StringEncoding];
  else
    data = nil;
  
  return data;
}

- (void)generateData {
  NGMutableHashMap *additionalHeaders;
  NSData           *bodyData;
  NSData           *headerData;
  
  /* the body generator will fill in headers if required */
  additionalHeaders = [[NGMutableHashMap alloc] initWithCapacity:16];

  if (debugOn) {
    [self debugWithFormat:@"generate part: 0x%p<%@>", 
	    self->part, NSStringFromClass([self->part class])];
  }
  
  bodyData = [self generateBodyData:additionalHeaders];
  if (debugOn) {
    [self debugWithFormat:@"  => body 0x%p<%@> length=%d",
	    bodyData, NSStringFromClass([bodyData class]), [bodyData length]];
  }
  
  headerData = [self generateHeaderData:additionalHeaders];
  if (debugOn) {
    [self debugWithFormat:@"  => header 0x%p<%@> length=%d",
	    headerData, NSStringFromClass([headerData class]), 
	    [headerData length]];
  }
  
  if (headerData != nil) {
    // TODO: length check is new, this should be correct, but might be wrong.
    //       Some strange things occur if we generate a part which is a
    //       NGMimeFileData (this method was called twiced, once without header
    //       data which in turn resulted in a superflous "\r\n" string
    if ([headerData length] > 0) {
      [self->result appendData:headerData];
      [self->result appendBytes:"\r\n" length:2];
    }
    
    if (bodyData != nil)
      [self->result appendData:bodyData];
    else if (debugOn)
      [self debugWithFormat:@"  => did not generate any body data!"];
  }
  else if (debugOn)
    [self debugWithFormat:@"  => did not generate any header data!"];
  
  [additionalHeaders release]; additionalHeaders = nil;
}

- (NSData *)generateMimeFromPart:(id<NGMimePart>)_part {
  NSData *data;
  
  [self prepareForGenerationOfPart:_part];
  if (![self generatePrefix])
    return nil;
    
  [self generateData];
  [self generateSuffix];
  data = self->result;
  self->result = nil;
  return [data autorelease];
}

- (NSString *)generateMimeFromPartToFile:(id<NGMimePart>)_part {
  NSString *filename = nil;

  static NSString      *TmpPath = nil;
  
  if (TmpPath == nil) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    TmpPath = [ud stringForKey:@"NGMimeBuildMimeTempDirectory"];
    if (TmpPath == nil)
      TmpPath = @"/tmp/";
    TmpPath = [[TmpPath stringByAppendingPathComponent:@"OGo"] copy];
  }
  
  filename = [Pi temporaryFileName:TmpPath];
  
  [self setUseMimeData:YES];

  if (![[self generateMimeFromPart:_part]
              writeToFile:filename atomically:YES]) {
    NSLog(@"ERROR[%s] couldn`t write data to temorary file %@",
          __PRETTY_FUNCTION__, filename);
    return nil;
  }
  return filename;
}

- (id<NGMimePart>)part {
  return self->part;
}

- (void)setUseMimeData:(BOOL)_b {
  self->useMimeData = _b;
}
- (BOOL)useMimeData {
  return self->useMimeData;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGMimePartGenerator */
