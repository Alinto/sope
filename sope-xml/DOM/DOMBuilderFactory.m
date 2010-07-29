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

#include "DOMBuilderFactory.h"
#include <DOM/DOMSaxBuilder.h>
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "common.h"

@implementation DOMBuilderFactory

static id factory = nil;

+ (id)standardDOMBuilderFactory {
  if (factory == nil)
    factory = [[self alloc] init];
  return factory;
}

/* primary method */

- (id<NSObject,DOMBuilder>)createDOMBuilderWithXmlReader:(id<SaxXMLReader>)_r {
  DOMSaxBuilder *builder;

  if (_r == nil)
    return nil;
  
  builder = [[DOMSaxBuilder alloc] initWithXMLReader:_r];
  return [builder autorelease];
}

/* reader constructors */

- (SaxXMLReaderFactory *)readerFactory {
  return [SaxXMLReaderFactory standardXMLReaderFactory];
}

- (id<NSObject,DOMBuilder>)createDOMBuilder {
  id<SaxXMLReader> reader;
  
  if ((reader = [[self readerFactory] createXMLReader]) == nil) {
    NSLog(@"%s:%i: could not create default DOM builder "
          @"because no SAX default reader could be constructed.",
          __PRETTY_FUNCTION__, __LINE__);
    return nil;
  }
  
  return [self createDOMBuilderWithXmlReader:reader];
}
- (id<NSObject,DOMBuilder>)createDOMBuilderWithName:(NSString *)_name {
  id<SaxXMLReader> reader;

  if ((reader = [[self readerFactory] createXMLReaderWithName:_name]) == nil) {
    NSLog(@"%s:%i: could not create DOM builder '%@' "
          @"because no SAX reader named '%@' could be constructed.",
          __PRETTY_FUNCTION__, __LINE__,
          _name, _name);
    return nil;
  }
  
  return [self createDOMBuilderWithXmlReader:reader];
}
- (id<NSObject,DOMBuilder>)createDOMBuilderForMimeType:(NSString *)_mtype {
  id<SaxXMLReader> reader;

  reader = [[self readerFactory] createXMLReaderForMimeType:_mtype];
  if (reader == nil) {
    NSLog(@"%s:%i: could not create DOM builder for MIME type '%@' "
          @"because no SAX proper reader could be constructed.",
          __PRETTY_FUNCTION__, __LINE__, _mtype);
    return nil;
  }
  
  return [self createDOMBuilderWithXmlReader:reader];
}

- (NSArray *)availableDOMBuilders {
  return [NSArray arrayWithObject:@"DOMSaxBuilder"];
}

@end /* DOMBuilderFactory */
