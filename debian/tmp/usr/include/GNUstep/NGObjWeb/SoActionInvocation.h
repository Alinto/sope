/*
  Copyright (C) 2002-2009 SKYRIX Software AG

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

#ifndef __SoObjects_SoActionInvocation_H__
#define __SoObjects_SoActionInvocation_H__

#import <Foundation/NSObject.h>

/*
  SoActionInvocation

  An invocation object for WODirectAction based SoClass methods.
  
  If the invocation is bound, the action is instantiated and initialized,
  if it is called, the "actionName" is called and the result is returned or
  if no "actionName" is set, the default action is called.
  
  Usage:
    methods = {
      view = {
        protectedBy = "View";
        actionClass = "DirectAction"; // class to be instantiated
        actionName  = "view";         // 'viewAction' will get called
      };
      ...
    }
  
  Positional Arguments

    When being queried using some method which supplies positional arguments
    (for example XML-RPC), you can assign keys to each position using the
    'positionalKeys' argument info.
    
    If more arguments are passed in than the number of keys specified in the
    argument info, the additional arguments will be ignore (a warning will get
    printed).
    
    If less arguments are passed in, the additional keys will be resetted to
    'nil' (-takeValue:nil forKey:key will get called) to ensure that the call
    signature is deterministic.
    
    methods = {
      "blogger.getUsersBlogs" = {
        protectedBy = "View";
        actionClass = BloggerGetUserBlogs;
        arguments = {
          positionalKeys = ( appId, login, password );
        };
      };
      ...
    }

  SOAP Arguments

    When being queried using SOAP, you can extract keys from the SOAP message
    using EDOM query pathes. The values are assigned to the specified keys of
    the action/page object.
    
    methods = {
      "cms.login" = {
         actionClass = CMSLoginAction;
         arguments   = {
           SOAP = { // key is from context.soRequestType
             login    = "/envelope/loginRequest/login";
             password = "/envelope/loginRequest/password";
           };
         }
      };
    }
*/

@class NSString, NSArray, NSDictionary, NSMutableString;

@interface SoActionInvocation : NSObject
{
  NSString     *actionClassName;
  NSString     *actionName;
  
  /* for bound invocations */
  id           methodObject;
  id           object;
  
  NSDictionary *argumentSpecifications;
}

- (id)initWithActionClassName:(NSString *)_cn;
- (id)initWithActionClassName:(NSString *)_cn actionName:(NSString *)_action;

/* accessors */

- (NSString *)actionClassName;
- (NSString *)actionName;

- (void)setArgumentSpecifications:(NSDictionary *)_specs;
- (NSDictionary *)argumentSpecifications;

/* bindings */

- (BOOL)isBound;
- (id)bindToObject:(id)_object inContext:(id)_ctx;

/* calling the method */

- (id)callOnObject:(id)_client inContext:(id)_ctx;
- (id)callOnObject:(id)_client 
  withPositionalParameters:(NSArray *)_args
  inContext:(id)_ctx;

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms;

@end

#endif /* __SoObjects_SoActionInvocation_H__ */
