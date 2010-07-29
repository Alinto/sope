/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "NSString+JS.h"
#include "NGJavaScriptContext.h"
#import <Foundation/Foundation.h>
#include "../common.h"

@implementation NSString(NGJavaScript)

+ (id)stringWithJavaScriptString:(JSString *)_jss {
  unsigned charCount;
  
  if (_jss == NULL)
    return nil;
  if ((charCount = JS_GetStringLength(_jss)) == 0)
    return @"";

  return [[[self alloc] initWithJavaScriptString:_jss] autorelease];
}

#if !HANDLE_NSSTRINGS_AS_OBJECTS
- (BOOL)_jsGetValue:(jsval *)_value inJSContext:(NGJavaScriptContext *)_ctx {
  JSContext *cx;
  JSString  *s;
  unsigned  len;
  char      *buf;
  
  len = [self cStringLength];
  
  //NSLog(@"%s: MORPH STRING (len=%i) ...", __PRETTY_FUNCTION__, len);
  
  cx = [_ctx handle];
  //NSAssert1(cx, @"missing JS context handle (ctx=%@) ...", _ctx);
  
  // TODO: unicode
  
  if ((buf = JS_malloc(cx, len + 3)) == NULL) {
    NSLog(@"%s: could not allocate string buffer (len=%i) ...", 
	  __PRETTY_FUNCTION__, len);
    return NO;
  }
  [self getCString:buf]; buf[len] = '\0';
  
  s = JS_NewString(cx, buf, len);
  *_value = STRING_TO_JSVAL(s);
  
  return YES;
}
#endif

- (id)_jsprop_length {
#if !HANDLE_NSSTRINGS_AS_OBJECTS
  printf("CALLED NSString 'length' JS property "
	 "(should never happen since NSStrings convert themselves to"
	 " JSString values !)\n");
#endif
  return [NSNumber numberWithInt:[self length]];
}

@end /* NSString(NGJavaScript) */

@implementation NSObject(NGJavaScript)
/* category on NSObject, so that NSTemporaryString is included ! */

- (id)initWithJavaScriptString:(JSString *)_jss {
#if WITH_UNICODE
  unsigned charCount, i;
  unichar  *uchars;
  jschar   *jchars;

  if (_jss == NULL) {
    [self release];
    return nil;
  }
  
  if ((charCount = JS_GetStringLength(_jss)) == 0) {
    [self release];
    return @"";
  }

  jchars = JS_GetStringChars(_jss);
  NSAssert(jchars, @"couldn't get chars of JavaScript string !");
  
  uchars = calloc(charCount + 3, sizeof(unichar));
  for (i = 0; i < charCount; i++)
    uchars[i] = jchars[i];

  self = [(NSString *)self initWithCharacters:uchars length:charCount];
  free(uchars);
  
  return self;
#else
  unsigned char *cstr;

  if ((cstr = JS_GetStringBytes(_jss)))
    return [(NSString *)self initWithCString:cstr];
  
  NSLog(@"ERROR(%s): did not get bytes of JS string 0x%p !",
	__PRETTY_FUNCTION__, _jss);
  [self release];
  return nil;
#endif
}

@end /* NSObject(NGJavaScript) */
