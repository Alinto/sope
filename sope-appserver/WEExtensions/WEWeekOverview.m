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

#include "WEContextConditional.h"
#include <NGObjWeb/WODynamicElement.h>

/*

  renders this:
  _______________________________
  | MO | TU | WE | TH | FR | SA |
  |-----------------------------|
  |    |    |    |    |    | 10 |
  |  0 |  2 |  4 |  6 |  8 | 11 |
  |____|____|____|____|____|____|
  |    |    |    |    |    | SU |
  |    |    |    |    |    |----|
  |    |    |    |    |    | 12 |
  |  1 |  3 |  5 |  7 |  9 | 13 |
  |____|____|____|____|____|____|

  Would be a nice addition:
  |a   |b   |c   |d   |e   |f   |
  -------------------------------
  |a   |b   |c   |d   |e   |f   |
  -------------------------------
  footerRow = 0 / footerRowList = ( 0, 1, 2, 3, 4 );
  headerRow = 0 / headerRowList = ( 0, 1, 2, 3, 4 );
  startDate/endDate
  
  the numbers corresponde to the indxes in the matrix (self->matrix[])

  Note: it does support additional header and footer rows which can be used
        to generate content above and below the view itself.

  Usage:
    WeekOverview: WEWeekOverview {
      list       = list;
      item       = item;
      weekStart  = weekStart;
      
      titleStyle   = "weekview_title";
      contentStyle = "weekview_content";
    }
    
    TitleMode:   WEWeekOverviewTitleMode   {};
    InfoMode:    WEWeekOverviewInfoMode    {};
    ContentMode: WEWeekOverviewContentMode {};
*/

// TODO: allow stylesheet classes!

#define SecondsPerWeek (7 * 24 * 60 * 60)
#define SecondsPerDay      (24 * 60 * 60)

@class NSMutableArray;

#define WEWeekOverview_TitleMode         @"WEWeekOverview_TitleMode"
#define WEWeekOverview_TitleModeDidMatch @"WEWeekOverview_TitleModeDidMatch"
#define WEWeekOverview_InfoMode          @"WEWeekOverview_InfoMode"
#define WEWeekOverview_PMInfoMode        @"WEWeekOverview_PMInfoMode"
#define WEWeekOverview_ContentMode       @"WEWeekOverview_ContentMode"

#define WEWeekOverview_FooterRowMode     @"WEWeekOverview_FooterRowMode"
#define WEWeekOverview_HeaderRowMode     @"WEWeekOverview_HeaderRowMode"

@interface WEWeekOverview : WODynamicElement
{
@protected
  WOAssociation  *list;
  WOAssociation  *item;
  WOAssociation  *index;
  WOAssociation  *identifier;
  
  WOAssociation  *dayIndex; // 0=firstDay, 1=secondDay, ..., 6=seventh day
  WOAssociation  *weekStart;
  
  WOAssociation  *startDateKey;
  WOAssociation  *endDateKey;
  
  WOAssociation  *titleStyle;
  WOAssociation  *contentStyle;
  WOAssociation  *titleColor;   // DEPRECATED
  WOAssociation  *contentColor; // DEPRECATED
  
  WOAssociation  *width;
  WOAssociation  *border;
  WOAssociation  *cellpadding;
  WOAssociation  *cellspacing;

  WOAssociation  *footerRows; // list of elements for footer rows
  WOAssociation  *footerRow;  // current element in footer row
  WOAssociation  *headerRows; // list of elements for header rows
  WOAssociation  *headerRow;  // current element in header row
  WOAssociation  *colIndex;   // for header/footer row
  
  WOAssociation  *isInfoItem; // is current item info entry
  WOAssociation  *infoItems;  // current info entries
  
  WOAssociation  *hideWeekend; /* should Sa/So be rendered? */

@private
  NSMutableArray *matrix[14];
  NSMutableArray *infos[14];
  BOOL           hasOwnTitle;
  
  WOElement      *template;
}
@end

#include <math.h> /* Needed for floor() */
#include "common.h"

@interface WOContext(WEWeekOverview)

- (void)appendWEIntElementID:(int)_intID;

- (void)enterWEWOMode:(NSString *)_mode elementID:(NSString *)_eid;
- (void)leaveWEWOMode:(NSString *)_mode;

@end

static NSString *retStrForInt(int i);
static NSString *WEInfoElementID = @"i";

@implementation WOContext(WEWeekOverview)

- (void)appendWEIntElementID:(int)_intID {
  NSString *s;
  // TODO: could make the number switch in here?
  
  s = retStrForInt(_intID);
  [self appendElementIDComponent:s];
  [s release];
}

- (void)enterWEWOMode:(NSString *)_mode elementID:(NSString *)_eid {
  [self setObject:@"YES" forKey:_mode];
  [self appendElementIDComponent:_eid];
}
- (void)leaveWEWOMode:(NSString *)_mode {
  [self deleteLastElementIDComponent]; // delete eid
  [self removeObjectForKey:_mode];
}

@end /* WOContext(WEWeekOverview) */

@implementation WEWeekOverview

// premature: don't know a "good" count
static NSNumber *smap[10] = { nil,nil,nil,nil,nil,nil,nil,nil,nil,nil };
static Class    NumClass  = Nil;
static Class    StrClass  = Nil;
static NSArray  *emptyArray = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  int i;
  if (didInit) return;
  didInit = YES;
  
  StrClass = [NSString class];
  NumClass = [NSNumber class];
  for (i = 0; i < 10; i++)
    smap[i] = [[NumClass numberWithInt:i] retain];
  
  if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
}

static NSNumber *numForInt(int i) {
  if (i >= 0 && i < 10)
    return smap[i];
  return [NumClass numberWithInt:i];
}
static NSString *retStrForInt(int i) {
  switch(i) {
  case 0:  return @"0";
  case 1:  return @"1";
  case 2:  return @"2";
  case 3:  return @"3";
  case 4:  return @"4";
  case 5:  return @"5";
  case 6:  return @"6";
  case 7:  return @"7";
  case 8:  return @"8";
  case 9:  return @"9";
  case 10: return @"10";
    // TODO: find useful count!
  default: {
    char buf[16];
    sprintf(buf, "%i", i);
    return [[StrClass alloc] initWithCString:buf];
  }
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->list         = WOExtGetProperty(_config, @"list");
    self->item         = WOExtGetProperty(_config, @"item");
    self->index        = WOExtGetProperty(_config, @"index");
    self->identifier   = WOExtGetProperty(_config, @"identifier");
    self->dayIndex     = WOExtGetProperty(_config, @"dayIndex");
    self->weekStart    = WOExtGetProperty(_config, @"weekStart");
    self->startDateKey = WOExtGetProperty(_config, @"startDateKey");
    self->endDateKey   = WOExtGetProperty(_config, @"endDateKey");
    self->hideWeekend  = WOExtGetProperty(_config, @"hideWeekend");

    self->titleColor   = WOExtGetProperty(_config, @"titleColor");
    self->titleStyle   = WOExtGetProperty(_config, @"titleStyle");
    self->contentColor = WOExtGetProperty(_config, @"contentColor");
    self->contentStyle = WOExtGetProperty(_config, @"contentStyle");
    
    self->width        = WOExtGetProperty(_config, @"width");
    self->border       = WOExtGetProperty(_config, @"border");
    self->cellspacing  = WOExtGetProperty(_config, @"cellspacing");
    self->cellpadding  = WOExtGetProperty(_config, @"cellpadding");

    self->headerRows   = WOExtGetProperty(_config, @"headerRows");
    self->headerRow    = WOExtGetProperty(_config, @"headerRow");
    self->footerRows   = WOExtGetProperty(_config, @"footerRows");
    self->footerRow    = WOExtGetProperty(_config, @"footerRow");
    self->colIndex     = WOExtGetProperty(_config, @"columnIndex");

    
    if (self->startDateKey == nil) {
      self->startDateKey = 
        [[WOAssociation associationWithValue:@"startDate"] retain];
    }

    if (self->endDateKey == nil) {
      self->endDateKey = 
        [[WOAssociation associationWithValue:@"endDate"] retain];
    }
    
    if (self->width == nil)
      self->width = [[WOAssociation associationWithValue:@"100%"] retain];
    if (self->border == nil)
      self->border = [[WOAssociation associationWithValue:@"0"] retain];
    if (self->cellspacing == nil)
      self->cellspacing = [[WOAssociation associationWithValue:@"2"] retain];
    if (self->cellpadding == nil)
      self->cellpadding = [[WOAssociation associationWithValue:@"5"] retain];
    
    self->isInfoItem = WOExtGetProperty(_config, @"isInfoItem");
    self->infoItems  = WOExtGetProperty(_config, @"infoItems");

    self->template = [_tmp retain];    
  }
  return self;
}

- (void)resetMatrix {
  int i;
  
  for (i = 0; i < 14; i++) {
    [self->matrix[i] release]; self->matrix[i] = nil;
    [self->infos[i]  release]; self->infos[i]  = nil;
  }
}

- (void)dealloc {
  [self->hideWeekend  release];
  [self->list         release];
  [self->item         release];
  [self->index        release];
  [self->identifier   release];
  [self->dayIndex     release];
  [self->weekStart    release];
  [self->startDateKey release];
  [self->endDateKey   release];
  [self->titleColor   release];
  [self->titleStyle   release];
  [self->contentColor release];
  [self->contentStyle release];
  [self->width        release];
  [self->border       release];
  [self->cellpadding  release];
  [self->cellspacing  release];
  [self->headerRows   release];
  [self->headerRow    release];
  [self->footerRows   release];
  [self->footerRow    release];
  [self->colIndex     release];
  [self->infoItems    release];
  [self->isInfoItem   release];

  [self resetMatrix];

  [self->template release];
  
  [super dealloc];
}

static inline void
_applyIdentifier(WEWeekOverview *self, WOComponent *comp, NSString *_idx)
{
  NSArray *array;
  unsigned count, cnt;

  array = [self->list valueInComponent:comp];
  count = [array count];

  if (count == 0)
    return;
    
  /* find subelement for unique id */
    
  for (cnt = 0; cnt < count; cnt++) {
    NSString *ident;
      
    if (self->index)
      [self->index setUnsignedIntValue:cnt inComponent:comp];

    if (self->item)
      [self->item setValue:[array objectAtIndex:cnt] inComponent:comp];

    ident = [self->identifier stringValueInComponent:comp];

    if ([ident isEqualToString:_idx]) {
      /* found subelement with unique id */
      return;
    }
  }
    
  [comp logWithFormat:
	  @"WEWeekOverview: array did change, "
	  @"unique-id isn't contained."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}

static inline void
_applyIndex(WEWeekOverview *self, WOComponent *comp, unsigned _idx)
{
  NSArray  *array;
  unsigned count;
  
  array = [self->list valueInComponent:comp];
  
  if (self->index)
    [self->index setUnsignedIntValue:_idx inComponent:comp];

  if (self->item == nil)
    return;
  
  count = [array count];
  if (_idx < count) {
    [self->item setValue:[array objectAtIndex:_idx] inComponent:comp];
    return;
  }

  [comp logWithFormat:
            @"WEWeekOverview: array did change, index is invalid."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}

- (void)_calcMatrixInContext:(WOContext *)_ctx {
  // THREAD: uses temporary ivars
  WOComponent    *comp;
  NSCalendarDate *startWeek;
  NSCalendarDate *endWeek;
  NSArray        *array;
  NSString       *startKey;
  NSString       *endKey;
  int            i, idx, idx2, cnt;
  
  [self resetMatrix];

  [_ctx removeObjectForKey:WEWeekOverview_TitleModeDidMatch];
  [_ctx setObject:@"YES" forKey:WEWeekOverview_TitleMode];
  [self->template appendToResponse:nil inContext:_ctx];
  [_ctx removeObjectForKey:WEWeekOverview_TitleMode];
  
  if ([_ctx objectForKey:WEWeekOverview_TitleModeDidMatch] != nil)
    self->hasOwnTitle = YES;
  else
    self->hasOwnTitle = NO;
  
  comp      = [_ctx component];
  array     = [self->list valueInComponent:comp];
  startKey  = [self->startDateKey stringValueInComponent:comp];
  endKey    = [self->endDateKey   stringValueInComponent:comp];
  startWeek = (self->weekStart)
    ? [self->weekStart valueInComponent:comp]
    : [NSCalendarDate calendarDate];
  endWeek   = [startWeek addTimeInterval:SecondsPerWeek];
  
  for (i = 0, cnt = [array count]; i < cnt; i++) {
    id             app;
    NSCalendarDate *sd, *ed;
    NSTimeInterval diff;
    BOOL           isInfo;
    
    app = [array objectAtIndex:i];
#if 0 // hh: so muesste es eigentlich sein: !!!
    [self->item setValue:app inComponent:comp];
    
    sd = [self->startDate valueInComponent:comp]; // item.startDate;
    ed = [self->endDate   valueInComponent:comp]; // item.startDate;
#endif
    
    sd  = [app valueForKey:startKey]; // startDate
    ed  = [app valueForKey:endKey];   // endDate

    if ((sd == nil) && (ed == nil)) continue;
    
    diff  = [(sd ? sd : ed) timeIntervalSinceDate:startWeek];

    idx = floor((diff / SecondsPerWeek) * 14);

    if ((self->item != nil) && (self->isInfoItem)) {
      [self->item setValue:app inComponent:comp];
      isInfo = [[self->isInfoItem valueInComponent:comp] boolValue];
    }
    else 
      isInfo = NO;
    
    if ((0 <= idx) && (idx < 14)) {      
      if (isInfo) {
        if (self->infos[idx] == nil)
          self->infos[idx] = [[NSMutableArray alloc] initWithCapacity:2];      
        [self->infos[idx] addObject:numForInt(i)];
      }
      else {
        if (self->matrix[idx] == nil)
          self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];
        [self->matrix[idx] addObject:numForInt(i)];       
      }
    }
    if (idx >= 0)
      idx = (idx % 2) ? idx + 1: idx +2;
    
    diff = [ed timeIntervalSinceDate:startWeek];
    
    idx2 = floor((diff / SecondsPerWeek) * 14);
    idx2 = (idx2 > 13) ? 13 : idx2;

    if (idx2 < 0) continue;
    
    while (idx <= idx2) {
      idx = (idx < 0) ? 0 : idx;
      if (isInfo) {
        if (self->infos[idx] == nil)
          self->infos[idx] = [[NSMutableArray alloc] initWithCapacity:2];      
        // TODO: optimize
        [self->infos[idx] addObject:numForInt(i)];
      }
      else {
        if (self->matrix[idx] == nil)
          self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];
        // TODO: optimize
        [self->matrix[idx] addObject:numForInt(i)];       
      }
      idx = idx + 2;
    }
  }
}

/* common template operations */

- (void)appendTemplateToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx
  mode:(NSString *)_mode elementID:(NSString *)_modeId
  index:(int)_idx
{
  [_ctx enterWEWOMode:_mode elementID:_modeId];
  [_ctx appendWEIntElementID:_idx];
  [self->template appendToResponse:_r inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete idx
  [_ctx leaveWEWOMode:_mode];
}

/* header rows */

- (void)appendHeaderRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  column:(int)_col
{
  WOComponent *comp;
  NSString    *bgcolor, *style;
  
  comp = [_ctx component];

  if ([self->colIndex isValueSettable])
    [self->colIndex setIntValue:_col inComponent:comp];

  bgcolor = [self->contentColor stringValueInComponent:comp];
  style   = [self->contentStyle stringValueInComponent:comp];
  
  [_response appendContentString:
             @"<td valign=\"top\" align=\"left\" width=\"17%\""];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  if ([style isNotEmpty]) {
    [_response appendContentString:@" class=\""];
    [_response appendContentString:style];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];

  [self appendTemplateToResponse:_response inContext:_ctx
	mode:WEWeekOverview_HeaderRowMode elementID:@"h"
	index:_col];
  
  [_response appendContentString:@"</td>"];
}
- (void)appendHeaderRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  row:(id)_rowItem
{
  int i, cnt;
  
  if ([self->headerRow isValueSettable])
    [self->headerRow setValue:_rowItem inComponent:[_ctx component]];
  
  /* Saturday/Sunday is the 6th column */
  cnt = (self->hideWeekend != nil)
    ? [self->hideWeekend boolValueInComponent:[_ctx component]] ? 5 : 6
    : 6;
  
  for (i = 0; i < cnt; i++)
    [self appendHeaderRowToResponse:_response inContext:_ctx column:i];
}
- (void)appendHeaderRowsToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  /* add n <tr> rows */
  WOComponent *comp;
  NSArray     *headers;
  int         cnt, i;
  
  comp = [_ctx component];
  if ((headers = [self->headerRows valueInComponent:comp]) == nil)
    return;
  
  for (i = 0, cnt = [headers count]; i < cnt; i++) {
    id one;
    
    one = [headers objectAtIndex:i];
      
    [_response appendContentString:@"<tr>"];
    [_ctx appendElementIDComponent:@"hr"]; // header row
    [_ctx appendWEIntElementID:i];
    
    [self appendHeaderRowToResponse:_response inContext:_ctx row:one];
      
    [_ctx deleteLastElementIDComponent]; // remove idx (i)
    [_ctx deleteLastElementIDComponent]; // remove 'hr'
    [_response appendContentString:@"</tr>"];
  }
}

/* footer rows */

- (void)appendFooterRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  column:(int)_col
{
  WOComponent *comp;
  NSString    *bgcolor;
  
  comp = [_ctx component];
  
  if ([self->colIndex isValueSettable])
    [self->colIndex setIntValue:_col inComponent:comp];
  
  bgcolor = [self->contentColor stringValueInComponent:comp];
  
  [_response appendContentString:
             @"<td valign=\"top\" align=\"left\" width=\"17%\""];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];

  [self appendTemplateToResponse:_response inContext:_ctx
	mode:WEWeekOverview_FooterRowMode elementID:@"f"
	index:_col];
  
  [_response appendContentString:@"</td>"];
}

- (void)appendFooterRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  row:(id)_rowItem
{
  // TODO: this method is a DUP to appendHeaderRowToResponse... => refactor
  int i, cnt;
  
  if ([self->footerRow isValueSettable])
    [self->footerRow setValue:_rowItem inComponent:[_ctx component]];
  
  /* Saturday/Sunday is the 6th column */
  cnt = (self->hideWeekend != nil)
    ? [self->hideWeekend boolValueInComponent:[_ctx component]] ? 5 : 6
    : 6;
  
  for (i = 0; i < cnt; i++) 
    [self appendFooterRowToResponse:_response inContext:_ctx column:i];
}

- (void)appendFooterRowsToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  // TODO: this is a copy of the head-row method!
  WOComponent *comp;
  NSArray     *footers;
  int i, cnt;

  comp = [_ctx component];

  if ((footers = [self->footerRows valueInComponent:comp]) == nil)
    return;

  for (i = 0, cnt = [footers count]; i < cnt; i++) {
    NSString *s;
    id one;

    one = [footers objectAtIndex:i];
      
    [_response appendContentString:@"<tr>"];
    [_ctx appendElementIDComponent:@"fr"];

    s = retStrForInt(i);
    [_ctx appendElementIDComponent:s];
    [s release];
      
    [self appendFooterRowToResponse:_response inContext:_ctx row:one];
      
    [_ctx deleteLastElementIDComponent]; // remove idx (i)
    [_ctx deleteLastElementIDComponent]; // remove 'fr'
    [_response appendContentString:@"</tr>"];
  }
}

- (void)appendDateTitleToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  day:(int)_day
{
  WOComponent *comp;
  NSString    *bgcolor, *style;

  comp = [_ctx component];
  
  if ([self->dayIndex isValueSettable])
    [self->dayIndex setIntValue:_day inComponent:comp];

  bgcolor = [self->titleColor stringValueInComponent:comp];
  style   = [self->titleStyle stringValueInComponent:comp];
  
  // TODO: use CSS for alignment, width and color
  [_response appendContentString:
             @"<td valign=\"top\" align=\"left\" width=\"17%\""];
  if ([bgcolor isNotEmpty]) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  if ([style isNotEmpty]) {
    [_response appendContentString:@" class=\""];
    [_response appendContentString:style];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];
  
  if (self->hasOwnTitle) {
    [self appendTemplateToResponse:_response inContext:_ctx
	  mode:WEWeekOverview_TitleMode elementID:@"t"
	  index:_day];
  }
  else {
    NSCalendarDate *date;
    NSString *s;
    
    date = (self->weekStart)
      ? [self->weekStart valueInComponent:comp]
      : [NSCalendarDate calendarDate];
    date = [date addTimeInterval:_day * SecondsPerDay];
    
    [_response appendContentString:
               @"<table cellpadding=\"0\" width=\"100%\" border=\"0\" "
	       @"cellspacing=\"0\">"
               @"<tr>"
               @"<td align=\"left\" valign=\"top\">"
	       // TODO: use style for that
               @"<font color=\"black\" size=\"+2\"><b>"];
    
    s = [date descriptionWithCalendarFormat:@"%d"]; // TODO: no cal-desc!
    [_response appendContentString:s];
    
    [_response appendContentString:
               @"</b></font></td>"
               @"<td align=\"center\" valign=\"top\">"
	       // TODO: use style for that
               @"<font color=\"black\">"];
    s = [date descriptionWithCalendarFormat:@"%A"]; // TODO: no cal-desc
    [_response appendContentString:s]; // TODO: do not use cal-desc
    [_response appendContentString:
               @"</font>"
               @"</td></tr></table>"];
  }
  [_response appendContentString:@"</td>"];
}

- (void)appendContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  index:(int)_index
{
  WOComponent *comp;
  NSArray     *array;
  id          app;
  int         i, cnt, idx, count;
  
  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];

  /* idx is the dayIndex 0=1stDay ... 6=7thDay (e.g. 0=Mon ... 6=Sun) */
  idx = (int)(_index / 2);
  
  if ([self->dayIndex isValueSettable])
    [self->dayIndex setIntValue:idx inComponent:comp];

  if ([self->infoItems isValueSettable]) {
    cnt = [self->infos[_index] count];
    if (cnt) {
      NSMutableArray *infoArr;
      
      infoArr = [[NSMutableArray alloc] initWithCapacity:cnt];
      for (i = 0; i < cnt; i++) {
        idx = [[self->infos[_index] objectAtIndex:i] intValue];
        
        if (idx >= count) {
          [self logWithFormat:
		  @"WARNING: WEWeekOverview: info index out of range"];
          continue;
        }
        [infoArr addObject:[array objectAtIndex:idx]];
      }
      [self->infoItems setValue:infoArr inComponent:comp];
      [infoArr release]; infoArr = nil;
    }
    else
      [self->infoItems setValue:emptyArray inComponent:comp];
  }

  // *** append day info
  if ((_index % 2) == 0) {
    // if AM-section...
    
    [self appendTemplateToResponse:_response inContext:_ctx
	  mode:WEWeekOverview_InfoMode elementID:WEInfoElementID
	  index:idx];
  }
  else if (_index < 10) {
    /*  P.M. slot of Monday .. Friday */
    [self appendTemplateToResponse:_response inContext:_ctx
	  mode:WEWeekOverview_PMInfoMode elementID:@"p"
	  index:idx];
  }
  
  // *** append day content
  [_ctx enterWEWOMode:WEWeekOverview_ContentMode elementID:@"c"];
  
  // append section id (0 = Mon AM, 1 = Mon PM, 2 = Tue AM, ...)
  [_ctx appendWEIntElementID:_index];
  
  for (i = 0, cnt = [self->matrix[_index] count]; i < cnt; i++) {
    idx = [[self->matrix[_index] objectAtIndex:i] intValue];

    if (idx >= count) {
      NSLog(@"Warning! WEWeekOverview: index out of range");
      continue;
    }
    
    app = [array objectAtIndex:idx];

    if ([self->item isValueSettable])
      [self->item  setValue:app inComponent:comp];
    if ([self->index isValueSettable])
      [self->index setIntValue:idx inComponent:comp];

    if (self->identifier == nil) {
      NSString *s;
      
      s = retStrForInt(idx);
      [_ctx appendElementIDComponent:s];
      [s release];
    }
    else {
      NSString *s;

      s = [self->identifier stringValueInComponent:comp];
      [_ctx appendElementIDComponent:s];
    }
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  if (cnt == 0)
    [_response appendContentString:@"&nbsp;"];
  
  [_ctx deleteLastElementIDComponent]; // delete section id
  [_ctx leaveWEWOMode:WEWeekOverview_ContentMode];
}

/* processing requests */

- (void)takeValuesForHeaderRows:(WORequest *)_req
  ctx:(WOContext *)_ctx
{
  WOComponent *comp;
  NSArray     *headers;
  int i, cnt;

  comp    = [_ctx component];
  if ((headers = [self->headerRows valueInComponent:comp]) == nil)
    return;

  [_ctx setObject:@"YES" forKey:WEWeekOverview_HeaderRowMode];
  [_ctx appendElementIDComponent:@"hr"]; // append 'hr'
  [_ctx appendZeroElementIDComponent];   // append i

  for (i = 0, cnt = [headers count]; i < cnt; i++) {
    int c;

    [_ctx appendElementIDComponent:@"h"]; // append 'h'
    [_ctx appendZeroElementIDComponent];  // append c
      
    if ([self->headerRow isValueSettable])
      [self->headerRow setValue:[headers objectAtIndex:i] inComponent:comp];
      
    // TODO: do not go over Saturday (6) with hideWeekend=YES
    for (c = 0; c < 6; c++) { // go throw columns
      if ([self->colIndex isValueSettable])
	[self->colIndex setIntValue:c inComponent:comp];
        
      [self->template takeValuesFromRequest:_req inContext:_ctx];
      [_ctx incrementLastElementIDComponent]; // increment c
    }
      
    [_ctx deleteLastElementIDComponent];    // delete c
    [_ctx deleteLastElementIDComponent];    // delete 'h'
    [_ctx incrementLastElementIDComponent]; // increment i
  }
  
  [_ctx deleteLastElementIDComponent]; // remove i
  [_ctx deleteLastElementIDComponent]; // remove 'hr'
  [_ctx removeObjectForKey:WEWeekOverview_HeaderRowMode];
}
- (void)takeValuesForFooterRows:(WORequest *)_req
  ctx:(WOContext *)_ctx
{
  // TODO: this is a DUP of the header row
  //       we might implement that code as an internal WODynamicElement?
  WOComponent *comp;
  NSArray     *footers;
  int i, cnt;

  comp    = [_ctx component];
  if ((footers = [self->footerRows valueInComponent:comp]) == nil)
    return;

  [_ctx setObject:@"YES" forKey:WEWeekOverview_FooterRowMode];
  [_ctx appendElementIDComponent:@"hr"]; // append 'fr'
  [_ctx appendZeroElementIDComponent];   // append i
  
  for (i = 0, cnt = [footers count]; i < cnt; i++) {
      int c;
      [_ctx appendElementIDComponent:@"f"]; // append 'f'
      [_ctx appendZeroElementIDComponent];  // append c
      
      if ([self->footerRow isValueSettable])
        [self->footerRow setValue:[footers objectAtIndex:i] inComponent:comp];
      
      // TODO: do not go over Saturday (6) with hideWeekend=YES
      for (c = 0; c < 6; c++) { // go throw columns
        if ([self->colIndex isValueSettable])
          [self->colIndex setIntValue:c inComponent:comp];
        [self->template takeValuesFromRequest:_req inContext:_ctx];
        [_ctx incrementLastElementIDComponent]; // increment c
      }
      
      [_ctx deleteLastElementIDComponent];    // delete c
      [_ctx deleteLastElementIDComponent];    // delete 'f'
      [_ctx incrementLastElementIDComponent]; // increment i
  }

  [_ctx deleteLastElementIDComponent]; // remove i
  [_ctx deleteLastElementIDComponent]; // remove 'fr'
  [_ctx removeObjectForKey:WEWeekOverview_FooterRowMode];
}

- (void)takeValues:(WORequest *)_req
  mode:(NSString *)_mode modeId:(NSString *)_id
  ctx:(WOContext *)_ctx
{
  int i;
  
  [_ctx setObject:@"YES" forKey:_mode];
  [_ctx appendElementIDComponent:_id];   // append mode id
  [_ctx appendZeroElementIDComponent];   // append first day (monday)
  
  // TODO: do not go over Saturday (5), Sunday(6) with hideWeekend=YES
  for (i = 0; i < 7; i++) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:i inComponent:[_ctx component]];
    
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx incrementLastElementIDComponent]; // increment day
  }
  [_ctx deleteLastElementIDComponent];  // delete day
  [_ctx deleteLastElementIDComponent];  // delete title mode
  [_ctx removeObjectForKey:_mode];
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSArray     *array;
  int         i, count;
  
  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];

  /* titles */
  [self takeValues:_req mode:WEWeekOverview_TitleMode modeId:@"t" ctx:_ctx];

  /* headers */
  [self takeValuesForHeaderRows:_req ctx:_ctx];
  
  /* infos */
  [self takeValues:_req mode:WEWeekOverview_InfoMode modeId:WEInfoElementID 
	ctx:_ctx];

  /* P.M.Infos */
  [self takeValues:_req mode:WEWeekOverview_PMInfoMode modeId:@"p" ctx:_ctx];

  // THREAD: uses temporary ivars
  [self _calcMatrixInContext:_ctx];

  [_ctx setObject:@"YES" forKey:WEWeekOverview_ContentMode];
  [_ctx appendElementIDComponent:@"c"]; // append content mode
  [_ctx appendZeroElementIDComponent];  // append section-id
  for (i = 0; i < 14; i++) {
    int     j, cnt, idx;
    
    cnt   = [self->matrix[i] count];
    
    if ((i % 2) == 0 && [self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:(int)(i / 2) inComponent:comp];
    
    for (j = 0; j < cnt; j++) {
      NSString *s;
      
      idx = [[self->matrix[i] objectAtIndex:j] intValue];
      
      if (idx >= count) {
        NSLog(@"Warning! WEWeekRepetition: Index is out of range");
        continue;
      }
      
      _applyIndex(self, comp, idx);
      
      if (self->identifier) {
        s = [self->identifier stringValueInComponent:comp];
        [_ctx appendElementIDComponent:s];
      }
      else {
        s = retStrForInt(idx);
        [_ctx appendElementIDComponent:s];
        [s release];
      }

      [self->template takeValuesFromRequest:_req inContext:_ctx];
      
      [_ctx deleteLastElementIDComponent];   // delete index-id
    }
    [_ctx incrementLastElementIDComponent]; // increase section-id
  }
  [_ctx deleteLastElementIDComponent];  // delete section-id
  [_ctx deleteLastElementIDComponent];  // delete content mode
  [_ctx removeObjectForKey:WEWeekOverview_ContentMode];
  
  /* footers */
  [self takeValuesForFooterRows:_req ctx:_ctx];

  [self resetMatrix];  
}

- (id)invokeActionForHeader:(WORequest *)_req inContext:(WOContext *)_ctx
  row:(id)_row
{
  WOComponent *comp;
  NSString *section;   // must be 'h'
  NSString *colIdx;    // must be between 0 and 6

  id result;

  comp = [_ctx component];

  section = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:section];
  colIdx  = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:colIdx];

  if ([self->headerRow isValueSettable])
    [self->headerRow setValue:_row inComponent:comp];
  if ([self->dayIndex isValueSettable])
    [self->colIndex setIntValue:[colIdx intValue] inComponent:comp];

  result = [self->template invokeActionForRequest:_req inContext:_ctx];

  [_ctx deleteLastElementIDComponent]; // column idx
  [_ctx deleteLastElementIDComponent]; // section ('h')

  return result;
}
- (id)invokeActionForFooter:(WORequest *)_req inContext:(WOContext *)_ctx
  row:(id)_row
{
  WOComponent *comp;
  NSString *section;   // must be 'f'
  NSString *colIdx;    // must be between 0 and 6

  id result;

  comp = [_ctx component];

  section = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:section];
  colIdx  = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:colIdx];

  if ([self->footerRow isValueSettable])
    [self->footerRow setValue:_row inComponent:comp];
  if ([self->dayIndex isValueSettable])
    [self->colIndex setIntValue:[colIdx intValue] inComponent:comp];

  result = [self->template invokeActionForRequest:_req inContext:_ctx];

  [_ctx deleteLastElementIDComponent]; // column idx
  [_ctx deleteLastElementIDComponent]; // section ('f')

  return result;
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *comp;
  id          result = nil;
  NSString    *cid;
  NSString    *sectionId;

  cid = [_ctx currentElementID];       // get mode ("t" or "i" or "c")
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:cid];
  sectionId = [_ctx currentElementID];       // get section id
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:sectionId];

  comp = [_ctx component];

  if ([cid isEqualToString:@"t"] ||
      [cid isEqualToString:WEInfoElementID] || [cid isEqualToString:@"p"]) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:[sectionId intValue] inComponent:comp];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  else if ([cid isEqualToString:@"c"]) {
    NSString *idxId;

    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:([sectionId intValue] / 2) inComponent:comp];

    if ((idxId = [_ctx currentElementID])) {
      [_ctx consumeElementID];               // consume index-id
      [_ctx appendElementIDComponent:idxId];

      if (self->identifier)
        _applyIdentifier(self, comp, idxId);
      else
        _applyIndex(self, comp, [idxId intValue]);

      result = [self->template invokeActionForRequest:_req inContext:_ctx];

      [_ctx deleteLastElementIDComponent]; // delete index-id
    }
  }
  else if ([cid isEqualToString:@"hr"]) {
    NSArray  *headers;
    int      idx;

    headers = [self->headerRows valueInComponent:comp];
    idx     = [sectionId intValue];
    if (idx >= (int)[headers count]) {
      [self warnWithFormat:@"WEWeekOverview: wrong headerrow index"];
    }
    else {
      result = [self invokeActionForHeader:_req
                     inContext:_ctx
                     row:[headers objectAtIndex:idx]];
    }
  }
  else if ([cid isEqualToString:@"fr"]) {
    NSArray  *footers;
    int      idx;

    footers = [self->footerRows valueInComponent:comp];
    idx     = [sectionId intValue];
    if (idx >= (int)[footers count]) {
      [self warnWithFormat:@"WEWeekOverview: wrong footerrow index"];
    }
    else {
      result = [self invokeActionForFooter:_req
                     inContext:_ctx
                     row:[footers objectAtIndex:idx]];
    }
  }
  else
    NSLog(@"WARNING! WEWeekOverview: wrong section");

  [_ctx deleteLastElementIDComponent]; // delete section id
  [_ctx deleteLastElementIDComponent]; // delete mode
  
  return result;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSString    *bgcolor, *style;
  NSString    *w;  // width
  NSString    *b;  // border
  NSString    *cp; // cellpadding
  NSString    *cs; // cellspacing
  int         i;
  BOOL        showWeekend;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [self _calcMatrixInContext:_ctx];
  
  comp = [_ctx component];
  w    = [self->width       stringValueInComponent:comp];
  b    = [self->border      stringValueInComponent:comp];
  cs   = [self->cellspacing stringValueInComponent:comp];
  cp   = [self->cellpadding stringValueInComponent:comp];
  
  showWeekend = (self->hideWeekend != nil)
    ? [self->hideWeekend boolValueInComponent:comp] ? NO : YES
    : YES;

  // TODO: use CSS over here
  [_response appendContentString:
             @"<table border=\""];
  [_response appendContentString:b];  // border
  [_response appendContentString:@"\" cellpadding=\""];
  [_response appendContentString:cp]; // cellspacing
  [_response appendContentString:@"\" width=\""];
  [_response appendContentString:w];  // width
  [_response appendContentString:@"\" cellspacing=\""];
  [_response appendContentString:cs]; // cellspaing
  [_response appendContentString:@"\">"];
  
  /*** append title row (monday - saturday) ***/
  [_response appendContentString:@"<tr>"];
  for (i = 0; i < (showWeekend ? 6 : 5 ); i++)
    [self appendDateTitleToResponse:_response inContext:_ctx day:i];
  [_response appendContentString:@"</tr>"];
  
  /**** header rows ****/
  [self appendHeaderRowsToResponse:_response inContext:_ctx];

  /*** append AM content row + saturday ***/
  [_response appendContentString:@"<tr>"];
  
  /* AM weekdays content (this is count=10 because we slot 0=AM/1=PM, etc) */
  for (i = 0; i < 10; i = i + 2) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:(i / 2) inComponent:comp];

    [_response appendContentString:@"<td valign=\"top\""];
    if ((bgcolor = [self->contentColor stringValueInComponent:comp])) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bgcolor];
      [_response appendContentCharacter:'"'];
    }
    if ((style = [self->contentStyle stringValueInComponent:comp])) {
      [_response appendContentString:@" class=\""];
      [_response appendContentString:style];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    [self appendContentToResponse:_response inContext:_ctx index:i];
    [_response appendContentString:@"</td>"];
  }
  /* saturday content */
  if (showWeekend) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:5 inComponent:comp];

    [_response appendContentString:@"<td valign=\"top\""];
  
    if ((bgcolor = [self->contentColor stringValueInComponent:comp])) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bgcolor];
      [_response appendContentCharacter:'"'];
    }
    if ((style = [self->contentStyle stringValueInComponent:comp])) {
      [_response appendContentString:@" class=\""];
      [_response appendContentString:style];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    
    /* 10 is Saturday AM, 11 is Saturday PM, week overview shows them in one */
    [self appendContentToResponse:_response inContext:_ctx index:10];
    [self appendContentToResponse:_response inContext:_ctx index:11];
    [_response appendContentString:@"</td>"];
  }
  
  [_response appendContentString:@"</tr>"]; /* close AM row */

  /*** append PM content row + sunday ***/
  [_response appendContentString:@"<tr>"];

  /* PM weekdays content */
  for (i = 1; i < 11; i = i + 2) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:(i/2) inComponent:comp];
      
    [_response appendContentString:@"<td valign=\"top\""];
    
    if (showWeekend) /* for Sunday we need an additional <tr> */
      [_response appendContentString:@" rowspan=\"2\""]; 
    
    if ((bgcolor = [self->contentColor stringValueInComponent:comp])) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bgcolor];
      [_response appendContentCharacter:'"'];
    }
    if ((style = [self->contentStyle stringValueInComponent:comp])) {
      [_response appendContentString:@" class=\""];
      [_response appendContentString:style];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];

      
    [self appendContentToResponse:_response inContext:_ctx index:i];
    [_response appendContentString:@"</td>"];
  }

  if (showWeekend) {
    /* sunday title */
    [self appendDateTitleToResponse:_response inContext:_ctx day:6];
    [_response appendContentString:@"</tr>"];

    /*  sunday row */
    [_response appendContentString:@"<tr>"];

    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:6 inComponent:comp];
  
    [_response appendContentString:@"<td valign=\"top\""];
    if ((bgcolor = [self->contentColor stringValueInComponent:comp])) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bgcolor];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    
    /* 12 is Sunday/AM, 13 is Sunday/PM */
    [self appendContentToResponse:_response inContext:_ctx index:12];
    [self appendContentToResponse:_response inContext:_ctx index:13];
    [_response appendContentString:@"</td>"];
  }
  
  [_response appendContentString:@"</tr>"]; /* close PM row */

  /***** footer rows *****/
  [self appendFooterRowsToResponse:_response inContext:_ctx];

  [_response appendContentString:@"</table>"];

  [self resetMatrix];
}

@end /* WeekOverview */

@interface WEWeekOverviewTitleMode : WEContextConditional
@end

@implementation WEWeekOverviewTitleMode
- (NSString *)_contextKey {
  return WEWeekOverview_TitleMode;
}

- (NSString *)_didMatchKey {
  return WEWeekOverview_TitleModeDidMatch;
}
@end /* WEWeekOverviewTitleMode */

// --

@interface WEWeekOverviewInfoMode : WEContextConditional
@end

@implementation WEWeekOverviewInfoMode
- (NSString *)_contextKey {
  return WEWeekOverview_InfoMode;
}
@end /* WEWeekOverviewInfoMode */

// --

@interface WEWeekOverviewContentMode : WEContextConditional
@end

@implementation WEWeekOverviewContentMode
- (NSString *)_contextKey {
  return WEWeekOverview_ContentMode;
}
@end /* WEWeekOverview_ContentMode */

// --

@interface WEWeekOverviewPMInfoMode : WEContextConditional
@end

@implementation WEWeekOverviewPMInfoMode
- (NSString *)_contextKey {
  return WEWeekOverview_PMInfoMode;
}
@end /* WEWeekOverviewPMInfoMode */

@interface WEWeekOverviewHeaderMode : WEContextConditional
@end

@implementation WEWeekOverviewHeaderMode
- (NSString *)_contextKey {
  return WEWeekOverview_HeaderRowMode;
}
@end /* WEWeekOverviewHeaderMode */

@interface WEWeekOverviewFooterMode : WEContextConditional
@end

@implementation WEWeekOverviewFooterMode
- (NSString *)_contextKey {
  return WEWeekOverview_FooterRowMode;
}
@end /* WEWeekOverviewFooterMode */
