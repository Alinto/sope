/*
  Copyright (C) 2004 eXtrapola Srl

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

#import <Foundation/Foundation.h>

@interface StructuredStack : NSObject
{
  NSMutableArray *_stack;

  int		 start;
  int		 pos;

  BOOL		 cursorFIFO;
}

- (NSMutableArray *)stack;

- (void)removeAllObjects;

- (void)push:(id)anObject;
- (id)pop;

- (void)first;
- (void)last;

- (id)nextObject;
- (id)currentObject;
- (id)prevObject;

- (BOOL)cursorFollowsFIFO;
- (void)setCursorFollowsFIFO:(BOOL)aValue;

- (id)objectRelativeToCursorAtIndex:(int)anIndex;

@end
