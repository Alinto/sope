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

#include "DAVParserTest.h"
#include "common.h"
#include <NGObjWeb/SaxDAVHandler.h>
#include <SaxObjC/SaxObjC.h>

@implementation DAVParserTest

static id<NSObject,SaxXMLReader> xmlParser = nil;
static SaxDAVHandler             *davsax   = nil;

- (id)init {
  if ((self = [super init])) {
    if (xmlParser == nil) {
      xmlParser =
        [[[SaxXMLReaderFactory standardXMLReaderFactory] 
                               createXMLReaderForMimeType:@"text/xml"]
                               retain];
      if (xmlParser == nil) {
        [self logWithFormat:@"found no XML-parser !"];
        return nil;
      }
    }
    if (davsax == nil) {
      if ((davsax = [[SaxDAVHandler alloc] init]) == nil) {
        [self logWithFormat:@"found no DAV SAX handler ..."];
        return nil;
      }
      [davsax setDelegate:self];
    }
  }
  return self;
}

- (void)dealloc {
  [self->propQueue release];
  [super dealloc];
}

/* parser */

- (void)lockParser:(id)_sax {
  [_sax reset];
  [xmlParser setContentHandler:_sax];
  [xmlParser setErrorHandler:_sax];
}
- (void)unlockParser:(id)_sax {
  [xmlParser setContentHandler:nil];
  [xmlParser setErrorHandler:nil];
  [_sax reset];
}

/* the DAV parser reports properties using the prop-queue */

- (void)startPropQueue {
  if (self->propQueue)
    [self->propQueue removeAllObjects];
  else
    self->propQueue = [[NSMutableDictionary alloc] initWithCapacity:128];
}
- (void)clearPropQueue {
  [self->propQueue release]; 
  self->propQueue = nil;
}

- (void)davHandler:(SaxDAVHandler *)_handler
  receivedProperties:(NSDictionary *)_record
  forURI:(NSString *)_uri
{
  /* Note: _record is volatile ! */
  NSURL        *lurl;
  NSDictionary *r;
  
  [self logWithFormat:@"PROPS on %@: %@", _uri, _record];
  
  lurl = [NSURL URLWithString:_uri];
  r = [_record copy];
  [self->propQueue setObject:r forKey:(lurl ? [lurl path] : _uri)];
  [r release];
}

- (NSDictionary *)doQueueParseDict:(id)_src {
  id results;
  
  [self startPropQueue];
  [self lockParser:davsax];
  [xmlParser parseFromSource:_src];
  [self unlockParser:davsax];
  results = [self->propQueue retain];
  [self clearPropQueue];
  return [results autorelease];
}
- (NSArray *)doQueueParse:(id)_src {
  return [[self doQueueParseDict:_src] allValues];
}

/* running */

- (void)printResults {
  EOFetchSpecification *fs;
  id tmp;
  
  /* responses */
  
  if ([self->propQueue count] > 0) {
    [self logWithFormat:@"collected %i property sets: %@",
            [self->propQueue count],
            self->propQueue];
  }
  
  /* patches */
  
  if ((tmp = [davsax propPatchValues]))
    [self logWithFormat:@"patch %i values: %@", [tmp count], tmp];
  if ((tmp = [davsax propPatchPropertyNamesToRemove]))
    [self logWithFormat:@"remove %i properties: %@", [tmp count], tmp];
  
  /* queries */

  if ([davsax propFindAllProperties])
    [self logWithFormat:@"find all properties !"];
  if ([davsax propFindPropertyNames])
    [self logWithFormat:@"deliver only property names (not their values)"];
  
  if ((tmp = [davsax propFindQueriedNames]))
    [self logWithFormat:@"find %i attributes: %@", [tmp count], tmp];
  
  if ((tmp = [davsax bpropFindTargets]))
    [self logWithFormat:@"bulkfind %i targets: %@", [tmp count], tmp];

  if ((fs = [davsax searchFetchSpecification]))
    [self logWithFormat:@"search: %@", fs];
}

- (void)runOnArgument:(NSString *)_arg {
  NSURL *url;
  
  if (xmlParser == nil || davsax == nil)
    [self logWithFormat:@"missing XML-parser ..."];
  
  if (![_arg isAbsolutePath]) {
    _arg = [[[NSFileManager defaultManager] currentDirectoryPath] 
                            stringByAppendingPathComponent:_arg];
  }
  url = [[[NSURL alloc] initFileURLWithPath:_arg] autorelease];
  [self logWithFormat:@"process %@: %@", _arg, url];
  
  [self startPropQueue];
  [self lockParser:davsax];
  
  [xmlParser parseFromSource:url];
  [self printResults];
  
  [self unlockParser:davsax];
  [self clearPropQueue];
}

- (void)runWithArguments:(NSArray *)_args {
  unsigned i, count;
  
  if ((count = [_args count]) == 1) {
    [self logWithFormat:@"usage: %@ <files*>", [_args objectAtIndex:0]];
    return;
  }
  
  /* foreach arg */
  for (i = 1; i < count; i++)
    [self runOnArgument:[_args objectAtIndex:i]];
}

@end /* DAVParserTest */
