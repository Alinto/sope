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

#ifndef __Database_NGImap4_NGImap4Message_H__
#define __Database_NGImap4_NGImap4Message_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGPart.h>
#include <NGImap4/NGImap4Support.h>

@class NSArray, NSMutableDictionary;
@class EOGlobalID;
@class NGHashMap;
@class NGImap4Context, NGImap4Folder, NGImap4FolderMailRegistry;

@interface NGImap4Message : NSObject
{
@protected
  NGHashMap      *headers;
  unsigned       uid;
  int            size;
  NSArray        *flags;

  id<NGMimePart> message;
  id<NGMimePart> bodyStructure;
  NSData         *rawData;

  NGImap4Context *context;
  NGImap4Folder  *folder; // not retained
  NGImap4FolderMailRegistry *mailRegistry;
  
  NSURL          *url;
  EOGlobalID     *globalID;

  NSMutableDictionary *bodyStructureContent;

  NSString *removeFlagNotificationName;
  NSString *addFlagNotificationName;
  
  int isRead;
}

- (id)initWithUid:(unsigned)_uid folder:(NGImap4Folder *)_folder
  context:(NGImap4Context *)_ctx;

- (id)initWithUid:(unsigned)_uid headers:(NGHashMap *)_header
  size:(unsigned)_size flags:(NSArray *)_flags folder:(NGImap4Folder *)_folder
  context:(NGImap4Context *)_ctx;

/* accessors */

- (NSException *)lastException;
- (void)resetLastException;
- (NGHashMap *)headers;
- (int)size;
- (unsigned)uid;
- (NSArray *)flags;

- (NSData *)contentsOfPart:(NSString *)_part;
- (id<NGMimePart>)bodyStructure;
- (id<NGMimePart>)message;
- (NSData *)rawData;

- (NGImap4Folder *)folder;
- (NGImap4Context *)context;

- (NSURL *)url;
- (EOGlobalID *)globalID;

/* flag processing */

- (void)addFlag:(NSString *)_flag;
- (void)removeFlag:(NSString *)_flag;

- (BOOL)isRead;
- (void)markRead;
- (void)markUnread;

- (BOOL)isFlagged;
- (void)markFlagged;
- (void)markUnFlagged;

- (BOOL)isAnswered;
- (void)markAnswered;
- (void)markNotAnswered;

/* equality */

- (BOOL)isEqual:(id)_obj;
- (BOOL)isEqualToNGImap4Message:(NGImap4Message *)_messages;

@end

#endif /* __Database_NGImap4_NGImap4Message_H__ */
