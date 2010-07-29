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

#include "WOXMLSaxModelHandler.h"
#include "WOXMLMappingEntity.h"
#include "WOXMLMappingModel.h"
#include "WOXMLMappingProperty.h"
#include "common.h"

@implementation WOXMLSaxModelHandler

- (void)dealloc {
  RELEASE(self->currentModel);
  RELEASE(self->currentProperty);
  RELEASE(self->currentEntity);
  [super dealloc];
}

- (WOXMLMappingModel *)model {
  return AUTORELEASE(RETAIN(self->currentModel));
}

/* tag handler */

- (void)startModel:(id<SaxAttributes>)_attrs {
  if ((self->currentProperty != nil) || (self->currentEntity != nil)) {
    NSLog(@"cannot nest 'model' tags inside property or entity tags !");
    return;
  }

  RELEASE(self->currentModel); self->currentModel = nil;
  self->currentModel = [[WOXMLMappingModel alloc] init];
}
- (void)endModel {
  if ((self->currentProperty != nil) || (self->currentEntity != nil))
    return;
}

- (void)startEntity:(id<SaxAttributes>)_attrs {
  NSString *s;
  
  if (self->currentProperty) {
    NSLog(@"cannot nest 'entity' tags inside property tags !");
    return;
  }
  if (self->currentEntity) {
    NSLog(@"cannot nest 'entity' tags inside entity tags !");
    return;
  }
  if (self->currentModel == nil) {
    NSLog(@"missing 'model' parent element for 'entity' tag !");
    return;
  }
  
  self->currentEntity = [[WOXMLMappingEntity alloc] init];
  
  if ((s = [_attrs valueForRawName:@"name"]))
    [self->currentEntity setName:s];
  if ((s = [_attrs valueForRawName:@"xmlTag"]))
    [self->currentEntity setXmlTag:s];
  if ((s = [_attrs valueForRawName:@"unmappedTagsKey"]))
    [self->currentEntity setUnmappedTagsKey:s];
  if ((s = [_attrs valueForRawName:@"contentsKey"]))
    [self->currentEntity setContentsKey:s];
  
  if ((s = [_attrs valueForRawName:@"ignoreUnmappedTags"])) {
    [self->currentEntity setIgnoreUnmappedTags:
         [[s uppercaseString] isEqualToString:@"YES"]];
  }
}
- (void)endEntity {
  if ((self->currentProperty != nil) || (self->currentModel == nil))
    return;
  
  if (self->currentEntity) {
    if ([self->currentEntity isValid])
      [self->currentModel addEntity:self->currentEntity];
    RELEASE(self->currentEntity); self->currentEntity = nil;
  }
}

- (void)startProperty:(id<SaxAttributes>)_attrs {
  NSString *s;
  
  if (self->currentProperty) {
    NSLog(@"cannot nest 'property' tags inside property tags !");
    return;
  }
  if ((self->currentEntity == nil) || (self->currentModel == nil)) {
    NSLog(@"missing 'entity' parent element for 'property' tag !");
    return;
  }

  self->currentProperty = [[WOXMLMappingProperty alloc] init];

  if ((s = [_attrs valueForRawName:@"name"]))
    [self->currentProperty setName:s];
  if ((s = [_attrs valueForRawName:@"xmlTag"]))
    [self->currentProperty setXmlTag:s];
  if ((s = [_attrs valueForRawName:@"codeBasedOn"]))
    [self->currentProperty setCodeBasedOn:s];
  if ((s = [_attrs valueForRawName:@"outputTags"]))
    [self->currentProperty setOutputTags:s];
  
  if ((s = [_attrs valueForRawName:@"attribute"])) {
    [self->currentProperty setAttribute:
         [[s uppercaseString] isEqualToString:@"YES"]];
  }
  if ((s = [_attrs valueForRawName:@"forceList"])) {
    [self->currentProperty setForceList:
         [[s uppercaseString] isEqualToString:@"YES"]];
  }
  if ((s = [_attrs valueForRawName:@"reportEmptyValues"])) {
    [self->currentProperty setReportEmptyValues:
         [[s uppercaseString] isEqualToString:@"YES"]];
  }
}
- (void)endProperty {
  if ((self->currentEntity == nil) || (self->currentModel == nil))
    return;

  if (self->currentProperty) {
    if ([self->currentProperty isValid])
      [self->currentEntity addProperty:self->currentProperty];

    RELEASE(self->currentProperty); self->currentProperty = nil;
  }
}

/* SAX */

- (void)startDocument {
  RELEASE(self->currentModel);    self->currentModel    = nil;
  RELEASE(self->currentEntity);   self->currentEntity   = nil;
  RELEASE(self->currentProperty); self->currentProperty = nil;
}
- (void)endDocument {
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  if ([_rawName isEqualToString:@"model"])
    [self startModel:_attrs];
  else if ([_rawName isEqualToString:@"entity"])
    [self startEntity:_attrs];
  else if ([_rawName isEqualToString:@"property"])
    [self startProperty:_attrs];
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  if ([_rawName isEqualToString:@"model"])
    [self endModel];
  else if ([_rawName isEqualToString:@"entity"])
    [self endEntity];
  else if ([_rawName isEqualToString:@"property"])
    [self endProperty];
}

@end /* WOXMLSaxModelHandler */
