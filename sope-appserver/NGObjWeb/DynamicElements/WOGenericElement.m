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

#include "WOGenericElement.h"
#include "WOElement+private.h"
#include "decommon.h"
#include <NGObjWeb/WOxElemBuilder.h>
#include <DOM/DOMProtocols.h>

// TODO: we should be able to store the key as ASCII ?
// TODO: does it make sense to resolve constant associations ?
//       all constant assocs could be joined at init time ?

#define TagNameType_Assoc  0
#define TagNameType_String 1
#define TagNameType_ASCII  2

typedef struct {
  NSString      *key;
  WOAssociation *value;
} OWAttribute;

@implementation WOGenericElement

- (id)initWithElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder
{
  NSString            *name;
  NSMutableDictionary *assocs;
  NSArray             *children;
  id<NSObject,DOMNamedNodeMap> attrs;
  unsigned lcount;
  
  name  = [_element tagName];
  
  /* construct associations */

  assocs = nil;
  attrs = [_element attributes];
  if ((lcount = [attrs length]) > 0)
    assocs = [_builder associationsForAttributes:attrs];

  if (assocs == nil) {
    assocs = 
      [NSMutableDictionary dictionaryWithObject:
                             [_builder associationForValue:[_element tagName]]
                           forKey:@"elementName"];
  }
  else {
    [assocs setObject:[_builder associationForValue:[_element tagName]]
            forKey:@"elementName"];
  }
  
  /* construct child elements */

  children = [_element hasChildNodes]
    ? [_builder buildNodes:[_element childNodes] templateBuilder:_builder]
    : (NSArray *)nil;
  [children autorelease];
  
  /* construct self ... */
  self = [(WODynamicElement *)self initWithName:name 
                                   associations:assocs 
                                   contentElements:children];
  return self;
}

- (BOOL)_isASCIIString:(NSString *)_s {
  /* TODO: not a very fast check for an ASCII string ... */
  return [_s dataUsingEncoding:NSASCIIStringEncoding 
             allowLossyConversion:NO] != nil ? YES : NO;
}

- (void)_setupAssociations:(NSMutableDictionary *)_associations {
  NSEnumerator *keys;
  NSString     *key     = nil;
  OWAttribute  *mapping = NULL;
  
  if (self->count == 0)
    return;
  
  keys           = [_associations keyEnumerator];
  self->mappings = calloc(self->count, sizeof(OWAttribute));
  
  for (mapping = self->mappings; (key = [keys nextObject]); mapping++) {
    WOAssociation *value;
        
    value = [_associations objectForKey:key];
    mapping->key   = [key copy];
    mapping->value = [value retain];
  }
  [_associations removeAllObjects];
}

- (void)_configureForConstantElementName:(NSString *)s {
  if ([self _isASCIIString:s]) {
    unsigned char *cs;
    unsigned len;
        
    len = [s cStringLength];
    cs = malloc(len + 2);
    [s getCString:(char *)cs];
    cs[len] = '\0';
    self->tagName = cs;
    self->tagNameType = TagNameType_ASCII;
  }
  else {
    /* a tagname which is not ASCII ?? */
    self->tagName = [s copy];
    self->tagNameType = TagNameType_String;
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_template
{
  self = [super initWithName:_name
                associations:_associations
                template:_template];
  
  if (self) {
    WOAssociation *a;
    
    self->tagName     = a = OWGetProperty(_associations, @"elementName");
    self->tagNameType = TagNameType_Assoc;
    self->count   = [_associations count];
    
    if ([a isValueConstant]) {
      [self _configureForConstantElementName:[a stringValueInComponent:nil]];
      [a release]; a = nil;
    }
    
    if (self->count > 0)
      [self _setupAssociations:(NSMutableDictionary *)_associations];
  }
  return self;
}

- (void)dealloc {
  if (self->mappings) {
    OWAttribute *map;
    unsigned cnt;

    for (cnt = 0, map = self->mappings; cnt < self->count; cnt++, map++) {
      [map->key   release]; map->key   = nil;
      [map->value release]; map->value = nil;
    }
    if (self->mappings) free(self->mappings);
    self->mappings = NULL;
  }
  
  switch (self->tagNameType) {
    case TagNameType_Assoc:  [(id)self->tagName release]; break;
    case TagNameType_String: [(id)self->tagName release]; break;
    case TagNameType_ASCII:
      if (self->tagName) free(self->tagName);
      break;
    default:
      [self errorWithFormat:@"unknown tag-name-type %i !", self->tagNameType];
      break;
  }
  [super dealloc];
}

/* response generation */

- (void)_appendAttributesToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  // TODO: this seems to take some time during profiling, maybe we can
  //       optimize that (ASCII keys, constant assocs)
  WOComponent *sComponent = [_ctx component];
  OWAttribute *map;
  unsigned cnt;
  
  for (cnt = 0, map = self->mappings; cnt < self->count; cnt++, map++) {
    register id value;
    
    if ((value = [map->value valueInComponent:sComponent]) == nil)
      continue;

    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response, map->key);
    WOResponse_AddCString(_response, "=\"");
    WOResponse_AddHtmlString(_response, [value stringValue]);
    WOResponse_AddChar(_response, '"');
  }
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *tag;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;
  
  sComponent = [_ctx component];
  
  WOResponse_AddChar(_response, '<');
  switch (self->tagNameType) {
    case TagNameType_Assoc:
      tag = [(id)self->tagName stringValueInComponent:sComponent];
      WOResponse_AddString(_response, tag);
      break;
    case TagNameType_String:
      WOResponse_AddString(_response, self->tagName);
      break;
    case TagNameType_ASCII:
      WOResponse_AddCString(_response, self->tagName);
      break;
  }
  
  [self _appendAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                           sComponent]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

@end /* WOGenericElement */
