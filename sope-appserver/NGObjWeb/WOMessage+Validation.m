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

#include <NGObjWeb/WOMessage.h>
#include <SaxObjC/SaxObjC.h>
#include "common.h"

@interface WOMessageSaxValidator : SaxDefaultHandler < SaxErrorHandler >
{
  id<NSObject,SaxXMLReader> parser;
  NSMutableArray *issues;
}

+ (id)validatorWithXmlReaderName:(NSString *)_name;

- (NSArray *)validateContent:(NSData *)_content withType:(NSString *)_ctype;

@end

@implementation WOMessageSaxValidator

static BOOL valDebugOn = NO;

- (id)initWithXmlReaderName:(NSString *)_name {
  if ((self = [super init])) {
    SaxXMLReaderFactory *factory;
    
    factory = [SaxXMLReaderFactory standardXMLReaderFactory];
    self->parser = [[factory createXMLReaderWithName:_name] retain];
    if (self->parser == nil) {
      [self release];
      return nil;
    }
    
    /* we are only interested in errors */
    [self->parser setErrorHandler:self];
  }
  return self;
}
+ (id)validatorWithXmlReaderName:(NSString *)_name {
  return [[[self alloc] initWithXmlReaderName:_name] autorelease];
}

- (void)dealloc {
  [self->issues release];
  [self->parser release];
  [super dealloc];
}

/* issues */

- (void)addIssue:(id)_issue {
  if (_issue == nil) return;
  
  if (self->issues == nil) 
    self->issues = [[NSMutableArray alloc] initWithCapacity:16];
  [self->issues addObject:_issue];
}
- (void)reset {
  [self->issues removeAllObjects];
}

/* validation */

- (void)warning:(SaxParseException *)_exception {
  [self addIssue:_exception];
}
- (void)error:(SaxParseException *)_exception {
  [self addIssue:_exception];
}
- (void)fatalError:(SaxParseException *)_exception {
  [self addIssue:_exception];
}

- (NSArray *)validateContent:(NSData *)_content withType:(NSString *)_ctype {
  NSArray *tmp;
  
  [self reset];
  if (self->parser == nil) return nil;
  
  [self debugWithFormat:@"validate %@, content size %d",
          _ctype, [_content length]];
  
  [self->parser parseFromSource:_content 
                systemId:[@"validator://" stringByAppendingString:_ctype]];

  tmp = [self->issues copy];
  [self reset];

  if (tmp == nil)
    [self debugWithFormat:@"  no issues found :-)"];
  else
    [self debugWithFormat:@"  %d issues found :-|", [tmp count]];
  return [tmp autorelease];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return valDebugOn;
}

@end /* WOMessageHTMLValidator */

@implementation WOMessage(Validation)

- (id)validatorForContentType:(NSString *)_ctype {
  if ([_ctype hasPrefix:@"text/html"]) {
    // Note: the HTML driver does not report invalid tags
    return [WOMessageSaxValidator validatorWithXmlReaderName:
                                    @"libxmlHTMLSAXDriver"];
  }
  
  if ([_ctype hasPrefix:@"text/xml"]) {
    return [WOMessageSaxValidator validatorWithXmlReaderName:
                                    @"libxmlSAXDriver"];
  }
  
  if ([_ctype hasPrefix:@"image/"])
    return nil;
  if ([_ctype hasPrefix:@"application/octet-stream"])
    return nil;
  if ([_ctype hasPrefix:@"text/plain"])
    return nil;
  
  [self logWithFormat:@"no validator for type: %@", _ctype];
  return nil;
}

- (NSArray *)validateContent {
  NSString *ctype;
  id validator;
  
#if 0
  [self logWithFormat:@"should validate output"];
#endif
  
  if ((ctype = [self headerForKey:@"content-type"]) == nil)
    return [NSArray arrayWithObject:@"missing content type."];
  
  if ((validator = [self validatorForContentType:ctype]) == nil)
    return nil;
  
  return [validator validateContent:[self content] withType:ctype];
}

@end /* WOMessage(Validation) */
