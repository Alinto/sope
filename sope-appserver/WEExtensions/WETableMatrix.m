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

#include <NGObjWeb/WODynamicElement.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include "WETableCalcMatrix.h"
#include "common.h"

/*
  for examples of this element, look at SkySchedulerViews chart-views.
*/

/* context keys */
static NSString *WETableMatrix_Query   = @"WETableMatrix_Query";
static NSString *WETableMatrix_Mode    = @"WETableMatrix_Mode";
static NSString *WETableMatrix_Index   = @"WETableMatrix_Index";
static NSString *WETableMatrix_Count   = @"WETableMatrix_Count";
static NSString *WETableMatrix_ColSpan = @"WETableMatrix_ColSpan";
static NSString *WETableMatrix_RowSpan = @"WETableMatrix_RowSpan";

@interface WETableMatrix : WODynamicElement
{
  WOAssociation *list;    /* array of objects */
  WOAssociation *item;    /* current object   */
  
  WOAssociation *rows;    /* array of row objects    (eg days)         */
  WOAssociation *columns; /* array of column objects (eg times of day) */
  WOAssociation *row;     /* current row object    */
  WOAssociation *column;  /* current column object */
  
  WOAssociation *itemActive; /* query whether item is active in row/column */
  WOAssociation *isRowActive;
  WOAssociation *isColumnActive;

  WOElement     *template;

  /* transient, not reentrant (need to lock) */
  WOComponent   *component;
  NSArray       *_rows;
  NSArray       *_cols;
  NSArray       *objs;
  NSSet         *subElems;
}

@end

@interface WEHSpanTableMatrix : WETableMatrix
@end

@interface WEVSpanTableMatrix : WETableMatrix
{
  WOAssociation *rowHeight;          /* height of TR tag */
  WOAssociation *noSpanInEmptyCells; /* do empty cells span rows ? */
} 
@end

static BOOL genComments = NO;

@implementation WETableMatrix

// premature: don't know a "good" count
static NSNumber *smap[10] = { nil,nil,nil,nil,nil,nil,nil,nil,nil,nil };
static Class StrClass = Nil;
static Class NumClass = Nil;

+ (void)initialize {
  static BOOL didInit = NO;
  int i;
  if (didInit) return;
  didInit = YES;
  
  StrClass = [NSString class];
  NumClass = [NSNumber class];
  for (i = 0; i < 10; i++)
    smap[i] = [[NumClass numberWithUnsignedInt:i] retain];
}

static NSNumber *numForUInt(unsigned int i) {
  // TODO: prof
  if (i < 10) return smap[i];
  return [NumClass numberWithUnsignedInt:i];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->list           = WOExtGetProperty(_config, @"list");
    self->item           = WOExtGetProperty(_config, @"item");
    self->rows           = WOExtGetProperty(_config, @"rows");
    self->columns        = WOExtGetProperty(_config, @"columns");
    self->row            = WOExtGetProperty(_config, @"row");
    self->column         = WOExtGetProperty(_config, @"column");
    self->itemActive     = WOExtGetProperty(_config, @"itemActive");
    self->isRowActive    = WOExtGetProperty(_config, @"isRowActive");
    self->isColumnActive = WOExtGetProperty(_config, @"isColumnActive");
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->isRowActive    release];
  [self->isColumnActive release];
  [self->itemActive release];
  [self->row        release];
  [self->column   release];
  [self->rows     release];
  [self->columns  release];
  [self->list     release];
  [self->item     release];
  [self->template release];
  [super dealloc];
}

/* matrix delegate */

- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldPlaceObject:(id)_object
  atPosition:(unsigned)_x:(unsigned)_y
{
  id   _row, _col;
  BOOL doPlace;
  
  _col = [self->_cols objectAtIndex:_x];
  _row = [self->_rows objectAtIndex:_y];
  
  /* setup context in component */
  [self->row    setValue:_row    inComponent:self->component];
  [self->column setValue:_col    inComponent:self->component];
  [self->item   setValue:_object inComponent:self->component];
  
#if 0
  NSLog(@"%i/%i: col %@ row %@", _x,_y, _col, _row);
#endif
  
  /* check */
  doPlace = [self->itemActive boolValueInComponent:self->component];
#if 0
  NSLog(@"  %@ placed: %s", self->itemActive, doPlace ? "yes" : "no");
#endif
  
  return doPlace;
}

- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldProcessColumn:(unsigned)_x
  forObject:(id)_object
{
  if (!self->isColumnActive)
    return YES;
  
  [self->column setValue:[self->_cols objectAtIndex:_x]
                inComponent:self->component];
  [self->item setValue:_object inComponent:self->component];
    
  return [self->isColumnActive boolValueInComponent:self->component];
}
- (BOOL)tableCalcMatrix:(WETableCalcMatrix *)_matrix
  shouldProcessRow:(unsigned)_y
  forObject:(id)_object
{
  if (!self->isRowActive)
    return YES;
  
  [self->row setValue:[self->_rows objectAtIndex:_y]
             inComponent:self->component];
  [self->item setValue:_object inComponent:self->component];

  return [self->isRowActive boolValueInComponent:self->component];
}

/* HTML generation */

- (NSArray *)spansFromMatrix:(WETableCalcMatrix *)_matrix {
  [self logWithFormat:@"ERROR: subclasses should override %@!",
          NSStringFromSelector(_cmd)];
  return nil;
}
- (void)appendSpans:(NSArray *)_spans
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [self logWithFormat:@"ERROR: subclasses should override %@!",
          NSStringFromSelector(_cmd)];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSLog(@"WARNING(WETableMatrix): unsupported invokeActionForRequest called!");
  return [super invokeActionForRequest:_req inContext:_ctx];
}


- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSAutoreleasePool  *pool;
  WETableCalcMatrix *matrix;
  NSArray            *allSpans;
  unsigned           rowCount, colCount, count;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  self->component = [_ctx component];
  self->objs      = 
    [[[self->list    valueInComponent:self->component] copy] autorelease];
  self->_rows     = 
    [[[self->rows    valueInComponent:self->component] copy] autorelease];
  self->_cols     = 
    [[[self->columns valueInComponent:self->component] copy] autorelease];
  
  count    = [self->objs count];
  rowCount = [self->_rows count];
  colCount = [self->_cols count];
  
  /* query subelements */
  {
    NSMutableSet *qs;

    qs = [[NSMutableSet alloc] init];
    [_ctx setObject:qs forKey:WETableMatrix_Query];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx removeObjectForKey:WETableMatrix_Query];
    self->subElems = [[qs copy] autorelease];
    [qs release];
  }
  
  if ([self->subElems count] == 0) {
    /* no content */
    [self warnWithFormat:@"no sub-elements !"];
    return;
  }

#if 0
  NSLog(@"subelems: %@", [self->subElems allObjects]);
#endif
  
  /* fill matrix and calculate spans */
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    matrix = [[WETableCalcMatrix alloc] initWithSize:colCount:rowCount];
    [matrix setDelegate:self];
    [matrix placeObjects:objs];
    allSpans = [[self spansFromMatrix:matrix] copy];
    [matrix release]; matrix = nil;
  }
  [pool release]; pool = nil;
  [allSpans autorelease];

  /* generate vertical table */
  
  pool = [[NSAutoreleasePool alloc] init];

  [_response appendContentString:@"<table"];
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentString:@">"];
  
  [self appendSpans:allSpans
        toResponse:_response
        inContext:_ctx];

  [_response appendContentString:@"</table>"];

  /* remove context keys */
  [_ctx removeObjectForKey:WETableMatrix_Mode];
  [_ctx removeObjectForKey:WETableMatrix_Index];
  [_ctx removeObjectForKey:WETableMatrix_Count];
  [_ctx removeObjectForKey:WETableMatrix_ColSpan];
  [_ctx removeObjectForKey:WETableMatrix_RowSpan];
  
  /* reset transients */
  self->subElems  = nil;
  self->_rows     = nil;
  self->_cols     = nil;
  self->objs      = nil;
  self->component = nil;
  [pool release];
}

@end /* WETableMatrix */

@implementation WEVSpanTableMatrix

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->rowHeight          = WOExtGetProperty(_config, @"rowHeight");
    self->noSpanInEmptyCells = WOExtGetProperty(_config, @"noSpanInEmptyCells");
  }
  return self;
}

- (void)dealloc {
  [self->noSpanInEmptyCells release];
  [self->rowHeight release];
  [super dealloc];
}

- (NSArray *)spansFromMatrix:(WETableCalcMatrix *)_matrix {
  return [_matrix columnSpans];
}

- (void)_genEmptyCellWithRowSpan:(int)_span
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *s;
  
  if (_span > 1) {
    char buf[16];
    sprintf(buf, "%i", _span);
    s = [[StrClass alloc] initWithCString:buf];
  }
  else
    s = @"1";
  
  if ([self->subElems containsObject:@"empty"]) {
    if (_span > 0)
      [_ctx setObject:s forKey:WETableMatrix_RowSpan];
    
    [_ctx setObject:@"empty" forKey:WETableMatrix_Mode];
    
    [self->template appendToResponse:_response inContext:_ctx];
    
    if (_span > 0)
      [_ctx removeObjectForKey:WETableMatrix_RowSpan];
  }
  else {
    [_response appendContentString:@"<td"];
    if (_span > 1) {
      [_response appendContentString:@" rowspan=\""];
      [_response appendContentString:s];
      [_response appendContentString:@"\""];
    }
    [_response appendContentString:@">"];

    [_response appendContentString:@"&nbsp;"];
    [_response appendContentString:@"</td>\n"];
  }
  
  [s release];
}

- (void)appendSpans:(NSArray *)_spans
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
#if 0 // hh: unused
  NSString *horizWidth;
#endif
  unsigned columnCount, rowCount;
  BOOL noEmptySpan; // empty cells do not have ROWSPAN (more cells are written)
  
  sComponent  = [_ctx component];
  columnCount = [self->_cols count];
  rowCount    = [self->_rows count];
#if 0 // hh: unused
  horizWidth  =
    [StrClass stringWithFormat:@"%d%%", (unsigned)(100.0/columnCount)];
#endif

  noEmptySpan = [self->noSpanInEmptyCells boolValueInComponent:sComponent];
  
  [_ctx setObject:numForUInt(columnCount) forKey:WETableMatrix_Count];

  /* head row */
  if ([self->subElems containsObject:@"top"]) {
    unsigned x;
    int numOfLeftLabels;

    numOfLeftLabels = 0;
    if ([self->subElems containsObject:@"left"])
      numOfLeftLabels++;
    
    [_response appendContentString:@"<tr>\n"];

    /* left/top edge */
    if (numOfLeftLabels > 0) {
      char buf[8];
      NSString *s;
      
      sprintf(buf, "%i", numOfLeftLabels);
      s = [[StrClass alloc] initWithCString:buf];
      
      if ([self->subElems containsObject:@"topleft"]) {
        [_ctx setObject:s          forKey:WETableMatrix_ColSpan];
        [_ctx setObject:@"topleft" forKey:WETableMatrix_Mode];
        
        [self->template appendToResponse:_response inContext:_ctx];
        
        [_ctx removeObjectForKey:WETableMatrix_ColSpan];
      }
      else {
        [_response appendContentString:@"  <td"];
        if (numOfLeftLabels > 1) {
          [_response appendContentString:@" colspan=\""];
          [_response appendContentString:s];
          [_response appendContentString:@"\""];
        }
        [_response appendContentString:@">&nbsp;</td>\n"];
      }
      [s release];
    }
    
    /* header */
    [_ctx setObject:@"top" forKey:WETableMatrix_Mode];
    
    for (x = 0; x < columnCount; x++) {
      NSArray  *spans;
      char     buf[64];
      NSString *s;
      
      spans = [_spans objectAtIndex:x];
      
#if GS_64BIT_OLD
      sprintf(buf, "%ld", [spans count]);
#else
      sprintf(buf, "%ld", [spans count]);
#endif
      s = [[StrClass alloc] initWithCString:buf];
      [_ctx setObject:s forKey:WETableMatrix_ColSpan];
      
      [self->column setValue:[self->_cols objectAtIndex:x]
                    inComponent:sComponent];
      [_ctx setObject:numForUInt(x) forKey:WETableMatrix_Index];
      
      [self->template appendToResponse:_response inContext:_ctx];
      
      [s release]; s = nil;
    }
    
    [_response appendContentString:@"</tr>"];
  }

  [_ctx removeObjectForKey:WETableMatrix_ColSpan];
  [_ctx removeObjectForKey:WETableMatrix_RowSpan];
  [_ctx removeObjectForKey:WETableMatrix_Index];
  
  /* body rows */
  {
    unsigned y;
    
    /* foreach row */
    for (y = 0; y < rowCount; y++) {
      unsigned x;

      [self->row setValue:[self->_rows objectAtIndex:y]
                 inComponent:[_ctx component]];

      if (self->rowHeight) {
        [_response appendContentString:@"<tr height=\""];
        [_response appendContentString:
                     [self->rowHeight stringValueInComponent:sComponent]];
        [_response appendContentString:@"\">"];
      }
      else {
        [_response appendContentString:@"<tr>"];
      }
      if (genComments) {
        NSString *s;
        s = [[StrClass alloc] initWithFormat:@"<!-- row %i -->\n", y];
        [_response appendContentString:s];
        [s release];
      }
      
      /* left edge */
      {
        char     buf[64];
        NSString *s;
        
        [_ctx setObject:@"left" forKey:WETableMatrix_Mode];

        sprintf(buf, "%i", y);
        s = [[StrClass alloc] initWithCString:buf];
        
        [_ctx setObject:numForUInt(y) forKey:WETableMatrix_Index];
        
        [self->template appendToResponse:_response inContext:_ctx];
        [s release];
      }
      
      /* foreach column */
      for (x = 0; x < columnCount; x++) {
        NSArray  *spans;
        unsigned i;

        spans = [_spans objectAtIndex:x];
        
        if ([spans count] == 0) { /* no content cells */
          if ((y == 0) || noEmptySpan) {
            /* max rowspan, only encode in first row */
            
            [self _genEmptyCellWithRowSpan:(noEmptySpan ? 1 : rowCount)
                  toResponse:_response
                  inContext:_ctx];
          }
          continue;
        }
        
        /* foreach sub-columns (title-COLSPAN=subcell-count) */

        for (i = 0; i < [spans count]; i++) {
          NSArray *thread; /* sub-column top-down */
          unsigned j;
            
          thread = [spans objectAtIndex:i];
          NSCAssert([thread count] > 0, @"no contents in thread");
            
          for (j = 0; j < [thread count]; j++) {
            id span;
              
            span = [thread objectAtIndex:j];
            if (![span occupiesIndex:y])
              continue;
            
            if ([span startsAtIndex:y]) {
              char buf[64];
              NSString *s;
              
              sprintf(buf, "%i", [span size]);
              s = [[StrClass alloc] initWithCString:buf];
              [_ctx setObject:s forKey:WETableMatrix_RowSpan];
              
              [self->column setValue:[self->_cols objectAtIndex:x]
                            inComponent:self->component];
              
              if ([span object]) {
                /* setup context */
                [self->item setValue:[span object] inComponent:self->component];
                
                /* generate body */
                [_ctx setObject:@"content" forKey:WETableMatrix_Mode];
              
                [self->template appendToResponse:_response inContext:_ctx];
              }
              else {
                [self _genEmptyCellWithRowSpan:(noEmptySpan ? 1 : [span size])
                      toResponse:_response
                      inContext:_ctx];
              }

              [_ctx removeObjectForKey:WETableMatrix_RowSpan];
              [s release]; s = nil;
            }
            else if (noEmptySpan) {
              if ([span object] == nil) {
                [self _genEmptyCellWithRowSpan:1
                      toResponse:_response
                      inContext:_ctx];
              }
            }
          }
        } /* end of 'foreach sub-columns (title-COLSPAN=subcell-count)' */
      } /* end of 'foreach column' */
      [_response appendContentString:@"</tr>"];
    }
  }
  
  /* footer row */
  
  if ([self->subElems containsObject:@"bottom"]) {
  }
}

@end /* WEVSpanTableMatrix */

@implementation WEHSpanTableMatrix

- (NSArray *)spansFromMatrix:(WETableCalcMatrix *)_matrix {
  return [_matrix rowSpans];
}

- (void)appendVerticalSpan:(NSArray *)_threads
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  unsigned x, width;
  
  width = [self->_cols count];

  for (x = 0; x < width; x++) { /* foreach table column */
    unsigned j, tc;
          
    for (j = 0, tc = [_threads count]; j < tc; j++) {
      id span;
            
      span = [_threads objectAtIndex:j];
      if (![span occupiesIndex:x])
        continue;

      if ([span startsAtIndex:x]) {
        NSString *s;
        char buf[64];

        sprintf(buf, "%d", [span size]);
        s = [[StrClass alloc] initWithCString:buf];
        [_ctx setObject:s forKey:WETableMatrix_ColSpan];
        
        if ([span object]) {
          /* setup context */
          [self->column setValue:[self->_cols objectAtIndex:x]
                        inComponent:self->component];
          [self->item setValue:[span object] inComponent:self->component];

          /* generate body */
          [_ctx setObject:@"content" forKey:WETableMatrix_Mode];
          [self->template appendToResponse:_response inContext:_ctx];
        }
        else {
          /* generate empty body */
          if ([self->subElems containsObject:@"empty"]) {
            [_ctx setObject:@"empty" forKey:WETableMatrix_Mode];
            [self->template appendToResponse:_response inContext:_ctx];
          }
          else {
            [_response appendContentString:@"<td colspan=\""];
            [_response appendContentString:s];
            [_response appendContentString:@"\">"];
            [_response appendContentString:@"&nbsp;"];
            [_response appendContentString:@"</td>\n"];
          }
        }
        [s release]; s = nil;
      }
    }
  }
}

- (void)appendSpans:(NSArray *)_spans
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
#if 0 // hh: unused
  NSString *horizWidth;
#endif
  unsigned columnCount;

  sComponent  = [_ctx component];
  columnCount = [self->_cols count];
#if 0 // hh: unused
  horizWidth  =
    [StrClass stringWithFormat:@"%d%%", (unsigned)(100.0/columnCount)];
#endif
  
  [_ctx setObject:numForUInt(columnCount) forKey:WETableMatrix_Count];
  
  /* head row */

  if ([self->subElems containsObject:@"top"]) {
    unsigned i, count;
    
    [_response appendContentString:@"<tr>"];

    /* edge */
    if ([self->subElems containsObject:@"left"])
      [_response appendContentString:@"<td>&nbsp;</td>"];
    
    /* header */
    [_ctx setObject:@"top" forKey:WETableMatrix_Mode];
    count = [self->_cols count];
    
    for (i = 0; i < count; i++) {
      [_ctx setObject:numForUInt(i) forKey:WETableMatrix_Index];
      
      [self->column setValue:[self->_cols objectAtIndex:i]
                    inComponent:sComponent];
      
      [self->template appendToResponse:_response inContext:_ctx];
    }
    [_response appendContentString:@"</tr>"];
  }
  
  /* body rows */
  {
    unsigned y, width, height;

    width  = [self->_cols count];
    height = [self->_rows count];
    
    for (y = 0; y < height; y++) { /* foreach row */
      NSArray  *rowSpans;
      unsigned i, count;
      
      /* apply context */
      [self->row setValue:[self->_rows objectAtIndex:y]
                 inComponent:self->component];

      /* get span */
      rowSpans = [_spans objectAtIndex:y];
      count    = [rowSpans count];

      /* begin first row */
      [_response appendContentString:@"<tr>"];

      /* left edge */
      {
        char     buf[64];
        NSString *s;
      
        sprintf(buf, "%d", count);
        s = [[StrClass alloc] initWithCString:buf];
        [_ctx setObject:s forKey:WETableMatrix_RowSpan];
        
        [_ctx setObject:@"left" forKey:WETableMatrix_Mode];
        
        [_ctx setObject:numForUInt(y) forKey:WETableMatrix_Index];        
        [self->template appendToResponse:_response inContext:_ctx];
        [s release]; s = nil;
        [_ctx removeObjectForKey:WETableMatrix_RowSpan];
      }
#if 0 /* hh: why is this commented out ? */
      /* left label ? */
      [_response appendContentString:@"<td"];
      if (count > 1) {
        NSString *s;

        [_response appendContentString:@" rowspan=\""];
        s = [[StrClass alloc] initWithFormat:@"%d", count];
        [_response appendContentString:s];
        [s release];
        [_response appendContentString:@"\""];
      }
      [_response appendContentString:@">"];
      [genLabel];
      [_response appendContentString:@"</td>"];
#endif
      
      /* check for empty span */
      if (count == 0) {
        NSString *s;

        s = [[StrClass alloc] initWithFormat:@"%d", width];
        
        /* max rowspan, only encode in first row */
        [_ctx setObject:@"empty" forKey:WETableMatrix_Mode];
        [_ctx setObject:s forKey:WETableMatrix_ColSpan];
        [self->template appendToResponse:_response inContext:_ctx];
        [_ctx removeObjectForKey:WETableMatrix_ColSpan];
#if 0 /* hh: why is this commented out ? */
        
        [_response appendContentString:@"<td colspan=\""];
        [_response appendContentString:s];
        [_response appendContentString:@"\">&nbsp;</td>"];
        
        /* close completly filled row */
        [_response appendContentString:@"</tr>"];
#endif
        [s release];
        continue;
      }
      
      /* first span (same row like vertical label) */
      if (count > 0) {
        NSArray *thread;
        
        thread = [rowSpans objectAtIndex:0];

        [self appendVerticalSpan:thread
              toResponse:_response
              inContext:_ctx];
      }
      /* close first row */
      [_response appendContentString:@"</tr>"];

      for (i = 1; i < count; i++) { /* foreach additional span */
        NSArray *thread;
        
        thread = [rowSpans objectAtIndex:i];

        [_response appendContentString:@"<tr>"];
        
        [self appendVerticalSpan:thread
              toResponse:_response
              inContext:_ctx];
        
        [_response appendContentString:@"</tr>"];
      }
      [_ctx removeObjectForKey:WETableMatrix_ColSpan];
    }
  }
  
  /* footer row */
  
  if ([self->subElems containsObject:@"bottom"]) {
    unsigned i, count;
    
    [_response appendContentString:@"<tr>"];
    
    /* edge */
    if ([self->subElems containsObject:@"left"])
      [_response appendContentString:@"<td>&nbsp;</td>"];
    
    /* footer */
    
    [_ctx setObject:@"bottom" forKey:WETableMatrix_Mode];
    
    count = [self->_cols count];
    
    for (i = 0; i < count; i++) {
      [_ctx setObject:numForUInt(i) forKey:WETableMatrix_Index];
      
      [self->column setValue:[self->_cols objectAtIndex:i]
                    inComponent:sComponent];
      
      [self->template appendToResponse:_response inContext:_ctx];
    }
    [_response appendContentString:@"</tr>"];
  }
}

@end /* WEVSpanTableMatrix */
