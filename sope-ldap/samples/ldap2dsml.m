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
#import <SaxObjC/SaxXMLReader.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>
#import <NGLdap/NGLdapConnection.h>
#include "common.h"

@interface DSMLSaxProducer : NSObject
{
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler;
- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler;

- (void)produceOnConnection:(NGLdapConnection *)_con dn:(NSString *)_dn;

@end

static NSString *XMLNS_DSML = @"http://wwww.dsml.org/DSML";

@implementation DSMLSaxProducer

- (void)dealloc {
  [self->errorHandler   release];
  [self->contentHandler release];
  [super dealloc];
}

- (void)setContentHandler:(id<NSObject,SaxContentHandler>)_handler {
  ASSIGN(self->contentHandler, _handler);
}
- (void)setErrorHandler:(id<NSObject,SaxErrorHandler>)_handler {
  ASSIGN(self->errorHandler, _handler);
}

- (void)_produceAttribute:(NGLdapAttribute *)_attribute
  ofEntry:(NGLdapEntry *)_entry
{
  SaxAttributes *attrs;

  attrs = [[SaxAttributes alloc] init];
  
  [attrs addAttribute:@"name" uri:XMLNS_DSML rawName:@"name"
         type:@"CDATA"
         value:[_attribute attributeName]];
  
  [self->contentHandler
       startElement:@"attr"
       namespace:XMLNS_DSML
       rawName:@"attr"
       attributes:attrs];
  
  [attrs release]; attrs = nil;
  
  /* encode values */
  {
    NSEnumerator *values;
    NSString *value;
  
    values = [_attribute stringValueEnumerator];
    while ((value = [values nextObject])) {
      unsigned len;
      unichar  *chars;

      if ((len = [value length]) == 0)
        continue;
      
      chars = calloc(len + 1, sizeof(unichar));
      [value getCharacters:chars];
      
      [self->contentHandler
           startElement:@"value"
           namespace:XMLNS_DSML
           rawName:@"value"
           attributes:nil];
      
      [self->contentHandler characters:chars length:len];
      
      if (chars) free(chars);
      
      [self->contentHandler
           endElement:@"value"
           namespace:XMLNS_DSML
           rawName:@"value"];
    }
  }
  
  [self->contentHandler
       endElement:@"attr"
       namespace:XMLNS_DSML
       rawName:@"attr"];
}

- (void)_produceObjectClassOfEntry:(NGLdapEntry *)_entry {
  NGLdapAttribute *attr;

  if ((attr = [_entry attributeWithName:@"objectclass"]) == nil)
    return;
  
  [self->contentHandler
       startElement:@"objectclass"
       namespace:XMLNS_DSML
       rawName:@"objectclass"
       attributes:nil];
  
  /* encode values */
  {
    NSEnumerator *values;
    NSString *value;
  
    values = [attr stringValueEnumerator];
    while ((value = [values nextObject])) {
      unsigned len;
      unichar  *chars;

      if ((len = [value length]) == 0)
        continue;
      
      chars = calloc(len + 1, sizeof(unichar));
      [value getCharacters:chars];
      
      [self->contentHandler
           startElement:@"objectclass"
           namespace:XMLNS_DSML
           rawName:@"objectclass"
           attributes:nil];
      
      [self->contentHandler characters:chars length:len];
      
      if (chars) free(chars);
      
      [self->contentHandler
           endElement:@"objectclass"
           namespace:XMLNS_DSML
           rawName:@"objectclass"];
    }
  }
  
  [self->contentHandler
       endElement:@"objectclass"
       namespace:XMLNS_DSML
       rawName:@"objectclass"];
}

- (void)_produceEntry:(NGLdapEntry *)_entry {
  SaxAttributes *attrs;
  NSEnumerator  *names;
  NSString      *cname;
  
  attrs = [[SaxAttributes alloc] init];
  
  [attrs addAttribute:@"dn" uri:XMLNS_DSML rawName:@"dn"
         type:@"CDATA"
         value:[_entry dn]];
  
  [self->contentHandler
       startElement:@"entry"
       namespace:XMLNS_DSML
       rawName:@"entry"
       attributes:attrs];

  [attrs release]; attrs = nil;

  /* attributes */

  [self _produceObjectClassOfEntry:_entry];
  
  names = [[_entry attributeNames] objectEnumerator];
  while ((cname = [names nextObject])) {
    NGLdapAttribute *attr;

    if ([cname isEqualToString:@"objectclass"])
      continue;
    
    if ((attr = [_entry attributeWithName:cname]))
      [self _produceAttribute:attr ofEntry:_entry];
  }  
  
  [self->contentHandler
       endElement:@"entry"
       namespace:XMLNS_DSML
       rawName:@"entry"];
}

- (void)_produceEntries:(NSEnumerator *)_entries {
  NGLdapEntry *entry;

  [self->contentHandler
       startElement:@"directory-entries"
       namespace:XMLNS_DSML
       rawName:@"directory-entries"
       attributes:nil];
  
  while ((entry = [_entries nextObject]))
    [self _produceEntry:entry];
  
  [self->contentHandler
       endElement:@"directory-entries"
       namespace:XMLNS_DSML
       rawName:@"directory-entries"];
}

- (void)produceOnConnection:(NGLdapConnection *)_con dn:(NSString *)_dn {
  [self->contentHandler startDocument];
  [self->contentHandler startPrefixMapping:@"" uri:XMLNS_DSML];
  
  [self->contentHandler
       startElement:@"dsml"
       namespace:XMLNS_DSML
       rawName:@"dsml"
       attributes:nil];

  [self _produceEntries:[_con flatSearchAtBaseDN:_dn
                              qualifier:nil
                              attributes:nil]];
  
  [self->contentHandler endElement:@"dsml" namespace:XMLNS_DSML rawName:@"dsml"];
  
  [self->contentHandler endPrefixMapping:@""];
  [self->contentHandler endDocument];
}

@end /* DSMLSaxProducer */

#import <SaxObjC/SaxDefaultHandler.h>

@interface DSMLSaxOutputter : SaxDefaultHandler
{
  int level;
}
@end

@implementation DSMLSaxOutputter

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  int i, count;
  
  level++;
  for (i = 0; i < level; i++)
    printf("  ");
  printf("<dsml:%s", [_localName cString]);
  
  if (level <= 1) {
    printf(" xmlns:dsml='%s'", [_ns cString]);
  }

  for (i = 0, count = [_attrs count]; i < count; i++) {
    printf(" %s='%s'",
           [[_attrs nameAtIndex:i] cString],
           [[_attrs valueAtIndex:i] cString]);
  }
  
  printf(">\n");
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  int i;
  for (i = 0; i < level; i++)
    printf("  ");
  printf("</dsml:%s>\n", [_localName cString]);
  level--;
}

- (void)characters:(unichar *)_chars length:(int)_len {
  int i;
  NSString *s;
  
  for (i = 0; i < level + 1; i++)
    printf("  ");

  s = [[NSString alloc] initWithCharacters:_chars length:_len];
  printf("%s\n", [s cString]);
  [s release];
}

@end /* DSMLSaxOutputter */

#import <Foundation/Foundation.h>

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSUserDefaults   *ud;
  NSArray          *args;
  DSMLSaxProducer  *cpu;
  DSMLSaxOutputter *out;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 1) {
    NSLog(@"usage: %@ <files>", [args objectAtIndex:0]);
    exit(1);
  }
  else if ([args count] == 1)
    args = [args arrayByAddingObject:@"."];

  ud = [NSUserDefaults standardUserDefaults];

  cpu = [[DSMLSaxProducer alloc] init];
  out = [[DSMLSaxOutputter alloc] init];
  [cpu setContentHandler:out];
  [cpu setErrorHandler:out];

#if 0
  fm = [[NGLdapFileManager alloc]
                           initWithHostName:[ud stringForKey:@"LDAPHost"]
                           port:0
                           bindDN:[ud stringForKey:@"LDAPBindDN"]
                           credentials:[ud stringForKey:@"LDAPPassword"]
                           rootDN:[ud stringForKey:@"LDAPRootDN"]];
  fm = [fm autorelease];
#endif

  {
    NGLdapConnection *con;

    con = [[NGLdapConnection alloc]
                             initWithHostName:[ud stringForKey:@"LDAPHost"]
                             port:0];
    [con bindWithMethod:@"simple"
         binddn:[ud stringForKey:@"LDAPBindDN"]
         credentials:[ud stringForKey:@"LDAPPassword"]];
    
    [cpu produceOnConnection:con
         dn:[ud stringForKey:@"LDAPRootDN"]];
    
    [con release];
  }
  [pool release];
  exit(0);
  return 0;
}
