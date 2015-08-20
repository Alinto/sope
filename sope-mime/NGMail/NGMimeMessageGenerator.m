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

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

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

int _encodeWord(const char *bytes, unsigned int length, NSMutableData *destination)
{
  const char *iso = "=?utf-8?q?";
  unsigned int isoLen = 10;
  const char *isoEnd = "?=";
  unsigned int isoEndLen = 2;
  char *des = NULL;
  unsigned int desLen = 0;
  int retval = -1;
  
  desLen = length*3 + isoLen + isoEndLen;
  des = calloc(desLen + 2, sizeof(char));
  if (!des) {
    return -1;
  }

  memcpy(des, iso, isoLen);
  desLen = NGEncodeQuotedPrintableMime((unsigned char *) bytes, 
                                       length,
                                       (unsigned char *)(des + isoLen),
                                       desLen - isoLen - isoEndLen);
  if ((int)desLen != -1) {
    memcpy(des + isoLen + desLen, isoEnd, isoEndLen);
    [destination appendBytes: des
                      length: (isoLen + desLen + isoEndLen)];
    retval = 0;
  }

  free(des);
  return retval;
}

/*
This function assumes the format of MIME header parameters.

The no-MIME headers will continue to be correctly encoded, just it will be 
several q-encoded words separated as if they were header MIME parameters.

Also, it assumes that the header MIME parameters are correctly generated
by the client, and does not try to enforce that parameter names should 
not be encoded.
*/
- (id)_escapeFieldValue:(NSData *)_data 
{
  NSMutableData *encodedHeader = nil;
  const char *bytes;
  unsigned int valueLength  = 0;
  unsigned int lastPosition;

  unsigned int i;
  BOOL doEnc = NO;
  unsigned int encodingPos = 0;
  unsigned int asciiPos = 0;
  unsigned int parameterPos = 0;
  BOOL quoted = NO;

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

  bytes = (char*) [_data bytes];
  valueLength = [_data length];
  lastPosition = valueLength - 1;

  for (i=0; i < valueLength; i++) {
    unsigned char chr = (unsigned char)bytes[i];
    BOOL endWord = NO;

    if (i == lastPosition) {
      endWord = YES;
      if (chr > 127)
        doEnc = YES;
    } else if (chr > 127)  {
      doEnc = YES;
    } else if (chr == ';') {
      if (encodingPos == i) {
        // this is to skip contiguous ';'
        encodingPos += 1;
      } else {
        endWord = YES;
      }
    } else if (chr == '=' && !doEnc && i > 0) {
      if (((unsigned char)bytes[i-1] != '=') &&
          ((unsigned char)bytes[i+1] != '=')) {
        parameterPos = encodingPos;
        encodingPos = i + 1;

        if ((unsigned char)bytes[i+1] == '"')
          quoted = YES;
      }
    }

    if (endWord) {
      if (!doEnc) {
        encodingPos = i +1;
        if ((i == lastPosition) && encodedHeader) {
          [encodedHeader appendBytes: "\n"
                              length: 1];
          [encodedHeader appendBytes: bytes + asciiPos
                              length: valueLength - asciiPos];
        }
      } else {
        unsigned int lenAscii;
        unsigned int lenParameter;
        unsigned int lenEncode;
        unsigned int afterCrLfPos;
        if (encodedHeader == nil)
          encodedHeader = [NSMutableData data];

        // calculate length of the sections
        if (asciiPos == encodingPos) {
          lenAscii = 0;
          lenParameter = 0;
        } else {
          if (asciiPos > parameterPos) {
            // no parameter in this case
            lenAscii = encodingPos - asciiPos;
            lenParameter = 0;
          } else {
            lenAscii = parameterPos - asciiPos;
            lenParameter = encodingPos - parameterPos;
          }
        }
        lenEncode = i + 1 - encodingPos;

        if (lenAscii) {
          // add no encoded bytes as they are
          [encodedHeader appendBytes: bytes + asciiPos
                              length: lenAscii];
        }

        if (lenAscii || asciiPos > 0) {
          // we need a crlf+space to split the header value
          afterCrLfPos = asciiPos + lenAscii;
          if ((unsigned char)bytes[afterCrLfPos] == ' ') {
            if ((afterCrLfPos+1 != lastPosition) &&
                (unsigned char)bytes[afterCrLfPos+1] != ' ') {
              if (lenParameter == 0) {
                // assure the space is not encoded
                [encodedHeader appendBytes: "\n "
                                    length: 2];
                encodingPos += 1;
                lenEncode -= 1;
              } else {
                // the space after the mime delimiter will be recicled as continue-line
                [encodedHeader appendBytes: "\n"
                                    length: 1];
              }
            } else {
              // 2 spaces at begin of line we must quote the second
              [encodedHeader appendBytes: "\n \\ "
                                  length: 4];
              // we must adjust pointer to bypass the two altered spaces
              if (lenParameter) {
                parameterPos += 2;
                lenParameter -= 2;
              } else {
                encodingPos += 2;
                lenEncode -= 2;
              }
            }
          } else {
            [encodedHeader appendBytes: "\n "
                                length: 2];
          }
        }

        if (lenParameter) {
          // add parameter lvalue as is it
          [encodedHeader appendBytes: bytes + parameterPos
                              length: lenParameter];
        }

        // dont encode ';' termination
        // and check if it is fully quoted if needed
        if (chr == ';') {
          lenEncode -= 1;
          if ((unsigned char)bytes[i-1] != '"')
                quoted = NO;
        } else if (quoted && (chr != '"')) {
          quoted = NO;
        }

        if (quoted) {
          encodingPos += 1;
          lenEncode -= 2; // because we left two characters aside
          [encodedHeader appendBytes: "\""
                              length: 1];     
        }

        if (_encodeWord (bytes+encodingPos, lenEncode, encodedHeader) == 0) {
          doEnc = NO;
          asciiPos = i + 1;
          encodingPos = i + 1;
          if (quoted) {
            [encodedHeader appendBytes: "\""
                                length: 1];     
            quoted = NO;
          }
          if (chr == ';') {
            [encodedHeader appendBytes: ";"
                                length: 1];
          }
        } else {
          [self logWithFormat:
                    @"WARNING: Error during quoted-printable encoding"];
          return _data;
        }
      }
    }
  }  

  if (encodedHeader == nil)
    return _data;

  return encodedHeader;
}

- (NSData *)generateDataForHeaderField:(NSString *)_hf value:(id)_value {
  NSData *data;
  
  // TODO: properly deal with header field values, add proper quoting
  //       prior passing the value up?
  
  data = [super generateDataForHeaderField:_hf value:_value];
  return [self _escapeFieldValue: data];
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
