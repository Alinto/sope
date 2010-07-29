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

#ifndef __NGJavaScriptContext_H__
#define __NGJavaScriptContext_H__

#import <Foundation/NSObject.h>

@class NSString, NSException;
@class NGJavaScriptRuntime;

@interface NGJavaScriptContext : NSObject
{
  NGJavaScriptRuntime *rt;
  void                *handle;

  NSException *lastError;
}

+ (NGJavaScriptContext *)jsContextForHandle:(void *)_handle;

- (id)initWithRuntime:(NGJavaScriptRuntime *)_rt
  maximumStackSize:(unsigned)_size;
- (id)initWithRuntime:(NGJavaScriptRuntime *)_rt;
- (id)init;

- (BOOL)loadStandardClasses;

/* private */

- (void *)handle;

/* accessors */

- (NGJavaScriptRuntime *)runtime;

- (BOOL)isRunning;
- (BOOL)isConstructing;

- (void)setJavaScriptVersion:(int)_version;
- (int)javaScriptVersion;

/* evaluation */

- (id)evaluateScript:(NSString *)_script;

/* invocation */

- (id)callFunctionNamed:(NSString *)_funcName, ...;

/* errors */

- (void)reportException:(NSException *)_exc;
- (void)reportError:(NSString *)_fmt, ...;
- (void)reportOutOfMemory;

- (void)reportError:(NSString *)_msg
  inFile:(NSString *)_path inLine:(unsigned)_line
  report:(void *)_report;
- (NSException *)lastError;
- (void)clearLastError;

/* garbage collector */

- (void)collectGarbage;
- (void)maybeCollectGarbage;

- (void *)malloc:(unsigned)_size;
- (void *)realloc:(void *)_pointer size:(unsigned)_size;
- (void)freePointer:(void *)_pointer;

- (BOOL)addRootPointer:(void *)_root;
- (BOOL)addRootPointer:(void *)_root name:(NSString *)_name;
- (BOOL)removeRootPointer:(void *)_root;

- (BOOL)lockGCThing:(void *)_ptr;
- (BOOL)unlockGCThing:(void *)_ptr;

- (BOOL)beginGarbageCollection;
- (BOOL)endGarbageCollection;

/* threads */

- (void)beginRequest;
- (void)endRequest;
- (void)suspendRequest;
- (void)resumeRequest;

@end

#endif /* __NGJavaScriptContext_H__ */
