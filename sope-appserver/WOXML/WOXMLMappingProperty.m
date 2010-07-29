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

#include "WOXMLMappingProperty.h"
#include "common.h"

@implementation WOXMLMappingProperty

- (id)initWithEntity:(WOXMLMappingEntity *)_entity {
  self->entity = _entity;
  return self;
}

- (void)dealloc {
  RELEASE(self->name);
  RELEASE(self->xmlTag);
  RELEASE(self->codeBasedOn);
  RELEASE(self->outputTags);
  [super dealloc];
}

/* validity */

- (BOOL)isValid {
  if ([self->name length] == 0)
    return NO;
  if ([self->xmlTag length] == 0)
    return NO;
  return YES;
}

- (WOXMLMappingEntity *)entity {
  return self->entity;
}

/* attributes */

- (void)setName:(NSString *)_name {
  ASSIGN(self->name, _name);
}
- (NSString *)name {
  return self->name;
}

- (void)setXmlTag:(NSString *)_xmlTag {
  ASSIGN(self->xmlTag, _xmlTag);
}
- (NSString *)xmlTag {
  return self->xmlTag;
}

- (void)setCodeBasedOn:(NSString *)_codeBasedOn {
  ASSIGN(self->codeBasedOn, _codeBasedOn);
}
- (NSString *)codeBasedOn {
  return self->codeBasedOn;
}

- (void)setOutputTags:(NSString *)_tags {
  ASSIGN(self->outputTags, _tags);
}
- (NSString *)outputTags {
  return self->outputTags;
}

- (void)setAttribute:(BOOL)_flag {
  self->attribute = _flag;
}
- (BOOL)attribute {
  return self->attribute;
}

- (void)setForceList:(BOOL)_flag {
  self->forceList = _flag;
}
- (BOOL)forceList {
  return self->forceList;
}

- (void)setReportEmptyValues:(BOOL)_flag {
  self->reportEmptyValues = _flag;
}
- (BOOL)reportEmptyValues {
  return self->reportEmptyValues;
}

/* XML representation */

- (NSString *)xmlStringValue {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:100];
  [s appendString:@"<property"];
  [s appendString:@" name='"];
  [s appendString:[self name]];
  [s appendString:@"' xmlTag='"];
  [s appendString:[self xmlTag]];
  [s appendString:@"'"];
  
  if ([self reportEmptyValues])
    [s appendString:@" reportEmptyValues='YES'"];
  if ([self forceList])
    [s appendString:@" forceList='YES'"];
  if ([self attribute])
    [s appendString:@" attribute='YES'"];
  
  [s appendString:@"/>\n"];
  return s;
}

/* description */

- (NSString *)description {
  NSMutableString *s;

  s = [NSMutableString stringWithCapacity:100];
  [s appendFormat:@"<%@ 0x%p:", NSStringFromClass([self class]), self];

  if ([self name])
    [s appendFormat:@" name=%@", [self name]];
  if ([self xmlTag])
    [s appendFormat:@" tag=%@", [self xmlTag]];
  if ([self codeBasedOn])
    [s appendFormat:@" codeBasedOn=%@", [self codeBasedOn]];
  if ([self outputTags])
    [s appendFormat:@" out-tags=%@", [self outputTags]];

  if ([self attribute])
    [s appendString:@" attribute"];
  if ([self forceList])
    [s appendString:@" forceList"];
  if ([self reportEmptyValues])
    [s appendString:@" reportEmptyValues"];
  
  [s appendString:@">"];
  return s;
}

@end /* WOXMLMappingProperty */
