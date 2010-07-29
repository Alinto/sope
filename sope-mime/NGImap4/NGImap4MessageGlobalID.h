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

#ifndef __NGImap4_NGImap4MessageGlobalID_H__
#define __NGImap4_NGImap4MessageGlobalID_H__

#include <EOControl/EOGlobalID.h>

@interface NGImap4MessageGlobalID : EOGlobalID < NSCopying >
{
  EOGlobalID   *folderGlobalID;
  unsigned int uid;
}

+ (id)imap4MessageGlobalIDWithFolderGlobalID:(EOGlobalID *)_gid 
  andUid:(unsigned int)_uid;
- (id)initWithFolderGlobalID:(EOGlobalID *)_gid andUid:(unsigned int)_uid;

/* accessors */

- (EOGlobalID *)folderGlobalID;
- (unsigned int)uid;

/* comparison */

- (unsigned)hash;

- (BOOL)isEqualToImap4MessageGlobalID:(NGImap4MessageGlobalID *)_other;
- (BOOL)isEqual:(id)_otherObject;

@end

#endif /* __NGImap4_NGImap4MessageGlobalID_H__ */
