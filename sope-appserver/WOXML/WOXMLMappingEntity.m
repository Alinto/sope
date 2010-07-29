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

#include "WOXMLMappingEntity.h"
#include "WOXMLMappingProperty.h"
#include "common.h"

@implementation WOXMLMappingEntity

- (void)dealloc {
  RELEASE(self->name);
  RELEASE(self->xmlTag);
  RELEASE(self->unmappedTagsKey);
  RELEASE(self->contentsKey);
  RELEASE(self->properties);
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

- (void)setUnmappedTagsKey:(NSString *)_unmappedTagsKey {
  ASSIGN(self->unmappedTagsKey, _unmappedTagsKey);
}
- (NSString *)unmappedTagsKey {
  return self->unmappedTagsKey;
}

- (void)setContentsKey:(NSString *)_contentsKey {
  ASSIGN(self->contentsKey, _contentsKey);
}
- (NSString *)contentsKey {
  return self->contentsKey;
}

- (void)setIgnoreUnmappedTags:(BOOL)_flag {
  self->ignoreUnmappedTags = _flag;
}
- (BOOL)ignoreUnmappedTags {
  return self->ignoreUnmappedTags;
}

/* properties */

- (void)addProperty:(WOXMLMappingProperty *)_property {
  NSAssert1([_property isValid], @"tried to add invalid property %@", _property);
  
  if (self->properties == nil)
    self->properties = [[NSMutableArray alloc] init];
  if (self->tagToProperty == nil)
    self->tagToProperty = [[NSMutableDictionary alloc] init];
  
  if ([self->tagToProperty objectForKey:[_property xmlTag]]) {
    NSLog(@"WARNING: already defined propery for tag %@", [_property xmlTag]);
    return;
  }

  [self->properties    addObject:_property];
  [self->tagToProperty setObject:_property forKey:[_property xmlTag]];
}

- (WOXMLMappingProperty *)propertyForXmlTag:(NSString *)_xmlTag {
  return [self->tagToProperty objectForKey:_xmlTag];
}

- (NSArray *)properties {
  return self->properties;
}

/* XML representation */

- (NSString *)xmlStringValue {
  NSMutableString *s;
  NSEnumerator *e;
  id prop;

  s = [NSMutableString stringWithCapacity:4096];
  [s appendString:@"<entity"];
  [s appendString:@" name='"];
  [s appendString:[self name]];
  [s appendString:@"' xmlTag='"];
  [s appendString:[self xmlTag]];
  [s appendString:@"'"];
  [s appendString:@">\n"];
  
  e = [[self properties] objectEnumerator];
  while ((prop = [e nextObject]))
    [s appendString:[prop xmlStringValue]];
  
  [s appendString:@"</entity>\n"];
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
  if ([self unmappedTagsKey])
    [s appendFormat:@" unmapped=%@", [self unmappedTagsKey]];
  if ([self contentsKey])
    [s appendFormat:@" content=%@", [self contentsKey]];
  
  if (self->ignoreUnmappedTags)
    [s appendString:@" ignore-unmapped"];
  
  [s appendString:@">"];
  return s;
}

@end /* WOXMLMappingEntity */
