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

#ifndef __NGObjWeb_WOElementID_H__
#define __NGObjWeb_WOElementID_H__

#import <Foundation/NSObject.h>

/*
  WOElementID
  
  This object is used to keep efficient representations of a NGObjWeb
  element-id. An element id is a "path" to an object kept in a tree.
*/

#define NGObjWeb_MAX_ELEMENT_ID_COUNT 126

@class NSString, NSMutableString;

typedef struct {
  NSString     *string;
  unsigned int number;
  NSString     *fqn;
} WOElementIDPart;

@interface WOElementID : NSObject
{
@public
  WOElementIDPart elementId[NGObjWeb_MAX_ELEMENT_ID_COUNT + 1];
  char elementIdCount;
  char idPos;
  
  /* keep a mutable string around ... */
  NSMutableString *cs;
  IMP addStr;
}

- (id)initWithString:(NSString *)_s;

/* methods */

- (NSString *)elementID;

- (void)appendElementIDComponent:(NSString *)_eid;
- (void)deleteAllElementIDComponents;

- (void)appendZeroElementIDComponent;
- (void)deleteLastElementIDComponent;
- (void)incrementLastElementIDComponent;
- (void)appendIntElementIDComponent:(int)_eid;

/* request ID processing */

- (id)currentElementID;
- (id)consumeElementID;

@end

#endif /* __NGObjWeb_WOElementID_H__ */
