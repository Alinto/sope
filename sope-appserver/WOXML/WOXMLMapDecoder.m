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

#include "WOXMLMapDecoder.h"
#include "WOXMLMappingModel.h"
#include "WOXMLMappingEntity.h"
#include "WOXMLMappingProperty.h"
#include "common.h"

#include <DOM/DOMElement.h>
#include <DOM/DOMDocument.h>

@implementation WOXMLMapDecoder

- (id)initWithModel:(WOXMLMappingModel *)_model {
  self->model = [_model retain];
  return self;
}

- (void)dealloc {
  [self->model release];
  [super dealloc];
}

/* operations */

- (WOXMLMappingEntity *)defaultEntity {
  return nil;
}

- (id)_processDOMElementNode:(id)_node {
  WOXMLMappingEntity *entity;
  Class        entityClass;
  id           object;
  NSMutableSet *childTags;
  
  NSAssert1([_node nodeType] == DOM_ELEMENT_NODE,
            @"passed invalid element node: %@", _node);
  
  if ((entity = [self->model entityForXmlTag:[_node tagName]]) == nil) {
    /* missing entity */
    entity = [self defaultEntity];
  }
  if (entity == nil)
    return [_node textValue];
  
  entityClass = NSClassFromString([entity name]);
  if (entityClass == Nil) entityClass = [NSMutableDictionary class];
  
  object = AUTORELEASE([[entityClass alloc] init]);

  childTags = [NSMutableSet setWithCapacity:16];
  
  /* apply properties */
  {
    NSEnumerator *e;
    WOXMLMappingProperty *prop;
    
    e = [[entity properties] objectEnumerator];
    while ((prop = [e nextObject])) {
      if (![prop isValid])
        continue;
      
      if ([prop attribute]) {
        /* an attribute property */
        NSString *attrName;
        NSString *value;
        
        attrName = [prop xmlTag];

        if ((value = [_node attribute:attrName]) == nil)
          value = [_node attribute:attrName namespaceURI:@"*"];
        
        if (value)
          [object takeValue:value forKey:[prop name]];
      }
      else
        [childTags addObject:[prop xmlTag]];
    }
  }
  
  /* walk children */
  {
    unsigned i, count;
    id childNodes;
    NSMutableDictionary *d;

    d = [NSMutableDictionary dictionaryWithCapacity:16];
    
    childNodes = [_node childNodes];
    for (i = 0, count = [childNodes count]; i < count; i++) {
      id child;
      
      child = [childNodes objectAtIndex:i];

      if ([child nodeType] == DOM_ELEMENT_NODE) {
        if ([childTags containsObject:[child tagName]]) {
          /* a property */
          WOXMLMappingProperty *prop;
          id o;
          
          prop = [entity propertyForXmlTag:[child tagName]];
          
          o = [self _processDOMElementNode:child];
          if (o == nil)
            o = [EONull null];

          if ([prop forceList]) {
            NSMutableArray *a;

            a = [d objectForKey:[prop name]];
            if (a == nil) {
              a = [NSMutableArray arrayWithCapacity:1];
              [d setObject:a forKey:[prop name]];
            }
            [a addObject:o];
          }
          else {
            id old;
            
            if ((old = [d objectForKey:[prop name]])) {
              if ([old isKindOfClass:[NSMutableArray class]])
                [old addObject:o];
              else {
                NSMutableArray *a;

                a = [NSMutableArray arrayWithCapacity:2];
                [a addObject:old];
                [a addObject:o];
                [d setObject:a forKey:[prop name]];
              }
            }
            else {
              /* first element */
              [d setObject:o forKey:[prop name]];
            }
          }
        }
        else {
          /* plain content tag */
        }
      }
      else {
      }
    }
    [object takeValuesFromDictionary:d];
  }
  
  return object;
}

- (id)_processDOMDocument:(id)_dom {
  return [self _processDOMElementNode:[_dom documentElement]];
}

/* parsing DOM tree */

- (id)decodeRootObjectFromString:(NSString *)_str {
  id doc;
  
  doc = [NGDOMDocument documentFromString:_str];
  
  return [self _processDOMDocument:doc];
}

- (id)decodeRootObjectFromData:(NSData *)_data {
  id doc;
  
  doc = [NGDOMDocument documentFromData:_data];
  
  return [self _processDOMDocument:doc];
}
- (id)decodeRootObjectFromFileHandle:(NSFileHandle *)_fh {
  return [self decodeRootObjectFromData:[_fh readDataToEndOfFile]];
}

@end /* WOXMLMapDecoder */
