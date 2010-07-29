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

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxContentHandler.h>
#include <SaxObjC/SaxDTDHandler.h>
#include <SaxObjC/SaxErrorHandler.h>
#include <SaxObjC/SaxEntityResolver.h>
#include <SaxObjC/SaxLexicalHandler.h>
#include <SaxObjC/SaxLocator.h>
#include <SaxObjC/SaxDeclHandler.h>
#include <expat.h>

@class NSMutableArray, NSMutableDictionary;
@class SaxAttributes;

@interface PlistSaxDriver : NSObject < SaxXMLReader >
{
@private
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;

  /* features */
  BOOL     fNamespaces;
  BOOL     fNamespacePrefixes;
  NSString *plistNamespace;
}

@end

#include <SaxObjC/SaxException.h>
#include <SaxObjC/SaxDocumentHandlerAdaptor.h>
#include <NGExtensions/NGExtensions.h>
#include "common.h"

@interface NSObject(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver;
@end

@interface PlistSaxDriver(Privates)
- (void)_walkDictionary:(NSDictionary *)_dict;
- (void)_walkArray:(NSArray *)_dict;
- (void)_walkData:(NSData *)_dict;
- (void)_walkString:(NSString *)_dict;
@end

@implementation PlistSaxDriver

- (void)dealloc {
  RELEASE(self->contentHandler);
  RELEASE(self->errorHandler);
  [super dealloc];
}

/* properties */

- (void)setProperty:(NSString *)_name to:(id)_value {
  return;
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
}
- (id)property:(NSString *)_name {
  return nil;
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
  return nil;
}

/* features */

- (void)setFeature:(NSString *)_name to:(BOOL)_value {
  if ([_name isEqualToString:@"http://xml.org/sax/features/namespaces"]) {
    self->fNamespaces = _value;
    return;
  }
  
  if ([_name isEqualToString:
               @"http://xml.org/sax/features/namespace-prefixes"]) {
    self->fNamespacePrefixes = _value;
    return;
  }

  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
}
- (BOOL)feature:(NSString *)_name {
  if ([_name isEqualToString:@"http://xml.org/sax/features/namespaces"])
    return self->fNamespaces;
  
  if ([_name isEqualToString:
               @"http://xml.org/sax/features/namespace-prefixes"])
    return self->fNamespacePrefixes;
  
  if ([_name isEqualToString:
               @"http://www.skyrix.com/sax/features/predefined-namespaces"])
    return NO;
  
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
  return NO;
}

/* handlers */

- (void)setDocumentHandler:(id<NSObject,SaxDocumentHandler>)_handler {
  SaxDocumentHandlerAdaptor *a;
  
  a = [[SaxDocumentHandlerAdaptor alloc] initWithDocumentHandler:_handler];
  [self setContentHandler:a];
  RELEASE(a);
}

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return nil;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return nil;
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

/* walking the list */

- (NSString *)plistNamespace {
  return nil;
}

- (void)_writeString:(id)_s {
  unsigned len;
  
  _s = [_s stringValue];
  if ((len = [_s length]) == 0) return;
  
  if (len == 1) {
    unichar c[2];
    [_s getCharacters:&(c[0])];
    c[1] = '\0';
    [self->contentHandler characters:&(c[0]) length:1];
  }
  else {
    unichar *ca;

    ca = calloc(len + 1, sizeof(unichar));
    [_s getCharacters:ca];
    ca[len] = 0;
    [self->contentHandler characters:ca length:len];
    if (ca) free(ca);
  }
}

- (void)_walkDictionary:(NSDictionary *)_dict {
  NSEnumerator *keys;
  id key;

  if (_dict == nil) return;
  
  [self->contentHandler
       startElement:@"dict" namespace:self->plistNamespace
       rawName:@"dict"
       attributes:nil];
  
  keys = [_dict keyEnumerator];
  while ((key = [keys nextObject])) {
    id value;
    
    value = [_dict objectForKey:key];
    
    [self->contentHandler
         startElement:@"key" namespace:self->plistNamespace
         rawName:@"key"
         attributes:nil];

    [self _writeString:key];
    
    [self->contentHandler
         endElement:@"key" namespace:self->plistNamespace
         rawName:@"key"];
    
    [value _walkWithPlistSaxDriver:self];
  }
  
  [self->contentHandler
       endElement:@"dict" namespace:self->plistNamespace
       rawName:@"dict"];
}

- (void)_walkArray:(NSArray *)_array {
  unsigned i, count;

  if (_array == nil) return;
  
  [self->contentHandler
       startElement:@"array" namespace:self->plistNamespace
       rawName:@"array"
       attributes:nil];
  
  for (i = 0, count = [_array count]; i < count; i++)
    [[_array objectAtIndex:i] _walkWithPlistSaxDriver:self];
  
  [self->contentHandler
       endElement:@"array" namespace:self->plistNamespace
       rawName:@"array"];
}

- (void)_walkData:(NSData *)_data {
  NSString *s;
  if (_data == nil) return;
  
  s = [[NSString alloc] initWithData:[_data dataByEncodingBase64]
                        encoding:NSUTF8StringEncoding];
  AUTORELEASE(s);
  
  [self->contentHandler
       startElement:@"data" namespace:self->plistNamespace
       rawName:@"data"
       attributes:nil];
  
  [self _writeString:s];
  
  [self->contentHandler
       endElement:@"data" namespace:self->plistNamespace
       rawName:@"data"];
}

- (void)_walkString:(NSString *)_s {
  if (_s == nil) return;
  
  [self->contentHandler
       startElement:@"string" namespace:self->plistNamespace
       rawName:@"string"
       attributes:nil];

  [self _writeString:_s];

  [self->contentHandler
       endElement:@"string" namespace:self->plistNamespace
       rawName:@"string"];
}

- (void)_walkRoot:(id)_plist {
  static SaxAttributes *versionAttr = nil;

  if (versionAttr == nil) {
    versionAttr = [[SaxAttributes alloc] init];
    [versionAttr addAttribute:@"version" uri:self->plistNamespace
                 rawName:@"version"
                 type:@"CDATA"
                 value:@"0.9"];
  }
  
  [self->contentHandler startDocument];
  
  [self->contentHandler
       startElement:@"plist" namespace:self->plistNamespace
       rawName:@"plist"
       attributes:versionAttr];
  
  [_plist _walkWithPlistSaxDriver:self];
  
  [self->contentHandler
       endElement:@"plist" namespace:self->plistNamespace
       rawName:@"plist"];
  
  [self->contentHandler endDocument];
}

/* parsing ... */

- (void)_parseFromString:(NSString *)_str systemId:(NSString *)_sysId {
  id plist;
  
  if ((plist = [_str propertyList])) {
    [self _walkRoot:plist];
  }
  else if (self->errorHandler) {
    /* log parse error */
    SaxParseException *e;
    NSDictionary *ui;

    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _sysId, @"systemId",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SAXError"
                               reason:@"couldn't parse property list"
                               userInfo:ui];
    
    [self->errorHandler error:e];
  }
}

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
  
  if ([_source isKindOfClass:[NSData class]]) {
    NSString *s;

    s = [[NSString alloc] initWithData:_source
                          encoding:[NSString defaultCStringEncoding]];
    AUTORELEASE(s);
    
    [self _parseFromString:s systemId:_sysId];
  }
  else if ([_source isKindOfClass:[NSURL class]]) {
    [self parseFromSystemId:_source];
  }
  else if ([_source isKindOfClass:[NSString class]]) {
    if (_sysId == nil) _sysId = @"<string>";
    [self _parseFromString:_source systemId:_sysId];
  }
  else if ([_source isKindOfClass:[NSDictionary class]]) {
    if (_sysId == nil) _sysId = @"<dictionary>";
    [_source _walkRoot:self];
  }
  else if ([_source isKindOfClass:[NSArray class]]) {
    if (_sysId == nil) _sysId = @"<array>";
    [_source _walkRoot:self];
  }
  else {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _source ? _source : @"<nil>", @"source",
                         self,                         @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"can't handle data-source"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
  }
  
  RELEASE(pool);
}
- (void)parseFromSource:(id)_source {
  [self parseFromSource:_source systemId:@"<memory>"];
}

- (void)parseFromSystemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  NSString *str;
  NSURL    *url;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  url = [NSURL URLWithString:_sysId];
  str = [NSString stringWithContentsOfURL:url];
  
  [self _parseFromString:str systemId:_sysId];
  
  RELEASE(pool);
}

@end /* PlistSaxDriver */

@implementation NSDictionary(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkDictionary:self];
}
@end

@implementation NSArray(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkArray:self];
}
@end

@implementation NSSet(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkArray:[self allObjects]];
}
@end

@implementation NSData(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkData:self];
}
@end

@implementation NSString(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkString:self];
}
@end

@implementation NSObject(Walking)
- (void)_walkWithPlistSaxDriver:(PlistSaxDriver *)_driver {
  [_driver _walkString:[self stringValue]];
}
@end
