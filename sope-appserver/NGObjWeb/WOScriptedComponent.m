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

#include "WOScriptedComponent.h"
#include <NGObjWeb/WOTemplateBuilder.h>
#include <NGScripting/NGScriptLanguage.h>
#include "common.h"

@interface NSObject(misc)
- (void)applyStandardClasses;
- (BOOL)isScriptFunction;

- (id)callScriptFunction:(NSString *)_name withObject:(id)_arg0;
- (id)evaluateScript:(NSString *)_script source:(NSString *)_s line:(int)_line;

@end

@interface WOComponent(UsedPrivates)
- (id)initWithName:(NSString *)_cname
  template:(WOTemplate *)_template
  inContext:(WOContext *)_ctx;
@end

@interface WOComponentScript(UsedPrivates)
- (id)initScriptWithComponent:(id)_comp;
@end

@implementation WOScriptedComponent

static BOOL logScriptKVC     = NO;
static BOOL logScriptInit    = NO;
static BOOL logScriptDealloc = NO;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    logScriptKVC     = [ud boolForKey:@"WOLogScriptKVC"];
    logScriptInit    = [ud boolForKey:@"WOLogScriptInit"];
    logScriptDealloc = [ud boolForKey:@"WOLogScriptDealloc"];
  }
}

- (id)initWithName:(NSString *)_cname
  template:(WOTemplate *)_template
  inContext:(WOContext *)_ctx
{
  if ((self = [super initWithName:_cname template:_template inContext:_ctx])) {
    self->script = [[_template componentScript] retain];

    self->language = 
      [[NGScriptLanguage languageWithName:[self->script language]] retain];
    if (self->language == nil) {
      [self logWithFormat:
              @"did not find engine for script language %@", 
	      [self->script language]];
      RELEASE(self);
      return nil;
    }
    
    if ((self->shadow = [self->language createShadowForMaster:self]) == nil) {
      [self logWithFormat:
              @"could not create shadow for component in language %@", 
	      self->language];
      RELEASE(self);
      return nil;
    }
    
    if ([self->shadow respondsToSelector:@selector(applyStandardClasses)])
      [(id)self->shadow applyStandardClasses];
    
    [self->script initScriptWithComponent:self];
    
    if (logScriptInit)
      [self logWithFormat:@"created scripted component: %@", self];
  }
  return self;
}

- (void)dealloc {
  if (logScriptDealloc)
    [self logWithFormat:@"will dealloc scripted component: %@", self];
  
  [self->shadow invalidateShadow]; /* ensure shadow is dead ;-) */
  RELEASE(self->shadow);
  RELEASE(self->language);
  RELEASE(self->script);
  RELEASE(self->template);
  [super dealloc];
}

/* accessors */

- (void)setTemplate:(id)_template {
  ASSIGN(self->template, _template);
}
- (WOElement *)_woComponentTemplate {
  return self->template;
}

- (BOOL)isScriptedComponent {
  return YES;
}

/* scripting */

- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang 
  source:(NSString *)_src line:(unsigned)_line
{
  return [self->shadow evaluateScript:_script source:_src line:_line];
}

/* notification mapping */

- (void)awake {
  [super awake];
  
  if ([self->shadow hasFunctionNamed:@"awake"])
    [self->shadow callScriptFunction:@"awake"];
}
- (void)sleep {
  if ([self->shadow hasFunctionNamed:@"sleep"])
    [self->shadow callScriptFunction:@"sleep"];
  
  //[self debugWithFormat:@"vars: %@", [self variableDictionary]];
  [super sleep];
}

/* script properties */

- (BOOL)takeValue:(id)_value forJSPropertyNamed:(NSString *)_key {
  NSAssert1(self->shadow, @"missing shadow for component %@", self);
  [self->shadow setObject:_value forKey:_key];
  return YES;
}
- (id)valueForJSPropertyNamed:(NSString *)_key {
  [self debugWithFormat:@"value for prop %@", _key];
  NSAssert1(self->shadow, @"missing shadow for component %@", self);
  return [self->shadow objectForKey:_key];
}

/* extra variables */

- (void)setObject:(id)_obj forKey:(NSString *)_key {
  //[self debugWithFormat:@"setObject:%@ forKey:%@", _obj, _key];
  NSAssert1(self->shadow, @"missing shadow for component %@", self);
  [self->shadow setObject:_obj forKey:_key];
}
- (id)objectForKey:(NSString *)_key {
  NSAssert1(self->shadow, @"missing shadow for component %@", self);
  return [self->shadow objectForKey:_key];
}

/* key-value coding */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  NSString *funcName;
  id       func;
  unsigned len;
  unsigned char *buf;
  
  len = [_key cStringLength];
  buf = malloc(len + 4);
  [_key getCString:&(buf[3])];
  buf[0] = 's'; buf[1] = 'e'; buf[2] = 't';
  buf[len + 3] = '\0';
  if (len > 0) buf[3] = toupper(buf[3]);
  funcName = [NSString stringWithCString:buf length:(len + 3)];
  free(buf);
  
  if ((func = [self->shadow objectForKey:funcName])) {
    if ([func isScriptFunction]) {
      id result;
      
      if (logScriptKVC) {
	[self logWithFormat:@"KVC: for key %@ call %@(%@)", 
	        _key, funcName, _value];
      }
      
      result = [self->shadow callScriptFunction:funcName withObject:_value];
    }
    else {
      [self logWithFormat:
	      @"KVC: object stored at '%@' is not a function, "
	      @"could not set value for key %@ !",
	      funcName, _key];
    }
  }
  else {
    if (logScriptKVC) {
      [self logWithFormat:@"KVC: assign %@=%@ (no func '%@')", 
	      _key, _value, funcName];
    }
    
    [self->shadow setObject:_value forKey:_key];
  }
}

- (id)valueForKey:(NSString *)_key {
  id obj;
  
  //[self logWithFormat:@"script: valueForKey:%@", _key];
  
  if ((obj = [self->shadow objectForKey:_key])) {
    if ([obj isScriptFunction]) {
      if (logScriptKVC) {
	[self logWithFormat:@"KVC: for key %@ call %@", 
	        _key, _key];
      }
      obj = [self->shadow callScriptFunction:_key];
    }
    else {
      if (logScriptKVC) {
	[self logWithFormat:@"KVC: valueForKey(%@): %@", 
	        _key, obj];
      }
    }
    return obj;
  }
  else {
    if (logScriptKVC) {
      [self logWithFormat:@"KVC: get value for key %@ from WOComponent", 
	      _key];
    }
    return [super valueForKey:_key];
  }
}

/* logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"script<%@>[0x%p]", [self name], self];
}

@end /* WOScriptedComponent */

@implementation NSObject(ScriptFunc)

- (BOOL)isScriptFunction {
  return NO;
}

@end /* NSObject(ScriptFunc) */
