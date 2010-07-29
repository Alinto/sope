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

#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"

NGMime_DECLARE NSString *NGMimeContentDispositionInlineType     = @"inline";
NGMime_DECLARE NSString *NGMimeContentDispositionAttachmentType = @"attachment";
NGMime_DECLARE NSString *NGMimeContentDispositionFormType       = @"form-data";

@implementation NGMimeContentDispositionHeaderField

static int MimeLogEnabled = -1;

+ (int)version {
  return 2;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  MimeLogEnabled = [ud boolForKey:@"MimeLogEnabled"] ? 1 : 0;
}

- (id)initWithString:(NSString *)_value {
  unsigned len = [_value length];
  unichar  buf[len+1];
  
  if (len == 0) {
    [self logWithFormat:
	    @"WARNING(%s): no value for disposition header value!",
            __PRETTY_FUNCTION__];
    self = [self autorelease];
    return nil;
  }
  
  [_value getCharacters:buf];
  buf[len] = '\0';
  
  if ((self = [super init])) {
    unsigned cnt, start;

    cnt = 0;
    // skip leading spaces
    
    while (isRfc822_LWSP(buf[cnt])) cnt++;
    
    if (buf[cnt] == '\0') {
      if (MimeLogEnabled) 
        [self logWithFormat:@"WARNING(%s): no value for disposition header"
              @" value !", __PRETTY_FUNCTION__];
      self = [self autorelease];
      return nil;
    }
    start = cnt;
    
    while ((buf[cnt] != ';') && (buf[cnt] != '\0') && !isRfc822_LWSP(buf[cnt]))
      cnt++;

    if (cnt <= start) {
      if (MimeLogEnabled) 
        [self logWithFormat:@"WARNING(%s): found no type in disposition "
              @"header value (%@) !", __PRETTY_FUNCTION__, _value];
      self = [self autorelease];
      return nil;
    }
    
    self->type = [[[NSString alloc]
                             initWithCharacters:buf+start length:(cnt - start)]
                             autorelease];
    start      = 0;
    self->type = [self->type lowercaseString];
    self->type = [self->type retain];
    
    if (self->type == nil) {
      if (MimeLogEnabled)
        [self logWithFormat:@"WARNING(%s): found no type in disposition header "
              @"value (%@) !", __PRETTY_FUNCTION__, _value];
      self = [self autorelease];
      return nil;
    }
    self->parameters = [parseParameters(self, _value, buf+cnt) retain];
  }
  return self;
}

- (id)init {
  return [self initWithString:nil];
}

- (void)dealloc {
  [self->type       release];
  [self->parameters release];
  [super dealloc];
}

/* accessors */

- (NSString *)type {
  return self->type;
}

/* parameters */

- (NSString *)name {
  return [self->parameters objectForKey:@"name"];
}
- (NSString *)filename {
  NSString *fn;

  fn = [self->parameters objectForKey:@"filename"];

  if (![fn isNotNull])
    fn = nil;
  
  if (![fn length]) {
    fn = [self name];
  }
  return fn;
}

- (NSString *)valueOfParameterWithName:(NSString *)_name {
  return [self->parameters objectForKey:_name];
}

- (BOOL)valueNeedsQuotes:(NSString *)_parameterValue {
  int     len = [_parameterValue length];
  unichar cstr[len + 1];
  int     cnt;

  [_parameterValue getCharacters:cstr];

  for (cnt = 0; cnt < len; cnt++) {

    if (isMime_SpecialByte(cstr[cnt]))
      return YES;

    if (cstr[cnt] == 32)
      return YES;
  }
  return NO;
}

- (NSString *)parametersAsString {
  NSEnumerator *names;

  if ((names = [self->parameters keyEnumerator])) {
    NSMutableString *result = [NSMutableString stringWithCapacity:64];
    NSString *name;

    while ((name = [names nextObject])) {
      id value = [[parameters objectForKey:name] stringValue];
      [result appendString:@"; "];
      [result appendString:name];
      [result appendString:@"="];
      if ([self valueNeedsQuotes:value]) {
        [result appendString:@"\""];
        [result appendString:value];
        [result appendString:@"\""];
      }
      else
        [result appendString:value];
    }
    return result;
  }
  else
    return nil;
}

- (NSString *)stringValue {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:20];
  [str appendString:type];
  {
    NSString *paras = [self parametersAsString];
    if (paras) [str appendString:paras];
  }
  return str;
}

/* description */

- (NSString *)description {
  NSMutableString *d;

  d = [[NSMutableString alloc] init];

  [d appendFormat:@"<%@[0x%p]: type=%@",
       NSStringFromClass([self class]), self, self->type];

  if (self->parameters)
    [d appendFormat:@" parameters=%@", self->parameters];

  [d appendString:@">"];
  return [d autorelease];
}

@end /* NGMimeContentDispositionHeaderField */
