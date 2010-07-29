/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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

#include "ChangeLogSaxDriver.h"
#include "NSString+Extensions.h"
#include "NSCalendarDate+Extensions.h"
#include "common.h"

@interface ChangeLogSaxDriver(PrivateAPI)
- (NSString *)_namespace;
- (void)_writeString:(NSString *)_s;
- (void)_processLine:(NSString *)_line;
- (void)_parseFromString:(NSString *)_str systemId:(NSString *)_sysId;

- (void)_beginEntryWithDate:(NSCalendarDate *)_date;
- (void)_endEntry;
- (void)_beginLogs;
- (void)_endLogs;
- (void)_beginLog;
- (void)_appendLog:(NSString *)_s;
- (void)_endLog;
@end

@implementation ChangeLogSaxDriver

static NSCharacterSet *wsSet   = nil;
static NSCharacterSet *wsnlSet = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if(didInit) return;
  didInit = YES;
  wsSet   = [[NSCharacterSet whitespaceCharacterSet] retain];
  wsnlSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (void)dealloc {
  [self->contentHandler release];
  [self->errorHandler release];
  [self->namespace release];
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

/*
 - (void)setDocumentHandler:(id<NSObject,SaxDocumentHandler>)_handler {
   SaxDocumentHandlerAdaptor *a;
   
   a = [[SaxDocumentHandlerAdaptor alloc] initWithDocumentHandler:_handler];
   [self setContentHandler:a];
   [a release];
 }
 */

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


/* parsing ... */

- (void)parseFromSource:(id)_source systemId:(NSString *)_sysId {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  if ([_source isKindOfClass:[NSData class]]) {
    NSString *s;
    
    s = [[NSString alloc] initWithData:_source
                              encoding:[NSString defaultCStringEncoding]];
    [self _parseFromString:s systemId:_sysId];
    [s release];
  }
  else if ([_source isKindOfClass:[NSURL class]]) {
    [self parseFromSystemId:_source];
  }
  else if ([_source isKindOfClass:[NSString class]]) {
    if (_sysId == nil) _sysId = @"<string>";
    [self _parseFromString:_source systemId:_sysId];
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
  
  [pool release];
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
  
  [pool release];
}


/* Private API */

- (void)_parseFromString:(NSString *)_s systemId:(NSString *)_sysId {
  static SaxAttributes *versionAttr = nil;
  NSArray *lines;
  unsigned i, count;
  
  self->currentLog     = [[NSMutableString alloc] initWithCapacity:200];
  self->flags.hasLog   = NO;
  self->flags.hasEntry = NO;

  if (versionAttr == nil) {
    versionAttr = [[SaxAttributes alloc] init];
    [versionAttr addAttribute:@"version"
                 uri:[self _namespace]
                 rawName:@"version"
                 type:@"CDATA"
                 value:@"1.0"];
  }
  
  lines = [_s componentsSeparatedByString:@"\n"];
  count = [lines count];
  
  [self->contentHandler startDocument];
  [self->contentHandler startElement:@"changelog"
                        namespace:[self _namespace]
                        rawName:@"changelog"
                        attributes:versionAttr];

  for(i = 0; i < count; i++) {
    [self _processLine:[lines objectAtIndex:i]];
  }
  [self _endEntry];
  [self->contentHandler endElement:@"changelog"
                        namespace:[self _namespace]
                        rawName:@"changelog"];

  [self->contentHandler endDocument];
  [self->currentLog     release];
}

- (void)_processLine:(NSString *)_line {
  if([_line length] > 0) {
    unichar        first;
    NSCalendarDate *date;
    NSString       *author;

    first = [_line characterAtIndex:0];
    if(!(first == '*' ||
         first == '-' ||
         [wsSet characterIsMember:first]) &&
       [_line parseDate:&date andAuthor:&author])
    {
      SaxAttributes *authorAttrs;
      NSString      *realName, *email;

      /* entry start */
      [self _beginEntryWithDate:date];
      /* author */
      [author getRealName:&realName andEmail:&email];
      if(!email)
        email = @"";
      authorAttrs = [[SaxAttributes alloc] init];
      [authorAttrs addAttribute:@"email"
                   uri:[self _namespace]
                   rawName:@"email"
                   type:@"CDATA"
                   value:email];
      [self->contentHandler startElement:@"author"
                            namespace:[self _namespace]
                            rawName:@"author"
                            attributes:authorAttrs];
      [authorAttrs release];
      [self _writeString:realName];
      [self->contentHandler endElement:@"author"
                            namespace:[self _namespace]
                            rawName:@"author"];
    }
    else {
      /* strip leading whitespace and "*" from line */
      _line = [_line stringByTrimmingLeadSpaces];
      if([_line length] > 0) {
        first = [_line characterAtIndex:0];

        if(first == '*') {
          /* new log line */
          [self _beginLog];
          _line = [_line substringFromIndex:1];
          _line = [_line stringByTrimmingLeadSpaces];
        }
        [self _appendLog:_line];
      }
    }
  }
}

- (void)_beginEntryWithDate:(NSCalendarDate *)_date {
  SaxAttributes *entryAttrs;

  [self _endEntry];

  /* date */
  entryAttrs = [[SaxAttributes alloc] init];
  [entryAttrs addAttribute:@"date"
              uri:[self _namespace]
              rawName:@"date"
              type:@"CDATA"
              value:[_date w3OrgDateTimeRepresentation]];
  [self->contentHandler startElement:@"entry"
                        namespace:[self _namespace]
                        rawName:@"entry"
                        attributes:entryAttrs];
  [entryAttrs release];
  self->flags.hasEntry = YES;
}

- (void)_endEntry {
  if(self->flags.hasEntry) {
    [self _endLogs];
    [self->contentHandler endElement:@"entry"
                          namespace:[self _namespace]
                          rawName:@"entry"];
    self->flags.hasEntry = NO;
  }
}

- (void)_beginLogs {
  if(!self->flags.hasLog) {
    [self->contentHandler startElement:@"logs"
                          namespace:[self _namespace]
                          rawName:@"logs"
                          attributes:nil];
    self->flags.hasLog = YES;
  }
}

- (void)_endLogs {
  if(self->flags.hasLog) {
    [self _endLog];
    [self->contentHandler endElement:@"logs"
                          namespace:[self _namespace]
                          rawName:@"logs"];
    self->flags.hasLog = NO;
  }
}


- (void)_beginLog {
  [self _beginLogs];
  [self _endLog];
}

- (void)_appendLog:(NSString *)_s {
  unsigned loc;

  if([_s length] == 0)
    return;
  loc = [self->currentLog length];
  if(loc > 0) {
    unichar last;
    
    last = [self->currentLog characterAtIndex:loc - 1];
    if(![wsnlSet characterIsMember:last]) {
      [self->currentLog appendString:@" "];
    }
  }
  [self->currentLog appendString:_s];
}

- (void)_endLog {
  NSRange r;

  r = NSMakeRange(0, [self->currentLog length]);
  if(r.length == 0)
    return;

  [self _beginLogs];
  [self->contentHandler startElement:@"log"
                        namespace:[self _namespace]
                        rawName:@"log"
                        attributes:nil];
  [self _writeString:self->currentLog];
  [self->contentHandler endElement:@"log"
                        namespace:[self _namespace]
                        rawName:@"log"];
  [self->currentLog deleteCharactersInRange:r];
}

- (NSString *)_namespace {
  if(!self->namespace)
    return @"";
  return self->namespace;
}

- (void)_writeString:(NSString *)_s {
  unsigned len;
  
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

@end /* ChangeLogSaxDriver */
