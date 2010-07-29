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

#include <NGObjWeb/WODynamicElement.h>
#include "WOElement+private.h"
#include "WOCompoundElement.h"
#include <NGObjWeb/WOApplication.h>
#include "common.h"

typedef struct _WOExtraAttrItem  {
  NSString      *key;
  WOAssociation *value;
  NSString      *(*valQuery)(id,SEL,WOComponent *c);
} WOExtraAttrItem;

typedef struct _WOExtraAttrStruct  {
  WOExtraAttrItem *items;
  NSString        *extraString;
  unsigned char   count;
} WOExtraAttrs;

@implementation WODynamicElement

+ (int)version {
  return [super version] + 0 /* v2 */;
}

static Class FormClass        = Nil;
static Class FormElementClass = Nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if (!isInitialized) {
    isInitialized = YES;

    FormClass        = NSClassFromString(@"WOForm");
    FormElementClass = NSClassFromString(@"WOInput");
  }
}

//static int i = 0;

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_rootChild
{
  if ((self = [super init])) {
    WOAssociation *t;
    
    self->otherTagString = OWGetProperty(_associations, @"otherTagString");
    
    t = OWGetProperty(_associations, @"debug");
    self->debug = [t boolValueInComponent:nil];
    [t release]; t = nil;
  }
  return self;
}
- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  contentElements:(NSArray *)_contents
{
  /* this method was discovered in SSLContainer.h and may not be public */
  WOCompoundElement *template;
  int count;
  
  count = [_contents count];
  
  if (count == 0) {
    template = nil;
  }
  else if (count == 1) {
    template = [_contents objectAtIndex:0];
  }
  else {
    template = [[WOCompoundElement allocForCount:[_contents count]
                                   zone:[self zone]]
                                   initWithContentElements:_contents];
    [template autorelease];
  }
  
  return [self initWithName:_name
               associations:_associations
               template:template];
}

- (id)init {
  return [self initWithName:[NSString stringWithFormat:@"0x%p", self]
               associations:nil
               template:nil];
}

- (void)dealloc {
  register WOExtraAttrs *ea;
  
  [self->otherTagString release];

  if ((ea = self->extraAttributes) != NULL) { // GC
    register unsigned short i;
    
    [ea->extraString release];
    for (i = 0; i < ea->count; i++) {
      [ea->items[i].key   release];
      [ea->items[i].value release];
    }
    if (ea->items)
      free(ea->items);
    
    free(self->extraAttributes);
    self->extraAttributes = ea = NULL;
  }
  [super dealloc];
}

/* accessors */

- (NSString *)elementID {
  return [[[WOApplication application] context] elementID];
}

- (void)setExtraAttributes:(NSDictionary *)_extras {
  register WOExtraAttrs *ea;
  NSEnumerator    *ke;
  NSString        *key;
  NSMutableString *es;

  if ([_extras count] == 0)
    /* no extra attributes ... */
    return;
  
  if (self->extraAttributes) {
    [self errorWithFormat:
            @"(%s): tried to reset extra attributes (access denied) !!!",
            __PRETTY_FUNCTION__];
    return;
  }
  
  /* setup structure */

  ea = calloc(1, sizeof(WOExtraAttrs));
  ea->count = 0;
  ea->items = calloc([_extras count], sizeof(WOExtraAttrItem));
  
  /* fill structure */
  
  es = nil;
  ke = [_extras keyEnumerator];
  while ((key = [ke nextObject])) {
    WOAssociation *value;

    //key   = [key lowercaseString];
    value = [_extras objectForKey:key];
    
    if ([value isValueConstant]) {
      /* static value (calculated *now*) */
      NSString *s;
      
      if (es == nil)
        es = [[NSMutableString alloc] initWithCapacity:128];
      
      /* query value */
      s = [value stringValueInComponent:nil];
      
      /* HTML escape value ... */
      s = [s stringByEscapingHTMLAttributeValue];
      
      /* add to static string */
      [es appendString:@" "];
      [es appendString:key];
      [es appendString:@"=\""];
      [es appendString:s];
      [es appendString:@"\""];
    }
    else {
      /* dynamic value (calculated at runtime) */
      register WOExtraAttrItem *item;
      
      item = &(ea->items[ea->count]);
      item->key   = [key copy];
      item->value = RETAIN(value);
      item->valQuery = /* cache method IMP */
        (void*)[value methodForSelector:@selector(stringValueInComponent:)];
      ea->count++;
    }
  }
  
  /* check results for static vs dynamic ... */
  
  if (ea->count == 0) {
    /* no dynamic attributes, free items structure ... */
    free(ea->items);
    ea->items = NULL;
  }
  if ([es length] > 0) ea->extraString = [es copy];
  [es release]; es = nil;
  
  /* finish */
  self->extraAttributes = ea;
}

- (id)template {
  return nil;
}

+ (BOOL)isDynamicElement {
  return YES;
}

/* description */

- (void)appendExtraAttributesToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (self->extraAttributes) {
    register WOExtraAttrs *ea;
    
    ea = self->extraAttributes;
    
    if (ea->count > 0) {
      /* has dynamic attributes */
      WOComponent *sComponent;
      register unsigned short i;
      
      sComponent = [_ctx component];
      
      for (i = 0; i < ea->count; i++) {
        register WOExtraAttrItem *item;
        NSString *value;
        
        item = &(ea->items[i]);
        
        if (item->valQuery) {
          /* use cached selector implementation */
          value = item->valQuery(item->value,@selector(stringValueInComponent:),
                                 sComponent);
        }
        else {
          value = [item->value stringValueInComponent:sComponent];
        }
        
        WOResponse_AddChar(_response, ' ');
        WOResponse_AddString(_response, item->key);
        WOResponse_AddCString(_response, "=\"");
        [_response appendContentHTMLAttributeValue:value];
        WOResponse_AddChar(_response, '"');
      }
    }
    
    /* add static string */
    if (ea->extraString)
      WOResponse_AddString(_response, ea->extraString);
  }
}

- (NSString *)associationDescription {
#if 1
  return nil;
#else
  if (self->extraAttributes) {
    NSMutableString *ad;
    NSEnumerator *keys;
    NSString     *key;

    ad = [NSMutableString stringWithCapacity:32];
    keys = [self->extraAttributes keyEnumerator];
    while ((key = [keys nextObject])) {
      WOAssociation *value;
      
      value = [self->extraAttributes objectForKey:key];
      
      [ad appendString:@" "];
      [ad appendString:key];
      [ad appendString:@"="];
      [ad appendString:[value description]];
    }
    return ad;
  }
  else
    return nil;
#endif
}

- (NSString *)description {
  NSMutableString *desc      = [NSMutableString stringWithCapacity:100];
  NSString        *assocDesc = [self associationDescription];

  [desc appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  if (assocDesc) [desc appendString:assocDesc];
  [desc appendString:@">"];

  return desc;
}

@end /* WODynamicElement */

#include <DOM/EDOM.h>
#include <NGObjWeb/NGObjWeb.h>
#include <NGObjWeb/WOxElemBuilder.h>
#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

/*
  The new DOM element init function for elements constructed from DOM element
  nodes.

  The default method is defined on NSObject instead of WOElement, since some
  dynamic elements are class clusters, which use temporary non-WOElement 
  classes during construction.

  The default construction process requires no support from existing NGObjWeb
  elements.
  It maps all tag attributes to element associations and all child nodes to 
  subelements.
  The tagname is used as the dynamic element name.
*/

@implementation NSObject(InitElement)

- (id)initWithElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder
{
  NSString            *name;
  NSMutableDictionary *assocs;
  NSArray             *children;
  id<NSObject,DOMNamedNodeMap> attrs;
  unsigned count;
  
  name = [_element tagName];
  
  /* construct associations */
  
  assocs = nil;
  attrs = [_element attributes];
  if ((count = [attrs length]) > 0)
    assocs = [_builder associationsForAttributes:attrs];
  
  /* construct child elements */
  
  if ([_element hasChildNodes]) {
    /* look for var:binding tags ... */
    
    children = [_builder buildNodes:[_element childNodes]
                         templateBuilder:_builder];
    [children autorelease];
  }
  else
    children = nil;
  
  /* construct self ... */
  
  self = [(WODynamicElement *)self initWithName:name 
                                   associations:assocs 
                                   contentElements:children];
  [(id)self setExtraAttributes:assocs];
  return self;
}

@end /* NSObject(InitElement) */
