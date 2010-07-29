/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __SoObjects_SoSelectorInvocation_H__
#define __SoObjects_SoSelectorInvocation_H__

#import <Foundation/NSObject.h>

/*
  An invocation object for Objective-C selector based SoClass methods. Multiple
  selectors can map to a single SoClass method because those methods have a
  name independend from the arguments.
*/

@class NSString, NSDictionary;

@interface SoSelectorInvocation : NSObject
{
  SEL sel;
  int argCount;
  struct {
    int addContextParameter:1;
    int reserved:31;
  } flags;
  /* for bound invocations */
  IMP method;
  id  object;
  
  NSDictionary *argumentSpecifications;
}

- (id)initWithSelectorNamed:(NSString *)_sel addContextParameter:(BOOL)_f;

/* configuration */

- (void)addSelectorNamed:(NSString *)_name;

- (void)setDoesAddContextParameter:(BOOL)_flag;
- (BOOL)doesAddContextParameter;

- (void)setArgumentSpecifications:(NSDictionary *)_specs;
- (NSDictionary *)argumentSpecifications;

/* binding */

- (BOOL)isBound;
- (id)bindToObject:(id)_object inContext:(id)_ctx;

@end

#endif /* __SoObjects_SoSelectorInvocation_H__ */
