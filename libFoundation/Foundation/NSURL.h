/* 
   NSURL.h

   Copyright (C) 2000 MDlink GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSURL_h__
#define __NSURL_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSURLHandle.h>

@class NSData, NSNumber;

LF_EXPORT NSString *NSURLFileScheme;

@interface NSURL : NSObject < NSCoding, NSCopying, NSURLHandleClient >
{
    id currentClient;
}

+ (id)URLWithString:(NSString *)_str;
+ (id)URLWithString:(NSString *)_str relativeToURL:(NSURL *)_base;
+ (id)fileURLWithPath:(NSString *)_path;

- (id)initFileURLWithPath:(NSString *)_path;
- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path;
- (id)initWithString:(NSString *)_string relativeToURL:(NSURL *)_baseURL;
- (id)initWithString:(NSString *)_string;

/* relative URLs */

- (NSURL *)baseURL;
- (NSString *)relativePath;
- (NSString *)relativeString;
- (NSString *)absoluteString;

/* attributes */

- (NSString *)fragment;
- (NSString *)host;
- (NSString *)path;
- (NSString *)scheme;
- (NSString *)user;
- (NSString *)password;
- (NSNumber *)port;
- (NSString *)query;

- (BOOL)isFileURL;

/* fetching */

- (NSURLHandle *)URLHandleUsingCache:(BOOL)_useCache;
- (void)loadResourceDataNotifyingClient:(id)_client usingCache:(BOOL)_useCache;

- (NSData *)resourceDataUsingCache:(BOOL)_useCache;
- (BOOL)setResourceData:(NSData *)_data;

@end

@interface NSObject(NSURLClient)
@end

@interface NSString(NSURLUtilities)

- (BOOL)isAbsoluteURL;
- (NSString *)urlScheme;

@end

#endif /* __NSURL_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
