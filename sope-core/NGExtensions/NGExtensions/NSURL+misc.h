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

#ifndef __NGExtensions_NSURL_misc_H__
#define __NGExtensions_NSURL_misc_H__

#import <Foundation/NSObject.h> // required by gstep-base
#import <Foundation/NSURL.h>
#import <Foundation/NSString.h>

@interface NSURL(misc)

/*
  This method tries to construct the "shortest" path
  between the two URLs. If the URLs are not in the same
  namespace, -absoluteString is returned ...
*/
- (NSString *)stringValueRelativeToURL:(NSURL *)_base;

/*
  This checks whether protocol, host, login match. That is,
  checks whether it's possible to build a relative URL to
  _url (whether self is in the same path namespace).
*/
- (BOOL)isInSameNamespaceWithURL:(NSURL *)_url;

/* adding fragments and queries to a string ... */
- (NSString *)stringByAddingFragmentAndQueryToPath:(NSString *)_path;

@end

@interface NSString(URLPathProcessing)

/* relative path processing (should never return an absolute path) */

/*
  eg:                "/a/b/c.html"
  should resolve to: "c.html"
    
  Directories are a bit more difficult, eg:
    "/a/b/c/"
  is resolved to
    "../c/"
*/
- (NSString *)urlPathRelativeToSelf;

/* this is the same like the absolute path, only without a leading "/" .. */
- (NSString *)urlPathRelativeToRoot;

/*
  This can be used for URLs in the same namespace. It should
  never return an absolute path (it only does in error conditions).
*/
- (NSString *)urlPathRelativeToPath:(NSString *)_base;

@end

#endif /* __NGExtensions_NSURL_misc_H__ */
