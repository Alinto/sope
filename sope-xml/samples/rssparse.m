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

/*
  A small demonstration program to show how to use SaxObjectDecoder
  to parse XML files. This one parses a RSS channel file and collects
  the information in a dictionary.
  
  This one is much easier and more high-level than rss2plist1 and rss2plist2.
  Instead of writing a low level SAX event handler, you just define a mapping
  model and the "enterprise" classes.
*/

#import <Foundation/Foundation.h>
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/SaxMethodCallHandler.h>

/* ******************** the "business" objects ************ */

@interface RSSObject : NSObject
{
  NSString *title;
  NSString *link;
  NSString *info;
}

@end

@interface RSSChannel : RSSObject
@end

@interface RSSItem : RSSObject
@end

@implementation RSSObject

- (void)dealloc {
  [self->title release];
  [self->link  release];
  [self->info  release];
  [super dealloc];
}

/* accessors */

- (void)setTitle:(NSString *)_value {
  [self->title autorelease];
  self->title = [_value copy];
}
- (void)setLink:(NSString *)_value {
  [self->link autorelease];
  self->link = [_value copy];
}
- (void)setInfo:(NSString *)_value {
  [self->info autorelease];
  self->info = [_value copy];
}

/* description */

- (NSString *)description {
  NSMutableString *s = [NSMutableString stringWithCapacity:64];
  [s appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  if (self->title) [s appendFormat:@" title='%@'", self->title];
  if (self->link)  [s appendFormat:@" link='%@'",  self->link];
  //[s appendFormat:@" info='%@'", self->info];
  [s appendString:@">"];
  return s;
}

@end /* RSSObject */

@implementation RSSChannel
@end /* RSSChannel */

@implementation RSSItem
@end /* RSSItem */

/* ******************** C main section ******************** */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  if ([[[NSProcessInfo processInfo] arguments] count] < 2) {
    fprintf(stderr, "usage: %s <rssfile>\n",
  	    [[[[NSProcessInfo processInfo] arguments] lastObject] cString]);
    return 1;
  }
  
  /* the interesting section */
  {
    NSEnumerator     *args;
    NSString         *arg;
    id<SaxXMLReader> parser;
    SaxObjectDecoder *sax;
    
    /* step a, get a parser for XML */
    parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
  	                           createXMLReaderForMimeType:@"text/xml"];
    
    /* step b, create a SAX handler and attach it to the parser */
    sax = [[SaxObjectDecoder alloc] initWithMappingAtPath:@"./rssparse.xmap"];
    [parser setContentHandler:sax];
    [parser setErrorHandler:sax];
    [sax autorelease];
    
    /* step c, parse :-) */
    
    args = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
    [args nextObject]; /* skip tool name */
    
    while ((arg = [args nextObject])) {
      id channel;
      
      /* the parser takes URLs, NSData's, NSString's */
      arg = [[[NSURL alloc] initFileURLWithPath:arg] autorelease];
      
      /* let the parser parse (it will report SAX events to the handler) */
      [parser parseFromSource:arg];
      
      /* now query the handler for the result */
      channel = [sax rootObject];
      
      /* TODO: use NSPropertyListSerialization on OSX */
      NSLog(@"parsed channel: %@", channel);
    }
    
    return 0;
  }
  [pool release];
  return 0;
}
