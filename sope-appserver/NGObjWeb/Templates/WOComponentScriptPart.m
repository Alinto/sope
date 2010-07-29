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

#include <NGObjWeb/WOTemplateBuilder.h>
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@implementation WOComponentScriptPart

- (id)initWithURL:(NSURL *)_url startLine:(unsigned)_ln script:(NSString *)_s {
  self->url       = RETAIN(_url);
  self->startLine = _ln;
  self->script    = [_s copy];
  return self;
}
- (id)initWithContentsOfFile:(NSString *)_path {
  NSURL    *furl;
  NSString *s;
  
  if ([_path length] == 0) {
    RELEASE(self);
    return nil;
  }
  
  if ((s = [[NSString alloc] initWithContentsOfFile:_path]) == nil) {
    RELEASE(self);
    return nil;
  }
  
  furl = [[NSURL alloc] initFileURLWithPath:_path];
  self = [self initWithURL:furl startLine:0 script:s];
  RELEASE(furl);
  RELEASE(s);
  return self;
}

- (void)dealloc {
  RELEASE(self->url);
  RELEASE(self->script);
  [super dealloc];
}

/* operations */

- (NSException *)handleException:(NSException *)_exception {
  if (self->startLine == 0)
    return _exception;
  
  if ([[_exception name] isEqualToString:@"JavaScriptError"]) {
    /* correct script start lines to actual value */
    NSMutableDictionary *ui;
    int line;
    
    ui = [[_exception userInfo] mutableCopy];
    line = [[ui objectForKey:@"line"] intValue];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    [ui setObject:[NSNumber numberWithInt:(line + self->startLine)]
	forKey:@"line"];
    [_exception setUserInfo:ui];
    RELEASE(ui);
  }
  return _exception;
}

- (void)initScriptWithComponent:(WOComponent *)_object {
#if 1
  [self errorWithFormat:@"cannot apply script on object: %@", _object];
#else
  /* fixed on JavaScript, part should have a language ... */
  NS_DURING {
    [_object evaluateScript:self->script language:@"javascript"
	     source:[self->url absoluteString] line:self->startLine];
  }
  NS_HANDLER
    [[self handleException:localException] raise];
  NS_ENDHANDLER;
#endif
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:32];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->url) {
    if ([self->url isFileURL])
      [ms appendFormat:@" path=%@", [self->url path]];
    else
      [ms appendFormat:@" url=%@", self->url];
    if (self->startLine > 0)
      [ms appendFormat:@":%i", self->startLine];
  }
  else if (self->startLine > 0)
    [ms appendFormat:@" line=%@", self->startLine];

  if ([self->script length] == 0)
    [ms appendString:@" no script"];
  else if ([self->script length] < 16)
    [ms appendFormat:@" script=%@", self->script];
  else
    [ms appendFormat:@" script=%@...", [self->script substringToIndex:13]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* WOComponentScriptPart */
