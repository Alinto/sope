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

#include "WOxTemplateBuilder.h"
#include <NGObjWeb/WOxElemBuilder.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOElement.h>
#include <DOM/DOM.h>
#include <DOM/DOMBuilderFactory.h>
#include "common.h"

@implementation WOxTemplateBuilder

static BOOL  profLoading = NO;
static Class DateClass = Nil;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if (DateClass == Nil)
    DateClass = [NSDate class];
}

- (WOxElemBuilder *)builderForDocument:(id<DOMDocument>)_document {
  return [[WOApplication application] builderForDocument:_document];
}
- (Class)templateClass {
  return [WOTemplate class];
}

- (WOTemplate *)buildTemplateFromDocument:(id<NSObject,DOMDocument>)_doc
  url:(NSURL *)_url
{
  WOTemplate        *template;
  NSTimeInterval    st = 0.0;
  WOxElemBuilder    *builder;
  WOElement         *root;
  WOComponentScript *script;
  
  if (_doc == nil)
    return nil;
  
  if (profLoading)
    st = [[DateClass date] timeIntervalSince1970];
  
  builder = [self builderForDocument:_doc];
  
  root = [builder buildTemplateFromDocument:_doc];
  
  template = [[self templateClass] alloc];
  template = [template initWithURL:_url rootElement:root];
  [root release];
  
  /* transform builder info's into element defs ... */
  
  if (template) {
    NSEnumerator *scinfos;
    WOxElemBuilderComponentInfo *scinfo;
    
    scinfos = [[builder subcomponentInfos] objectEnumerator];
    
    while ((scinfo = [scinfos nextObject])) {
      [template addSubcomponentWithKey:[scinfo componentId]
                name:[scinfo pageName]
                bindings:[scinfo bindings]];
    }
    
    if ((script = [builder componentScript]))
      [template setComponentScript:script];
  }
  
  /* reset building state */
  [builder reset];
  
  if (profLoading) {
    NSTimeInterval diff;
    diff = [[DateClass date] timeIntervalSince1970] - st;
    printf("  building from XML: %0.3fs\n", diff);
  }
  return template;
}

- (id<DOMBuilder>)xmlParserForURL:(NSURL *)_url {
  static DOMBuilderFactory *factory = nil;
  
  if (factory == nil)
    factory = [[DOMBuilderFactory standardDOMBuilderFactory] retain];
  
  // TODO: somewhat hackish
  if ([[_url path] hasSuffix:@".html"])
    return [factory createDOMBuilderForMimeType:@"text/html"];
  if ([[_url path] hasSuffix:@".stx"])
    return [factory createDOMBuilderForMimeType:@"text/structured"];
  
  // TODO: do we want to cache the builder?
  return [factory createDOMBuilderForMimeType:@"text/xml"];
}

- (WOTemplate *)buildTemplateAtURL:(NSURL *)_url {
  id<NSObject,DOMDocument> domDocument;
  NSAutoreleasePool *pool;
  id<DOMBuilder>    builder;
  WOTemplate        *template;
  
#if 0  
  [self logWithFormat:@"loading XML template %@ ...", self->path];
#endif
  
  pool = [[NSAutoreleasePool alloc] init];
  
  builder = [self xmlParserForURL:_url];
  NSAssert(builder != nil, @"missing XML parser ..");
  
  domDocument = [builder buildFromSource:_url];
#if 0
  [@"file://" stringByAppendingString:self->path]];
#endif

  /* construct template for DOM document */
  
  if (domDocument) {
    template = [self buildTemplateFromDocument:domDocument url:_url];
    
    /* should scan document for class/script information */
  }
  else
    template = nil;

  [pool release];
  
  return template;  
}

@end /* WOxTemplateBuilder */
