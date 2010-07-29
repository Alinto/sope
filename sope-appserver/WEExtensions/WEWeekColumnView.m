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
    draws this:
    
      |---------------|---------------|
      |Mo  <content>  | Do  <content> |             
      |               |               |
      |               |               |
      |---------------|---------------|
      |Di  <content>  | Fr  <content> |             
      |               |               |
      |               |               |
      |---------------|---------------|
      |Mi  <content>  | Sa  <content> |             
      |               |---------------|
      |               | So  <content> |
      |---------------|---------------|
*/

#define SecondsPerWeek (7 * 24 * 60 * 60)
#define SecondsPerDay      (24 * 60 * 60)
#define MatrixSections  7

@class NSMutableArray;


#define WEWeekColumnView_TitleMode         @"WEWeekColumnView_TitleMode"
#define WEWeekColumnView_TitleModeDidMatch @"WEWeekColumnView_TitleModeMatched"
#define WEWeekColumnView_InfoMode          @"WEWeekColumnView_InfoMode"
#define WEWeekColumnView_ContentMode       @"WEWeekColumnView_ContentMode"

@interface WEWeekColumnView : WODynamicElement
{
@protected
  WOAssociation  *list;
  WOAssociation  *item;
  WOAssociation  *index;
  WOAssociation  *identifier;
  
  WOAssociation  *dayIndex;
  WOAssociation  *weekStart;
  
  WOAssociation  *startDateKey;
  WOAssociation  *endDateKey;

  WOAssociation  *titleColor;
  WOAssociation  *contentColor;
  
  WOAssociation  *isInfoItem; // is current item info entry
  WOAssociation  *infoItems;  // current info entries
  
  WOAssociation  *hideWeekend; /* should Sa/So be rendered? */
  
@private
  NSMutableArray *matrix[MatrixSections];
  NSMutableArray *infos[MatrixSections];
  BOOL           hasOwnTitle;
  
  WOElement      *template;
}
@end

#include <math.h> /* Needed for floor() */
#include "common.h"

@implementation WEWeekColumnView

static Class StrClass = Nil;

+ (void)initialize {
  StrClass = [NSString class];
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
  default:
    return [[StrClass alloc] initWithFormat:@"%i", i];
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
    
    self->titleColor   = WOExtGetProperty(_config, @"titleColor");
    self->contentColor = WOExtGetProperty(_config, @"contentColor");
    
    self->hideWeekend  = WOExtGetProperty(_config, @"hideWeekend");

    if (self->startDateKey == nil) {
      self->startDateKey =
        [[WOAssociation associationWithValue:@"startDate"] retain];
    }
    if (self->endDateKey == nil) {
      self->endDateKey = 
        [[WOAssociation associationWithValue:@"endDate"] retain];
    }

    self->isInfoItem = WOExtGetProperty(_config, @"isInfoItem");
    self->infoItems  = WOExtGetProperty(_config, @"infoItems");
    
    ASSIGN(self->template, _tmp);    
  }
  return self;
}

- (void)resetMatrix {
  int i;
  
  for (i=0; i<MatrixSections; i++) {
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
  [self->contentColor release];
  [self->infoItems    release];
  [self->isInfoItem   release];

  [self resetMatrix];
  [self->template release];
  [super dealloc];
}

static inline void
_applyIdentifier(WEWeekColumnView *self, WOComponent *comp, NSString *_idx)
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
                  @"WEWeekColumnView: array did change, "
                  @"unique-id isn't contained."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}

static inline void
_applyIndex(WEWeekColumnView *self, WOComponent *comp, unsigned _idx)
{
  NSArray *array;
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
            @"WEWeekColumnView: array did change, index is invalid."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}

- (void)_calcMatrixInContext:(WOContext *)_ctx {
  WOComponent    *comp;
  NSCalendarDate *startWeek;
  NSArray        *array;
  NSString       *startKey;
  NSString       *endKey;
  int            i, idx, idx2, cnt;
  
  [self resetMatrix];

  [_ctx removeObjectForKey:WEWeekColumnView_TitleModeDidMatch];
  [_ctx setObject:@"YES" forKey:WEWeekColumnView_TitleMode];
  [self->template appendToResponse:nil inContext:_ctx];
  [_ctx removeObjectForKey:WEWeekColumnView_TitleMode];
  
  if ([_ctx objectForKey:WEWeekColumnView_TitleModeDidMatch] != nil)
    self->hasOwnTitle = YES;
  else
    self->hasOwnTitle = NO;
  
  comp      = [_ctx component];
  array     = [self->list valueInComponent:comp];
  startKey  = [self->startDateKey stringValueInComponent:comp];
  endKey    = [self->endDateKey   stringValueInComponent:comp];
  startWeek = (self->weekStart)
    ? [self->weekStart    valueInComponent:comp]
    : [NSCalendarDate calendarDate];
  
  for (i = 0, cnt = [array count]; i < cnt; i++) {
    id             app;
    NSCalendarDate *sd, *ed;
    NSTimeInterval diff;
    BOOL           isInfo;
    
    app = [array objectAtIndex:i];
    sd  = [app valueForKey:startKey]; // startDate
    ed  = [app valueForKey:endKey];   // endDate

    if ((sd == nil) && (ed == nil)) continue;

    if ((sd != nil) && (ed != nil) && [ed isEqual:[sd earlierDate:ed]]) {
      NSCalendarDate *tmp;

      tmp = sd;
      sd  = ed;
      ed  = tmp;
    }
    
    diff  = [(sd ? sd : ed) timeIntervalSinceDate:startWeek];
    
    idx = floor((diff / SecondsPerWeek) * MatrixSections);

    if ((self->item) && (self->isInfoItem)) {
      [self->item setValue:app inComponent:comp];
      isInfo = [[self->isInfoItem valueInComponent:comp] boolValue];
    }
    else isInfo = NO;

    if ((0 <= idx) && (idx < MatrixSections)) {
      if (isInfo) {
        if (self->infos[idx] == nil)
          self->infos[idx] = [[NSMutableArray alloc] initWithCapacity:2];      
        [self->infos[idx] addObject:[NSNumber numberWithInt:i]];
      }
      else {
        if (self->matrix[idx] == nil)
          self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];
        [self->matrix[idx] addObject:[NSNumber numberWithInt:i]];
      }
    }
    idx = (idx >= 0) ? idx+1 : idx;
    diff = [ed timeIntervalSinceDate:startWeek];
    
    idx2 = floor((diff / SecondsPerWeek) * MatrixSections);
    idx2 = (idx2 >= MatrixSections) ? (MatrixSections - 1) : idx2;

    if (idx2 < 0) continue;
    
    while (idx <= idx2) {
      idx = (idx < 0) ? 0 : idx;
      if (isInfo) {
        if (self->infos[idx] == nil)
          self->infos[idx] = [[NSMutableArray alloc] initWithCapacity:2];      
        [self->infos[idx] addObject:[NSNumber numberWithInt:i]];
      }
      else {
        if (self->matrix[idx] == nil)
          self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];
        [self->matrix[idx] addObject:[NSNumber numberWithInt:i]];
      }
      idx++;
    }
  }
}

- (void)appendDateTitleToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  day:(int)_day
{
  WOComponent *comp;
  NSString    *bgcolor;

  comp = [_ctx component];
  
  bgcolor = [self->titleColor stringValueInComponent:comp];
  
  if ([self->dayIndex isValueSettable])
    [self->dayIndex setIntValue:_day inComponent:comp];

  [_response appendContentString:@"<td valign='top' align='left' width='50%'"];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];

  if (self->hasOwnTitle) {
    NSString *s;
    
    [_ctx setObject:@"YES" forKey:WEWeekColumnView_TitleMode];
    
    [_ctx appendElementIDComponent:@"t"];
    s = retStrForInt(_day);
    [_ctx appendElementIDComponent:s];
    [s release];
    
    [self->template appendToResponse:_response inContext:_ctx];

    [_ctx deleteLastElementIDComponent]; // delete day index
    [_ctx deleteLastElementIDComponent]; // delete "t"

    [_ctx removeObjectForKey:WEWeekColumnView_TitleMode];
  }
  else {
    NSCalendarDate *date;
    
    date = (self->weekStart)
      ? [self->weekStart valueInComponent:comp]
      : [NSCalendarDate calendarDate];
    date = [date addTimeInterval:_day * SecondsPerDay];

    [_response appendContentString:
               @"<table cellpadding=0 width=100% border=0 cellspacing=0>"
               @"<tr>"
               @"<td align=left valign=top>"
               @"<font color=\"black\" size=\"+2\"><b>"];
 
    [_response appendContentString:[date descriptionWithCalendarFormat:@"%d"]];

    [_response appendContentString:
               @"</b></font></td>"
               @"<td align=\"center\" valign=\"top\">"
               @"<font color=\"black\">"];

    [_response appendContentString:[date descriptionWithCalendarFormat:@"%A"]];
    [_response appendContentString:
               @"</font>"
               @"</td>"
               @"</tr>"
               @"</table>"];
  }
  [_response appendContentString:@"</td>"];
}

- (void)appendContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  day:(int)_day
{
  WOComponent *comp;
  NSArray     *array;
  id          app;
  NSString    *s;
  int         i, cnt, idx, count;

  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];

  if ([self->infoItems isValueSettable]) {
    if ((cnt = [self->infos[_day] count])) {
      NSMutableArray *infoArr;
      
      infoArr = [NSMutableArray arrayWithCapacity:cnt];
      for (i = 0; i < cnt; i++) {
        idx = [[self->infos[_day] objectAtIndex:i] intValue];
        
        if (idx >= count) {
          [self logWithFormat:
		  @"WARNING: WEWeekOverview: info index out of range"];
          continue;
        }
        [infoArr addObject:[array objectAtIndex:idx]];
      }
      [self->infoItems setValue:infoArr inComponent:comp];
    }
    else {
      [self->infoItems setValue:[NSArray array] inComponent:comp];
    }
  }
  
  // *** append day info
  [_ctx setObject:@"YES" forKey:WEWeekColumnView_InfoMode];
  [_ctx appendElementIDComponent:@"i"];
  s = retStrForInt(_day);
  [_ctx appendElementIDComponent:s];
  [s release];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete day
  [_ctx deleteLastElementIDComponent]; // delete "i"
  [_ctx removeObjectForKey:WEWeekColumnView_InfoMode];

  // *** append day content
  [_ctx appendElementIDComponent:@"c"];
  s = retStrForInt(_day);
  [_ctx appendElementIDComponent:s];
  [s release];
  
  [_ctx setObject:@"YES" forKey:WEWeekColumnView_ContentMode];

  for (i = 0, cnt = [self->matrix[_day] count]; i < cnt; i++) {
    idx = [[self->matrix[_day] objectAtIndex:i] intValue];

    if (idx >= count) {
      NSLog(@"Warning! WEWeekColumnView: index out of range");
      continue;
    }
    app = [array objectAtIndex:idx];

    if ([self->item isValueSettable])
      [self->item  setValue:app inComponent:comp];
    if ([self->index isValueSettable])
      [self->index setIntValue:idx inComponent:comp];

    if (self->identifier == nil) {
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
  [_ctx removeObjectForKey:WEWeekColumnView_ContentMode];

  [_ctx deleteLastElementIDComponent]; // delete day index
  [_ctx deleteLastElementIDComponent]; // delete "c"
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSArray     *array;
  int         i, count;
  
  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];

  /* titles */
  [_ctx setObject:@"YES" forKey:WEWeekColumnView_TitleMode];
  [_ctx appendElementIDComponent:@"t"]; // append title mode
  [_ctx appendZeroElementIDComponent];  // append first day (monday)
  for (i = 0; i < 7; i++) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:i inComponent:comp];
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx incrementLastElementIDComponent]; // increment day
  }
  [_ctx deleteLastElementIDComponent];  // delete day
  [_ctx deleteLastElementIDComponent];  // delete title mode
  [_ctx removeObjectForKey:WEWeekColumnView_TitleMode];
  
  /* infos */
  [_ctx setObject:@"YES" forKey:WEWeekColumnView_InfoMode];
  [_ctx appendElementIDComponent:@"i"]; // append info mode
  [_ctx appendZeroElementIDComponent];  // append day
  for (i=0; i< 7; i++) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:i inComponent:comp];
    
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    
    [_ctx incrementLastElementIDComponent]; // increment day
    [_ctx incrementLastElementIDComponent]; // in steps of 2
  }
  [_ctx deleteLastElementIDComponent];  // delete day
  [_ctx deleteLastElementIDComponent];  // delete info mode
  [_ctx removeObjectForKey:WEWeekColumnView_InfoMode];

  // content
  [self _calcMatrixInContext:_ctx];

  [_ctx setObject:@"YES" forKey:WEWeekColumnView_ContentMode];
  [_ctx appendElementIDComponent:@"c"]; // append content mode
  [_ctx appendZeroElementIDComponent];  // append day-id
  for (i = 0; i < 7; i++) {
    int     j, cnt, idx;
    
    cnt   = [self->matrix[i] count];
    
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:i inComponent:comp];
    
    for (j = 0; j < cnt; j++) {
      idx = [[self->matrix[i] objectAtIndex:j] intValue];
      
      if (idx >= count) {
        NSLog(@"Warning! WEWeekColumnView: Index is out of range");
        continue;
      }
      
      _applyIndex(self, comp, idx);
      
      if (self->identifier) {
        NSString *s;
	
        s = [self->identifier stringValueInComponent:comp];
        [_ctx appendElementIDComponent:s];
      }
      else {
        NSString *s;
        
        s = retStrForInt(idx);
        [_ctx appendElementIDComponent:s];
        [s release];
      }

      [self->template takeValuesFromRequest:_req inContext:_ctx];
      
      [_ctx deleteLastElementIDComponent];   // delete index-id
    }
    [_ctx incrementLastElementIDComponent]; // increase day-id
  }
  [_ctx deleteLastElementIDComponent];  // delete day-id
  [_ctx deleteLastElementIDComponent];  // delete content mode
  [_ctx removeObjectForKey:WEWeekColumnView_ContentMode];
  
  [self resetMatrix];  
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *comp;
  id          result = nil;
  NSString    *cid;
  NSString    *dayId;

  cid = [_ctx currentElementID];           // get mode ("t" or "i" or "c")
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:cid];
  dayId = [_ctx currentElementID];         // get day
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:dayId];

  comp = [_ctx component];
  
  if ([cid isEqualToString:@"t"]) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:[dayId intValue] inComponent:comp];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  else if ([cid isEqualToString:@"i"]) {
    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:[dayId intValue] inComponent:comp];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  else if ([cid isEqualToString:@"c"]) {
    NSString *idxId;

    if ([self->dayIndex isValueSettable])
      [self->dayIndex setIntValue:[dayId intValue] inComponent:comp];

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
  else
    [self logWithFormat:@"WARNING! WEWeekColumnView: wrong section"];
  
  [_ctx deleteLastElementIDComponent]; // delete section id
  [_ctx deleteLastElementIDComponent]; // delete mode
  
  return result;
}

/* generating response */

- (void)appendBgColor:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  day:(unsigned)_day 
{
  NSString *bg;
  
  if ([self->dayIndex isValueSettable])
    [self->dayIndex setIntValue:_day inComponent:[_ctx component]];
  
  if ((bg = [self->contentColor stringValueInComponent:[_ctx component]])) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bg];
    [_response appendContentCharacter:'"'];
  }
}

- (void)appendFirstRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx 
{
  /* first row (Mo,Do) */
    [_response appendContentString:@"<tr>"];
    [self appendDateTitleToResponse:_response inContext:_ctx day:0];
    [self appendDateTitleToResponse:_response inContext:_ctx day:3];
    [_response appendContentString:@"</tr>"];

    [_response appendContentString:@"<tr>"];
    
    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:0];
    [_response appendContentCharacter:'>'];
    
    [self appendContentToResponse:_response inContext:_ctx day:0];
    [_response appendContentString:@"</td>"];
    
    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:3];
    [_response appendContentCharacter:'>'];
    
    [self appendContentToResponse:_response inContext:_ctx day:3];
    [_response appendContentString:@"</td>"];
    [_response appendContentString:@"</tr>"];
}

- (void)appendSecondRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx 
{
  /* second row (Di,Fr) */
    [_response appendContentString:@"<tr>"];
    [self appendDateTitleToResponse:_response inContext:_ctx day:1];
    [self appendDateTitleToResponse:_response inContext:_ctx day:4];
    [_response appendContentString:@"</tr>"];

    [_response appendContentString:@"<tr>"];

    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:1];
    [_response appendContentCharacter:'>'];

    [self appendContentToResponse:_response inContext:_ctx day:1];
    [_response appendContentString:@"</td>"];
    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:4];
    [_response appendContentCharacter:'>'];
    
    [self appendContentToResponse:_response inContext:_ctx day:4];
    [_response appendContentString:@"</td>"];
    [_response appendContentString:@"</tr>"];
}

- (void)appendThirdRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx 
{
  /* third row (Mi, Sa, So ) */
  BOOL showWeekend;

  showWeekend = (self->hideWeekend != nil)
    ? [self->hideWeekend boolValueInComponent:[_ctx component]] ? NO : YES
    : YES;
  
  [_response appendContentString:@"<tr>"];
  [self appendDateTitleToResponse:_response inContext:_ctx day:2]; /* Wed */
  if (showWeekend)
    [self appendDateTitleToResponse:_response inContext:_ctx day:5]; /* Sat */
  [_response appendContentString:@"</tr>"];

  [_response appendContentString:@"<tr>"];
    
  [_response appendContentString:
	       showWeekend 
	     ? @"<td rowspan=\"3\" valign=\"top\"" : @"<td valign=\"top\""];
  [self appendBgColor:_response inContext:_ctx day:2]; /* Wed */
  [_response appendContentCharacter:'>'];
  
  [self appendContentToResponse:_response inContext:_ctx day:2]; /* Wed */
  [_response appendContentString:@"</td>"];
  
  if (showWeekend) {
    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:5];
    [_response appendContentCharacter:'>'];
    
    [self appendContentToResponse:_response inContext:_ctx day:5];
    [_response appendContentString:@"</td>"];
    [_response appendContentString:@"</tr>"];

    [_response appendContentString:@"<tr>"];
    [self appendDateTitleToResponse:_response inContext:_ctx day:6];
    [_response appendContentString:@"</tr>"];

    [_response appendContentString:@"<tr>"];
    
    [_response appendContentString:@"<td valign=\"top\""];
    [self appendBgColor:_response inContext:_ctx day:6];
    [_response appendContentCharacter:'>'];
  
    [self appendContentToResponse:_response inContext:_ctx day:6];
    [_response appendContentString:@"</td>"];
  }
  
  [_response appendContentString:@"</tr>"];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [self _calcMatrixInContext:_ctx];
  
  [_response appendContentString:@"<table "];
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentString:@">"];  
  
  /* first row (Mo,Do) */
  [self appendFirstRowToResponse:_response inContext:_ctx];
  
  /* second row (Di,Fr) */
  [self appendSecondRowToResponse:_response inContext:_ctx];
  
  /* third row (Mi, Sa, So ) */
  [self appendThirdRowToResponse:_response inContext:_ctx];
  
  [_response appendContentString:@"</table>"];

  [self resetMatrix];
}

@end /* WeekOverview */

@interface WEWeekColumnViewTitleMode : WEContextConditional
@end

@implementation WEWeekColumnViewTitleMode
- (NSString *)_contextKey {
  return WEWeekColumnView_TitleMode;
}
- (NSString *)_didMatchKey {
  return WEWeekColumnView_TitleModeDidMatch;
}
@end

// --

@interface WEWeekColumnViewInfoMode : WEContextConditional
@end

@implementation WEWeekColumnViewInfoMode
- (NSString *)_contextKey {
  return WEWeekColumnView_InfoMode;
}
@end

// --

@interface WEWeekColumnViewContentMode : WEContextConditional
@end

@implementation WEWeekColumnViewContentMode
- (NSString *)_contextKey {
  return WEWeekColumnView_ContentMode;
}
@end
