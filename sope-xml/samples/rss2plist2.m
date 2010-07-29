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
  A small demonstration program to show how to write a SAX handler
  using SaxObjC. It goes over a RSS channel file and collects the
  item information in a dictionary.
  
  This example is almost the same like rss2plist1.m, but uses the
  SaxMethodCallHandler which calls a method for each tag, so you
  don't need to do manual tagname checks.
  Note that we only process known content, all other tags are ignored.
  
  As you will see it's quite a bit of work dealing with SAX ;-)
*/

#import <Foundation/Foundation.h>
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/SaxMethodCallHandler.h>

/* ******************** the SAX handler ****************** */

@interface RSSSaxHandler : SaxMethodCallHandler
{
  NSMutableArray      *entries;
  NSMutableDictionary *entry;

  /* parsing state */
  NSString *value;   /* the (PCDATA) content of a tag */
}

- (NSArray *)rssEntries;

@end

@implementation RSSSaxHandler

- (id)init {
  if ((self = [super init])) {
    self->entries = [[NSMutableArray alloc] initWithCapacity:16];
    self->entry   = [[NSMutableDictionary alloc] initWithCapacity:8];
    
    /* those are required for mapping the names */
    [self registerNamespace:@"http://purl.org/rss/1.0/" withKey:@"rss"];
    [self registerNamespace:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	  withKey:@"rdf"];
    [self registerNamespace:@"http://purl.org/rss/1.0/modules/slash/"
	  withKey:@"slash"];
    [self registerNamespace:@"http://purl.org/rss/1.0/modules/syndication/"
	  withKey:@"syn"];
  }
  return self;
}
- (void)dealloc {
  [self->entry   release];
  [self->entries release];
  [super dealloc];
}

/* accessing results */

- (NSArray *)rssEntries {
  return [[self->entries copy] autorelease];
}

/* setup/teardown */

- (void)startDocument {
  /* ensure consistent state */
  [self->entries removeAllObjects];
}

/* parsing */

- (void)start_rssitem:(id<SaxAttributes>)_attributes {
  [self->entry removeAllObjects];
}
- (void)end_rssitem {
  [self->entries addObject:[[self->entry copy] autorelease]];
}

/* the subtags of item ... */

- (void)start_rsstitle:(id<SaxAttributes>)_attributes {
  [self->value release]; self->value = nil;
}
- (void)end_rsstitle {
  if (self->value)
    [self->entry setObject:self->value forKey:@"title"];
}

- (void)start_rsslink:(id<SaxAttributes>)_attributes {
  [self->value release]; self->value = nil;
}
- (void)end_rsslink {
  if (self->value)
    [self->entry setObject:self->value forKey:@"link"];
}

- (void)start_rssdescription:(id<SaxAttributes>)_attributes {
  [self->value release]; self->value = nil;
}
- (void)end_rssdescription {
  if (self->value)
    [self->entry setObject:self->value forKey:@"info"];
}

- (void)characters:(unichar *)_chars length:(int)_len {
  NSString *s;
  
  /* 
     Note: The characters callback is allowed to be called multiple times
           by the parser (makes writing parsers easier, but complicates the
           handler ...).
  */
  s = [[NSString alloc] initWithCharacters:_chars length:_len];
  if (self->value) {
    self->value = [[self->value stringByAppendingString:s] copy];
    [s release];
  }
  else
    self->value = s;
}

@end /* RSSSaxHandler */

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
    RSSSaxHandler    *sax;
    
    /* step a, get a parser for XML */
    parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
  	                         createXMLReaderForMimeType:@"text/xml"];
    
    /* step b, create a SAX handler and attach it to the parser */
    sax = [[[RSSSaxHandler alloc] init] autorelease];
    [parser setContentHandler:sax];
    [parser setErrorHandler:sax];
    
    /* step c, parse :-) */
    
    args = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
    [args nextObject]; /* skip tool name */
    
    while ((arg = [args nextObject])) {
      NSArray *entries;
      
      /* the parser takes URLs, NSData's, NSString's */
      arg = [[[NSURL alloc] initFileURLWithPath:arg] autorelease];
      
      /* let the parser parse (it will report SAX events to the handler) */
      [parser parseFromSource:arg];
      
      /* now query the handler for the result */
      entries = [sax rssEntries];
      
      /* TODO: use NSPropertyListSerialization on OSX */
      printf("%s\n", [[entries description] cString]);
    }
    
    return 0;
  }
  [pool release];
  return 0;
}
