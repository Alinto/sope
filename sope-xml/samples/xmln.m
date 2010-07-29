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

#include <SaxObjC/SaxObjC.h>
#import <Foundation/Foundation.h>

/*
  This tool uses a SAX parser to generate a PYX representation
  of an XML file. PYX is a simplified XML syntax for line oriented
  processing of XML files.
  See 'XML Processing with Python' for an explanation of PYX.
*/

@interface PYXSaxHandler : SaxDefaultHandler
{
  FILE *out;
}

- (void)write:(NSString *)_s;

@end

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool         *pool;
  id<NSObject,SaxXMLReader> parser;
  id                        sax;
  NSEnumerator              *paths;
  NSString                  *path;

#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];
  
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
                                 createXMLReader];
  if (parser == nil) {
    fprintf(stderr, "could not load a SAX driver bundle !\n");
    exit(2);
  }
  
  sax = [[[PYXSaxHandler alloc] init] autorelease];
  [parser setContentHandler:sax];
  [parser setDTDHandler:sax];
  [parser setErrorHandler:sax];
  
  /* parse */

  paths = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  [paths nextObject];
  while ((path = [paths nextObject])) {
    NSAutoreleasePool *pool;

    if ([path hasPrefix:@"-"]) {
      /* skip defaults */
      [paths nextObject];
      continue;
    }
    
    pool = [[NSAutoreleasePool alloc] init];

    path = [@"file://" stringByAppendingString:path];
    
    NS_DURING
      [parser parseFromSystemId:path];
    NS_HANDLER
      fprintf(stderr, "xmln: catched: %s\n", 
	      [[localException description] cString]);
    NS_ENDHANDLER;
    
    [pool release]; pool = nil;
  }
  
  /* cleanup */
  [pool release];

  exit(0);
  return 0;
}

#include <stdio.h>

@implementation PYXSaxHandler

- (id)init {
  self->out = stdout;
  return self;
}

- (void)write:(NSString *)_s {
  unsigned len;
  char *buf;
  if ((len = [_s cStringLength]) == 0)
    return;
  buf = malloc(len + 1);
  [_s getCString:buf];
  fprintf(self->out, "%s", buf);
  free(buf); buf = NULL;
}
- (void)tag:(unsigned char)_t key:(NSString *)_s value:(NSString *)_value {
  unsigned len, vlen;
  char *buf;
  
  fputc(_t, self->out);
  
  len  = [_s cStringLength];
  vlen = [_value cStringLength];
  
  buf = malloc((len>vlen ? len : vlen) + 1);
  [_s getCString:buf];
  if (_value) {
    fprintf(self->out, "%s", buf);
    [_value getCString:buf];
    fprintf(self->out, " %s\n", buf);
  }
  else
    fprintf(self->out, "%s\n", buf);
  free(buf); buf = NULL;
}
- (void)tag:(unsigned char)_t key:(NSString *)_s {
  [self tag:_t key:_s value:nil];
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  int i, c;
  
  [self tag:'(' key:_rawName];
  
  for (i = 0, c = [_attrs count]; i < c; i++) {
    NSString *aname, *avalue;
    
    aname  = [_attrs rawNameAtIndex:i];
    avalue = [_attrs valueAtIndex:i];
    
    [self tag:'A' key:aname value:avalue];
  }
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  [self tag:')' key:_rawName];
}

- (void)characters:(unichar *)_chars length:(int)_len {
  int i;
  
  if (_len == 0) return;
  
  fputc('-', self->out);
  
  for (i = 0; i < _len; i++) {
    if (_chars[i] > 255) {
      fprintf(stderr, "found unichar, code 0x%04X\n", _chars[i]);
    }
    else {
      register unsigned char c = _chars[i];

      switch (c) {
      case '\n':
	fputc('\\', self->out);
	fputc('n', self->out);
	break;
      default:
	fputc(c, self->out);
	break;
      }
    }
  }
  fputc('\n', self->out);
}

- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
  [self tag:'?' key:_pi value:_data];
}

- (void)warning:(SaxParseException *)_exception {
  NSLog(@"WARNING: %@", [_exception reason]);
}
- (void)error:(SaxParseException *)_exception {
  NSLog(@"ERROR: %@:%@: %@",
        [[_exception userInfo] objectForKey:@"systemId"],
        [[_exception userInfo] objectForKey:@"line"],
        [_exception reason]);
}
- (void)fatalError:(SaxParseException *)_exception {
  [_exception raise];
}

@end /* PYXSaxHandler */
