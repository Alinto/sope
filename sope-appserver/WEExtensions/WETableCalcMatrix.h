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

#ifndef __WETableCalcMatrix_H__
#define __WETableCalcMatrix_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSRange.h>

@class NSArray;

/*
  Object to calculate HTML Table based charts, eg the
  Appointment week-overview.
*/

@interface WETableCalcMatrixSpan : NSObject
{
  id      object;
  NSRange range;
}

+ (id)spanWithObject:(id)_obj range:(NSRange *)_range;
- (id)initWithObject:(id)_obj range:(NSRange *)_range;

/* accessors */

- (id)object;
- (NSRange)range;

/* calculates accessors */

- (BOOL)startsAtIndex:(unsigned)_idx;
- (BOOL)occupiesIndex:(unsigned)_idx;
- (unsigned)size;

@end

@interface WETableCalcMatrix : NSObject
{
  void           *matrix;
  unsigned short width;
  unsigned short height;
  NSMapTable     *objToPos;
  id             delegate;  /* non-retained */
  BOOL           columnCheck;
  BOOL           rowCheck;
}

- (id)initWithSize:(unsigned)_width:(unsigned)_height;

/* static accessors */

- (unsigned)width;
- (unsigned)height;

- (void)setDelegate:(id)_delegate;
- (id)delegate;

/* clearing the structure */

- (void)removeAllObjects;

/* adding objects */

- (void)placeObjects:(NSArray *)_objects;
- (void)placeObject:(id)_object;

/* calculating */

- (NSArray *)objectsInColumn:(unsigned)_x;
- (NSArray *)objectsInRow:(unsigned)_y;
- (NSArray *)spansOfColumn:(unsigned)_x;
- (NSArray *)spansOfRow:(unsigned)_y;
- (NSArray *)columnSpans;
- (NSArray *)rowSpans;

@end

@interface NSObject(WETableCalcMatrixDelegate)

/* method for optimizing matrix scan (not required) */

- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldProcessColumn:(unsigned)_x
  forObject:(id)_object;
- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldProcessRow:(unsigned)_y
  forObject:(id)_object;

/* shall the object be placed at the specified coordinate ? */

- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldPlaceObject:(id)_object
  atPosition:(unsigned)_x:(unsigned)_y;

/* define if you want to create own span objects */

- (id)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  spanForObject:(id)_object
  range:(NSRange)_range;

@end

#endif /* __WETableCalcMatrix_H__ */
