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
// $Id: NGScriptLanguage.h 6 2004-08-20 17:57:50Z helge $

#ifndef __NGScriptLanguage_H__
#define __NGScriptLanguage_H__

#import <Foundation/NSObject.h>

@class NGObjectMappingContext;

@interface NGScriptLanguage : NSObject < NSCoding >

+ (id)languageWithName:(NSString *)_language;
- (id)initWithLanguage:(NSString *)_language;

/* evaluation */

- (id)evaluateScript:(NSString *)_script onObject:(id)_object
  source:(NSString *)_source line:(unsigned)_line;

/* function calls */

- (id)callFunction:(NSString *)_func onObject:(id)_object;
- (id)callFunction:(NSString *)_func withArgument:(id)_arg0 onObject:(id)_o; 
- (id)callFunction:(NSString *)_func
  withArgument:(id)_arg0
  withArgument:(id)_arg1
  onObject:(id)_object;

/* reflection */

- (BOOL)object:(id)_object hasFunctionNamed:(NSString *)_name;

/* shadow objects */

- (id)createShadowForMaster:(id)_master; /* returns a retained object */

/* object mapping */

- (NGObjectMappingContext *)activeMappingContext;
- (NGObjectMappingContext *)createMappingContext; // result is retained!

@end

/*
  Shadow objects are always tied to a specific language ...
*/

@protocol NGScriptShadow

- (void)invalidateShadow;

- (id)evaluateScript:(NSString *)_script;
- (id)callScriptFunction:(NSString *)_func;
- (BOOL)hasFunctionNamed:(NSString *)_func;

@end

#endif /* __NGScriptLanguage_H__ */
