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

#include "NGMimeMessageGenerator.h"
#include "NGMimeMessage.h"
#include <NGMime/NGMimeFileData.h>
#include "common.h"
#include <string.h>

@implementation NGMimeMessageGenerator

static BOOL debugOn = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  debugOn = [ud boolForKey:@"NGMimeGeneratorDebugEnabled"];
  if (debugOn)
    NSLog(@"WARNING[%@]: NGMimeGeneratorDebugEnabled is enabled!", self);
}

/* header field specifics */

- (BOOL)isMultiValueCommaHeaderField:(NSString *)_headerField {
  /* 
     This is called by the superclass when generating fields.
     
     Currently checks for: to, cc, bcc 
  */
  unsigned len;
  unichar  c0, c1;
  
  if ((len = [_headerField length]) < 2)
    return [super isMultiValueCommaHeaderField:_headerField];
  
  c0 = [_headerField characterAtIndex:0];
  c1 = [_headerField characterAtIndex:1];
  
  switch (len) {
  case 2:
    if ((c0 == 't' || c0 == 'T') && ((c1 == 'o' || c1 == 'O')))
      return YES;
    if ((c0 == 'c' || c0 == 'C') && ((c1 == 'c' || c1 == 'C')))
      return YES;
    break;
  case 3:
    if ((c0 == 'b' || c0 == 'B') && ((c1 == 'c' || c1 == 'C'))) {
      c0 = [_headerField characterAtIndex:2];
      if (c0 == 'c' || c0 == 'C')
	return YES;
    }
    break;
  }
  return [super isMultiValueCommaHeaderField:_headerField];
}

- (id)_escapeHeaderFieldValue:(NSData *)_data {
  const char   *bytes  = NULL;
  unsigned int length  = 0;
  unsigned int desLen  = 0;
  char         *des    = NULL;
  unsigned int cnt;
  BOOL         doEnc;
//   NSString     *str;

  // TODO: this s***s big time!
//   NSLog (@"class: '%@'", NSStringFromClass ([_data class]));
// #if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
//   str = [[NSString alloc] initWithData:_data
//                           encoding:NSISOLatin1StringEncoding];
//   str = [str autorelease];
  
// #else
//   str = [[NSString alloc] initWithData:_data
//                           encoding:NSISOLatin9StringEncoding];
// #endif
//   bytes  = [str cString];
//   length = [str cStringLength];

  bytes = [_data bytes];
  length = [_data length];

  /* check whether we need to encode */
  cnt = 0;
  doEnc = NO;
  while (!doEnc && cnt < length)
    if ((unsigned char)bytes[cnt] > 127)
      doEnc = YES;
    else
      cnt++;

  if (!doEnc)
    return _data;
  
  /* encode quoted printable */
  {
    char        iso[]     = "=?utf-8?q?";
    unsigned    isoLen    = 16;
    char        isoEnd[]  = "?=";
    unsigned    isoEndLen = 2;
      
    desLen = length * 3 + 20;
      
    des = calloc(desLen + 2, sizeof(char));
      
    // memcpy(des, bytes, cnt);
    memcpy(des, iso, isoLen);
    desLen = NGEncodeQuotedPrintableMime((unsigned char *)bytes, length,
                                         (unsigned char *)(des + isoLen),
					 desLen - isoLen);
    if ((int)desLen != -1) {
      memcpy(des + isoLen + desLen, isoEnd, isoEndLen);
      
      return [NSData dataWithBytesNoCopy:des
                     length:(isoLen + desLen + isoEndLen)];
    }
    else {
      [self logWithFormat:
              @"WARNING: An error occour during quoted-printable decoding"];
      if (des != NULL) free(des);
      return _data;
    }
  }
}

- (NSData *)generateDataForHeaderField:(NSString *)_hf value:(id)_value {
  NSData *data;
  
  // TODO: properly deal with header field values, add proper quoting
  //       prior passing the value up?
  
  data = [super generateDataForHeaderField:_hf value:_value];
  return [self _escapeHeaderFieldValue:data];
}


/* content-transfer-encoding */

- (id<NGMimeBodyGenerator>)defaultBodyGenerator {
  NGMimeMessageBodyGenerator *gen;
  
  gen  = [[NGMimeMessageBodyGenerator alloc] init];
  [gen setUseMimeData:self->useMimeData];
  return gen;
}

- (id<NGMimeBodyGenerator>)generatorForBodyOfPart:(id<NGMimePart>)_part {
  /* called by -generateBodyData:? */
  id<NGMimeBodyGenerator> bodyGen;
  NGMimeType              *contentType;
  NSString                *type;
  Class generatorClass;
  
  if (self->delegateRespondsTo.generatorGeneratorForBodyOfPart) {
    bodyGen = [self->delegate mimePartGenerator:self
                              generatorForBodyOfPart:self->part];
  
    if (bodyGen != nil)
      return bodyGen;
  }
  
  if ((contentType = [_part contentType]) == nil)
    contentType = [self defaultContentTypeForPart:_part];
  
  if (contentType == nil) {
    [self logWithFormat:@"WARNING(%s): missing content-type in part 0x%p.",
	    __PRETTY_FUNCTION__, _part];
    return nil;
  }
  
  type = [contentType type];

  generatorClass = Nil;
  if ([type isEqualToString:NGMimeTypeMultipart])
    generatorClass = [NGMimeMessageMultipartBodyGenerator class];
  else if ([type isEqualToString:NGMimeTypeText])
    generatorClass = [NGMimeMessageTextBodyGenerator class];
  else if (([type isEqualToString:NGMimeTypeMessage]) &&
           [[contentType subType] isEqualToString:@"rfc822"]) {
    generatorClass = [NGMimeMessageRfc822BodyGenerator class];
  }

  if (generatorClass == Nil) {
    [self debugWithFormat:
	    @"found no body generator class for part with type: %@", 
	    contentType];
    return nil;
  }
  
  if (debugOn) {
    [self debugWithFormat:@"using body generator class %@ for part: %@",
	    generatorClass, _part];
  }
  
  /* allocate generator */
  
  bodyGen = [[[generatorClass alloc] init] autorelease];
  [(id)bodyGen setUseMimeData:self->useMimeData];
  return bodyGen;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGMimeMessageGenerator */
