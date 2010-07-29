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

#include "WOXMLMappingModel.h"
#include "WOXMLMappingEntity.h"
#include "WOXMLSaxModelHandler.h"
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "common.h"

@implementation WOXMLMappingModel

+ (id)mappingModelByParsingFromURL:(NSString *)_url {
  id<NSObject,SaxXMLReader> parser;
  WOXMLSaxModelHandler      *sax;
  WOXMLMappingModel         *model;
  
  if ([_url length] == 0)
    /* invalid URL */
    return nil;
  
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory] createXMLReader];
  if (parser == nil)
    /* couldn't create parser */
    return nil;
  
  sax = [[WOXMLSaxModelHandler alloc] init];
  [parser setContentHandler:sax];
  [parser setErrorHandler:sax];
  
  [parser parseFromSystemId:_url];
  
  model = RETAIN([sax model]);
  RELEASE(sax);
  
  return AUTORELEASE(model);
}

- (void)dealloc {
  RELEASE(self->tagToEntity);
  RELEASE(self->entities);
  [super dealloc];
}

/* entities */

- (void)addEntity:(WOXMLMappingEntity *)_entity {
  NSAssert1([_entity isValid], @"tried to add invalid entity %@", _entity);
  
  if (self->entities == nil)
    self->entities = [[NSMutableArray alloc] init];
  if (self->tagToEntity == nil)
    self->tagToEntity = [[NSMutableDictionary alloc] init];
  
  if ([self->tagToEntity objectForKey:[_entity xmlTag]]) {
    NSLog(@"WARNING: already defined entity for tag %@", [_entity xmlTag]);
    return;
  }
  
  [self->entities    addObject:_entity];
  [self->tagToEntity setObject:_entity forKey:[_entity xmlTag]];
}

- (WOXMLMappingEntity *)entityForXmlTag:(NSString *)_xmlTag {
  return [self->tagToEntity objectForKey:_xmlTag];
}

- (NSArray *)entities {
  return self->entities;
}

/* XML representation */

- (NSString *)xmlStringValue {
  NSMutableString *s;
  NSEnumerator *e;
  id entity;

  s = [NSMutableString stringWithCapacity:4096];
  [s appendString:@"<model>\n"];
  
  e = [[self entities] objectEnumerator];
  while ((entity = [e nextObject]))
    [s appendString:[entity xmlStringValue]];
  
  [s appendString:@"</model>\n"];
  return s;
}

@end /* WOXMLMappingModel */
