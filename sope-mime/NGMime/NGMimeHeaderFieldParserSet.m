/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NGMimeHeaderFieldParser.h"
#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"
#include <NGMime/NGMimePartParser.h>

@implementation NGMimeHeaderFieldParserSet

+ (int)version {
  return 2;
}

static NGMimeHeaderFieldParserSet *rfc822set = nil;

+ (id)headerFieldParserSet {
  return [[[self alloc] init] autorelease];
}

+ (id)defaultRfc822HeaderFieldParserSet {
  id parser = nil;
  static NGMimeHeaderNames *Fields = NULL;
  
  if (rfc822set)
    return rfc822set;
  
  if (Fields == NULL)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
    
  rfc822set = [[self alloc] init];

  [rfc822set setParser:
                 (parser = [[NGMimeContentTypeHeaderFieldParser alloc] init])
	     forField:Fields->contentType];
  [parser release]; parser = nil;
    
  [rfc822set setParser:
	       (parser = [[NGMimeContentLengthHeaderFieldParser alloc] init])
	     forField:Fields->contentLength];
  [parser release]; parser = nil;
    
  [rfc822set setParser:
	       (parser = [[NGMimeStringHeaderFieldParser alloc]
			   initWithRemoveComments:NO])
	     forField:Fields->received];
  [parser release]; parser = nil;
    
  [rfc822set setParser:
                 (parser = [[NGMimeStringHeaderFieldParser alloc]
                                 initWithRemoveComments:NO])
	     forField:Fields->subject];
  [parser release]; parser = nil;
    
  [rfc822set setParser:
                 (parser = [[NGMimeStringHeaderFieldParser alloc]
                                 initWithRemoveComments:NO])
	     forField:@"x-face"];
  [parser release]; parser = nil;

  [rfc822set setParser:
	       (parser = [[NGMimeContentDispositionHeaderFieldParser alloc] 
			   init])
	     forField:Fields->contentDisposition];
  [parser release]; parser = nil;
  [rfc822set setParser:
	       (parser = [[NGMimeRFC822DateHeaderFieldParser alloc] init])
	     forField:Fields->date];
  [parser release]; parser = nil;
  
  return rfc822set;
}

- (id)init {
  return [self initWithDefaultParser:
                 [[[NGMimeStringHeaderFieldParser alloc] init] autorelease]];
}
- (id)initWithDefaultParser:(id<NGMimeHeaderFieldParser>)_parser {
  if ((self = [super init])) {
    self->fieldNameToParser = 
      [[NSMutableDictionary alloc] initWithCapacity:32];
    [self setDefaultParser:_parser];
  }
  return self;
}
- (id)initWithParseSet:(NGMimeHeaderFieldParserSet *)_set {
  if ((self = [self initWithDefaultParser:[_set defaultParser]])) {
    [self->fieldNameToParser addEntriesFromDictionary:_set->fieldNameToParser];
  }
  return self;
}

- (void)dealloc {
  [self->fieldNameToParser release];
  [self->defaultParser     release];
  [super dealloc];
}

/* accessors */

- (void)setParser:(id<NGMimeHeaderFieldParser>)_parser
  forField:(NSString *)_name {

  [self->fieldNameToParser setObject:_parser forKey:_name];
}

- (void)setDefaultParser:(id<NGMimeHeaderFieldParser>)_parser {
  ASSIGN(self->defaultParser, _parser);
}
- (id<NGMimeHeaderFieldParser>)defaultParser {
  return self->defaultParser;
}

/* operation */

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  id parser;

  parser = [self->fieldNameToParser objectForKey:_field];
  
  if (parser == nil)
    parser = [self defaultParser];

  return [parser parseValue:_data ofHeaderField:_field];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  id           copy;
  NSEnumerator *keys;
  NSString     *key;

  copy = [[NGMimeHeaderFieldParserSet allocWithZone:_zone]
                                      initWithDefaultParser:
                                        [self defaultParser]];
  
  keys = [self->fieldNameToParser keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    id value;

    value = [self->fieldNameToParser objectForKey:key];
    [copy setParser:value forField:key];
  }
  return copy;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<HeaderFieldParserSet: id=0x%p map=%@ default=%@>",
                     self, self->fieldNameToParser,
                     [self defaultParser]];
}

@end /* NGMimeHeaderFieldParserSet */
