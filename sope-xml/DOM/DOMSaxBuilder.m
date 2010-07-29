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

#include "DOMSaxBuilder.h"
#include "DOMSaxHandler.h"
#include "DOMAttribute.h"
#include "DOMDocument.h"
#include "common.h"
#include <SaxObjC/SaxObjC.h>

@implementation DOMSaxBuilder

- (id)initWithXMLReader:(id)_saxParser {
  if (_saxParser == nil) {
    [self release];
    return nil;
  }
  
  ASSIGN(self->parser, _saxParser);
  
  self->sax = [[DOMSaxHandler alloc] init];
  
  [self->parser setContentHandler:self->sax];
  [self->parser setDTDHandler:self->sax];
  [self->parser setErrorHandler:self->sax];
  
  [self->parser setProperty:@"http://xml.org/sax/properties/declaration-handler"
                to:self->sax];
  [self->parser setProperty:@"http://xml.org/sax/properties/lexical-handler"
                to:self->sax];

  return self;
}
- (id)initWithXMLReaderForMimeType:(id)_mimeType {
  id reader;

  reader = [[SaxXMLReaderFactory standardXMLReaderFactory]
                                 createXMLReaderForMimeType:_mimeType];
  if (reader == nil) {
    NSLog(@"%s: could not find a SAX driver bundle for type '%@' !\n",
          __PRETTY_FUNCTION__, _mimeType);
    [self release];
    return nil;
  }
  
  return [self initWithXMLReader:reader];
}

- (id)init {
  id reader;

  reader = [[SaxXMLReaderFactory standardXMLReaderFactory] createXMLReader];

  if (reader == nil) {
    NSLog(@"%s: could not load a SAX driver bundle !\n",
          __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
  
  return [self initWithXMLReader:reader];
}
- (void)dealloc {
  [self->parser release];
  [self->sax    release];
  [super dealloc];
}

/* DOM building */

- (id<NSObject,DOMDocument>)_docAfterParsing {
  id<NSObject,DOMDocument> doc;

  doc = [[self->sax document] retain];

  [(id)doc addErrors:[self->sax errors]];
  [(id)doc addWarnings:[self->sax warnings]];
  
  [self->sax clear];
  return [doc autorelease];
}

- (id)buildFromData:(NSData *)_data {
  NSAutoreleasePool *pool;
  id doc;
  
  if (_data == nil) {
    NSLog(@"missing data ..");
    return nil;
  }
  NSAssert(self->sax,    @"missing sax handler ..");
  NSAssert(self->parser, @"missing XML parser ..");
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    [self->parser parseFromSource:_data];
    doc = [[self _docAfterParsing] retain];
  }
  [pool release];

#if DEBUG
  NSAssert(self->sax,    @"missing sax handler ..");
  NSAssert(self->parser, @"missing XML parser ..");
#endif
  
  return [doc autorelease];
}

- (id)buildFromContentsOfFile:(NSString *)_path {
  NSAutoreleasePool *pool;
  id doc;
  
  if ([_path length] == 0)
    return nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSDate *date;
    NSTimeInterval duration;

    date = [NSDate date];
    _path = [@"file://" stringByAppendingString:_path];
    
    [self->parser parseFromSystemId:_path];
    doc = [[self _docAfterParsing] retain];
    
    duration = [[NSDate date] timeIntervalSinceDate:date];
  }
  [pool release];
  
  return [doc autorelease];
}

- (id<NSObject,DOMDocument>)buildFromSource:(id)_source
  systemId:(NSString *)_sysId
{
  NSAutoreleasePool *pool;
  id doc;
  
  if (_source == nil)
    return nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSDate *date;
    NSTimeInterval duration;

    date = [NSDate date];
    
    [self->parser parseFromSource:_source systemId:_sysId];
    doc = [[self _docAfterParsing] retain];
    
    duration = [[NSDate date] timeIntervalSinceDate:date];
  }
  [pool release];
  
  return [doc autorelease];
}
- (id<NSObject,DOMDocument>)buildFromSource:(id)_source {
  return [self buildFromSource:_source systemId:nil];
}

- (id<NSObject,DOMDocument>)buildFromSystemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  id doc;
  
  if ([_sysId length] == 0)
    return nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSDate *date;
    NSTimeInterval duration;

    date = [NSDate date];
    
    [self->parser parseFromSystemId:_sysId];
    doc = [[self _docAfterParsing] retain];
    
    duration = [[NSDate date] timeIntervalSinceDate:date];
  }
  [pool release];
  
  return [doc autorelease];
}

@end /* DOMSaxBuilder */
