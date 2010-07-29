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
// $Id: NSObject+Scripting.m 6 2004-08-20 17:57:50Z helge $

#include "NGScriptLanguage.h"
#include "common.h"
#import <EOControl/EOControl.h>

@implementation NSObject(ScriptingSupport)

/* evaluation */

+ (NSString *)defaultScriptLanguage {
  return @"javascript";
}

- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang 
  source:(NSString *)_src line:(unsigned)_line 
{
  NGScriptLanguage *l;
  
  if ((l = [NGScriptLanguage languageWithName:_lang]) == nil) {
    NSLog(@"%s: cannot evaluate script, language '%@' unknown",
	  __PRETTY_FUNCTION__, _lang);
    return nil;
  }
  return [l evaluateScript:_script onObject:self source:_src line:_line];
}
- (id)evaluateScript:(NSString *)_script language:(NSString *)_lang {
  return [self evaluateScript:_script language:_lang
	       source:@"<string>" line:0];
}

/* JavaScript functions */

- (id)callScriptFunction:(NSString *)_func language:(NSString *)_lang {
  NGScriptLanguage *l;
  
  if ((l = [NGScriptLanguage languageWithName:_lang]) == nil) {
    NSLog(@"%s: cannot evaluate script, language '%@' unknown",
	  __PRETTY_FUNCTION__, _lang);
    return nil;
  }
  return [l callFunction:_func onObject:self];
}
- (id)callScriptFunction:(NSString *)_func language:(NSString *)_lang
  withObject:(id)_arg0
{
  NGScriptLanguage *l;
  
  if ((l = [NGScriptLanguage languageWithName:_lang]) == nil) {
    NSLog(@"%s: cannot evaluate script, language '%@' unknown",
	  __PRETTY_FUNCTION__, _lang);
    return nil;
  }
  return [l callFunction:_func withArgument:_arg0 onObject:self];
}
- (id)callScriptFunction:(NSString *)_func language:(NSString *)_lang
  withObject:(id)_arg0
  withObject:(id)_arg1
{
  NGScriptLanguage *l;
  
  if ((l = [NGScriptLanguage languageWithName:_lang]) == nil) {
    NSLog(@"%s: cannot evaluate script, language '%@' unknown",
	  __PRETTY_FUNCTION__, _lang);
    return nil;
  }
  return [l callFunction:_func
	    withArgument:_arg0
	    withArgument:_arg1 
	    onObject:self];
}

@end /* NSObject(JSSupport) */
