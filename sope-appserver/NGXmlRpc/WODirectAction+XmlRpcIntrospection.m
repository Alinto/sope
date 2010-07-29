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

#include "WODirectAction+XmlRpcIntrospection.h"
#include "WODirectAction+XmlRpc.h"
#include "NSObject+Reflection.h"
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WORequest.h>
#include "common.h"

@interface NSMethodSignature(XmlRpcSignature)

- (NSArray *)xmlRpcSignature;

@end

@implementation NSMethodSignature(XmlRpcSignature)

- (NSString *)xmlRpcTypeForObjCType:(const char *)_type {
  if (_type == NULL) return nil;
#if GNU_RUNTIME
  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      return @"string";

    case _C_SEL:
    case _C_CHARPTR:
      return @"string";
      
    case _C_CHR:
    case _C_UCHR:
      return @"boolean";
      
    case _C_INT:
    case _C_UINT:
    case _C_SHT:
    case _C_USHT:
    case _C_LNG:
    case _C_ULNG:
      return @"i4";

    case _C_ARY_B:
      return @"array";
    case _C_STRUCT_B:
      return @"struct";
      
    case _C_FLT:
    case _C_DBL:
      return @"double";
  }
#endif
  return @"string";
}

- (NSArray *)xmlRpcSignature {
  NSMutableArray *signature;
  unsigned i;

  signature = [NSMutableArray arrayWithCapacity:8];

  /* return value */
  [signature addObject:[self xmlRpcTypeForObjCType:[self methodReturnType]]];
  
  /* arguments */
  for (i = 2; i < [self numberOfArguments]; i++) {
    const char *t;
    
    t = [self getArgumentTypeAtIndex:i];
    [signature addObject:[self xmlRpcTypeForObjCType:t]];
  }
  
  return signature;
}

@end /* NSMethodSignature(XmlRpcSignature) */

@implementation WODirectAction(XmlRpcIntrospection)

static NSArray *blacklist = nil;

- (NSArray *)system_listMethodsAction {
  NSMutableArray *ma;
  NSEnumerator   *sels;
  NSString       *sel;
  NSString       *namespace;
  NSArray        *selectors;

  namespace = [self xmlrpcComponentNamespace];

  if (blacklist == nil) {  
    blacklist = [[NSArray alloc] initWithObjects:@"RPC2Action",
                                 @"RPC2InfoPageAction",
                                 @"xmlrpcAction",
                                 @"commitFailedAction",
                                 @"WOStatsAction",
                                 @"defaultAction",
                                 @"missingAuthAction",
                                 @"selectorForXmlRpcAction:",
                                 @"accessDeniedAction",nil];
  }

  selectors = [self respondsToSelectors];
  sels = [selectors objectEnumerator];

  ma = [NSMutableArray arrayWithCapacity:[selectors count]];

  while ((sel = [sels nextObject])) {
    unsigned idx, len;
    NSString *actionName;
    NSRange rng;

    if ([blacklist containsObject:sel])
      continue;

    rng = [sel rangeOfString:@"Action"];
    if (rng.length <= 0) continue;
    
    /* strip Action */
    actionName = [sel substringToIndex:rng.location];

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
    
    /* make action name XMLRPC-style friendly */    
    actionName = [actionName stringByReplacingString:@"_" withString:@"."];

    if (namespace == nil)
      [ma addObject:actionName];
    else {
      /* add to reflection set */
      if ([actionName hasPrefix:@"system."])
        [ma addObject:actionName];
      else {
        NSString *s;
        
        s = [[NSString alloc] initWithFormat:@"%@.%@", namespace,actionName];
        [ma addObject:s];
        [s release];
      }
    }
  }

  return [[[ma copy] autorelease] sortedArrayUsingSelector:
                     @selector(caseInsensitiveCompare:)];
}

- (NSArray *)system_methodSignatureAction:(NSString *)_xmlrpcMethod {
  /*
    It returns an array of possible signatures for this method. A signature
    is an array of types. The first of these types is the return type of the
    method, the rest are parameters.

    Multiple signatures (ie. overloading) are permitted: this is the reason
    that an array of signatures are returned by this method.

    Signatures themselves are restricted to the top level parameters expected
    by a method. For instance if a method expects one array of structs as a
    parameter, and it returns a string, its signature is simply
    "string, array". If it expects three integers, its signature is
    "string, int, int, int".

    If no signature is defined for the method, a none-array value is returned.
  */
  NSMutableArray *signatures;
  NSString       *actionName;
  NSEnumerator   *sels;
  NSString       *sel;
  unsigned len;
  Class clazz;

  clazz      = [self class];
  signatures = [NSMutableArray arrayWithCapacity:4];
  actionName = [self selectorForXmlRpcAction:_xmlrpcMethod];
  
  len = [actionName length];
  
  sels = [[self respondsToSelectors] objectEnumerator];
  while ((sel = [sels nextObject])) {
    NSArray *signature;
    NSMethodSignature *ms;
    
    if (![sel hasPrefix:actionName]) continue;
    
    ms = [self methodSignatureForSelector:NSSelectorFromString(sel)];
    if (ms) {
      signature = [ms xmlRpcSignature];
    }
    else {
      [self logWithFormat:@"missing Objective-C method signature for %@ ...",
              sel];
      signature = nil;
    }
    
    if (signature)
      [signatures addObject:signature];
  }
  
  return [signatures isNotEmpty]
    ? signatures
    : (NSMutableArray *)[NSNumber numberWithBool:NO];
}

- (NSString *)system_methodHelpAction:(NSString *)_xmlrpcMethod {
  return
    @"Note: the Objective-C runtime cannot return the correct XML-RPC type "
    @"for object parameters automatically (only for base types ...).";
}

@end /* WODirectAction(XmlRpcIntrospection) */


#include <NGObjWeb/WOResponse.h>

@implementation WODirectAction(XmlRpcInfo)

- (id<WOActionResults>)RPC2InfoPageAction {
  WOResponse *r;
  NSEnumerator *e;
  id tmp;

  r = [WOResponse alloc];
  r = [[r initWithRequest:[self request]] autorelease];
  [r setHeader:@"text/html" forKey:@"content-type"];

  [r appendContentString:@"<html><head><title>WebService at "];
  [r appendContentHTMLString:[[self request] uri]];
  [r appendContentString:@"</title></head><body bgcolor=\"#FFFFFF\">"];
  
  [r appendContentString:@"<h3>WebService at "];
  [r appendContentHTMLString:[[self request] uri]];
  [r appendContentString:@"</h3>"];
  
  [r appendContentString:@"<h4>methods</h4>"];

  [r appendContentString:@"<table border='1'>\n"];
  [r appendContentString:
     @"<tr><th>name</th><th>signature</th><th>info</th></tr>\n"];
  
  e = [[self system_listMethodsAction] objectEnumerator];
  while ((tmp = [e nextObject])) {
    NSString *mname, *info;
    id sig;

    mname = [tmp stringValue];
    [r appendContentString:@"<tr>"];
    
    [r appendContentString:@"<td>"];
    [r appendContentHTMLString:mname];
    [r appendContentString:@"</td>"];
    
    sig  = [self system_methodSignatureAction:mname];
    info = [self system_methodHelpAction:mname];

    [r appendContentString:@"<td>"];
    if ([sig isKindOfClass:[NSArray class]]) {
      [r appendContentHTMLString:[sig stringValue]];
    }
    [r appendContentString:@"</td>"];

    if ([info isNotEmpty]) {
      [r appendContentString:@"<td>"];
      [r appendContentString:info];
      [r appendContentString:@"</td>"];
    }
    
    [r appendContentString:@"</tr>\n"];
  }
  [r appendContentString:@"</table>"];
  
  [r appendContentString:@"</body></html>"];
  
  return r;
}

@end /* WODirectAction(XmlRpcInfo) */
