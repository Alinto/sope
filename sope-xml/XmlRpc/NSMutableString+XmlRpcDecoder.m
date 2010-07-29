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

#include "common.h"
#include <string.h>

@implementation NSMutableString(XmlRpcDecoder)

- (void)appendXmlRpcString:(NSString *)_value {
#if 1 // TODO: to be tested !
  unsigned i, j, len;
  BOOL     didEscape = NO;
  unichar  *buf, *escbuf = NULL;
  
  if ((len = [_value length]) == 0)
    /* nothing to add ... */
    return;
    
  if (len == 1) {
    /* a single char */
    unichar c;
    
    switch ((c = [_value characterAtIndex:0])) {
      case '&': [self appendString:@"&amp;"];  break;
      case '<': [self appendString:@"&lt;"];   break;
      case '>': [self appendString:@"&gt;"];   break;
      case '"': [self appendString:@"&quot;"]; break;
      default:  [self appendString:_value];    break;
    }
    return;
  }
  
  buf = calloc(len + 2, sizeof(unichar));
  [_value getCharacters:buf];
  
  for (i = 0, j = 0; i < len; i++) {
    switch (buf[i]) {
      case '&':
      case '<':
      case '>':
      case '"': {
        didEscape = YES;
        if (escbuf == NULL) {
          /* worst case: string consists of quotes */
          escbuf = calloc(len * 6 + 2, sizeof(unichar));
          memcpy(escbuf, buf, i * sizeof(unichar));
          j = i;
        }
        escbuf[j++] = '&';
        switch (buf[i]) {
          case '&':
            escbuf[j++] = 'a'; escbuf[j++] = 'm'; escbuf[j++] = 'p';
            break;
          case '<':
            escbuf[j++] = 'l'; escbuf[j++] = 't';
            break;
          case '>':
            escbuf[j++] = 'g'; escbuf[j++] = 't';
            break;
          case '"':
            escbuf[j++] = 'q'; escbuf[j++] = 'u';
            escbuf[j++] = 'o'; escbuf[j++] = 't';
            break;
        }
        escbuf[j++] = ';';
        break;
      }
      default:
        if (escbuf)
          escbuf[j++] = buf[i];
        break;
    }
  }
  
  if (escbuf) {
    NSString *s;
    
    s = [[NSString alloc] initWithCharacters:escbuf length:j];
    [self appendString:s];
    [s release];
    free(escbuf);
  }
  else
    [self appendString:_value];
  
  if (buf) free(buf);
#else
#warning UNICODE !!!
  void (*addBytes)(id,SEL,const char *,unsigned);
  id            dummy = nil;
  unsigned      clen;
  unsigned char *cbuf;
  unsigned char *cstr;

  if ([_value length] == 0) return;

  clen = [_value cStringLength];
  if (clen == 0) return; /* nothing to add .. */
  
  cbuf = cstr = malloc(clen + 1);
  [_value getCString:cbuf]; cbuf[clen] = '\0';
  dummy = [[NSMutableData alloc] initWithCapacity:2*clen];

  addBytes = (void*)[dummy methodForSelector:@selector(appendBytes:length:)];
  NSAssert(addBytes != NULL, @"could not get appendBytes:length: ..");
  
  while (*cstr) {
    switch (*cstr) {
      case '&':
        addBytes(dummy, @selector(appendBytes:length:), "&amp;", 5);
        break;
      case '<':
        addBytes(dummy, @selector(appendBytes:length:), "&lt;", 4);
        break;
      case '>':
        addBytes(dummy, @selector(appendBytes:length:), "&gt;", 4);
        break;
      case '"':
        addBytes(dummy, @selector(appendBytes:length:), "&quot;", 6);
        break;
      
      default:
        addBytes(dummy, @selector(appendBytes:length:), cstr, 1);
        break;
    }
    cstr++;
  }
  free(cbuf);
  {
    NSString *tmp = nil;
    
    tmp = [[NSString alloc] initWithData:dummy
                            encoding:[NSString defaultCStringEncoding]];
    [self appendString:tmp];
    [tmp release];
  }
#endif
}

@end /* NSMutableString(XmlRpcDecoder) */
