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

#ifndef __NGHttp_NGHttpCookie_H__
#define __NGHttp_NGHttpCookie_H__

#import <Foundation/NSObject.h>

@class NSString, NSDate;

/*
  Cookie values. Occures in 'Cookie' and 'Set-Cookie' header fields. Examples:

    'Set-Cookie: CUSTOMER=WILE_E_COYOTE; path=/'
    'Cookie: CUSTOMER=WILE_E_COYOTE'
*/
@interface NGHttpCookie : NSObject
{
@protected
  NSString *name;
  id       value;        // the value of the cookie, should respond to -stringValue
  NSDate   *expireDate;  // defines how long the cookies is valid
  NSString *path;        // the root-path where the cookie is valid
  NSString *domainName;  // the domain where the cookie is valid (default: hostname)
  BOOL     onlyIfSecure; // send only if communication-channel is secure (SSL)
}

+ (id)cookieWithName:(NSString *)_name;
- (id)initWithName:(NSString *)_name value:(id)_value;

// accessors

- (void)setCookieName:(NSString *)_name;
- (NSString *)cookieName;

- (void)setValue:(id)_value;
- (id)value;
- (void)addAdditionalValue:(id)_value; // use with care !

- (void)setExpireDate:(NSDate *)_date;
- (NSDate *)expireDate;
- (BOOL)doesExpireWhenUserSessionEnds;

- (void)setPath:(NSString *)_path;
- (NSString *)path;
- (void)setDomainName:(NSString *)_domainName;
- (NSString *)domainName;
- (void)setNeedsSecureChannel:(BOOL)_flag;
- (BOOL)needsSecureChannel;

// description

- (NSString *)stringValue;

@end

#endif /* __NGHttp_NGHttpCookie_H__ */
