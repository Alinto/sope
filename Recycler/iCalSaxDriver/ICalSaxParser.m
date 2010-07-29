/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "ICalSaxParser.h"
#include "NSString+ICal.h"
#include <SaxObjC/XMLNamespaces.h>
#include <SaxObjC/SaxAttributes.h>
#include "common.h"
#ifdef XCODE_BUILD
#import <libical/ical.h>
#else
#include <ical.h>
#endif

/*
  OPEN: apply default attributes in conformance to xcal !
*/

@interface ICalSaxParser(Privates)

/* walking */

- (void)logUnknownComponentKind:(icalcomponent *)_comp;
- (void)walkSubComponents:(icalcomponent *)_comp;
- (void)walkComponent:(icalcomponent *)_comp;

@end

static BOOL debugOn = NO;

static int _UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
                        unichar **targetStart, const unichar *targetEnd);

@implementation ICalSaxParser 

static Class StrClass = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  StrClass = [NSString class];

  debugOn = [ud boolForKey:@"iCalSaxDriverDebugEnabled"];
}

- (void)dealloc {
  [self->contentHandler release];
  [self->errorHandler   release];
  [self->attrs          release];
  [super dealloc];
}

/* logging of unknown elements etc */

- (void)logUnknownComponentKind:(icalcomponent *)_comp {
  NSLog(@"%s: cannot process component kind: '%s'",
        __PRETTY_FUNCTION__,
        _comp
        ?icalenum_component_kind_to_string(icalcomponent_isa(_comp)):"null");
}

- (void)logUnknownPropertyKind:(icalproperty *)_p {
  NSLog(@"%s: cannot process property kind: '%s'",
        __PRETTY_FUNCTION__,
        _p ? icalenum_property_kind_to_string(icalproperty_isa(_p)) : "null");
}

- (void)logUnknownParameterKind:(icalparameter *)_pa {
  NSLog(@"%s: cannot process parameter kind: '%s'",
        __PRETTY_FUNCTION__,
        _pa ? icalparameter_kind_to_string(icalparameter_isa(_pa)): "null");
}

/* walking */

- (NSString *)stringForValue:(icalvalue *)_val 
  ofProperty:(icalproperty *)_p 
  inComponent:(icalcomponent *)_comp 
{
  const unsigned char *s;
  int len;

  if (_val == NULL) return nil;
  
  if ((s = icalvalue_as_ical_string(_val)) == NULL) {
    /* error ? */
    NSLog(@"%s: couldn't process an iCal value (component=%s,property=%s).",
	  __PRETTY_FUNCTION__,
	  icalenum_component_kind_to_string(icalcomponent_isa(_comp)),
	  icalenum_property_kind_to_string(icalproperty_isa(_p)));
    return nil;
  }
  
  if ((len = strlen(s)) == 0) 
    return @"";

  /* SHOULD USE UTF-8 ?? */
  return [StrClass stringWithCString:s];
}

- (void)walkValue:(icalvalue *)_val 
  ofProperty:(icalproperty *)_p 
  inComponent:(icalcomponent *)_comp 
{
  const unsigned char *s;
  unichar  *data, *ts;
  unsigned len;
  
  if (_val == NULL) return;
  
  /* generic handling for value: pass them as SAX characters ... */
  
  if ((s = icalvalue_as_ical_string(_val)) == NULL) {
    /* error ? */
    NSLog(@"%s: couldn't process an iCal value (component=%s,property=%s).",
	  __PRETTY_FUNCTION__,
	  icalenum_component_kind_to_string(icalcomponent_isa(_comp)),
	  icalenum_property_kind_to_string(icalproperty_isa(_p)));
    return;
  }
  
  if ((len = strlen(s)) == 0) {
    unichar c = 0;
    data = &c;
    [self->contentHandler characters:data length:0];
    return;
  }

  data = ts = calloc(len + 1, sizeof(unichar)); /* GC ?! */
  
  if (_UTF8ToUTF16((void *)&s, (void *)(s + len),
                   (void *)&ts, ts + (len * sizeof(unichar)))) {
    free(data);
    NSLog(@"ERROR(%s:%i): couldn't convert UTF8 to UTF16 !",
          __PRETTY_FUNCTION__, __LINE__);
  }
  else {
    [self->contentHandler characters:data length:((unsigned)(ts - data))];
    free(data);
  }
}

- (NSString *)stringForValueParameter:(icalparameter *)_pa {
  switch (icalparameter_get_value(_pa)) {
  case ICAL_VALUE_BINARY:     return @"binary";
  case ICAL_VALUE_BOOLEAN:    return @"boolean";
  case ICAL_VALUE_DATE:       return @"date";
  case ICAL_VALUE_DURATION:   return @"duration";
  case ICAL_VALUE_FLOAT:      return @"float";
  case ICAL_VALUE_INTEGER:    return @"integer";
  case ICAL_VALUE_PERIOD:     return @"period";
  case ICAL_VALUE_RECUR:      return @"recur";
  case ICAL_VALUE_TEXT:       return @"text";
  case ICAL_VALUE_TIME:       return @"time";
  case ICAL_VALUE_URI:        return @"uri";
  case ICAL_VALUE_ERROR:      return @"error";
  case ICAL_VALUE_DATETIME:   return @"datetime";
  case ICAL_VALUE_UTCOFFSET:  return @"utcoffset";
  case ICAL_VALUE_CALADDRESS: return @"caladdress";
  default:
    return nil;
  }
}
- (NSString *)stringForTzIdParameter:(icalparameter *)_pa {
  const char *s;

  if ((s = icalparameter_get_tzid(_pa)))
    return [StrClass stringWithCString:s];
  return nil;
}
- (NSString *)stringForXParameter:(icalparameter *)_pa {
  const char *s;

  if ((s = icalparameter_get_x(_pa)))
    return [StrClass stringWithCString:s];
  return nil;
}
- (NSString *)stringForCnParameter:(icalparameter *)_pa {
  const char *s;

  if ((s = icalparameter_get_cn(_pa)))
    return [StrClass stringWithCString:s];
  return nil;
}
- (NSString *)stringForDirParameter:(icalparameter *)_pa {
  const char *s;
  
  if ((s = icalparameter_get_dir(_pa)))
    return [StrClass stringWithCString:s];
  return nil;
}
- (NSString *)stringForRoleParameter:(icalparameter *)_pa {
  switch (icalparameter_get_role(_pa)) {
  case ICAL_ROLE_CHAIR:
    return @"CHAIR";
  case ICAL_ROLE_REQPARTICIPANT:
    return @"REQ-PART";
  case ICAL_ROLE_OPTPARTICIPANT:
    return @"OPT-PART";
  case ICAL_ROLE_NONPARTICIPANT:
    return @"NON-PART";
    
  case ICAL_ROLE_NONE:
  case ICAL_ROLE_X:
  default:
    return nil;
  }
}

- (NSString *)stringForPartStatParameter:(icalparameter *)_pa {
  switch (icalparameter_get_partstat(_pa)) {
  case ICAL_PARTSTAT_NEEDSACTION: return @"NEEDSACTION";
  case ICAL_PARTSTAT_ACCEPTED:    return @"ACCEPTED";
  case ICAL_PARTSTAT_DECLINED:    return @"DECLINED";
  case ICAL_PARTSTAT_TENTATIVE:   return @"TENTATIVE";
  case ICAL_PARTSTAT_DELEGATED:   return @"DELEGATED";
  case ICAL_PARTSTAT_COMPLETED:   return @"COMPLETED";
  case ICAL_PARTSTAT_INPROCESS:   return @"INPROCESS";
    
  case ICAL_PARTSTAT_X:
  case ICAL_PARTSTAT_NONE:
  default:
    return nil;
  }
}

- (NSString *)stringForRsvpParameter:(icalparameter *)_pa {
  switch (icalparameter_get_rsvp(_pa)) {
  case ICAL_RSVP_TRUE:  return @"true";
  case ICAL_RSVP_FALSE: return @"false";
    
  case ICAL_RSVP_X:
  case ICAL_RSVP_NONE:
  default:
    return nil;
  }
}

- (id<SaxAttributes>)attrsForPropertyParameters:(icalproperty *)_p {
  /*
   2.7 Mapping Property Parameters to XML

   The property parameters defined in the standard iCalendar format are
   represented in the XML representation as an attribute on element
   types.  The following table specifies the attribute name
   corresponding to each property parameter.

      +----------------+----------------+-----------+-----------------+
      | Property       | Attribute      | Attribute | Default         |
      | Parameter Name | Name           | Type      | Value           |
      +----------------+----------------+-----------+-----------------+
      | ALTREP         | altrep         | ENTITY    | IMPLIED         |
      | CN             | cn             | CDATA     | Null String     |
      | CUTYPE         | cutype         | NMTOKEN   | INDIVIDUAL      |
      | DELEGATED-FROM | delegated-from | CDATA     | IMPLIED         |
      | DELEGATED-TO   | delegated-to   | CDATA     | IMPLIED         |
      | DIR            | dir            | ENTITY    | IMPLIED         |
      | ENCODING       | Not Used       | n/a       | n/a             |
      | FMTTYPE        | fmttype        | CDATA     | REQUIRED        |
      | FBTYPE         | fbtype         | NMTOKEN   | BUSY            |
      | LANGUAGE       | language       | CDATA     | IMPLIED         |
      | MEMBER         | member         | CDATA     | IMPLIED         |
      | PARTSTAT       | partstat       | NMTOKEN   | NEEDS-ACTION    |
      | RANGE          | range          | NMTOKEN   | THISONLY        |
      | RELATED        | related        | NMTOKEN   | START           |
      | RELTYPE        | reltype        | NMTOKEN   | PARENT          |
      | ROLE           | role           | NMTOKEN   | REQ-PARTICIPANT |
      | RSVP           | rsvp           | NMTOKEN   | FALSE           |
      | SENT-BY        | sent-by        | CDATA     | IMPLIED         |
      | TZID           | tzid           | CDATA     | IMPLIED         |
      | VALUE          | value          | NOTATION  | See elements    |
      +----------------+----------------+-----------+-----------------+

   The inline "ENCODING" property parameter is not needed in the XML
   representation.  Inline binary information is always included as
   parsable character data, after first being encoded using the BASE64
   encoding of [RFC 2045].
   */
  icalparameter *pa;
  int s = 0;
  
  for (pa = icalproperty_get_first_parameter(_p, ICAL_ANY_PARAMETER);
       pa != NULL;
       pa = icalproperty_get_next_parameter(_p, ICAL_ANY_PARAMETER)) {
    NSString   *v = nil;
    NSString   *attrName = nil;
    
    switch (icalparameter_isa(pa)) {
    case ICAL_VALUE_PARAMETER:
      attrName = @"value";
      v = [self stringForValueParameter:pa];
      break;
      
    case ICAL_TZID_PARAMETER:
      attrName = @"tzid";
      v = [self stringForTzIdParameter:pa];
      break;
      
    case ICAL_X_PARAMETER:
      attrName = [StrClass stringWithFormat:@"x-unknown-%i", s++];
      v = [self stringForXParameter:pa];
      break;
    case ICAL_CN_PARAMETER:
      attrName = @"cn";
      v = [self stringForCnParameter:pa];
      break;
    case ICAL_DIR_PARAMETER:
      attrName = @"dir";
      v = [self stringForDirParameter:pa];
      break;
    case ICAL_RSVP_PARAMETER:
      attrName = @"rsvp";
      v = [self stringForRsvpParameter:pa];
      break;
    case ICAL_PARTSTAT_PARAMETER:
      attrName = @"partstat";
      v = [self stringForPartStatParameter:pa];
      break;
    case ICAL_ROLE_PARAMETER:
      attrName = @"role";
      v = [self stringForRoleParameter:pa];
      break;
      
    default:
      [self logUnknownParameterKind:pa];
      break;
    }
    
    if (attrName == nil) continue;
    if (v        == nil) continue;
    
    if (self->attrs == nil)
      self->attrs = [[SaxAttributes alloc] init];

    [self->attrs
	 addAttribute:attrName uri:XMLNS_XCAL_01 rawName:attrName 
	 type:@"CDATA"
	 value:v];
  }
  
  return attrs;
}

- (void)handleErrorProperty:(icalproperty *)_p
  ofComponent:(icalcomponent *)_comp 
{
  switch (icalproperty_isa(_p)) {
  case ICAL_XLICERROR_PROPERTY:
    NSLog(@"iCalSaxDriver: found an error property: %s",
	  icalproperty_get_xlicerror(_p));
    break;
    
  default:
    NSLog(@"iCalSaxDriver: found an unknown error property !");
    break;
  }
}

- (void)walkProperty:(icalproperty *)_p ofComponent:(icalcomponent *)_comp {
  /*
2.9 Mapping Component Properties to XML

   Component properties in the standard iCalendar format provide
   calendar information about the calendar component.  The component
   properties defined in the standard iCalendar format are represented
   in the XML representation as element types.  The following tables
   specify the element types corresponding to each of the properties in
   the specified property category.

      Descriptive Component Properties
      +----------------+-------------+-----------------------------+
      | Component      | Element     | Element Content Model       |
      | Property Name  | Name        |                             |
      +----------------+-------------+-----------------------------+
      | ATTACH         | attach      | extref or b64bin            |
      |                | extref      | EMPTY                       |
      |                | b64bin      | PCDATA                      |
      | CATEGORIES     | categories  | Any number of item elements |
      |                | item        | PCDATA                      |
      | CLASS          | class       | PCDATA                      |
      | COMMENT        | comment     | PCDATA                      |
      | DESCRIPTION    | description | PCDATA                      |
      | GEO            | geo         | lat followed by lon element |
      |                | lat         | PCDATA                      |
      |                | lon         | PCDATA                      |
      | LOCATION       | location    | PCDATA                      |
      | PERCENT        | percent     | PCDATA                      |
      | PRIORITY       | priority    | PCDATA                      |
      | RESOURCES      | resources   | Any number of item elements |
      | STATUS         | status      | PCDATA                      |
      | SUMMARY        | summary     | PCDATA                      |
      +----------------+-------------+-----------------------------+
      Date and Time Component Properties
      +----------------+------------+-----------------------------+
      | Component      | Element    | Element Content Model       |
      | Property Name  | Name       |                             |
      +----------------+------------+-----------------------------+
      | COMPLETED      | completed  | PCDATA                      |
      | DTEND          | dtend      | PCDATA                      |
      | DUE            | due        | PCDATA                      |
      | DTSTART        | dtstart    | PCDATA                      |
      | DURATION       | duration   | PCDATA                      |
      | FREEBUSY       | freebusy   | PCDATA                      |
      | TRANSP         | transp     | PCDATA                      |
      +----------------+------------+-----------------------------+


      Time Zone Component Properties
      +----------------+-------------+-----------------------------+
      | Component      | Element     | Element Content Model       |
      | Property Name  | Name        |                             |
      +----------------+-------------+-----------------------------+
      | TZID           | tzid        | PCDATA                      |
      | TZNAME         | tzname      | PCDATA                      |
      | TZOFFSETFROM   | tzoffsetfrom| PCDATA                      |
      | TZOFFSETTO     | tzoffsetto  | PCDATA                      |
      | TZURL          | tzurl       | EMPTY                       |
      +----------------+-------------+-----------------------------+


      Relationship Component Properties
      +----------------+---------------+--------------------------+
      | Component      | Element       | Element Content Model    |
      | Property Name  | Name          |                          |
      +----------------+---------------+--------------------------+
      | ATTENDEE       | attendee      | PCDATA                   |
      | CONTACT        | contact       | PCDATA                   |
      | ORGANIZER      | organizer     | PCDATA                   |
      | RECURRENCE-ID  | recurrence-id | PCDATA                   |
      | RELATED-TO     | related-to    | PCDATA                   |
      | URL            | url           | EMPTY                    |
      | UID            | uid           | PCDATA                   |
      +----------------+---------------+--------------------------+


      Recurrence Component Properties
      +----------------+------------+-----------------------------+
      | Component      | Element    | Element Content Model       |
      | Property Name  | Name       |                             |
      +----------------+------------+-----------------------------+
      | EXDATE         | exdate     | PCDATA                      |
      | EXRULE         | exrule     | PCDATA                      |
      | RDATE          | rdate      | PCDATA                      |
      | RRULE          | rrule      | PCDATA                      |
      +----------------+------------+-----------------------------+


      Alarm Component Properties
      +----------------+------------+-----------------------------+
      | Component      | Element    | Element Content Model       |
      | Property Name  | Name       |                             |
      +----------------+------------+-----------------------------+
      | ACTION         | action     | PCDATA                      |
      | REPEAT         | repeat     | PCDATA                      |
      | TRIGGER        | trigger    | PCDATA                      |
      +----------------+------------+-----------------------------+


      Change Management Component Properties
      +----------------+---------------+--------------------------+
      | Component      | Element       | Element Content Model    |
      | Property Name  | Name          |                          |
      +----------------+---------------+--------------------------+
      | CREATED        | created       | PCDATA                   |
      | DTSTAMP        | dtstamp       | PCDATA                   |
      | LAST-MODIFIED  | last-modified | PCDATA                   |
      | SEQUENCE       | sequence      | PCDATA                   |
      +----------------+---------------+--------------------------+


      Miscellaneous Component Properties
      +----------------+----------------+-------------------------+
      | Component      | Element        | Element Content Model   |
      | Property Name  | Name           |                         |
      +----------------+----------------+-------------------------+
      | REQUEST-STATUS | request-status | PCDATA                  |
      +----------------+----------------+-------------------------+
  */
  NSString *tagName = nil;
  
  if (_p == NULL) return;
  
  switch (icalproperty_isa(_p)) {
  case ICAL_ACTION_PROPERTY:        tagName = @"action";         break;
  case ICAL_ATTENDEE_PROPERTY:      tagName = @"attendee";       break;
  case ICAL_CLASS_PROPERTY:         tagName = @"class";          break;
  case ICAL_COMMENT_PROPERTY:       tagName = @"comment";        break;
  case ICAL_COMPLETED_PROPERTY:     tagName = @"completed";      break;
  case ICAL_CONTACT_PROPERTY:       tagName = @"contact";        break;
  case ICAL_CREATED_PROPERTY:       tagName = @"created";        break;
  case ICAL_DESCRIPTION_PROPERTY:   tagName = @"description";    break;
  case ICAL_DTEND_PROPERTY:         tagName = @"dtend";          break;
  case ICAL_DTSTAMP_PROPERTY:       tagName = @"dtstamp";        break;
  case ICAL_DTSTART_PROPERTY:       tagName = @"dtstart";        break;
  case ICAL_DUE_PROPERTY:           tagName = @"due";            break;
  case ICAL_DURATION_PROPERTY:      tagName = @"duration";       break;
  case ICAL_FREEBUSY_PROPERTY:      tagName = @"freebusy";       break;
  case ICAL_EXDATE_PROPERTY:        tagName = @"exdate";         break;
  case ICAL_EXRULE_PROPERTY:        tagName = @"exrule";         break;
  case ICAL_RDATE_PROPERTY:         tagName = @"rdate";          break;
  case ICAL_RRULE_PROPERTY:         tagName = @"rrule";          break;
  case ICAL_LASTMODIFIED_PROPERTY:  tagName = @"last-modified";  break;
  case ICAL_LOCATION_PROPERTY:      tagName = @"location";       break;
  case ICAL_ORGANIZER_PROPERTY:     tagName = @"organizer";      break;
  case ICAL_PRIORITY_PROPERTY:      tagName = @"priority";       break;
  case ICAL_REPEAT_PROPERTY:        tagName = @"repeat";         break;
  case ICAL_RELATEDTO_PROPERTY:     tagName = @"related-to";     break;
  case ICAL_RECURRENCEID_PROPERTY:  tagName = @"recurrence-id";  break;
  case ICAL_REQUESTSTATUS_PROPERTY: tagName = @"request-status"; break;
  case ICAL_SEQUENCE_PROPERTY:      tagName = @"sequence";       break;
  case ICAL_STATUS_PROPERTY:        tagName = @"status";         break;
  case ICAL_SUMMARY_PROPERTY:       tagName = @"summary";        break;
  case ICAL_TRANSP_PROPERTY:        tagName = @"transp";         break;
  case ICAL_TRIGGER_PROPERTY:       tagName = @"trigger";        break;
  case ICAL_TZID_PROPERTY:          tagName = @"tzid";           break;
  case ICAL_TZNAME_PROPERTY:        tagName = @"tzname";         break;
  case ICAL_TZOFFSETFROM_PROPERTY:  tagName = @"tzoffsetfrom";   break;
  case ICAL_TZOFFSETTO_PROPERTY:    tagName = @"tzoffsetto";     break;
  case ICAL_TZURL_PROPERTY:         tagName = @"tzurl";          break;
  case ICAL_UID_PROPERTY:           tagName = @"uid";            break;
  case ICAL_URL_PROPERTY:           tagName = @"url";            break;
  case ICAL_PERCENTCOMPLETE_PROPERTY:  
    tagName = @"percent-complete";        
    break;
    
    /* special handling in xcal !! check ! */

  case ICAL_GEO_PROPERTY:
    tagName = @"geo";   /* lat followed by lon element */
    //tagName = @"lat";
    //tagName = @"lon";
    break;
    
  case ICAL_RESOURCES_PROPERTY:    
    /* content model: Any number of item elements */
    tagName = @"resources";        
    break;
  case ICAL_CATEGORIES_PROPERTY:    
    /* content model: Any number of item elements */
    tagName = @"categories";        
    break;

  case ICAL_ATTACH_PROPERTY: 
    tagName = @"attach";    /* content model: extref || b64bin */
    // tagName = @"extref"; /* content model: empty  */
    // tagName = @"b64bin"; /* content model: pcdata */
    break;
    
    /* attribute properties */
  case ICAL_PRODID_PROPERTY:
  case ICAL_METHOD_PROPERTY:
  case ICAL_VERSION_PROPERTY:
  case ICAL_CALSCALE_PROPERTY:
    return;
    
    /* extension properties */
  case ICAL_XLICERROR_PROPERTY:
    [self handleErrorProperty:_p ofComponent:_comp];
    return;
    
  case ICAL_X_PROPERTY:
    tagName = [StrClass stringWithCString:icalproperty_get_x_name(_p)];
    break;
    
  default:
    [self logUnknownPropertyKind:_p];
    return;
  }
  
  [self->attrs clear];
  [self->contentHandler
       startElement:tagName
       namespace:XMLNS_XCAL_01
       rawName:tagName
       attributes:[self attrsForPropertyParameters:_p]];
  [self->attrs clear];
  
  switch (icalproperty_isa(_p)) {
    case ICAL_RRULE_PROPERTY: {
      /* this should unparse the rrule parameters as-is */
      NSLog(@"iCalSaxDriver: recurrence rules are not properly handled yet");
      break;
    }
    
    default:
      /* generic handling for value: pass them as SAX characters ... */
      [self walkValue:icalproperty_get_value(_p) 
	    ofProperty:_p inComponent:_comp];
  }
  
  [self->contentHandler
       endElement:tagName
       namespace:XMLNS_XCAL_01
       rawName:tagName];
}

- (id<SaxAttributes>)attrPropertiesOfComponent:(icalcomponent *)_comp {
  icalproperty *p;
  
  for (p = icalcomponent_get_first_property(_comp,ICAL_ANY_PROPERTY);
       p != nil;
       p = icalcomponent_get_next_property(_comp,ICAL_ANY_PROPERTY)) {
    NSString   *v = nil;
    NSString   *attrName = nil;
    
    switch (icalproperty_isa(p)) {
    case ICAL_PRODID_PROPERTY:    attrName = @"prodid";   break;
    case ICAL_METHOD_PROPERTY:    attrName = @"method";   break;
    case ICAL_VERSION_PROPERTY:   attrName = @"version";  break;
    case ICAL_CALSCALE_PROPERTY:  attrName = @"calscale"; break;
    default:
      continue;
    }
    
    if (attrName == nil) continue;
    
    v = [self stringForValue:icalproperty_get_value(p)
	      ofProperty:p
	      inComponent:_comp];
    
    if (v == nil) continue;
    
    if (self->attrs == nil)
      self->attrs = [[SaxAttributes alloc] init];
    
    [self->attrs
	 addAttribute:attrName uri:XMLNS_XCAL_01 rawName:attrName 
	 type:@"CDATA"
	 value:v];
  }
  return self->attrs;
}

- (void)walkPropertiesOfComponent:(icalcomponent *)_comp {
  icalproperty *p;
  
  for (p = icalcomponent_get_first_property(_comp,ICAL_ANY_PROPERTY);
       p != nil;
       p = icalcomponent_get_next_property(_comp,ICAL_ANY_PROPERTY)) {
    [self walkProperty:p ofComponent:_comp];
  }
}

- (void)walkSubComponents:(icalcomponent *)_comp {
  icalcomponent *c;
  
  for(c = icalcomponent_get_first_component(_comp, ICAL_ANY_COMPONENT);
      c != NULL;
      c = icalcomponent_get_next_component(_comp, ICAL_ANY_COMPONENT)) {
    [self walkComponent:c];
  }
}

- (void)walkComponent:(icalcomponent *)_comp {
  /*
      Component Structuring Properties
      +----------------+------------+-------------------------------+
      | Component      | Element    | Element Content Model         |
      | Property Name  | Name       |                               |
      +----------------+------------+-------------------------------+
      | Multiple iCal- | iCalendar  | One or more iCal elements     |
      | endar objects  |            |                               |
      | VCALENDAR      | vcalendar  | calcomp parameter entity      |
      | VEVENT         | vevent     | vevent.opt1 and vevent.optm   |
      |                |            | parameter entity and valarm   |
      |                |            | element                       |
      | VTODO          | vtodo      | vtodo.opt1 and vtodo.optm     |
      |                |            | parameter entity and valarm   |
      |                |            | element                       |
      | VJOURNAL       | vjournal   | vjournal.opt1 and             |
      |                |            | vjournal.optm parameter       |
      |                |            | entity                        |
      | VFREEBUSY      | vfreebusy  | vfreebusy.opt1 and            |
      |                |            | vfreebusy.optm parameter      |
      |                |            | entity                        |
      | VTIMEZONE      | vtimezone  | vtimezone.man,                |
      |                |            | vtimezone.opt1,               |
      |                |            | vtimezone.mann parameter      |
      |                |            | entity                        |
      | STANDARD       | standard   | standard.man or standard.optm |
      |                |            | entity                        |
      | DAYLIGHT       | daylight   | daylight.man or daylight.optm |
      |                |            | entity                        |
      | VALARM         | valarm     | valarm.audio, valarm.display, |
      |                |            | valarm.email and              |
      |                |            | valarm.procedure entity       |
      +----------------+------------+-------------------------------+
  */
  NSString *tagName = nil;
  
  switch (icalcomponent_isa(_comp)) {
    case ICAL_VCALENDAR_COMPONENT:
      tagName = @"vcalendar";
      break;
    case ICAL_VFREEBUSY_COMPONENT:
      tagName = @"vfreebusy";
      break;
    case ICAL_VEVENT_COMPONENT:
      tagName = @"vevent";
      break;
    case ICAL_VTODO_COMPONENT:
      tagName = @"vtodo";
      break;
    case ICAL_VJOURNAL_COMPONENT:
      tagName = @"vjournal";
      break;
    case ICAL_VTIMEZONE_COMPONENT:
      tagName = @"vtimezone";
      break;
    case ICAL_VALARM_COMPONENT:
      tagName = @"valarm";
      break;

    case ICAL_XSTANDARD_COMPONENT:
      tagName = @"standard"; // in xcal as "standard" component ?
      break;
    case ICAL_XDAYLIGHT_COMPONENT:
      tagName = @"daylight"; // in xcal as "daylight" component ?
      break;
      
    case ICAL_XROOT_COMPONENT:
      /* root component for a file with multiple components */
      tagName = @"iCalendar";
      break;
      
    default:
      [self logUnknownComponentKind:_comp];
      return;
  }
  
  /*
    attributes:
      calscale - cdata   - implied
      method   - nmtoken - publish
      version  - cdata   - required
      prodid   - cdata   - implied

    vcalendar: language - cdata - implied
  */
  
  [self->attrs clear];
  [self->contentHandler
       startElement:tagName
       namespace:XMLNS_XCAL_01
       rawName:tagName
       attributes:[self attrPropertiesOfComponent:_comp]];
  [self->attrs clear];

  [self walkPropertiesOfComponent:_comp];
  
  [self walkSubComponents:_comp];
  
  [self->contentHandler
       endElement:tagName
       namespace:XMLNS_XCAL_01
       rawName:tagName];
}

- (void)walkRootComponent:(icalcomponent *)_comp {
  [self->contentHandler startDocument];
  [self->contentHandler startPrefixMapping:@"" uri:XMLNS_XCAL_01];
  
  [self walkComponent:_comp];
  
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
}

/* parsing */

- (void)_reportICalErrno:(icalerrorenum)_errcode {
  switch (_errcode) {
  case ICAL_NO_ERROR:
    /* well, no error ... */
    break;
    
  case ICAL_BADARG_ERROR:
  case ICAL_NEWFAILED_ERROR:
  case ICAL_ALLOCATION_ERROR:
  case ICAL_MALFORMEDDATA_ERROR:
  case ICAL_PARSE_ERROR:
  case ICAL_INTERNAL_ERROR:
    /* Like assert --internal consist. prob */
  case ICAL_FILE_ERROR:
  case ICAL_USAGE_ERROR:
  case ICAL_UNIMPLEMENTED_ERROR:
  case ICAL_UNKNOWN_ERROR:
    /* Used for problems in input to icalerror_strerror()*/
    
  default: {
    SaxParseException *e;
    const char *errstr;
    NSString   *s;
    
    errstr = icalerror_strerror(_errcode);
    if (debugOn) {
      NSLog(@"%s: generic ical parsing error(code=%i): %s",
	    __PRETTY_FUNCTION__, _errcode, errstr);
    }
    s = [[StrClass alloc] initWithFormat:@"generic libical error %i: %s",
			    _errcode, errstr];
    e = (id)[SaxParseException exceptionWithName:@"SaxParseException"
                               reason:s
                               userInfo:nil];
    [s release];
    [self->errorHandler fatalError:e];
    break;
  }
  }
}

- (BOOL)parseString:(NSString *)_string {
  icalcomponent *c;
  const char    *str;

  if (debugOn) {
    NSLog(@"%s: parse string (len=%i)", __PRETTY_FUNCTION__, 
	  [_string length]);
  }
  if (_string == nil) {
    if (debugOn) NSLog(@"%s:   got no string ...", __PRETTY_FUNCTION__);
    return NO;
  }
  if ((str = [_string icalCString]) == NULL) {
    if (debugOn) NSLog(@"%s:   got no icalCString ...", __PRETTY_FUNCTION__);
    return NO;
  }

  // printf("STR: '%s'(%i)\n", str, strlen(str));
  
  if ((c = icalparser_parse_string(str)) == NULL) {
    /* parsing failed ... */
    if (debugOn)
      NSLog(@"%s:   libical parsing failed ...", __PRETTY_FUNCTION__);
    [self _reportICalErrno:icalerrno];
    return NO;
  }
  
  [self walkRootComponent:c];
  
  return YES;
}
- (BOOL)parseData:(NSData *)_data {
  icalcomponent *c;
  unsigned char *str;
  unsigned len;
  
  if (_data == nil) return NO;

  len = [_data length];
  str = malloc(len + 10);
  [_data getBytes:str length:len];
  str[len] = '\0';
  
  if ((c = icalparser_parse_string(str)) == NULL)
    /* parsing failed ... */
    return NO;
  
  [self walkRootComponent:c];
  
  return YES;
}

- (void)parseFileAtPath:(NSString *)_path encoding:(NSStringEncoding)_enc {
  NSAutoreleasePool *pool;
  NSData   *data;
  NSString *s;

  if (debugOn)
    NSLog(@"%s: parse file: %@", __PRETTY_FUNCTION__, _path);
  
  pool = [[NSAutoreleasePool alloc] init];
  
  data = [[NSData alloc] initWithContentsOfMappedFile:_path];
  if (data == nil) {
    /* throw Sax Exception ! */
    if (debugOn)
      NSLog(@"%s:   could not map data: %@", __PRETTY_FUNCTION__, _path);
    return;
  }
  
  s = [[[StrClass alloc] initWithData:data encoding:_enc] autorelease];
  [data release];
  
  [self parseString:s];
  
  [pool release];
}
- (void)parseFileAtPath:(NSString *)_path {
  [self parseFileAtPath:_path encoding:NSUTF8StringEncoding];
}

/* SaxXMLReader */

/* features & properties */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
}
- (BOOL)feature:(NSString *)_name {
  return NO;
}
- (void)setProperty:(NSString *)_name to:(id)_value {
}
- (id)property:(NSString *)_name {
  return nil;
}

/* handlers */

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
}
- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return nil;
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return nil;
}

/* parsing */

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  if (debugOn)
    NSLog(@"%s: parse(%@): %@", __PRETTY_FUNCTION__, _sysId, _source);
  
  if (_source == nil) {
    /* no source ??? */
    if (debugOn) NSLog(@"%s: not source: %@)", __PRETTY_FUNCTION__, _sysId);
    return;
  }

  if ([_source isKindOfClass:StrClass]) {
    /* convert strings to UTF8 data */
    if (_sysId == nil) _sysId = @"<string>";
    if (debugOn) {
      NSLog(@"%s:   parse string (len=%i))", __PRETTY_FUNCTION__, 
	    [_source length]);
    }
    [self parseString:_source];
    return;
  }
  
  if ([_source isKindOfClass:[NSURL class]]) {
    if (_sysId == nil) _sysId = [_source absoluteString];
    if (debugOn) NSLog(@"%s:  load URL: %@", __PRETTY_FUNCTION__, _source);
    _source = [_source resourceDataUsingCache:NO];
  }
  else if ([_source isKindOfClass:[NSData class]]) {
    if (_sysId == nil) _sysId = @"<data>";
  }
  else {
    SaxParseException *e;
    NSDictionary      *ui;
    
    if (debugOn) {
      NSLog(@"%s:  unknown source class: %@", __PRETTY_FUNCTION__, 
	    NSStringFromClass([_source class]));
    }
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _source ? _source : @"<nil>", @"source",
                         self,                         @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle datasource"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
    return;
  }
  
  if (debugOn) {
    NSLog(@"%s:   parse data (len=%i))", __PRETTY_FUNCTION__, 
	  [_source length]);
  }
  [self parseData:_source];
}

- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:nil];
}

- (void)parseFromSystemId:(NSString *)_sysId {
  if (debugOn)
    NSLog(@"%s: parse ID: %@", __PRETTY_FUNCTION__, _sysId);
  
  if (![_sysId hasPrefix:@"file:"]) {
    SaxParseException *e;
    NSDictionary      *ui;
    NSURL *url;
    
    if ((url = [NSURL URLWithString:_sysId])) {
      [self parseFromSource:url systemId:_sysId];
      return;
    }

    if (debugOn)
      NSLog(@"%s:   could not parse ID: %@", __PRETTY_FUNCTION__, _sysId);
  
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _sysId ? _sysId : @"<nil>", @"systemID",
                         self,                       @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"cannot handle system-id"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
    return;
  }

  /* cut off file:// */
  if ([_sysId hasPrefix:@"file://"])
    _sysId = [_sysId substringFromIndex:7];
  else
    _sysId = [_sysId substringFromIndex:5];
  
  if (debugOn)
    NSLog(@"%s:   parse file: %@", __PRETTY_FUNCTION__, _sysId);
  [self parseFileAtPath:_sysId];
}

@end /* ICalSaxParser */

@interface iCalSaxDriver : ICalSaxParser
@end

@implementation iCalSaxDriver
@end

#include "unicode.h"
