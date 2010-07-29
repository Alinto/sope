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

#include "NGJavaScriptFunction.h"
#include "NGJavaScriptContext.h"
#include "NGJavaScriptObject.h"
#include "NGJavaScriptObjectMappingContext.h"
#include "NSString+JS.h"
#include "common.h"

@implementation NGJavaScriptFunction

/* accessors */

- (NSString *)functionName {
  return [NSString stringWithCString:JS_GetFunctionName(self->handle)];
}

/* typing */

- (BOOL)isJavaScriptFunction {
  return YES;
}
- (BOOL)isScriptFunction {
  return YES;
}

/* compilation */

- (NSString *)decompileBodyWithIndent:(unsigned)_indent
  inContext:(NGJavaScriptContext *)_ctx
{
  JSString *s;

  s = JS_DecompileFunctionBody([_ctx handle], self->handle, _indent);
  return [NSString stringWithJavaScriptString:s];
}

- (NSString *)decompileWithIndent:(unsigned)_indent
  inContext:(NGJavaScriptContext *)_ctx
{
  JSString *s;

  s = JS_DecompileFunction([_ctx handle], self->handle, _indent);
  return [NSString stringWithJavaScriptString:s];
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)_coder {
  NSAssert(NO, @"decoding of functions not supported yet ...");
  return nil;
}
- (void)encodeWithCoder:(NSCoder *)_coder {
  NSAssert(NO, @"encoding of functions not supported yet ...");
}

@end /* NGJavaScriptFunction */

@implementation NSObject(JSFuncTyping)

- (BOOL)isJavaScriptFunction {
  return NO;
}

@end /* NSObject(JSFuncTyping) */
