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

#include "WECalendarField.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

static Class StrClass = Nil;

@implementation WECalendarField

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  StrClass = [NSString class];
}

static NSString *retStrForInt(int i) {
  // TODO: find out good statics
  return [[StrClass alloc] initWithFormat:@"%i", i];
}
static NSString *retStr02ForInt(int i) {
  switch (i) { // TODO: find out a good count ...
  case 0:  return @"00";
  case 1:  return @"01";
  case 2:  return @"02";
  case 3:  return @"03";
  case 4:  return @"04";
  case 5:  return @"05";
  case 6:  return @"06";
  case 7:  return @"07";
  case 8:  return @"08";
  case 9:  return @"09";
  default: 
    // TODO: add log ...
    return [[StrClass alloc] initWithFormat:@"%02i", i];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations: _config template:_subs])) {
    self->name           = OWGetProperty(_config, @"name");
    self->date           = OWGetProperty(_config, @"date");
    
    // time field associations
    self->hour           = OWGetProperty(_config, @"hour");
    self->minute         = OWGetProperty(_config, @"minute");
    self->second         = OWGetProperty(_config, @"second");
    self->useTextField   = OWGetProperty(_config, @"useTextField");
    self->hourInterval   = OWGetProperty(_config, @"hourInterval");
    self->minuteInterval = OWGetProperty(_config, @"minuteInterval");
    self->secondInterval = OWGetProperty(_config, @"secondInterval");

    // date field associations
    self->year           = OWGetProperty(_config, @"year");
    self->month          = OWGetProperty(_config, @"month");
    self->day            = OWGetProperty(_config, @"day");
    self->format         = OWGetProperty(_config, @"format");

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->name release];
  [self->date release];
  
  /* time field associations */
  [self->hour           release];
  [self->minute         release];
  [self->second         release];
  [self->useTextField   release];
  [self->hourInterval   release];
  [self->minuteInterval release];
  [self->secondInterval release];

  /* date field associations */
  [self->year   release];
  [self->month  release];
  [self->day    release];
  [self->format release];
  
  [self->template release];
  [super dealloc];
}

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self _takeValuesFromTimeFieldRequest:_rq inContext:_ctx];
  [self _takeValuesFromDateFieldRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result = nil;

  result = [self _invokeActionForTimeFieldRequest:_rq inContext:_ctx];
  if (result == nil)
    result = [self _invokeActionForDateFieldRequest:_rq inContext:_ctx];
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [_response appendContentString:
             @"<table border='0' cellpadding='0' cellspacing='0'>"
             @"<tr>"
             @"<td align='left' valign='bottom'>"];
  [self _appendTimeFieldToResponse:_response inContext:_ctx];
  
  [_response appendContentString:
             @"</td>"
             @"<td align='left' valign='bottom'>"];
  
  [self _appendDateFieldToResponse:_response inContext:_ctx];

  [_response appendContentString:
             @"</td>"
             @"</tr>"
             @"</table>"];
}

@end /* WECalendarField */

@implementation WECalendarField(WETimeFieldImplementation)

/* Private Methodes */

- (NSString *)_divIDAndScriptInContext:(WOContext *)_ctx
  response:(WOResponse *)_response
{
  int divCount;
  
  divCount = [[_ctx valueForKey: @"WETimeFieldScript"] intValue];
  if (divCount == 0) {
    [_response appendContentString:
      @"<style type=\"text/css\">\n"
      @"A.DDLlink { width: 23px; font: normal 10pt Arial; color: "
      @"#6F1537; text-decoration: none; } \n"
      @"A.DDLlink:hover { color: red; background: #FAE8B8; } \n"
      @"</style>"];
    [_response appendContentString:
      @"<script language=\"JavaScript\">\n"
      @"var DDLlayerCount = 1000;\n"
      @"function DDLopen(layerObj,el) {\n"
      @"  if (layerObj.style.visibility == 'hidden') {\n"
      @"    layerObj.style.visibility = 'visible';\n"
      @"    layerObj.style.zIndex     = DDLlayerCount;\n"
      @"    formObj = DDLformField(el);\n"
      @"    formObj.contentEditable = false;\n"
      @"    DDLlayerCount++;\n"
      @"    "
      @"  } else { layerObj.style.visibility = 'hidden'; }\n"
      @"}\n\n"
      @"function DDLreturn(layerObj,el,value) {\n"
      @"  formObj = DDLformField(el);\n"
      @"  formObj.value = value;\n"
      @"  formObj.contentEditable = true;\n"
      @"  layerObj.style.visibility = 'hidden';\n"
      @"}\n"
      @"function DDLformField(el) {\n"
      @"  for (i = 0; i < document.forms.length; i++)\n"
      @"    for (j = 0; j < document.forms[i].elements.length; j++)\n"
      @"      if (document.forms[i].elements[j].name == el)\n"
      @"        return document.forms[i].elements[j];\n"
      @"}\n"
      @"</script>"];
  }
  [_ctx takeValue:[NSNumber numberWithInt:(divCount+1)]
        forKey:@"WETimeFieldScript"];
  
  return [StrClass stringWithFormat:@"dropDownDiv%i", divCount];
}

- (void)_appendSelectToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  elementIDComponent:(NSString *)_elementIDComponent
  count:(int)_count
  selectedIndex:(int)_idx
  interval:(int)_interval
{
  WEClientCapabilities *ccaps;
  NSString *tmp;
  int      i;
  NSString *userAgent;
  BOOL     isMSIE;
  NSString *divID;
  NSString *img;
  NSString *elementId;

  ccaps     = [[_ctx request] clientCapabilities];
  userAgent = [[_ctx request] headerForKey: @"user-agent"];
  isMSIE    = [ccaps isInternetExplorer];
  elementId = [self elementIdWithSuffix:_elementIDComponent ctx:_ctx];
  
  divID = [self _divIDAndScriptInContext:_ctx response:_response];
  
  img = WEUriOfResource(@"downstairs.gif", _ctx);

  if (isMSIE && img) {
    NSString *s;
    
    [_response appendContentString:@"<input readonly=\"readonly\" name=\""];
    [_response appendContentString:elementId];
    [_response appendContentString:@"\" value=\""];

    s = retStr02ForInt(_idx);
    [_response appendContentHTMLAttributeValue:s];
    [s release];
    
    [_response appendContentString:
                 @"\" type=\"text\" size=\"2\" maxlength=\"2\""];
#if 0
    [_response appendContentString:@" style=\"background-color: #FFDAAA;\""];
#endif
    [_response appendContentString:@" /><img border=\"0\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" onClick=\""];
    [_response appendContentString:@"javascript:DDLopen("];
    [_response appendContentString:divID];
    [_response appendContentString:@",'"];
    [_response appendContentString:elementId];
    [_response appendContentString:@"')\" /><br />"];
    [_response appendContentString:@"<div id=\""];
    [_response appendContentString:divID];
    [_response appendContentString:
      @"\" style=\"position: absolute; overflow: auto; height: 150; width: 47;"
      @" background: #FFDAAA; border: 1 solid; "
      @"visibility: hidden; padding: 0 0 0 2;\">"];
  }
  else {
    [_response appendContentString:@"<select name=\""];
    [_response appendContentString:elementId];
    [_response appendContentString:@"\">"];
  }
  
  for (i = 0; i <= _count; i += _interval) {
    tmp = retStr02ForInt(i);
    if (isMSIE && img) {
      NSString *s;

      s = [[StrClass alloc] initWithFormat:
         @"<a class=\"DDLlink\" href=\"javascript:DDLreturn(%@,'%@','%@')\">%@"
         @"</a><br />",
                    divID, elementId, tmp, tmp];
      [_response appendContentString:s];
      [s release];
    }
    else {
      [_response appendContentString:@"<option value=\""];
      [_response appendContentString:tmp];
      [_response appendContentString:@"\""];
      [_response appendContentString:
                   (i == _idx) ? @" selected=\"selected\"" : @""];
      [_response appendContentString:@">"];
      [_response appendContentString:tmp];
      [_response appendContentString:@"</option>"];
    }
    [tmp release]; tmp = nil;
  }

  if (isMSIE && img)
    [_response appendContentString:@"</div>"];
  else
    [_response appendContentString:@"</select>"];
}

/* handle request */

- (void)_takeValuesFromTimeFieldRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *comp;
  id          formValue;
  BOOL        tuseTField;
  NSString    *elementId;
  NSArray     *ta;
  int         idx;
  
  comp = [_ctx component];
  tuseTField = self->useTextField
    ? [[self->useTextField valueInComponent: comp] boolValue]
    : NO;
  
  if (tuseTField) {
    // TextField value
    elementId = [self elementIdWithSuffix:@"" ctx:_ctx];
    if ((formValue = [_request formValueForKey:elementId])) {
      int intValue, cnt;
      
      ta = [formValue componentsSeparatedByString:@":"];
      cnt = [ta count];
      
      idx = 0;
      if ([self isHourSettable]) {
        intValue = (idx < cnt) ? [[ta objectAtIndex:idx] intValue] : 0;
        [self setHour:intValue inComponent:comp];
        idx++;
      }
      if ([self isMinuteSettable]) {
        intValue = (idx < cnt) ? [[ta objectAtIndex:idx] intValue] : 0;
        [self setMinute:intValue inComponent:comp];
        idx++;
      }
      if ([self isSecondSettable]) {
        intValue = (idx < cnt) ? [[ta objectAtIndex:idx] intValue] : 0;        
        [self setSecond:intValue inComponent:comp];
      }
    }
  }
  else {
    elementId = [self elementIdWithSuffix:@"hour" ctx:_ctx];
    if ((formValue = [_request formValueForKey:elementId])) {
      if ([self isHourSettable])
        [self setHour:[formValue intValue] inComponent:comp];
    }

    elementId = [self elementIdWithSuffix:@"minute" ctx:_ctx];
    if ((formValue = [_request formValueForKey:elementId])) {
      if ([self isMinuteSettable])
        [self setMinute:[formValue intValue] inComponent:comp];
    }

    elementId = [self elementIdWithSuffix:@"second" ctx:_ctx];
    if ((formValue = [_request formValueForKey:elementId])) {
      if ([self isSecondSettable])
        [self setSecond:[formValue intValue] inComponent:comp];
    }
  }
  
  /* template */
  [_ctx appendElementIDComponent:@"timeField"];
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)_invokeActionForTimeFieldRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx
{
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generate response */

- (void)_appendTimeFieldToResponse:(WOResponse *)_r inContext:(WOContext *)_cx{
  NSCalendarDate *tdate;
  WOComponent    *comp;
  BOOL           tuseTField;
  int            hourInt;        // hourInterval
  int            minuteInt;      // minuteInterval
  int            secondInt;      // secondInterval
  NSMutableArray *ta;

  comp  = [_cx component];
  tdate = [NSCalendarDate calendarDate];

  hourInt = self->hourInterval
    ? [self->hourInterval intValueInComponent:comp] : 1;

  minuteInt = self->minuteInterval
    ? [self->minuteInterval intValueInComponent:comp] : 1;

  secondInt = self->secondInterval
    ? [self->secondInterval intValueInComponent:comp] : 1;

  tuseTField = self->useTextField
    ? [self->useTextField boolValueInComponent:comp]
    : NO;
  
  // template
  [_cx appendElementIDComponent:@"timeField"];
  [self->template appendToResponse:_r inContext:_cx];
  [_cx deleteLastElementIDComponent];
  
  // all values in one textField
  if (tuseTField) {
    int h, m, s;
    NSString *tmp, *fmt;
    // build string of values and @":"

    h = [self   hourInComponent:comp];
    m = [self minuteInComponent:comp];
    s = [self secondInComponent:comp];
    
    ta = [[NSMutableArray alloc] initWithCapacity: 3];
    fmt = @"%02i";
    
    if ([self hasHourInComponent:comp]) {
      tmp = retStr02ForInt(h);
      [ta addObject:tmp];
      [tmp release];
    }
    if ([self hasMinuteInComponent:comp]) {
      tmp = [[StrClass alloc] initWithFormat:fmt, m];
      [ta addObject:tmp];
      [tmp release];
    }
    if ([self hasSecondInComponent:comp]) {
      tmp = [[StrClass alloc] initWithFormat:fmt, s];
      [ta addObject:tmp];
      [tmp release];
    }
    
    tmp = [ta componentsJoinedByString:@":"];
    [ta release]; ta = nil;

    /* append to response */
    if ([tmp isNotEmpty]) {
      [_r appendContentString:@"<input type=\"text\" name=\""];
      [_r appendContentString:[self elementIdWithSuffix:@"" ctx:_cx]];
      [_r appendContentString:@"\" value=\""];
      [_r appendContentString:tmp];
      [_r appendContentString:@"\""];
      
      tmp = retStrForInt([tmp length]);
      [_r appendContentString:@" size=\""];
      [_r appendContentString:tmp];
      [_r appendContentString:@"\" maxlength=\""];
      [_r appendContentString:tmp];
      [_r appendContentString:@"\""];
      [tmp release];
      
      [_r appendContentString:@" />"];
    }
  }
  else {
    // hour select field
    [_r appendContentString:
	  @"<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr>"];

    if ([self hasHourInComponent:comp]) {
      [_r appendContentString:@"<td valign=\"bottom\">"];
      [self _appendSelectToResponse:_r inContext:_cx
	    elementIDComponent:@"hour"
            count:23 selectedIndex:[self hourInComponent:comp]
            interval:hourInt];
      [_r appendContentString:@"</td>"];
    }
     
    // minute select field
    if ([self hasMinuteInComponent:comp]) {
      [_r appendContentString:@"<td valign=\"bottom\">"];
      [self _appendSelectToResponse:_r inContext:_cx 
	    elementIDComponent:@"minute"
            count:59 selectedIndex:[self minuteInComponent:comp]
            interval:minuteInt];
      [_r appendContentString:@"</td>"];
    }
    
    // second select field
    if ([self hasSecondInComponent:comp]) {
      [_r appendContentString:@"<td valign=\"bottom\">"];
      [self _appendSelectToResponse:_r inContext:_cx
            elementIDComponent:@"second"
            count:59 selectedIndex:[self secondInComponent:comp]
            interval:secondInt];
      [_r appendContentString:@"</td>"];
    }
    [_r appendContentString:@"</tr></table>"];

  } /* end of (!tuseTField) */
}

@end /* WECalendarField(WETimeFieldImplementation */

@implementation WECalendarField(WEDateFieldImplementation)

- (void)_takeValuesFromDateFieldRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString       *tformat;
  NSCalendarDate *tdate;
  int            tyear;
  int            tmonth;
  int            tday;
  WOComponent    *comp;
  NSString       *elementId;
  
  comp = [_ctx component];

  tformat = [self->format stringValueInComponent: comp];
  if (tformat == nil) tformat = @"%Y-%m-%d";
  elementId = [self elementIdWithSuffix:@"" ctx:_ctx];

  if ([self isKindOfClass:[WECalendarField class]]) {
    id t = tformat;
    
    t = [[t componentsSeparatedByString:@"%H"] componentsJoinedByString:@""];
    t = [[t componentsSeparatedByString:@"%M"] componentsJoinedByString:@""];
    t = [[t componentsSeparatedByString:@"%S"] componentsJoinedByString:@""];

    tformat = t;
  }
  
  tdate = [NSCalendarDate dateWithString:
                          [_request formValueForKey:elementId]
                          calendarFormat: tformat];
  if (tdate == nil) {
    NSLog(@"WARNING: WEDateField: field value and format do not match!");
  }
  else {
    tyear  = [tdate yearOfCommonEra];
    tmonth = [tdate monthOfYear];
    tday   = [tdate dayOfMonth];


    if ([self isYearSettable])  [self  setYear:tyear  inComponent:comp];
    if ([self isMonthSettable]) [self setMonth:tmonth inComponent:comp];
    if ([self isDaySettable])   [self   setDay:tday   inComponent:comp];
  }

  [_ctx appendElementIDComponent:@"dateField"];
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)_invokeActionForDateFieldRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return [self->template invokeActionForRequest:_request inContext:_ctx];
}

- (void)_appendDateFieldToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WEClientCapabilities *ccaps;
  int            tyear;
  int            tmonth;
  int            tday;
  NSString       *tformat;
  NSString       *tmp;
  WOComponent    *comp;
  NSCalendarDate *tdate;
  NSString       *calendarDivID;
  int            calendarID;
  BOOL           isMSIE;
  NSString       *value;

  ccaps  = [[_ctx request] clientCapabilities];
  comp   = [_ctx component];
  tdate  = [NSCalendarDate calendarDate];
  isMSIE = [ccaps isInternetExplorer];

  if (![_ctx valueForKey:@"WEDateFieldScriptDone"])
    [WEDateFieldScript appendWEDateFieldScriptToResponse: _response
      inContext: _ctx
      headBackground: HEAD_BACKGROUND_COLOR
      headColor:      HEAD_COLOR
      headNavColor:   HEAD_NAVIGATION_COLOR
      labels:         nil
      useImages:      NO];

  // associations
  tyear = ([self hasYearInComponent:comp])
    ? [self yearInComponent:comp]
    : [tdate yearOfCommonEra];
  tmonth = ([self hasMonthInComponent:comp])
    ? [self monthInComponent:comp]
    : [tdate monthOfYear];
  tday = ([self hasDayInComponent:comp])
    ? [self dayInComponent:comp]
    : [tdate dayOfMonth];
  tformat    = self->format
    ? [self->format stringValueInComponent: comp]
    : (NSString *)@"%Y-%m-%d";

  if ([self isKindOfClass:[WECalendarField class]]) {
    id t = tformat;

    t = [[t componentsSeparatedByString:@"%H"] componentsJoinedByString:@""];
    t = [[t componentsSeparatedByString:@"%M"] componentsJoinedByString:@""];
    t = [[t componentsSeparatedByString:@"%S"] componentsJoinedByString:@""];

    tformat = t;
  }

  // input field value
  tdate = [NSCalendarDate dateWithYear: tyear
                          month:        tmonth
                          day:          tday
                          hour: 0 minute: 0 second: 0
                          timeZone: [tdate timeZone]];

  value = [tdate descriptionWithCalendarFormat: tformat];

  // div id for javascript calendar
  calendarID = ([_ctx valueForKey: @"WEDateField_DivID"])
     ? [[_ctx valueForKey: @"WEDateField_DivID"] intValue]
     : 0;
  calendarDivID = [StrClass stringWithFormat:@"calendarDiv%d", calendarID];
  calendarID++;
  [_ctx takeValue:[NSNumber numberWithInt: calendarID]
        forKey:@"WEDateField_DivID"];

  // template
  [_ctx appendElementIDComponent:@"dateField"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];

  [_response appendContentString:
             @"<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">"];
  [_response appendContentString:
             @"<td valign=\"top\" align=\"left\">"];

  // input field
  [_response appendContentString:@"<input type=\"text\" name=\""];
  [_response appendContentString:[self elementIdWithSuffix:@"" ctx:_ctx]];
  [_response appendContentString:@"\" value=\""];
  [_response appendContentString:value];
  [_response appendContentString:@"\" size=\""];
  [_response appendContentString:
             [[NSNumber numberWithInt: [value length]] stringValue]];
  [_response appendContentString:@"\" maxlength=\""];
  [_response appendContentString:
             [[NSNumber numberWithInt: [value length]] stringValue]];
  [_response appendContentString:@"\" />"];
    
  /* link to calendar panel */
  [_response appendContentString:  @" <a href=\"javascript:doNothing()\" "];
  [_response appendContentString: @"onClick=\""];
  tmp = @"javascript:%@toggleCalendar('%@',%@%@,'%@')";
  tmp = [[StrClass alloc] initWithFormat: tmp,
              (isMSIE) ? @"" : @"actPos;",                  // layer position
              [self elementIdWithSuffix:@"" ctx:_ctx],      // form element
              (isMSIE) ? @"" : @"document.", calendarDivID, // calendar DIV
              tformat];                                     // dateFormat
  [_response appendContentString: tmp];
  [tmp release];
  [_response appendContentString: @"\">"];
  
  // calendar image
  tmp = WEUriOfResource(@"icon_popupcalendar.gif", _ctx);

  if (tmp) {
    tmp = [[StrClass alloc] initWithFormat:
                              @"<img border=\"0\" src=\"%@\" />", tmp];
  }
  else
    tmp = @"x";
  
  [_response appendContentString:tmp];
  [tmp release];

  [_response appendContentString: @"</a><br />"];
    
  /* calendar panel */
  [_response appendContentString: @"<div id=\""];
  [_response appendContentString: calendarDivID];
  [_response appendContentString: @"\" style=\"position: absolute; "];
  [_response appendContentString: @"visibility: "];
  [_response appendContentString: (isMSIE) ? @"hidden" : @"hide"];
  [_response appendContentString: @";\"></div>"];

  [_response appendContentString: @"</td></tr></table>"];
}

@end /* WECalendarField(WEDateFieldImplementation) */

@implementation WEDateFieldScript

- (id)initWithName:(NSString *)_name
   associations:(NSDictionary *)_config
   template:    (WOElement *)_subs
{
  if ((self = [super initWithName:_name associations: _config template:_subs]))
  {
    self->headBackground = OWGetProperty(_config, @"headBackground");
    self->headColor      = OWGetProperty(_config, @"headColor");
    self->headNavColor   = OWGetProperty(_config, @"headNavColor");
    self->labels         = OWGetProperty(_config, @"labels");
    self->useImages      = OWGetProperty(_config, @"useImages");
  }
  return self;
}

- (void)dealloc {
  [self->useImages      release];
  [self->headBackground release];
  [self->headColor      release];
  [self->headNavColor   release];
  [self->labels         release];
  [super dealloc];
}


+ (void)appendWEDateFieldScriptToResponse: (WOResponse *)_response
  inContext:      (WOContext *)_ctx
  headBackground: (NSString *)_hBack
  headColor:      (NSString *)_hCol
  headNavColor:   (NSString *)_hNav
  labels:         (id)_labels
  useImages:      (BOOL)_useImg
{
  NSString *tmp;
  NSString *tmon;
  NSString *tweek;
  NSString *timg;

  // images...
  NSString *firstI;
  NSString *prevI;
  NSString *todayI;
  NSString *nextI;
  NSString *lastI;
  NSString *closeI;
  
  // colors
  if (_hBack == nil) _hBack = HEAD_BACKGROUND_COLOR;
  if (_hCol  == nil) _hCol  = HEAD_COLOR;
  if (_hNav  == nil) _hNav  = HEAD_NAVIGATION_COLOR;

  // months and weekdays
  if (_labels   == nil) {
    NSLog(@"WARNING: WEDateFieldScript: undefined variable 'labels'");
    tmon  = @"var externMonths = false; \n";
    tweek = @"var externWeekdays = false; \n";
  }
  else {
    tmon = @"var externMonths = new Array("
           @"\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\","
           @"\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\"); \n";
    tmon = [[StrClass alloc] initWithFormat: tmon,
                     [_labels valueForKey: @"January"],
                     [_labels valueForKey: @"February"],
                     [_labels valueForKey: @"March"],
                     [_labels valueForKey: @"April"],
                     [_labels valueForKey: @"May"],
                     [_labels valueForKey: @"June"],
                     [_labels valueForKey: @"July"],
                     [_labels valueForKey: @"August"],
                     [_labels valueForKey: @"September"],
                     [_labels valueForKey: @"October"],
                     [_labels valueForKey: @"November"],
                     [_labels valueForKey: @"December"]
                     ];
    tweek = @"var externWeekdays = new Array("
            @"\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\"); \n";
    tweek = [[StrClass alloc] initWithFormat: tweek,
                      [_labels valueForKey: @"SundayAbbrev"],
                      [_labels valueForKey: @"MondayAbbrev"],
                      [_labels valueForKey: @"TuesdayAbbrev"],
                      [_labels valueForKey: @"WednesdayAbbrev"],
                      [_labels valueForKey: @"ThursdayAbbrev"],
                      [_labels valueForKey: @"FridayAbbrev"],
                      [_labels valueForKey: @"SaturdayAbbrev"]
                      ];
  }
  
  if (![_ctx valueForKey: @"WEDateFieldScriptDone"]) {
    tmp = @"<style type='text/css'>\n"
          @"TD.heading { text-decoration: none; color: black; "
            @"font: bold 8pt arial, helvetica; } \n "
          @"A.focusDay { color: blue; text-decoration: none; "
            @"font: 8pt arial, helvetica; } \n"
          @"A.focusDay:hover { color:darkred; text-decoration: none; "
            @"font: 8pt arial, helvetica; } \n"
          @"A.weekday { color: blue; text-decoration: none; "
            @"font: 8pt arial, helvetica; } \n"
          @"A.weekday:hover { color: darkred; font: 8pt arial, helvetica; } \n"
          @"A.navMonYear "
            @"{ color: %@; text-decoration: none; font: 8pt Arial; }\n"
          @"TD.topCal "
            @"{ font: 10pt Arial; color: %@; background-color: %@; } \n"
          @"</style>\n";
    tmp = [StrClass stringWithFormat: tmp, _hNav, _hCol, _hBack];
    [_response appendContentString: tmp];

    [_response appendContentString:
               @"<script language=\"JavaScript\">\n"];
    [_response appendContentString: @"var dateFormat = \"%Y-%m-%d\"; \n"];
    [_response appendContentString: tmon];
    [_response appendContentString: tweek];

    // navigation images
    // doppelt haelt wirklich besser
    firstI = WEUriOfResource(@"first.gif", _ctx);
    prevI  = WEUriOfResource(@"previous.gif", _ctx);
    todayI = WEUriOfResource(@"non_sorted.gif", _ctx);
    nextI  = WEUriOfResource(@"next.gif", _ctx);
    lastI  = WEUriOfResource(@"last.gif", _ctx);
    closeI = WEUriOfResource(@"icon_unread.gif", _ctx);

    if (_useImg) {
      NSString *s;
      
      timg = @"var %@=new Image(); %@.src='%@';\n"
             @"var %@=\"<img border='0' name='%@' src='%@' />\";\n";
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldFirst", @"dateFieldFirst", firstI,
                  @"dateFieldFirstSRC", @"dateFieldFirstImg", firstI];
      [_response appendContentString:s];
      [s release];
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldPrevious", @"dateFieldPrevious", prevI,
                  @"dateFieldPreviousSRC", @"dateFieldPreviousImg", prevI];
      [_response appendContentString:s];
      [s release];
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldToday", @"dateFieldToday", todayI,
                  @"dateFieldTodaySRC", @"dateFieldTodayImg", todayI];
      [_response appendContentString:s];
      [s release];
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldNext", @"dateFieldNext", nextI,
                  @"dateFieldNextSRC", @"dateFieldNextImg", nextI];
      [_response appendContentString:s];
      [s release];
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldLast", @"dateFieldLast", lastI,
                  @"dateFieldLastSRC", @"dateFieldLastImg", lastI];
      [_response appendContentString:s];
      [s release];
      s = [[StrClass alloc] initWithFormat: timg,
                  @"dateFieldClose", @"dateFieldClose", closeI,
                  @"dateFieldCloseSRC", @"dateFieldCloseImg", closeI];
      [_response appendContentString:s];
      [s release];
      [_response appendContentString:@"var usesNavImages = true;\n"];
    }
    else {
      [_response appendContentString:@"var dateFieldCloseSRC=\"X\";\n"];
      [_response appendContentString:@"var dateFieldFirstSRC=\"&lt;&lt;\";\n"];
      [_response appendContentString:@"var dateFieldPreviousSRC=\"&lt;\";\n"];
      [_response appendContentString:@"var dateFieldTodaySRC=\"O\";\n"];
      [_response appendContentString:@"var dateFieldNextSRC=\"&gt;\";\n"];
      [_response appendContentString:@"var dateFieldLastSRC=\"&gt;&gt;\";\n"];
      [_response appendContentString:@"var usesNavImages = false;\n"];
    }
    
    tmp =
#include "calendar.jsm"
      ;
    [_response appendContentString: tmp];
    [_response appendContentString: @"\n</script>"];
    
    [_ctx takeValue: [NSNumber numberWithBool: YES]
          forKey: @"WEDateFieldScriptDone"];
  }

  [tmon  release];
  [tweek release];
}

- (void)appendToResponse: (WOResponse *)_response
  inContext: (WOContext *)_ctx
{
  WOComponent *comp;
  
  if ([_ctx isRenderingDisabled]) return;

  comp = [_ctx component];
  
  [[self class] appendWEDateFieldScriptToResponse: _response inContext:_ctx
    headBackground: [self->headBackground stringValueInComponent:comp]
    headColor:      [self->headColor      stringValueInComponent:comp]
    headNavColor:   [self->headNavColor   stringValueInComponent:comp]
    labels:         [self->labels               valueInComponent:comp]
    useImages:      [[self->useImages valueInComponent: comp] boolValue]];
}

@end /* WEDateFieldScript */

@implementation WECalendarField(Accessors)

- (NSString *)elementIdWithSuffix:(NSString *)_suffix ctx:(WOContext *)_ctx {
  NSString *prefix = nil;
  
  if ((prefix = [self->name stringValueInComponent:[_ctx component]]) == nil)
    prefix = [_ctx elementID];
  
  if ([_suffix isNotEmpty])
    prefix = [prefix stringByAppendingString:@"_"];
  
  return [prefix stringByAppendingString:_suffix];
}

- (void)setSecond:(int)_second inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d = [self->date valueInComponent:_comp];

    
    d = [NSCalendarDate dateWithYear:[d yearOfCommonEra]
                        month:[d monthOfYear]
                        day:[d dayOfMonth]
                        hour:[d hourOfDay]
                        minute:[d minuteOfHour]
                        second:_second
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];
  }
  else {
    [self->second setIntValue:_second inComponent:_comp];
  }
}
- (int)secondInComponent:(WOComponent *)_comp {
  return (self->date != nil)
    ? [[self->date valueInComponent:_comp] secondOfMinute]
    : [self->second intValueInComponent:_comp];
}

- (void)setMinute:(int)_minute inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d;
    
    d = [self->date valueInComponent:_comp];
    d = [NSCalendarDate dateWithYear:[d yearOfCommonEra]
                        month:[d monthOfYear]
                        day:[d dayOfMonth]
                        hour:[d hourOfDay]
                        minute:_minute
                        second:[d secondOfMinute]
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];
  }
  else {
    [self->minute setIntValue:_minute inComponent:_comp];
  }
}
- (int)minuteInComponent:(WOComponent *)_comp {
  return (self->date != nil)
    ? [[self->date valueInComponent:_comp] minuteOfHour]
    : [self->minute intValueInComponent:_comp];
}

- (void)setHour:(int)_hour inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d = [self->date valueInComponent:_comp];

    
    d = [NSCalendarDate dateWithYear:[d yearOfCommonEra]
                        month:[d monthOfYear]
                        day:[d dayOfMonth]
                        hour:_hour
                        minute:[d minuteOfHour]
                        second:[d secondOfMinute]
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];
  }
  else {
    [self->hour setIntValue:_hour inComponent:_comp];
  }
}
- (int)hourInComponent:(WOComponent *)_comp {
  return (self->date != nil)
    ? [[self->date valueInComponent:_comp] hourOfDay]
    : [self->hour intValueInComponent:_comp];
}

- (void)setDay:(int)_day inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d = [self->date valueInComponent:_comp];
    
    d = [NSCalendarDate dateWithYear:[d yearOfCommonEra]
                        month:[d monthOfYear]
                        day:_day
                        hour:[d hourOfDay]
                        minute:[d minuteOfHour]
                        second:[d secondOfMinute]
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];
  }
  else {
    [self->day setIntValue:_day inComponent:_comp];
  }
}
- (int)dayInComponent:(WOComponent *)_comp {
  return (self->date != nil)
    ? [[self->date valueInComponent:_comp] dayOfMonth]
    : [self->day intValueInComponent:_comp];
}

- (void)setMonth:(int)_month inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d = [self->date valueInComponent:_comp];
    
    d = [NSCalendarDate dateWithYear:[d yearOfCommonEra]
                        month:_month
                        day:[d dayOfMonth]
                        hour:[d hourOfDay]
                        minute:[d minuteOfHour]
                        second:[d secondOfMinute]
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];    
  }
  else {
    [self->month setIntValue:_month inComponent:_comp];
  }
}
- (int)monthInComponent:(WOComponent *)_comp {
   return (self->date != nil)
    ? [[self->date valueInComponent:_comp] monthOfYear]
    : [self->month intValueInComponent:_comp];
}

- (void)setYear:(int)_year inComponent:(WOComponent *)_comp {
  if (self->date) {
    NSCalendarDate *d = [self->date valueInComponent:_comp];
    
    d = [NSCalendarDate dateWithYear:_year
                        month:[d monthOfYear]
                        day:[d dayOfMonth]
                        hour:[d hourOfDay]
                        minute:[d minuteOfHour]
                        second:[d secondOfMinute]
                        timeZone:[d timeZone]];
    
    [self->date setValue:d inComponent:_comp];        
  }
  else {
    [self->year setIntValue:_year inComponent:_comp];
  }
}
- (int)yearInComponent:(WOComponent *)_comp {
  return (self->date != nil)
    ? [[self->date valueInComponent:_comp] yearOfCommonEra]
    : [self->year intValueInComponent:_comp];
}

- (BOOL)isSecondSettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->second isValueSettable];
}

- (BOOL)isMinuteSettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->minute isValueSettable];
}

- (BOOL)isHourSettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->hour isValueSettable];
}

- (BOOL)isDaySettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->day isValueSettable];
}

- (BOOL)isMonthSettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->month isValueSettable];
}

- (BOOL)isYearSettable {
  return (self->date != nil)
    ? [self->date isValueSettable] : [self->year isValueSettable];
}

- (BOOL)_chkDateFormatKey:(NSString *)_s inComponent:(WOComponent *)_comp {
  NSString *fmt;
  
  if (self->format == nil)
    return YES;
  
  fmt = [self->format stringValueInComponent:_comp];
  return ([fmt rangeOfString:_s].length > 0) ? YES : NO;
}

- (BOOL)hasSecondInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"S" inComponent:_comp]
    : (self->second != nil ? YES : NO);
}

- (BOOL)hasMinuteInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"M" inComponent:_comp]
    : (self->minute != nil ? YES : NO);
}

- (BOOL)hasHourInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"H" inComponent:_comp]
    : (self->hour != nil ? YES : NO);
}

- (BOOL)hasDayInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"d" inComponent:_comp]
    : (self->day != nil ? YES : NO);
}

- (BOOL)hasMonthInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"m" inComponent:_comp]
    : (self->month != nil ? YES : NO);
}

- (BOOL)hasYearInComponent:(WOComponent *)_comp {
  return (self->date)
    ? [self _chkDateFormatKey:@"Y" inComponent:_comp]
    : (self->year != nil ? YES : NO);
}

@end /* WECalendarField */
