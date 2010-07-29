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

#ifndef __WEExtensions_WECalendarField_H__
#define __WEExtensions_WECalendarField_H__

/*
  required resources:

  // time field:
  downstairs.gif

  // date field:
  icon_popupcalendar.gif
  first.gif
  previous.gif
  non_sorted.gif
  next.gif
  last.gif
  icon_unread.gif
*/

#define HEAD_BACKGROUND_COLOR @"#FFDAAA"
#define HEAD_COLOR            @"#000000"
#define HEAD_NAVIGATION_COLOR @"#6F1537"

#include <NGObjWeb/NGObjWeb.h>

@interface WECalendarField : WODynamicElement
{
  WOAssociation *date;
  WOAssociation *name;
  
  // dateField elements
  WOAssociation *year;
  WOAssociation *month;
  WOAssociation *day;
  WOAssociation *format;

  // timeField elements
  WOAssociation *hour;
  WOAssociation *minute;
  WOAssociation *second;
  WOAssociation *useTextField;
  WOAssociation *hourInterval;
  WOAssociation *minuteInterval;
  WOAssociation *secondInterval;

  WOElement     *template;
}
@end

@interface WEDateFieldScript : WODynamicElement
{
  WOAssociation *headBackground;
  WOAssociation *headColor;
  WOAssociation *headNavColor;
  WOAssociation *labels;
  WOAssociation *useImages;
}

+ (void)appendWEDateFieldScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  headBackground: (NSString *) _hBack
  headColor:      (NSString *) _hCol
  headNavColor:   (NSString *) _hNav
  labels:         (id)_labels
  useImages:      (BOOL)_useImg;

@end

@interface WECalendarField(WETimeFieldImplementation)

- (void)_takeValuesFromTimeFieldRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx;
- (id)_invokeActionForTimeFieldRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx;
- (void)_appendTimeFieldToResponse:(WOResponse *)_r inContext:(WOContext *)_cx;

@end /* WECalendarField(WETimeFieldImplementation) */

@interface WECalendarField(WEDateFieldImplementation)

- (void)_takeValuesFromDateFieldRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx;
- (id)_invokeActionForDateFieldRequest:(WORequest *)_rq 
  inContext:(WOContext *)_ctx;
- (void)_appendDateFieldToResponse:(WOResponse *)_r inContext:(WOContext *)_cx;

@end /* WECalendarField(WEDateFieldImplementation) */

@interface WECalendarField(Accessors)

- (NSString *)elementIdWithSuffix:(NSString *)_suffix ctx:(WOContext *)_ctx;

- (void)setSecond:(int)_second inComponent:(WOComponent *)_comp;
- (int)secondInComponent:(WOComponent *)_comp;

- (void)setMinute:(int)_minute inComponent:(WOComponent *)_comp;
- (int)minuteInComponent:(WOComponent *)_comp;

- (void)setHour:(int)_hour inComponent:(WOComponent *)_comp;
- (int)hourInComponent:(WOComponent *)_comp;

- (void)setDay:(int)_day inComponent:(WOComponent *)_comp;
- (int)dayInComponent:(WOComponent *)_comp;

- (void)setMonth:(int)_month inComponent:(WOComponent *)_comp;
- (int)monthInComponent:(WOComponent *)_comp;

- (void)setYear:(int)_year inComponent:(WOComponent *)_comp;
- (int)yearInComponent:(WOComponent *)_comp;

- (BOOL)isSecondSettable;
- (BOOL)isMinuteSettable;
- (BOOL)isHourSettable;
- (BOOL)isDaySettable;
- (BOOL)isMonthSettable;
- (BOOL)isYearSettable;

- (BOOL)hasSecondInComponent:(WOComponent *)_comp;
- (BOOL)hasMinuteInComponent:(WOComponent *)_comp;
- (BOOL)hasHourInComponent:(WOComponent *)_comp;
- (BOOL)hasDayInComponent:(WOComponent *)_comp;
- (BOOL)hasMonthInComponent:(WOComponent *)_comp;
- (BOOL)hasYearInComponent:(WOComponent *)_comp;

@end

#endif /* __WEExtensions_WECalendarField_H__ */
