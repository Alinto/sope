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

#ifndef __NGJavaScriptFunction_H__
#define __NGJavaScriptFunction_H__

#include <NGJavaScript/NGJavaScriptObject.h>

@class NGJavaScriptContext;

@interface NGJavaScriptFunction : NGJavaScriptObject
{
  void *function;
  id   mapCtx; /* non-retained */
}

#if 0
- (id)initWithHandle:(void *)_handle mappingContext:(id)_mapCtx;

/* private */

- (void *)handle;
#endif

/* accessors */

- (NSString *)functionName;

/* typing */

- (BOOL)isJavaScriptFunction;

/* compilation */

- (NSString *)decompileBodyWithIndent:(unsigned)_indent
  inContext:(NGJavaScriptContext *)_ctx;
- (NSString *)decompileWithIndent:(unsigned)_indent
  inContext:(NGJavaScriptContext *)_ctx;

@end

@interface NSObject(JSFuncTyping)
- (BOOL)isJavaScriptFunction;
@end

#endif /* __NGJavaScriptFunction_H__ */
