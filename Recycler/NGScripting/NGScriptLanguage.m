/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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
// $Id: NGScriptLanguage.m 6 2004-08-20 17:57:50Z helge $

#include "NGScriptLanguage.h"
#include "NSObject+Scripting.h"
#include "NGObjectMappingContext.h"
#include "common.h"

@implementation NGScriptLanguage

static id js = nil;

+ (id)languageWithName:(NSString *)_language {
  if ([_language length] == 0) 
    _language = [NSObject defaultScriptLanguage];

  if (![_language hasPrefix:@"javascript"])
    return nil;
  
  if (js == nil) {
    js = [[NSClassFromString(@"NGJavaScriptLanguage") alloc] 
	     initWithLanguage:_language];
  }
  return js;
}

- (id)initWithLanguage:(NSString *)_language {
  return self;
}
- (id)init {
  return [self initWithLanguage:nil];
}

- (NSString *)language {
  return nil;
}

/* evaluation */

- (id)evaluateScript:(NSString *)_script onObject:(id)_object 
  source:(NSString *)_source line:(unsigned)_line
{
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}
- (id)evaluateScript:(NSString *)_script onObject:(id)_object {
  /* deprecated, use the method above */
  return [self evaluateScript:_script onObject:_object
	       source:@"<string>" line:0];
}

/* function calls */

- (id)callFunction:(NSString *)_func onObject:(id)_object {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}
- (id)callFunction:(NSString *)_func withArgument:(id)_arg0 onObject:(id)_o {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}
- (id)callFunction:(NSString *)_func
  withArgument:(id)_arg0
  withArgument:(id)_arg1
  onObject:(id)_object
{
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}

/* reflection */

- (BOOL)object:(id)_object hasFunctionNamed:(NSString *)_name {
  return NO;
}

/* shadow objects */

- (id)createShadowForMaster:(id)_master {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)_coder {
  NSString *lang;
  
  [self autorelease];
  
  lang = [_coder decodeObject];
  return [[NGScriptLanguage languageWithName:lang] retain];
}
- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:[self language]];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone { // to make Foundation happy
  return [self retain];
}

/* object mapping */

- (NGObjectMappingContext *)activeMappingContext {
  return [NGObjectMappingContext activeObjectMappingContext];
}
- (NGObjectMappingContext *)createMappingContext {
#if LIB_FOUNDATION_LIBRARY
  return [self subclassResponsibility:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
  return NULL;
#endif
}

@end /* NGScriptLanguage */
