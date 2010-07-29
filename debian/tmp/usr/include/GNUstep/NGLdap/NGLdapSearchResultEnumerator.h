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

#ifndef __NGLdapSearchResultEnumerator_H__
#define __NGLdapSearchResultEnumerator_H__

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSDate.h>

/*
  NGLdapSearchResultEnumerator
  
  TODO: document
*/

@class NGLdapConnection;

@interface NGLdapSearchResultEnumerator : NSEnumerator
{
@public // TODO: required to be public?!
  NGLdapConnection *connection;
  void             *handle;
  int              msgid;
  NSTimeInterval   timeout;
  NSTimeInterval   startTime;
  unsigned         index;
}

- (id)initWithConnection:(NGLdapConnection *)_con messageID:(int)_mid;

/* accessors */

- (int)messageID;
- (NSTimeInterval)duration;
- (unsigned)index;

- (void)setTimeout:(NSTimeInterval)_value;
- (NSTimeInterval)timeout;

/* operations */

- (void)cancel;

@end

#endif /* __NGLdapSearchResultEnumerator_H__ */
