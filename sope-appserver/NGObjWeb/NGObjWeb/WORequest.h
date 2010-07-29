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

#ifndef __NGObjWeb_WORequest_H__
#define __NGObjWeb_WORequest_H__

#import <Foundation/NSString.h>
#include <NGObjWeb/WOMessage.h>
#include <NGObjWeb/NGObjWebDecls.h>

@class NSString, NSArray, NSData, NSDictionary, NSCalendarDate;
@class NGHashMap;
@class NGHttpRequest;

NGObjWeb_EXPORT NSString *WORequestValueData;
NGObjWeb_EXPORT NSString *WORequestValueInstance;
NGObjWeb_EXPORT NSString *WORequestValuePageName;
NGObjWeb_EXPORT NSString *WORequestValueContextID;
NGObjWeb_EXPORT NSString *WORequestValueSenderID;
NGObjWeb_EXPORT NSString *WORequestValueSessionID;
NGObjWeb_EXPORT NSString *WORequestValueFragmentID;
NGObjWeb_EXPORT NSString *WONoSelectionString;

@interface WORequest : WOMessage
{
@private
  NGHttpRequest *request;     // NGHttp Request
  id            formContent;  // FORM data (message content or URL paras)
  
@private
  NSString      *method;
  NSString      *_uri; // TBD: why is this underscored?
  
@protected
  NSString     *adaptorPrefix;
  NSString     *appName;
  NSString     *requestHandlerKey;
  NSString     *requestHandlerPath;

@protected
  NSCalendarDate *startDate;
  id             startStatistics;
}

- (id)initWithMethod:(NSString *)_method
  uri:(NSString *)_uri
  httpVersion:(NSString *)_version
  headers:(NSDictionary *)_headers
  content:(NSData *)_body
  userInfo:(NSDictionary *)_userInfo;

/* WO accessors */

- (BOOL)isFromClientComponent;

- (NSString *)applicationName;
- (NSString *)adaptorPrefix;

/* HTTP accessors */

- (NSString *)method;
- (NSString *)uri;
- (BOOL)isProxyRequest; /* check whether uri is a full URL */

/* forms */

- (NSStringEncoding)formValueEncoding;
- (void)setDefaultFormValueEncoding:(NSStringEncoding)_enc;
- (NSStringEncoding)defaultFormValueEncoding;
- (void)setFormValueEncodingDetectionEnabled:(BOOL)_flag;
- (BOOL)isFormValueEncodingDetectionEnabled;

- (NSArray *)formValueKeys;
- (NSString *)formValueForKey:(NSString *)_key;
- (NSArray *)formValuesForKey:(NSString *)_key;
- (NSDictionary *)formValues;

/* HTTP header */

- (NSArray *)browserLanguages; // new in WO4

/* request handler */

- (NSString *)requestHandlerKey;       // new in WO4
- (NSString *)requestHandlerPath;      // new in WO4
- (NSArray *)requestHandlerPathArray;  // new in WO4

/* cookie support (new in WO4) */

- (NSArray *)cookieValuesForKey:(NSString *)_key;
- (NSString *)cookieValueForKey:(NSString *)_key;
- (NSDictionary *)cookieValues;

/* SOPE extensions */

- (NSString *)fragmentID;
- (BOOL)isFragmentIDInRequest;

@end

#if COMPILING_NGOBJWEB

@interface WORequest(PrivateMethods)

- (NGHttpRequest *)httpRequest;

/* accessors */

- (NGHashMap *)formParameters;

@end

#endif

@interface WORequest(DeprecatedMethodsInWO4)

- (NSString *)applicationHost; // use NSProcessInfo and/or NSTask
- (NSString *)sessionID;       // [[context session] sessionID]
- (NSString *)senderID;        // replaced by WOContext:-senderID
- (NSString *)contextID;       // use WOContext:-contextID

@end

#endif /* __NGObjWeb_WORequest_H__ */
