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

#ifndef __NGJavaScript_NGJavaScriptError_H__
#define __NGJavaScript_NGJavaScriptError_H__

#import <Foundation/NSException.h>

@class NSString;
@class NGJavaScriptContext;

@interface NGJavaScriptError : NSException
{
  NGJavaScriptContext *cx;
  unsigned int flags;
}

- (id)initWithErrorReport:(void *)_report
  message:(NSString *)_msg 
  context:(NGJavaScriptContext *)_ctx;
  
/* accessors */

- (NSString *)path;
- (int)line;
- (NSString *)message;
- (int)errorNumber;

/* JS error flags */

- (BOOL)isJSError;
- (BOOL)isJSWarning;
- (BOOL)isJSException;
- (BOOL)isJSStrictViolation;

@end

#endif /* __NGJavaScript_NGJavaScriptError_H__ */
