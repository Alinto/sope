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

#include "WETableCalcMatrix.h"
#include "common.h"
#include <string.h>

typedef struct {
  NSMutableArray *items;
} MatrixEntry;

typedef struct {
  unsigned x;
  unsigned y;
} MatrixCoord;

typedef struct {
  id *objects;
} MatrixThread;

typedef enum { WERow, WEColumn } WEOrientation;

static NSNull *null = nil;

@implementation WETableCalcMatrixSpan

+ (id)spanWithObject:(id)_obj range:(NSRange *)_range {
  id span;
  span = [[WETableCalcMatrixSpan alloc] initWithObject:_obj range:_range];
  return [span autorelease];
}
- (id)initWithObject:(id)_obj range:(NSRange *)_range {
  self->object = [_obj retain];
  self->range  = *_range;
  return self;
}
- (void)dealloc {
  [self->object release];
  [super dealloc];
}

/* accessors */

- (id)object {
  return self->object;
}
- (NSRange)range {
  return self->range;
}

/* calculations */

- (BOOL)startsAtIndex:(unsigned)_idx {
  return (_idx == self->range.location) ? YES : NO;
}
- (BOOL)occupiesIndex:(unsigned)_idx {
  if (_idx < self->range.location)
    return NO;
  if (_idx >= (self->range.location + self->range.length))
    return NO;
  return YES;
}
- (unsigned)size {
  return self->range.length;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: object=0x%p start=%d len=%d>",
                     self, NSStringFromClass([self class]),
                     [self object],
                     self->range.location,
                     self->range.length];
}

@end /* WETableCalcMatrixSpan */

@interface WETableCalcMatrixStripe : NSObject
{
@private
  unsigned           size;
  MatrixThread       *threads;
  short              threadCount;
  WETableCalcMatrix *matrix;     /* non-retained */
  id                 delegate;    /* non-retained */
}

- (unsigned)threadCount;
- (NSArray *)threads;
- (NSArray *)threadSpans;

/* modification */

- (void)addObject:(id)_obj atPositions:(unsigned *)_pos count:(unsigned)_c;

@end

@implementation WETableCalcMatrixStripe

+ (void)initialize {
  if (null == nil) null = [[NSNull null] retain];
}

- (id)initWithSize:(unsigned)_h
  matrix:(WETableCalcMatrix *)_matrix
  delegate:(id)_delegate
{
  self->size   = _h;
  self->matrix = _matrix;

  if ([_delegate respondsToSelector:
                   @selector(tableCalcMatrix:spanForObject:range:)])
    self->delegate = _delegate;
  
  return self;
}
- (void)dealloc {
  if (self->threads) {
    unsigned i;
    
    for (i = 0; i < (unsigned)self->threadCount; i++) {
      if (self->threads[i].objects) {
        unsigned j;

        for (j = 0; j < self->size; j++)
          [self->threads[i].objects[j] release];
        free(self->threads[i].objects);
      }
    }
    free(self->threads);
  }
  [super dealloc];
}

/* accessors */

- (unsigned)threadCount {
  return self->threadCount;
}

- (NSArray *)threadAtIndex:(unsigned)_idx {
  id       *objs;
  unsigned i;
  NSArray  *result;
  
  objs = calloc(self->size, sizeof(id));
  NSAssert(objs, @"could not allocate memory ..");
  NSAssert(self->size > 0, @"invalid size ..");
  
  for (i = 0; i < self->size; i++) {
    objs[i] = self->threads[_idx].objects[i];
    
    if (objs[i] == nil)
      objs[i] = null;
  }
  result = [NSArray arrayWithObjects:objs count:self->size];
  free(objs);
  return result;
}
- (NSArray *)spansAtIndex:(unsigned)_idx {
  id       *spans;
  unsigned i, spanCount;
  NSArray  *result;
  
  spans = calloc(self->size, sizeof(id));
  
  for (i = 0, spanCount = 0; i < self->size; ) {
    WETableCalcMatrixSpan *span;
    id      obj;
    NSRange r;
    
    span = nil;
    obj  = self->threads[_idx].objects[i];

    if ((i + 1) == self->size) {
      /* last entry */
      r.location = i;
      r.length   = 1;
      i++;
    }
    else {
      /* look ahead for similiar entries */
      unsigned j;
      
      r.location = i;
      r.length   = 0;

      for (j = i + 1; j < self->size; j++) {
        id nextObj;
        
        nextObj = self->threads[_idx].objects[j];
        if (nextObj != obj)
          break;
      }
      r.length = (j - i);

      /* continue at end of this object */
      i = j;
    }

    span = nil;
    if (self->delegate) {
      span = [self->delegate tableCalcMatrix:self->matrix
                             spanForObject:obj
                             range:r];
    }
    if (span == nil) {
      span = [[WETableCalcMatrixSpan alloc] initWithObject:obj range:&r];
      AUTORELEASE(span);
    }

    spans[spanCount] = span;
    spanCount++;
  }
  result = [NSArray arrayWithObjects:spans count:spanCount];
  free(spans);
  return result;
}

- (NSArray *)threads {
  if (self->threadCount == 0)
    return nil;
  if (self->threadCount == 1)
    return [NSArray arrayWithObject:[self threadAtIndex:0]];
  
  {
    id       threadArrays[self->threadCount];
    unsigned i;

    for (i = 0; i < (unsigned)self->threadCount; i++)
      threadArrays[i] = [self threadAtIndex:i];
    
    return [NSArray arrayWithObjects:threadArrays count:self->threadCount];
  }
}
- (NSArray *)threadSpans {
  if (self->threadCount == 0)
    return nil;
  else if (self->threadCount == 1)
    return [NSArray arrayWithObject:[self spansAtIndex:0]];
  else {
    NSArray  *threadArrays[self->threadCount];
    unsigned i;
    
    for (i = 0; i < (unsigned)self->threadCount; i++) {
      threadArrays[i] = [self spansAtIndex:i];
    }
    
    return [NSArray arrayWithObjects:threadArrays count:self->threadCount];
  }
}

/* addition */

- (unsigned)threadForPositions:(unsigned *)_pos count:(unsigned)_c {
  unsigned i;
  void *tmp;
  
  if (self->threadCount == 0) {
    self->threads  = calloc(1, sizeof(MatrixThread));
    self->threads[0].objects = calloc(self->size, sizeof(id));
    self->threadCount = 1;
    return 0;
  }
  
  /* check each column */
  for (i = 0; i < (unsigned)self->threadCount; i++) {
    unsigned       j;
    MatrixThread *column;
    BOOL           ok;
    
    column = &(self->threads[i]);
    
    /* check each required position in column */
    for (j = 0, ok = YES; j < _c; j++) {
      unsigned requiredPos;
      
      requiredPos = _pos[j];
      NSAssert(requiredPos < self->size, @"index to high ..");
      
      if (column->objects[requiredPos] != nil) {
        /* position already assigned */
        ok = NO;
        break;
      }
    }
    if (ok) {
      /* all required position available, return column */
      return i;
    }
    /* check next column */
  }

  /* all available threads are full, make new one .. */
  tmp = self->threads;
  self->threads = calloc(self->threadCount + 1, sizeof(MatrixThread));
  memcpy(self->threads, tmp, self->threadCount * sizeof(MatrixThread));
  self->threads[self->threadCount].objects = calloc(self->size, sizeof(id));
  self->threadCount++;
  return (self->threadCount - 1);
}

- (void)addObject:(id)_obj atPositions:(unsigned *)_pos count:(unsigned)_c {
  unsigned thread;
  unsigned i;

  if (_c == 0) return;
  
  /* find row */
  thread = [self threadForPositions:_pos count:_c];
  NSAssert(thread < (unsigned)self->threadCount, @"invalid idx");
  
  /* place object */
  for (i = 0; i < _c; i++) {
    unsigned requiredIdx;
    
    requiredIdx = _pos[i];
    
#if DEBUG
    NSAssert(requiredIdx < self->size, @"index to high ..");
    NSAssert3(self->threads[thread].objects[requiredIdx] == nil,
              @"index %i is already marked (by=0x%p, my=0x%p) !",
              requiredIdx, self->threads[thread].objects[requiredIdx], _obj);
#endif
    
    self->threads[thread].objects[requiredIdx] = RETAIN(_obj);
  }
}

@end

@interface WETableCalcMatrixPositionArray : NSObject
{ /* mutable array of matrix coordinates */
@private
  unsigned    count;
  MatrixCoord *positions;
}

- (void)addPosition:(unsigned)_x:(unsigned)_y;
- (void)checkForDuplicates;

/* narrow set to row or column */
- (unsigned *)indicesInColumn:(unsigned)_x count:(unsigned *)_count;
- (unsigned *)indicesInRow:(unsigned)_y    count:(unsigned *)_count;

@end

@implementation WETableCalcMatrixPositionArray

- (void)dealloc {
  if (self->positions) free(self->positions);
  [super dealloc];
}

- (void)checkForDuplicates {
  unsigned j;
  
  for (j = 0; j < self->count; j++) {
    unsigned i;

    for (i = 0; i < j; i++) {
      NSAssert4(!((self->positions[j].x) == self->positions[i].x &&
                 (self->positions[j].y) == self->positions[i].y),
                @"duplicate coordinate at %d and %d: %d/%d !",
                j, i, self->positions[j].x, self->positions[j].y);
    }
  }
}

- (void)addPosition:(unsigned)_x:(unsigned)_y {
  if (self->positions == NULL) {
    self->positions = calloc(1, sizeof(MatrixCoord));
    self->positions[0].x = _x;
    self->positions[0].y = _y;
    self->count = 1;
  }
  else {
    unsigned oldCount = self->count;
    void *tmp;
    
    tmp = self->positions;
    self->positions = calloc(oldCount + 1, sizeof(MatrixCoord));
    memcpy(self->positions, tmp, (oldCount * sizeof(MatrixCoord)));
    
    self->positions[oldCount].x = _x;
    self->positions[oldCount].y = _y;
    self->count++;
  }
}

- (unsigned *)indicesIn:(WEOrientation)o index:(unsigned)_idx
  count:(unsigned *)_count
{
  unsigned i, rowCount;
  unsigned *pos, *p;
  
  /* first count */
  for (i = 0, rowCount = 0; i < self->count; i++) {
    unsigned j;
    
    j = (o == WEColumn) ? self->positions[i].x : self->positions[i].y;
    if (j == _idx)
      rowCount++;
  }
  if (rowCount == 0)
    return NULL;
  
  /* then copy */
  pos = calloc(rowCount, sizeof(unsigned));
  *_count = rowCount;
  
  for (i = 0, p = pos; i < self->count; i++) {
    unsigned j;
    
    j = (o == WEColumn) ? self->positions[i].x : self->positions[i].y;
    
    if (j == _idx) {
      *p = (o == WEColumn)
        ? self->positions[i].y
        : self->positions[i].x;
      p++;
    }
  }
  return pos;
}

- (unsigned *)indicesInRow:(unsigned)_y count:(unsigned *)_count {
  return [self indicesIn:WERow index:_y count:_count];
}
- (unsigned *)indicesInColumn:(unsigned)_x count:(unsigned *)_count {
  return [self indicesIn:WEColumn index:_x count:_count];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%p[%@]: count=%d>",
                     self, NSStringFromClass([self class]),
                     self->count];
}

@end /* WETableCalcMatrixPositionArray */

@implementation WETableCalcMatrix

+ (int)version {
  return 0;
}

static inline MatrixEntry *entryAt(WETableCalcMatrix *self, unsigned x, 
				   unsigned y) {
  return self->matrix +
         (x * self->height * sizeof(MatrixEntry)) +
         (y * sizeof(MatrixEntry));
}

- (id)initWithSize:(unsigned)_width:(unsigned)_height {
  if (_width == 0 || _height == 0) {
    [self logWithFormat:@"ERROR: specified invalid matrix dimensions: %ix%i",
            _width, _height];
    [self release];
    return nil;
  }
  
  NSAssert(_width > 0 && _height > 0, @"invalid args ..");
  self->width  = _width;
  self->height = _height;
  self->matrix = (void *)calloc(_width * _height, sizeof(MatrixEntry));
  memset(self->matrix, 0, _width * _height * sizeof(MatrixEntry));

  self->objToPos = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                    NSObjectMapValueCallBacks,
                                    64);
  
  return self;
}
- (void)dealloc {
  [self removeAllObjects];

  if (self->objToPos)
    NSFreeMapTable(self->objToPos);
  
  if (self->matrix)
    free(self->matrix);
  
  [super dealloc];
}

/* accessors */

- (unsigned)width {
  return self->width;
}
- (unsigned)height {
  return self->height;
}

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
  
  self->columnCheck =
    [_delegate respondsToSelector:
                 @selector(tableCalcMatrix:shouldProcessColumn:forObject:)];
  self->rowCheck =
    [_delegate respondsToSelector:
                 @selector(tableCalcMatrix:shouldProcessRow:forObject:)];
}
- (id)delegate {
  return self->delegate;
}

/* clearing the structure */

- (void)removeAllObjects {
  unsigned y, x;
  
  if (self->objToPos) {
    NSResetMapTable(self->objToPos);
    self->objToPos = NULL;
  }
  
  if (self->matrix == NULL)
    return;
  
  for (y = 0; y < self->height; y++) {
    for (x = 0; x < self->width; x++) {
      MatrixEntry *e;
      
      e = entryAt(self, x, y);
      
      if (e->items == nil) 
	continue;
      
      [e->items release]; e->items = nil;
    }
  }
}

/* queries */

- (BOOL)object:(id)_obj possibleInRow:(unsigned)_y {
  /* optimization method, can always return 'YES' */
  if (self->rowCheck) {
    return [self->delegate tableCalcMatrix:self
                           shouldProcessRow:_y
                           forObject:_obj];
  }
  return YES;
}

- (BOOL)object:(id)_obj possibleInColumn:(unsigned)_x {
  /* optimization method, can always return 'YES' */
  if (self->columnCheck) {
    return [self->delegate tableCalcMatrix:self
                           shouldProcessColumn:_x
                           forObject:_obj];
  }
  return YES;
}

- (BOOL)object:(id)_obj matchesCellAt:(unsigned)_x:(unsigned)_y {
  return [self->delegate tableCalcMatrix:self
                         shouldPlaceObject:_obj
                         atPosition:_x:_y];
}

/* adding object to structure */

- (void)addObject:(id)_obj toCellAt:(unsigned)_x:(unsigned)_y {
  WETableCalcMatrixPositionArray *positions;
  MatrixEntry *e;
  
  if ((positions = NSMapGet(self->objToPos, _obj)) == nil) {
    positions = [[WETableCalcMatrixPositionArray alloc] init];
    NSMapInsert(self->objToPos, _obj, positions);
    RELEASE(positions);
  }
  
  [positions checkForDuplicates];
  
  e = entryAt(self, _x, _y);
  
  if (e->items == nil)
    e->items = [[NSMutableArray alloc] init];
  
  [e->items addObject:_obj];

  [positions checkForDuplicates];
  [positions addPosition:_x:_y];
  [positions checkForDuplicates];
}

/* placing objects */

- (void)placeObject:(id)_object {
  unsigned y, x;

  if (NSMapGet(self->objToPos, _object)) {
    //NSLog(@"already placed object %@ !", _object);
    return;
  }
  
  if (self->rowCheck) {
    for (y = 0; y < self->height; y++) {
      if (![self object:_object possibleInRow:y])
        continue;

      for (x = 0; x < self->width; x++) {
        if ([self object:_object matchesCellAt:x:y]) {
          /* add to cell x:y */
          [self addObject:_object toCellAt:x:y];
        }
      }
    }
  }
  else {
    for (x = 0; x < self->width; x++) {
      if (![self object:_object possibleInColumn:x])
        continue;
    
      for (y = 0; y < self->height; y++) {
        if ([self object:_object matchesCellAt:x:y]) {
          /* add to cell x:y */
          [self addObject:_object toCellAt:x:y];
        }
      }
    }
  }
}

- (void)placeObjects:(NSArray *)_objects {
  unsigned oc, i;
  
  if ((oc = [_objects count]) == 0)
    return;
  
  for (i = 0; i < oc; i++)
    [self placeObject:[_objects objectAtIndex:i]];
}

/* formatting */

- (NSArray *)objectsInColumn:(unsigned)_x {
  unsigned     y;
  NSMutableSet *set;
  NSArray      *result;

  set = [[NSMutableSet alloc] init];
  
  for (y = 0; y < self->height; y++) {
    MatrixEntry *e;
    
    e = entryAt(self, _x, y);
    if (e->items)
      [set addObjectsFromArray:e->items];
  }
  result = [set allObjects];
  RELEASE(set);
  return result;
}
- (NSArray *)objectsInRow:(unsigned)_y {
  unsigned     x;
  NSMutableSet *set;
  NSArray      *result;

  set = [[NSMutableSet alloc] init];
  
  for (x = 0; x < self->width; x++) {
    MatrixEntry *e;
    
    e = entryAt(self, x, _y);
    if (e->items)
      [set addObjectsFromArray:e->items];
  }
  result = [set allObjects];
  RELEASE(set);
  return result;
}

- (NSArray *)spansOfColumn:(unsigned)_x {
  WETableCalcMatrixStripe *stripe;
  NSEnumerator  *objects;
  id            object;
  
  stripe = [[WETableCalcMatrixStripe alloc]
                                     initWithSize:self->height
                                     matrix:self
                                     delegate:self->delegate];
  stripe = [stripe autorelease];
  
  objects = [[self objectsInColumn:_x] objectEnumerator];
  while ((object = [objects nextObject]) != nil) {
    WETableCalcMatrixPositionArray *pos;
    unsigned *indices;
    unsigned idxCount;
    
    pos = NSMapGet(self->objToPos, object);
    [pos checkForDuplicates];
    
    indices = [pos indicesInColumn:_x count:&idxCount];
    NSAssert(indices, @"available in column, but no indices ?");

    [stripe addObject:object atPositions:indices count:idxCount];
  }
  
  return [stripe threadSpans];
}
- (NSArray *)spansOfRow:(unsigned)_y {
  WETableCalcMatrixStripe *stripe;
  NSEnumerator  *objects;
  id            object;
  
  stripe = [[WETableCalcMatrixStripe alloc]
                                     initWithSize:self->width
                                     matrix:self
                                     delegate:self->delegate];
  stripe = [stripe autorelease];
  
  objects = [[self objectsInRow:_y] objectEnumerator];
  while ((object = [objects nextObject])) {
    WETableCalcMatrixPositionArray *pos;
    unsigned *indices;
    unsigned idxCount;
    
    pos = NSMapGet(self->objToPos, object);
    [pos checkForDuplicates];
    
    indices = [pos indicesInRow:_y count:&idxCount];
    NSAssert(indices, @"available in column, but no indices ?");
    
    [stripe addObject:object atPositions:indices count:idxCount];
  }
  
  return [stripe threadSpans];
}

- (NSArray *)columnSpans {
  id       objs[self->width];
  unsigned i;
  
  for (i = 0; i < self->width; i++) {
    objs[i] = [self spansOfColumn:i];
    if (objs[i] == nil) objs[i] = [NSArray array];
  }
  return [NSArray arrayWithObjects:objs count:self->width];
}
- (NSArray *)rowSpans {
  id       objs[self->height];
  unsigned i;
  
  for (i = 0; i < self->height; i++) {
    objs[i] = [self spansOfRow:i];
    if (objs[i] == nil) objs[i] = [NSArray array];
  }
  return [NSArray arrayWithObjects:objs count:self->height];
}

/* counting */

- (unsigned)widthOfColumn:(unsigned)_x {
  unsigned y;
  unsigned count;
  
  for (y = 0, count = 0; y < self->height; y++) {
    MatrixEntry *e;

    e = entryAt(self, _x, y);
    if ([e->items count] > count)
      count = [e->items count];
  }
  return count;
}

- (unsigned)countOfColumn:(unsigned)_x {
  return [[self objectsInColumn:_x] count];
}

@end /* WETableCalcMatrix */
