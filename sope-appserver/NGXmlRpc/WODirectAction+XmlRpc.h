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

#ifndef __WODirectAction_XMLRPC_H__
#define __WODirectAction_XMLRPC_H__

#import <NGObjWeb/WODirectAction.h>
@class NSString, NSArray;

@interface WODirectAction(XmlRpc)
- (NSString *)xmlrpcComponentNamespacePrefix;
- (NSString *)xmlrpcComponentName;
- (NSString *)xmlrpcComponentNamespace;
@end /* WODirectAction(XmlRpc) */

@interface WODirectAction(XmlRpcValues)

/* mapping XML-RPC actions to selectors */

- (NSString *)selectorForXmlRpcAction:(NSString *)_name;
- (NSString *)selectorForXmlRpcAction:(NSString *)_name
  parameters:(NSArray *)_params;

/* dispatcher */

- (id)performActionNamed:(NSString *)_actionName parameters:(NSArray *)_params;

/* direct action */

- (id<WOActionResults>)RPC2Action;

@end

@interface WODirectAction(XmlRpcInfo)

/*
  use reflection to show an "WebService" info page ...
*/
- (id<WOActionResults>)RPC2InfoPageAction;

@end

#endif /* __WODirectAction_XMLRPC_H__ */
