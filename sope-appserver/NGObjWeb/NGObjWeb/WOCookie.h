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

#ifndef __NGObjWeb_WOCookie_H__
#define __NGObjWeb_WOCookie_H__

#import <Foundation/NSObject.h>

@class NSString, NSDate;

@interface WOCookie : NSObject < NSCopying >
{
@protected
  NSString *name;
  NSString *value;

  // cookie configuration
  NSDate   *expireDate;  // defines how long the cookies is valid
  NSString *path;        // the root-path where the cookie is valid
  NSString *domainName;  // the domain where the cookie is valid (def: hostname)
  BOOL     onlyIfSecure; // send only if communication-channel is secure (SSL)
}

+ (id)cookieWithName:(NSString *)_name value:(NSString *)_value;

+ (id)cookieWithName:(NSString *)_name value:(NSString *)_value
  path:(NSString *)_path domain:(NSString *)_domain
  expires:(NSDate *)_date
  isSecure:(BOOL)_secure;

/* accessors */

- (void)setName:(NSString *)_name;
- (NSString *)name;
- (void)setValue:(NSString *)_value;
- (NSString *)value;
- (void)setExpires:(NSDate *)_date;
- (NSDate *)expires;
- (void)setPath:(NSString *)_path;
- (NSString *)path;
- (void)setDomain:(NSString *)_domain;
- (NSString *)domain;
- (void)setIsSecure:(BOOL)_flag;
- (BOOL)isSecure;

/* description */

- (NSString *)headerString;
- (NSString *)stringValue; // called by HTTP server

@end

#endif /* __NGObjWeb_WOCookie_H__ */
