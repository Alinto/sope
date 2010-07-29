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

#include <NGScripting/NGScriptLanguage.h>
#include "NGJavaScriptContext.h"
#include "NGJavaScriptObjectMappingContext.h"
#include "../common.h"
#import <EOControl/EOControl.h>

@implementation NSObject(JSSupport)

static NGScriptLanguage *js = nil;
static inline NGScriptLanguage *_jsLang(void) {
  if (js == nil)
    js = [[NGScriptLanguage languageWithName:@"javascript"] retain];
  return js;
}

#if 0 /* do not enable, would expose any ObjC KVC to JavaScript !!! */
- (BOOL)takeValue:(id)_value forJSPropertyNamed:(NSString *)_key {
  return [self takeValue:_value forKey:_key];
}
- (id)valueForJSPropertyNamed:(NSString *)_key {
  return [self valueForKey:_key];
}
#endif

/* parents */

- (id)_js_parentObject {
  return nil;
}

/* JS functions */

- (id)_jsprop_objCClass {
  return NSStringFromClass([self class]);
}

- (id)_jsfunc_print:(NSArray *)_args {
  NSEnumerator *e;
  id   o;
  BOOL isFirst;

  isFirst = YES;
  e = [_args objectEnumerator];
  while ((o = [e nextObject])) {
    NSString *s;

    if (!isFirst) fputc(' ', stdout);
    else isFirst = NO;
    
    s = [o stringValue];
    fputs(s ? [s cString] : "", stdout);
  }
  fputc('\n', stdout);
  
  return self;
}

/* evaluation */

- (id)evaluateJavaScript:(NSString *)_script {
  return [_jsLang() evaluateScript:_script onObject:self 
                    source:@"<string>" 
		    line:0];
}

/* JavaScript functions */

- (id)callJavaScriptFunction:(NSString *)_func {
  return [_jsLang() callFunction:_func onObject:self];
}

- (id)callJavaScriptFunction:(NSString *)_func withObject:(id)_arg0 {
  return [_jsLang() callFunction:_func withArgument:_arg0 onObject:self];
}

- (id)callJavaScriptFunction:(NSString *)_func
  withObject:(id)_arg0
  withObject:(id)_arg1
{
  return [_jsLang() callFunction:_func
		 withArgument:_arg0
		 withArgument:_arg1
		 onObject:self];
}

@end /* NSObject(JSSupport) */
