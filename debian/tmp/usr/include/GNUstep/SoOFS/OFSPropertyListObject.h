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

#ifndef __OFS_OFSPropertyListObject_H__
#define __OFS_OFSPropertyListObject_H__

#include <SoOFS/OFSFile.h>

/*
  OFSPropertyListObject
  
  The OFSPropertyListObject represents objects archived in a property list,
  that is, it's a quick way to store objects structured in a simple way.
  
  Note that the property list is loaded on-demand (if a stored key is 
  accessed).
  
  The class OFSPropertyListObject also acts as an object factory.
*/

@class NSArray, NSMutableDictionary;

@interface OFSPropertyListObject : OFSFile
{
  NSMutableDictionary *record; /* loaded on-demand */
  NSArray *recordKeys;
  struct {
    BOOL isLoading:1;
    BOOL isLoaded:1;
    BOOL isEdited:1;
    BOOL isNew:1;
    int  reserved:28;
  } flags;
}

/* accessors */

- (NSArray *)allKeys;

/* storage */

- (void)willChange;
- (BOOL)isRestored;
- (NSException *)restoreObject;
- (NSException *)saveObject;

@end

#endif /* __OFS_OFSPropertyListObject_H__ */
