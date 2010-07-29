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

#include "iCalPortalPage.h"
#include "common.h"

@interface iCalLabelDispatcher : NSObject
{
  iCalPortalPage *component;
}

- (id)initWithComponent:(iCalPortalPage *)_comp;

@end

@implementation iCalPortalPage

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [super dealloc];
}

/* accessors */

- (iCalPortalDatabase *)database {
  return [(id)[self application] database];
}

- (iCalPortalUser *)user {
  if (![self hasSession])
    return nil;
  
  return [[self session] objectForKey:@"user"];
}

/* actions */

- (BOOL)isSessionProtectedPage {
  return YES;
}

- (id<WOActionResults>)indexPage {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  WOSession *sn;
  
  if ((sn = [self existingSession])) {
    [sn removeObjectForKey:@"user"];
    [sn terminate];
  }
  
  if ([[ud objectForKey:@"DevMode"] boolValue]) {
    return [[self pageWithName:@"iCalPortalWelcomePage"] performPage];
  }
  else {
    WOResponse *r;
    
    r = [WOResponse responseWithRequest:[[self context] request]];
    
    [r setStatus:302];
    [r setHeader:@"/en/index.xhtml" forKey:@"location"];
    
    return r;
  }
}

- (id)performPage {
  id result;
  
  if ([self isSessionProtectedPage]) {
    if (![self hasSession]) {
      [self logWithFormat:
	      @"tried to access login protected page without session !"];
      return [self indexPage];
    }
  }
  
  result = [self run];
  
  return result;
}

- (id)run {
  return self;
}

/* labels */

- (id)label {
  return [[[iCalLabelDispatcher alloc] initWithComponent:self] autorelease];
}

- (NSString *)stringForKey:(NSString *)_key {
  NSString *s;
  NSArray  *langs;

  langs = [self hasSession]
    ? [[self session] languages]
    : [[[self context] request] browserLanguages];
  
  s = [[self resourceManager] 
             stringForKey:_key inTableNamed:@"main" withDefaultValue:_key
	     languages:langs];
  return s;
}

- (NSString *)localizedTitle {
  return [self stringForKey:[self name]];
}

@end /* iCalPortalPage */

@implementation iCalLabelDispatcher

- (id)initWithComponent:(iCalPortalPage *)_comp {
  self->component = _comp;
  return self;
}

- (id)valueForKey:(NSString *)_key {
  if ([_key length] == 0)
    return _key;
  
  return [self->component stringForKey:_key];
}

@end /* iCalLabelDispatcher */
