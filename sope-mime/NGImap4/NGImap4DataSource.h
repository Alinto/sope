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

#ifndef __NGImap4_NGImap4DataSource_H__
#define __NGImap4_NGImap4DataSource_H__

#import <NGExtensions/EODataSource+NGExtensions.h>
#import <NGImap4/NGImap4Folder.h>

/*
  NGImap4DataSource
  
  Returned by the NGImap4FileManager when -dataSourceAtPath: is called.
  
  TODO: does this also handle subfolders? If not, we should rename the
        datasource class (eg NGImap4MessageDataSource).
*/

@class NSArray;
@class NGImap4Folder;
@class EOFetchSpecification;

@interface NGImap4DataSource : EODataSource
{
@protected
  EOFetchSpecification *fspec;
  NSArray       *messages;
  NGImap4Folder *folder;
  int           oldExists; // remember the 'exists' flag of the folder
  int           oldUnseen; // remember the 'unseen' flag of the folder

  NSArray       *oldUnseenMessages;
}

- (id)initWithFolder:(NGImap4Folder *)_folder;

- (void)setFolder:(NGImap4Folder *)_folder;
- (NGImap4Folder *)folder;

- (int)oldExists;
- (int)oldUnseen;

@end /* __NGImap4_NGImap4DataSource_H__ */

#endif
