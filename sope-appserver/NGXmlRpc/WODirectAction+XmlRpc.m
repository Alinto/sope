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

#include "WODirectAction+XmlRpc.h"
#include <NGXmlRpc/NSObject+Reflection.h>
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation WODirectAction(XmlRpc)

static int CoreOnException = -1;

- (NSString *)xmlrpcComponentNamespacePrefix {
  // TODO: should be deprecated
  NSUserDefaults *ud;
  NSString *np;
  
  ud = [NSUserDefaults standardUserDefaults];
  np = [ud stringForKey:@"SxDefaultNamespacePrefix"];
  if ([np isNotEmpty])
    return np;

  [self logWithFormat:
          @"WARNING: SxDefaultNamespacePrefix default is not set !"];
  
  np = [(NSHost *)[NSHost currentHost] name];
  if ([np isNotEmpty]) {
    if (!isdigit([np characterAtIndex:0])) {
      NSArray *parts;

      parts = [np componentsSeparatedByString:@"."];
      if (![parts isNotEmpty]) {
      }
      else if ([parts count] == 1)
        return [parts objectAtIndex:0];
      else {
        NSEnumerator *e;
        BOOL     isFirst = YES;
        NSString *s;
        
        e = [parts reverseObjectEnumerator];
        while ((s = [e nextObject])) {
          if (isFirst) {
            isFirst = NO;
            np = s;
          }
          else {
            np = [[np stringByAppendingString:@"."] stringByAppendingString:s];
          }
        }
        return np;
      }
    }
  }
  
  return @"com.skyrix";
}
- (NSString *)xmlrpcComponentName {
  // TODO: should be deprecated
  NSString *s;

  s = NSStringFromClass([self class]);
  if (![s isEqualToString:@"DirectAction"])
    return s;
  
  return [[NSProcessInfo processInfo] processName];
}

- (NSString *)xmlrpcComponentNamespace {
  // TODO: should be deprecated
  NSString *ns, *n;
  
  ns = [self xmlrpcComponentNamespacePrefix];
  n  = [self xmlrpcComponentName];
  return [[ns stringByAppendingString:@"."] stringByAppendingString:n];
}

- (NSArray *)_methodActionNames {
  NSMutableArray *ma;
  NSEnumerator   *sels;
  NSString       *sel;

  sels = [[self respondsToSelectors] objectEnumerator];

  ma = [NSMutableArray arrayWithCapacity:16];
  while ((sel = [sels nextObject])) {
    unsigned idx, len;
    NSString *actionName;
    NSRange rng;
    
    rng = [sel rangeOfString:@"Action"];
    if (rng.length <= 0) continue;
    
    actionName = sel;
    
    /* ensure that only dots are following the 'Action' */
    for (idx = (rng.location + rng.length), len = [sel length]; 
         idx < len; idx++) {
      unichar c = [sel characterAtIndex:idx];
      if (c != ':') {
        actionName = nil;
        break;
      }
    }
    
    /* go to next selector if ... */
    if (![actionName isNotEmpty]) continue;
    
    /* add to reflection set */
    [ma addObject:actionName];
  }
  return [[ma copy] autorelease];
}

- (NSString *)selectorForXmlRpcAction:(NSString *)_name {
  NSString *actionName;
  NSString *p;

  actionName = @"Action";

  /* check component namespace and strip it ;-) */
  
  p = [self xmlrpcComponentNamespace];
  
  if ([p isNotEmpty]) {
    if ([_name hasPrefix:@"system."])
      ;
    else if ([_name hasPrefix:p]) {
      _name = [_name substringFromIndex:[p length]];
      if ([_name isNotEmpty]) {
        if ([_name characterAtIndex:0] == '.')
          _name = [_name substringFromIndex:1];
      }
    }
    else {
      [self logWithFormat:
            @"WARNING: tried to invoke XML-RPC method from "
            @"different component (namespace=%@): %@",
            p, _name];
    }
  }
  
  /* replace namespace points by '_' */
  
  _name      = [_name stringByReplacingString:@"." withString:@"_"];
  actionName = [_name stringByAppendingString:actionName];
  
  /* finished */
  return actionName;
}

- (NSString *)selectorForXmlRpcAction:(NSString *)_name
  parameters:(NSArray *)_params
{
  NSString *actionName;
  int i, cnt;
  
  actionName = [self selectorForXmlRpcAction:_name];
  
  /* append ':' for each parameter */

  switch ((cnt = [_params count])) {
    case 0:
      break;
    case 1:
      actionName = [actionName stringByAppendingString:@":"];
      break;
    case 2:
      actionName = [actionName stringByAppendingString:@"::"];
      break;
    case 3:
      actionName = [actionName stringByAppendingString:@":::"];
      break;
    case 4:
      actionName = [actionName stringByAppendingString:@"::::"];
      break;
      
    default:
      for (i = 0, cnt = [_params count]; i < cnt; i++)
        actionName = [actionName stringByAppendingString:@":"];
      break;
  }
  
  /* finished */
  return actionName;
}

- (id)performActionNamed:(NSString *)_name parameters:(NSArray *)_params {
  NSMethodSignature *sign;
  NSInvocation      *invo;
  NSString          *actionName;
  id   result = nil;
  SEL  sel;
  int  i, cnt = 0;
  
  /* generate selector */
  actionName = [self selectorForXmlRpcAction:_name parameters:_params];
  sel = NSSelectorFromString(actionName);
  
  if (![self respondsToSelector:sel]) {
    NSEnumerator *actEnum;
    NSString     *name    = nil;
    NSString     *act     = nil;
    
    actEnum    = [[self _methodActionNames] objectEnumerator];
    name       = [actionName stringByReplacingString:@":" withString:@""];
    actionName = nil;
    while ((act = [actEnum nextObject])) {
      NSString *tmp = [act stringByReplacingString:@":" withString:@""];
      
      if ([tmp isEqualToString:name]) actionName = act;
    }
    sel = NSSelectorFromString(actionName);
    
    if (sel == NULL) {
      /* Note: NULL selectors are not caught by MacOSX -respondsToSel: ! */
      [self logWithFormat:@"no such XMLRPC action: '%@'", _name];
      return [NSException exceptionWithName:@"NoSuchAction"
                          reason:@"action not implemented"
                          userInfo:nil];
    }
    else if (![self respondsToSelector:sel]) {
      [self logWithFormat:@"no such XMLRPC action: '%@' (selector=%@)",
              _name, NSStringFromSelector(sel)];
      
      return [NSException exceptionWithName:@"NoSuchAction"
                          reason:@"action not implemented"
                          userInfo:nil];
    }
    else {
      // count the ':'
      cnt = [[actionName componentsSeparatedByString:@":"] count] - 1;
    }
  }
  sign = [[self class] instanceMethodSignatureForSelector:sel];
  invo = [NSInvocation invocationWithMethodSignature:sign];
  [invo setSelector:sel];
  if (cnt == 0) cnt = ([sign numberOfArguments] - 2);
  
  [invo setTarget:self];
  
  cnt = (cnt > (int)[_params count]) ? (int)[_params count] : cnt;
  
  for (i = 0; i < cnt; i++) {
    id param;
    
    param = [_params objectAtIndex:i];
    [invo setArgument:&param atIndex:(i + 2)];
  }
  // TODO(hh): should fill the remaining args when less params available ?
  
  [invo invoke];
  [invo getReturnValue:&result];
  
  return result;
}

- (id)_faultForException:(NSException *)_exception {
  if (CoreOnException == -1) {
    // TODO: add default
    CoreOnException =   
      [[NSUserDefaults standardUserDefaults] 
	               boolForKey:@"WOCoreOnXmlRpcFault"] ? 1 : 0;
  }
  
  if (CoreOnException) {
    [self logWithFormat:@"core on exception: %@", _exception];
    abort();
    return nil;
  }
  else {
    [self logWithFormat:@"turn exception into fault: %@", _exception];
    return _exception;
  }
}

- (id<WOActionResults>)RPC2Action {
  XmlRpcMethodCall     *call;
  XmlRpcMethodResponse *mResponse;
  id                   result;
  
  if (![[[self request] method] isEqualToString:@"POST"]) {
    /* only POST is allowed for direct XML-RPC requests ! */
    
    if ([[[self request] method] isEqualToString:@"GET"])
      return [self RPC2InfoPageAction];
    
    return nil;
  }

  call = [XmlRpcMethodCall alloc];
  call = [[call initWithRequest:[self request]] autorelease];
  
  if (call == nil) {
    WORequest *rq;
    NSData    *content;
    
    rq      = [self request];
    content = [rq content];
    
    [self logWithFormat:@"couldn't decode XMLRPC content:\n"];
    [self logWithFormat:@"  content-len: %d", [content length]];
    [self logWithFormat:@"  encoding:    %d", [rq contentEncoding]];
    return nil;
  }
  
  [self debugWithFormat:@"decoded XMLRPC call: %@", call];
  
  NS_DURING {
    result = [[self performActionNamed:[call methodName]
                    parameters:[call parameters]]
                    retain];
  }
  NS_HANDLER
    result = [[self _faultForException:localException] retain];
  NS_ENDHANDLER;
  
  mResponse =
    [[[XmlRpcMethodResponse alloc] initWithResult:result] autorelease];
  
  [result release]; result = nil;
  
  return [mResponse generateResponse];
}
- (id<WOActionResults>)xmlrpcAction {
  [self debugWithFormat:@"deprecated, please use /RPC2 as direct action !"];
  return [self RPC2Action];
}

@end /* WODirectAction(XmlRpc) */
