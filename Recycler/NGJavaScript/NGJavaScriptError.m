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

#include "NGJavaScriptError.h"
#include "NGJavaScriptContext.h"
#include "common.h"

@implementation NGJavaScriptError

- (id)initWithErrorReport:(void *)_report
  message:(NSString *)_msg 
  context:(NGJavaScriptContext *)_ctx
{
#if 0 // JSErrorReport
    const char      *filename;      /* source file name, URL, etc., or null */
    uintN           lineno;         /* source line number */
    const char      *linebuf;       /* offending source line without final \n */
    const char      *tokenptr;      /* pointer to error token in linebuf */
    const jschar    *uclinebuf;     /* unicode (original) line buffer */
    const jschar    *uctokenptr;    /* unicode (original) token pointer */
    uintN           flags;          /* error/warning, etc. */
    uintN           errorNumber;    /* the error number, e.g. see js.msg */
    const jschar    *ucmessage;     /* the (default) error message */
    const jschar    **messageArgs;  /* arguments for the error message */
#endif
  JSErrorReport       *rp = _report;
  NSMutableDictionary *ui;
  NSString *lReason;
  
  ui = [NSMutableDictionary dictionaryWithCapacity:8];
  
  if (_msg) {
    lReason = [[_msg copy] autorelease];
    [ui setObject:lReason forKey:@"message"];
  }
  else
    lReason = @"no JavaScript reason available";

  if (rp->filename) 
    [ui setObject:[NSString stringWithCString:rp->filename] forKey:@"path"];
  if (rp->lineno > 0)
    [ui setObject:[NSNumber numberWithUnsignedInt:rp->lineno] forKey:@"line"];
  if (rp->errorNumber > 0)
    [ui setObject:[NSNumber numberWithUnsignedInt:rp->errorNumber] forKey:@"faultCode"];
    
  if (rp->linebuf)
    [ui setObject:[NSString stringWithCString:rp->linebuf] forKey:@"source"];
  
  self = [self initWithName:@"JavaScriptError"
               reason:lReason
               userInfo:ui];
  self->cx    = [_ctx retain];
  self->flags = rp->flags;
  return self;
}
- (void)dealloc {
  [self->cx release];
  [super dealloc];
}

/* accessors */

- (NSString *)path {
  return [[self userInfo] objectForKey:@"path"];
}
- (int)line {
  return [[[self userInfo] objectForKey:@"line"] intValue];
}
- (NSString *)sourceLine {
  return [[self userInfo] objectForKey:@"source"];
}
- (NSString *)message {
  return [self reason];
}
- (int)errorNumber {
  return [[[self userInfo] objectForKey:@"faultCode"] intValue];
}

- (BOOL)isJSError {
  return (self->flags & JSREPORT_ERROR) == JSREPORT_ERROR ? YES : NO;
}
- (BOOL)isJSWarning {
  return (self->flags & JSREPORT_WARNING) == JSREPORT_WARNING ? YES : NO;
}
- (BOOL)isJSException {
  return (self->flags & JSREPORT_EXCEPTION) == JSREPORT_EXCEPTION ? YES : NO;
}
- (BOOL)isJSStrictViolation {
  return (self->flags & JSREPORT_STRICT) == JSREPORT_STRICT ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms = [NSMutableString stringWithCapacity:64];
  id tmp;
  
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  if (self->cx)
    [ms appendFormat:@" cx=0x%p", self->cx];
  else
    [ms appendString:@" no-cx"];
  
  if ([self isJSError])     [ms appendString:@" error"];
  if ([self isJSWarning])   [ms appendString:@" warning"];
  if ([self isJSException]) [ms appendString:@" exception"];
  if ([self isJSStrictViolation]) [ms appendString:@" strict"];
  
  [ms appendFormat:@" code=%i", [self errorNumber]];
  
  if ((tmp = [self path]))
    [ms appendFormat:@" path=%@:%i", tmp, [self line]];
  if ((tmp = [self reason]))
    [ms appendFormat:@" reason=%@", tmp];
  if ((tmp = [self sourceLine]))
    [ms appendFormat:@" source=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGJavaScriptError */
