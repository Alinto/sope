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

#include "WOScriptAssociation.h"
#include <NGObjWeb/WOComponent.h>
#import "common.h"

@interface NSObject(Scripting)

- (id)evaluateScript:(NSString *)_script language:(NSString *)_language;

@end

@implementation WOScriptAssociation

static BOOL doDebug = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}
+ (NSString *)defaultScriptLanguage {
  return @"javascript";
}

- (id)initWithScript:(NSString *)_script language:(NSString *)_language {
  if ([_language length] == 0)
    _language = [WOScriptAssociation defaultScriptLanguage];
  
  if ([_script length] == 0) {
    if (doDebug) {
      NSLog(@"WARNING(%s): got passed an empty script ...",
	    __PRETTY_FUNCTION__);
    }
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    /* should compile script if possible !!! */
    self->script   = [_script   copy];
    self->language = [_language copy];
  }
  return self;
}
- (id)init {
  return [self initWithScript:nil language:nil];
}
- (id)initWithString:(NSString *)_s {
  if ([_s length] == 0) {
    if (doDebug) {
      NSLog(@"WARNING(%s): got passed an empty script ...", 
	    __PRETTY_FUNCTION__);
    }
    [self release];
    return nil;
  }
  return [self initWithScript:_s language:nil];
}

- (void)dealloc {
  [self->script   release];
  [self->language release];
  [super dealloc];
}

/* accessors */

- (NSString *)script {
  return self->script;
}
- (NSString *)language {
  return self->language;
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  // not settable
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}
- (id)valueInComponent:(WOComponent *)_component {
  return [_component evaluateScript:self->script language:self->language];
}

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return NO;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* script associations are immutable and don't need to be copied */
  return [self retain];
}

- (NSString *)description {
  NSMutableString *str;
  NSString *v;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%@[0x%p]: script(%@)=",
         NSStringFromClass([self class]), self, [self language]];
  
  v = self->script;
  if ([v length] > 10) {
      v = [v substringToIndex:9];
      v = [v stringByApplyingCEscaping];
      [str appendString:v];
      [str appendFormat:@"...[len=%i]", [self->script length]];
  }
  else {
      v = [v stringByApplyingCEscaping];
      [str appendString:v];
  }
  
  [str appendString:@">"];
  return str;
}

@end /* WOScriptAssociation */

#if 0
@interface WOAssociation(Blah)
- (id)initWithValue:(id)_value;
@end

@implementation WOAssociation(Overload)

+ (WOAssociation *)associationWithValue:(id)_value {
  WOAssociation *a;
  
  if ([_value isKindOfClass:[NSString class]]) {
    if ([(NSString *)_value hasPrefix:@"JS:"]) {
      _value = [_value substringFromIndex:3];
      a = [[WOScriptAssociation alloc] initWithJavaScript:_value];
      return [a autorelease];
    }
  }
  
  return [[[NSClassFromString(@"WOValueAssociation")
			     alloc] initWithValue:_value] autorelease];
}

@end /* WOAssociation(Overload) */
#endif /* 0 */
