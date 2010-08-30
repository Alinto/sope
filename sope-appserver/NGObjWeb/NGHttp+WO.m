/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "NGHttp+WO.h"
#include <NGHttp/NGHttp.h>
#include <NGObjWeb/WOCookie.h>
#include <NGObjWeb/WORequest.h>
#include <NGMime/NGMime.h>
#include "common.h"
#include <string.h>

@interface WORequest(NGSupport)
- (void)_setHttpRequest:(NGHttpRequest *)_request;
@end

@implementation NGHttpRequest(WOSupport)

static Class NSArrayClass = Nil;

- (id)initWithWORequest:(WORequest *)_request {
  NGHashMap *hm;
  
  hm = [NGHashMap hashMapWithDictionary:[_request headers]];
    
  self = [self initWithMethod:[_request method]
               uri:[_request uri]
               header:hm
               version:[_request httpVersion]];
  [self setBody:[_request content]];
  
  /* transfer cookies */
  if ([[_request cookies] isNotEmpty])
    [self warnWithFormat:@"cannot transfer cookies to NGHttpRequest yet !"];

  /* transfer headers !!! */
  
  return self;
}

- (WORequest *)woRequest {
  NSAutoreleasePool *pool;
  WORequest    *request;
  NSDictionary *woHeaders;
  
  pool = [[NSAutoreleasePool alloc] init];

  /* Note: headers are added below ... */
  woHeaders = nil;
  
  request = [[WORequest alloc]
                        initWithMethod:[self methodName]
                        uri:[self uri]
                        httpVersion:[self httpVersion]
                        headers:woHeaders
                        content:[self woContent]
                        userInfo:nil];
  request = [request autorelease];
  
  [request _setHttpRequest:self];
  
  /* process charset */
  // DUP: WOSimpleHTTPParser
  {
    NSStringEncoding enc = 0;
    NGMimeType *rqContentType = [self contentType];
    NSString   *charset = [rqContentType valueOfParameter:@"charset"];
    
    if ([charset isNotEmpty]) {
      enc = [NSString stringEncodingForEncodingNamed:charset];
    }
    else if (rqContentType != nil) {
      /* process default charsets for content types */
      NSString *majorType = [rqContentType type];
      
      if ([majorType isEqualToString:@"text"]) {
	NSString *subType = [rqContentType subType];
	
	if ([subType isEqualToString:@"calendar"]) {
	  /* RFC2445, section 4.1.4 */
	  enc = NSUTF8StringEncoding;
	}
      }
      else if ([majorType isEqualToString:@"application"]) {
	NSString *subType = [rqContentType subType];
	
	if ([subType isEqualToString:@"xml"]) {
	  // TBD: we should look at the actual content! (<?xml declaration
	  //      and BOM
	  enc = NSUTF8StringEncoding;
	}
      }
    }

    if (enc != 0)
      [request setContentEncoding:enc];
  }
  
  /* process cookies */
  {
    NSEnumerator *cs;
    WOCookie *cookie;
    
    cs = [[self woCookies] objectEnumerator];
    while ((cookie = [cs nextObject]) != nil)
      [request addCookie:cookie];
  }
  
  /* process headers */
  {
    NSEnumerator *keys;
    NSString *key;

    if (NSArrayClass == Nil)
      NSArrayClass = [NSArray class];
    
    keys = [self headerFieldNames];
    while ((key = [keys nextObject]) != nil) {
      NSEnumerator *values;
      id value;
      
      values = [self valuesOfHeaderFieldWithName:key];
      while ((value = [values nextObject]) != nil) {
        if ([value isKindOfClass:NSArrayClass]) {
          NSEnumerator *ev2;

          ev2 = [value objectEnumerator];
          while ((value = [ev2 nextObject]) != nil) {
            value = [value stringValue];
            [request appendHeader:value forKey:key];
          }
        }
        else {
          value = [value stringValue];
          [request appendHeader:value forKey:key];
        }
      }
    }
  }
  
  request = [request retain];
  [pool release]; pool = nil;
  
  return [request autorelease];
}

/* headers */

- (NSArray *)woHeaderKeys {
  NSMutableArray *keys;
  NSEnumerator   *ekeys;
  NSString       *key   = nil;
  
  keys  = [[NSMutableArray alloc] init];
  ekeys = [self headerFieldNames];
  
  while ((key = [ekeys nextObject]))
    [keys addObject:key];
  
  return [keys autorelease];
}

- (NSString *)woHeaderForKey:(NSString *)_key {
  return [[[self valuesOfHeaderFieldWithName:_key]
                 nextObject]
                 stringValue];
}

- (NSArray *)woHeadersForKey:(NSString *)_key {
  NSMutableArray *vals;
  NSEnumerator   *evals;
  NSString       *value = nil;

  vals  = [NSMutableArray arrayWithCapacity:2];
  evals = [self valuesOfHeaderFieldWithName:_key];
  
  while ((value = [evals nextObject])) {
    if ((value = [value stringValue]))
      [vals addObject:value];
  }

  return vals;
}

/* cookies */

- (void)_addHTTPCookie:(id)_cookie to:(NSMutableArray *)_a {
  static Class NGHttpCookieClass = Nil;
  static Class WOCookieClass = Nil;
  WOCookie *cookie;
  id cookieValue;
  
  if (_cookie == nil)
    return;
  
  if (NGHttpCookieClass == Nil) NGHttpCookieClass = [NGHttpCookie class];
  if (WOCookieClass     == Nil) WOCookieClass = NSClassFromString(@"WOCookie");

  if (![_cookie isKindOfClass:NGHttpCookieClass]) {
    static NGHttpCookieFieldParser *cookieParser = nil;
          
    if (cookieParser == nil)
      cookieParser = [[NGHttpCookieFieldParser alloc] init];
          
    _cookie = [_cookie stringValue];
    _cookie = [_cookie dataUsingEncoding:NSISOLatin1StringEncoding];
    _cookie = [cookieParser parseValue:_cookie ofHeaderField:@"cookie"];
  }
  
  if ([_cookie isKindOfClass:[NSArray class]]) {
    id singleCookie;
      
    _cookie = [_cookie objectEnumerator];
    
    while ((singleCookie = [_cookie nextObject]))
      [self _addHTTPCookie:singleCookie to:_a];
    return;
  }

  cookieValue = [(NGHttpCookie *)_cookie value];
  if ([cookieValue isKindOfClass:[NSArray class]]) {
    if (![cookieValue isNotEmpty])
      cookieValue = @"";
    else if ([cookieValue count] == 1)
      cookieValue = [[cookieValue objectAtIndex:0] stringValue];
    else {
      [self logWithFormat:
	      @"got %d values for cookie '%@', using first only: %@",
	      [cookieValue count],
	      [_cookie cookieName], 
	      [cookieValue componentsJoinedByString:@","]];
      cookieValue = [[cookieValue objectAtIndex:0] stringValue];
    }
  }
  else
    cookieValue = [cookieValue stringValue];
    
  cookie = [WOCookieClass cookieWithName:[_cookie cookieName]
			  value:cookieValue
			  path:[_cookie path]
			  domain:[_cookie domainName]
			  expires:[_cookie expireDate]
			  isSecure:[_cookie needsSecureChannel]];
  
  /* WOMessage */
  if (cookie != nil)
    [_a addObject:cookie];
}

- (NSArray *)woCookies {
  NSMutableArray *womCookies;
  NSArray        *woCookies;
  NSEnumerator   *mcookies;
  id             cookie;

  if (NSArrayClass == Nil) NSArrayClass = [NSArray class];
  
  womCookies = [NSMutableArray arrayWithCapacity:8];
  
  mcookies = [self valuesOfHeaderFieldWithName:@"cookie"];
  while ((cookie = [mcookies nextObject])) {
    if ([cookie isKindOfClass:NSArrayClass]) {
      id singleCookie;
      
      cookie = [cookie objectEnumerator];
      
      while ((singleCookie = [cookie nextObject]))
        [self _addHTTPCookie:singleCookie to:womCookies];
      
      continue;
    }
    
    [self _addHTTPCookie:cookie to:womCookies];
  }
  
  woCookies = [womCookies copy];
  return [woCookies autorelease];
}

/* content */

- (NSData *)woContent {
  NGMimePartGenerator *gen;
  id content;
  
  if ((content = [self body]) == nil) {
    /* no body */
    return nil;
  }
  
  if ([content isKindOfClass:[NSData class]])
    return content;
  
  if (![content conformsToProtocol:@protocol(NGMimePart)])
    return [[content stringValue] dataUsingEncoding:NSASCIIStringEncoding];
  
  gen  = [[NGMimePartGenerator alloc] init];
  content = [gen generateMimeFromPart:content];
  [gen release];
  return content;
}

/* form parameters */

static NGMimeType *multipartFormData = nil;
static Class      DispClass = Nil;

- (id)_decodeMultiPartFormDataContent {
  NGMutableHashMap    *formContent;
  NGMimeMultipartBody *ebody;
  NSArray             *parts;
  unsigned            i, count;

  if (DispClass == Nil)
    DispClass = [NGMimeContentDispositionHeaderField class];
  
  ebody = [self body];
  if (![ebody isKindOfClass:[NGMimeMultipartBody class]]) {
    [self errorWithFormat:
            @"form-data parser expected MultipartBody, got %@", ebody];
    return [[NGHashMap alloc] init];
  }
  
  parts = [ebody parts];
  count = [parts count];
  
  [self debugWithFormat:@"%s:   %i parts %@", __PRETTY_FUNCTION__, 
          count, parts];
  
  formContent = [[NGMutableHashMap alloc] init];
  for (i = 0; i < count; i++) {
    NGMimeContentDispositionHeaderField *disposition;
    id<NGMimePart> bodyPart;
    NSString *name;
    id       partBody;
	  
    bodyPart = [parts objectAtIndex:i];
    disposition =
      [[bodyPart valuesOfHeaderFieldWithName:@"content-disposition"]nextObject];
          
    if (disposition == nil) {
      [self errorWithFormat:
              @"did not find content disposition in form part %@", bodyPart];
      continue;
    }

    /* morph to disposition field in case it's unparsed ... */
    if (![disposition isKindOfClass:DispClass]) {
              disposition =
                [[DispClass alloc] initWithString:[disposition stringValue]];
              [disposition autorelease];
    }
            
    name     = [disposition name];
    partBody = [bodyPart body];
    
    if (partBody)
      [(NGMutableHashMap *)formContent addObject:partBody forKey:name];
  }
  return formContent;
}

- (NGHashMap *)_decodeFormContentURLParameters:(id)formContent {
  /* all this sounds expensive ;-) */
  NSString   *s;
  unsigned   urilen;
  char       *uribuf;
  const char *p;
  NGHashMap  *map;

  if ((s = [self uri]) == nil)
    return formContent;
  if ([s rangeOfString:@"?"].length == 0)
    return formContent;

  urilen = [s cStringLength];
  p = uribuf = malloc(urilen + 4);
  [s getCString:uribuf]; // UNICODE?
  
  if ((p = index(p, '?')) == NULL) {
    if (uribuf) free(uribuf);
    return formContent;
  }
  
  p++; // skip the '?'
  map = NGDecodeUrlFormParameters((unsigned char *)p, strlen((char *)p));
  if (uribuf != NULL) free(uribuf); uribuf = NULL; p = NULL;

  if (map == nil) 
    return formContent;
  if (formContent == nil)
    return map;
  
  map = [map autorelease]; // NGDecodeUrlFormParameters returns a retained map!
  
  if ([formContent isKindOfClass:[NGHashMap class]]) {
    NSEnumerator *keys;
    id key, tmp;
  
    tmp = formContent;
    formContent =  [[NGMutableHashMap alloc] initWithHashMap:tmp];
    [tmp release]; tmp = nil;
  
    keys = [map keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
      NSEnumerator *values;
      id value;
            
      values = [map objectEnumeratorForKey:key];
      while ((value = [values nextObject]) != nil)
	[formContent addObject:value forKey:key];
    }
  }
  else if ([formContent isKindOfClass:[NSDictionary class]]) {
    NSEnumerator *keys;
    id key, tmp;
	  
    tmp = formContent;
    formContent = [[NGMutableHashMap alloc] initWithDictionary:tmp];
    [tmp release];
    
    keys = [map keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
      NSEnumerator *values;
      id value;
  
      values = [map objectEnumeratorForKey:key];
      while ((value = [values nextObject]) != nil)
	[formContent addObject:value forKey:key];
    }
  }
  return formContent;
}

- (NGHashMap *)formParameters {
  id formContent;
  
  if (multipartFormData == nil)
    multipartFormData = [[NGMimeType mimeType:@"multipart/form-data"] retain];
  
  if ([[self methodName] isEqualToString:@"POST"]) {
    NGMimeType *contentType = [self contentType];
    
#if 0
    NSLog(@"%s: process POST, ctype %@", __PRETTY_FUNCTION__, contentType);
#endif
    
    formContent = [contentType hasSameType:multipartFormData]
      ? [self _decodeMultiPartFormDataContent]
      : [[self body] retain];
  }
  else
    formContent = nil;
  
  /* decode URL parameters */
  formContent = [self _decodeFormContentURLParameters:formContent];
  
  return [formContent autorelease];
}

@end /* NGHttpRequest */
