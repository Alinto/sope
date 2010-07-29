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
// $Id: NSObject+Scripting.h 6 2004-08-20 17:57:50Z helge $

#ifndef __NSObject_Scripting_H__
#define __NSObject_Scripting_H__

#import <Foundation/NSObject.h>

@interface NSObject(ScriptingSupport)

+ (NSString *)defaultScriptLanguage;

/* evaluation with 'self' as JS 'this' */

- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang 
  source:(NSString *)_src line:(unsigned)_line;
- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang;

/* script functions */

- (id)callScriptFunction:(NSString *)_func language:(NSString *)_language;
- (id)callScriptFunction:(NSString *)_func language:(NSString *)_language
  withObject:(id)_arg0;
- (id)callScriptFunction:(NSString *)_func language:(NSString *)_language
  withObject:(id)_arg0
  withObject:(id)_arg1;

@end

#endif /* __NSObject_Scripting_H__ */
