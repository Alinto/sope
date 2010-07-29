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

#ifndef __NGImap4_NGImap4FolderMailRegistry_H__
#define __NGImap4_NGImap4FolderMailRegistry_H__

#import <Foundation/NSObject.h>

@class NSString;
@class NGImap4Message;

/*
  NGImap4FolderMailRegistry

  Note: the registry does not retain the mails.
*/

@interface NGImap4FolderMailRegistry : NSObject
{
  unsigned int capacity;
  unsigned int len;
  id           *observers;
}

/* operations */

- (void)registerObject:(NGImap4Message *)_mail;
- (void)forgetObject:(NGImap4Message *)_mail;

/* notifications */

- (void)postFlagAdded:(NSString *)_flag   inMessage:(NGImap4Message *)_msg;
- (void)postFlagRemoved:(NSString *)_flag inMessage:(NGImap4Message *)_msg;

@end

#endif /* __NGImap4_NGImap4FolderMailRegistry_H__ */
