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

#include "pyxSAXDriver.h"
#include <SaxObjC/SaxException.h>
#include <SaxObjC/SaxAttributes.h>
#include <SaxObjC/SaxDocumentHandler.h>
#import <Foundation/Foundation.h>

#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
#  include <FoundationExt/NSObjectMacros.h>
#  include <FoundationExt/MissingMethods.h>
#endif

static NSString *SaxDeclHandlerProperty =
  @"http://xml.org/sax/properties/declaration-handler";
static NSString *SaxLexicalHandlerProperty =
  @"http://xml.org/sax/properties/lexical-handler";
#if 0
static NSString *SaxDOMNodeProperty =
  @"http://xml.org/sax/properties/dom-node";
static NSString *SaxXMLStringProperty =
  @"http://xml.org/sax/properties/xml-string";
#endif

@implementation pyxSAXDriver

- (id)init {
  self->nsStack = [[NSMutableArray alloc] init];
  
  /* feature defaults */
  self->fNamespaces        = YES;
  self->fNamespacePrefixes = NO;
  
  return self;
}

- (void)dealloc {
  RELEASE(self->nsStack);
  RELEASE(self->attrs);

  RELEASE(self->declHandler);
  RELEASE(self->lexicalHandler);
  RELEASE(self->contentHandler);
  RELEASE(self->dtdHandler);
  RELEASE(self->errorHandler);
  RELEASE(self->entityResolver);
  [super dealloc];
}

/* properties */

- (void)setProperty:(NSString *)_name to:(id)_value {
  if ([_name isEqualToString:SaxLexicalHandlerProperty]) {
    ASSIGN(self->lexicalHandler, _value);
    return;
  }
  if ([_name isEqualToString:SaxDeclHandlerProperty]) {
    ASSIGN(self->declHandler, _value);
    return;
  }
  
  [SaxNotRecognizedException raise:@"PropertyException"
                             format:@"don't know property %@", _name];
}
- (id)property:(NSString *)_name {
  if ([_name isEqualToString:SaxLexicalHandlerProperty])
    return self->lexicalHandler;
  if ([_name isEqualToString:SaxDeclHandlerProperty])
    return self->declHandler;
  
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
  
  [SaxNotRecognizedException raise:@"FeatureException"
                             format:@"don't know feature %@", _name];
  return NO;
}

/* handlers */

#if 0
- (void)setDocumentHandler:(id<NSObject,SaxDocumentHandler>)_handler {
  SaxDocumentHandlerAdaptor *a;

  a = [[SaxDocumentHandlerAdaptor alloc] initWithDocumentHandler:_handler];
  [self setContentHandler:a];
  RELEASE(a);
}
#endif

- (void)setDTDHandler:(id<NSObject,SaxDTDHandler>)_handler {
  ASSIGN(self->dtdHandler, _handler);
}
- (id<NSObject,SaxDTDHandler>)dtdHandler {
  return self->dtdHandler;
}

- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}
- (id<NSObject,SaxErrorHandler>)errorHandler {
  return self->errorHandler;
}

- (void)setEntityResolver:(id<NSObject,SaxEntityResolver>)_handler {
  ASSIGN(self->entityResolver, _handler);
}
- (id<NSObject,SaxEntityResolver>)entityResolver {
  return self->entityResolver;
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (id<NSObject,SaxContentHandler>)contentHandler {
  return self->contentHandler;
}

/* parsing */

- (void)parseFromSource:(id)_source {
  NSAutoreleasePool *pool;
  NSArray *lines;
  
  if ([_source isKindOfClass:[NSString class]]) {
    lines = [_source componentsSeparatedByString:@"\n"];
  }
  else if ([_source isKindOfClass:[NSData class]]) {
    _source = [[NSString alloc] 
		initWithData:_source
		encoding:[NSString defaultCStringEncoding]];
    lines = [_source componentsSeparatedByString:@"\n"];
    RELEASE(_source);
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
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];

  /* start parsing lines */
  {
    NSEnumerator *e;
    NSString *line;
    
    e = [lines objectEnumerator];
    while ((line = [e nextObject])) {
    recheck:
      if ([line hasPrefix:@"("]) {
	NSMutableDictionary *ns = nil;
	NSString *startTag;
        NSDictionary *nsDict = nil;

	/* not yet finished ! */
	
	startTag = [line substringFromIndex:1];
	line = [e nextObject];
	while ([line hasPrefix:@"A"]) {
	  /* attribute */
	  NSString *rawName, *value;
	  unsigned idx;
	  
	  line = [line substringFromIndex:1];
	  
	  if ((idx = [line indexOfString:@" "]) == NSNotFound) {
	    value   = @"";
	    rawName = line;
	  }
	  else {
	    rawName = [line substringToIndex:idx];
	    value   = [line substringFromIndex:(idx + 1)];
	  }
	  
	  if ([rawName hasPrefix:@"xmlns"]) {
	    /* a namespace declaration */
	    if (ns == nil) ns = [[NSMutableDictionary alloc] init];
	    
	    if ([rawName hasPrefix:@"xmlns:"]) {
	      /* eg <x xmlns:nl="http://www.w3.org"/> */
	      NSString *prefix, *uri;
	      
	      prefix = [rawName substringFromIndex:6];
	      uri    = value;
	      
	      [ns setObject:uri forKey:prefix];

	      if (self->fNamespaces)
		[self->contentHandler startPrefixMapping:prefix uri:uri];
	    }
	    else {
	      /* eg <x xmlns="http://www.w3.org"/> */
	      [ns setObject:value forKey:@":"];
	    }
	  }
	}
	/* start tag finished */
	nsDict = [ns copy];
	RELEASE(ns); ns = nil;
	
	/* manage namespace stack */
  
	if (nsDict == nil)
	  nsDict = [NSDictionary dictionary];
        
	[self->nsStack addObject:nsDict];

	/* to be completed ! */
	
	if (line != nil)
	  goto recheck;
      }
    }
  }
  
  RELEASE(pool);
}

- (void)parseFromSystemId:(NSString *)_sysId {
  NSString *s;

  /* _sysId is a URI */
  if (![_sysId hasPrefix:@"file://"]) {
    SaxParseException *e;
    NSDictionary      *ui;
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _sysId ? _sysId : @"<nil>", @"systemID",
                         self,                       @"parser",
                         nil];
    
    e = (id)[SaxParseException exceptionWithName:@"SaxIOException"
                               reason:@"can't handle system-id"
                               userInfo:ui];
    
    [self->errorHandler fatalError:e];
    return;
  }

  /* cut off file:// */
  _sysId = [_sysId substringFromIndex:7];
  
  /* start parsing .. */
  if ((s = [NSString stringWithContentsOfFile:_sysId]))
    [self parseFromSource:s];
}

/* entities */

- (NSString *)replacementStringForEntityNamed:(NSString *)_entityName {
  //NSLog(@"get entity: %@", _entityName);
  return [[@"&amp;" stringByAppendingString:_entityName]
                    stringByAppendingString:@";"];
}

/* namespace support */

- (NSString *)nsUriForPrefix:(NSString *)_prefix {
  NSEnumerator *e;
  NSDictionary *ns;
  
  e = [self->nsStack reverseObjectEnumerator];
  while ((ns = [e nextObject])) {
    NSString *uri;
    
    if ((uri = [ns objectForKey:_prefix]))
      return uri;
  }
  return nil;
}

- (NSString *)defaultNamespace {
  return [self nsUriForPrefix:@":"];
}

@end /* pyxSAXDriver */
