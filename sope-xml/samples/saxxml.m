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
  Usage:

    saxxml -XMLReader libxmlHTMLSAXDriver test.html
*/

@interface MySAXHandler : SaxDefaultHandler
{
  id  locator;
  int indent;
}

- (void)indent;

@end

@interface SaxXMLReaderFactory(Pathes)
- (NSArray *)saxReaderSearchPathes;
@end

static void usage(const char *n) {
  fprintf(stderr, 
	  "Usage: %s <file1> <file2> ...\n"
	  "\n"
	  "Arguments (Defaults):\n"
	  "  -XMLReader <classname> - select the SAX driver class\n"
	  "  --dirs                 - just print the dirs containing drivers\n"
	  "\n"
	  "Samples:\n"
	  "  %s /etc/X11/xkb/rules/xfree86.xml\n"
	  "  %s -XMLReader STXSaxDriver structured-document.stx\n"
	  "  %s -XMLReader VSiCalSaxDriver event.ics\n"
	  "  %s -XMLReader VSvCardSaxDriver steve.vcf\n"
	  , n, n, n, n, n);
}

static void listSaxScanDirs(void) {
  NSArray *a;
  unsigned i, count;
  
  a = [[SaxXMLReaderFactory standardXMLReaderFactory] saxReaderSearchPathes];
  for (i = 0, count = [a count]; i < count; i++)
    printf("%s\n", [[a objectAtIndex:i] cString]);
  
  if (i == 0) {
    fprintf(stderr, "found no search pathes!\n");
    exit(1);
  }
}

int main(int argc, char **argv, char **env) {
  id<NSObject,SaxXMLReader> parser;
  id           sax;
  NSEnumerator *paths;
  NSString     *path;
  NSAutoreleasePool *pool;
  NSString          *cwd;
  BOOL hadPath = NO;
  
  pool   = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory] createXMLReader];
  cwd    = [[NSFileManager defaultManager] currentDirectoryPath];
  
  if (parser == nil) {
    fprintf(stderr, "could not load a SAX driver bundle!\n");
    exit(2);
  }
  
  sax = [[MySAXHandler alloc] init];
  [parser setContentHandler:sax];
  [parser setDTDHandler:sax];
  [parser setErrorHandler:sax];
  
  [parser setProperty:@"http://xml.org/sax/properties/declaration-handler"
          to:sax];
#if 0
  [parser setProperty:@"http://xml.org/sax/properties/lexical-handler"
          to:sax];
#endif
  
  /* parse */

  paths = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  [paths nextObject];
  while ((path = [paths nextObject]) != nil) {
    NSAutoreleasePool *pool;

    if ([path isEqualToString:@"--help"]) {
      usage(argv[0]);
      exit(0);
    }

    if ([path isEqualToString:@"--dirs"]) {
      listSaxScanDirs();
      exit(0);
    }
    
    if ([path hasPrefix:@"-"]) { /* consume defaults */
      [paths nextObject];
      continue;
    }

    hadPath = YES;
    
    pool = [[NSAutoreleasePool alloc] init];
    
    if (![path isAbsolutePath])
      path = [cwd stringByAppendingPathComponent:path];
    
    path = [@"file://" stringByAppendingString:path];
    
    NS_DURING
      [parser parseFromSystemId:path];
    NS_HANDLER
      abort();
    NS_ENDHANDLER;
    
    [pool release];
  }

  if (!hadPath) {
    usage(argv[0]);
    exit(1);
  }
  
  /* cleanup */
  
  [sax release];
  //[parser release];

  [pool release];

  exit(0);
  return 0;
}

@implementation MySAXHandler

- (void)indent {
  int i;
  
  for (i = 0; i < (self->indent * 4); i++)
    fputc(' ', stdout);
}

@end /* MySAXHandler */

@implementation MySAXHandler(Documents)

- (void)dealloc {
  [self->locator release];
  [super dealloc];
}

- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_loc {
  [self->locator autorelease];
  self->locator = [_loc retain];
}

- (void)startDocument {
  puts("start document ..");
  self->indent++;
}
- (void)endDocument {
  self->indent--;
  puts("end document.");
}

- (void)startPrefixMapping:(NSString *)_prefix uri:(NSString *)_uri {
  [self indent];
  printf("ns-map: %s=%s\n", [_prefix cString], [_uri cString]);
}
- (void)endPrefixMapping:(NSString *)_prefix {
  [self indent];
  printf("ns-unmap: %s\n", [_prefix cString]);
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  int i, c;
  [self indent];
  printf("<%s", [_localName cString]);
  
  if ([_ns length] > 0)
    printf(" (ns=%s)", [_ns cString]);
  
  for (i = 0, c = [_attrs count]; i < c; i++) {
    NSString *type;
    
    printf(" %s=\"%s\"",
           [[_attrs nameAtIndex:i] cString],
           [[_attrs valueAtIndex:i] cString]);

    if (![_ns isEqualToString:[_attrs uriAtIndex:i]])
      printf("(ns=%s)", [[_attrs uriAtIndex:i] cString]);
    
    type = [_attrs typeAtIndex:i];
    if (![type isEqualToString:@"CDATA"] && (type != nil))
      printf("[%s]", [type cString]);
  }
  puts(">");
  self->indent++;
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  self->indent--;
  [self indent];
  printf("</%s>\n", [_localName cString]);
}

- (void)characters:(unichar *)_chars length:(int)_len {
  NSString *str;
  id tmp;
  unsigned i, len;

  if (_len == 0) {
    [self indent];
    printf("\"\"\n");
    return;
  }
  
  for (i = 0; i < (unsigned)_len; i++) {
    if (_chars[i] > 255) {
      NSLog(@"detected large char: o%04o d%03i h%04X",
            _chars[i], _chars[i], _chars[i]);
    }
  }
  
  str = [NSString stringWithCharacters:_chars length:_len];
  len = [str length];
  
  tmp = [str componentsSeparatedByString:@"\n"];
  str = [tmp componentsJoinedByString:@"\\n"];
  tmp = [str componentsSeparatedByString:@"\r"];
  str = [tmp componentsJoinedByString:@"\\r"];
  
  [self indent];
  printf("\"%s\"\n", [str cString]);
}
- (void)ignorableWhitespace:(unichar *)_chars length:(int)_len {
  NSString *data;
  id tmp;

  data = [NSString stringWithCharacters:_chars length:_len];
  tmp  = [data componentsSeparatedByString:@"\n"];
  data = [tmp componentsJoinedByString:@"\\n"];
  tmp  = [data componentsSeparatedByString:@"\r"];
  data = [tmp componentsJoinedByString:@"\\r"];
  
  [self indent];
  printf("whitespace: \"%s\"\n", [data cString]);
}

- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
  [self indent];
  printf("PI: '%s' '%s'\n", [_pi cString], [_data cString]);
}

#if 0
- (xmlEntityPtr)getEntity:(NSString *)_name {
  NSLog(@"get entity %@", _name);
  return NULL;
}
- (xmlEntityPtr)getParameterEntity:(NSString *)_name {
  NSLog(@"get para entity %@", _name);
  return NULL;
}
#endif

@end /* MySAXHandler(Documents) */

@implementation MySAXHandler(EntityResolver)

- (id)resolveEntityWithPublicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  [self indent];
  printf("shall resolve entity with '%s' '%s'",
         [_pubId cString], [_sysId cString]);
  return nil;
}

@end /* MySAXHandler(EntityResolver) */

@implementation MySAXHandler(Errors)

- (void)warning:(SaxParseException *)_exception {
  NSLog(@"warning(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
}

- (void)error:(SaxParseException *)_exception {
  NSLog(@"error(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
}

- (void)fatalError:(SaxParseException *)_exception {
  NSLog(@"fatal error(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
  [_exception raise];
}

@end /* MySAXHandler(Errors) */

@implementation MySAXHandler(DTD)

- (void)notationDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  NSLog(@"decl: notation %@ pub=%@ sys=%@", _name, _pubId, _sysId);
}

- (void)unparsedEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
  notationName:(NSString *)_notName
{
  NSLog(@"decl: unparsed entity %@ pub=%@ sys=%@ not=%@",
        _name, _pubId, _sysId, _notName);
}

@end /* MySAXHandler(DTD) */

@implementation MySAXHandler(Decl)

- (void)attributeDeclaration:(NSString *)_attributeName
  elementName:(NSString *)_elementName
  type:(NSString *)_type
  defaultType:(NSString *)_defType
  defaultValue:(NSString *)_defValue
{
  NSLog(@"decl: attr %@[%@] type '%@' default '%@'[%@]",
        _attributeName, _elementName, _type, _defValue, _defType);
}

- (void)elementDeclaration:(NSString *)_name contentModel:(NSString *)_model {
  NSLog(@"decl: element %@ model %@", _name, _model);
}

- (void)externalEntityDeclaration:(NSString *)_name
  publicId:(NSString *)_pub
  systemId:(NSString *)_sys
{
  NSLog(@"decl: e-entity %@ pub %@ sys %@", _name, _pub, _sys);
}

- (void)internalEntityDeclaration:(NSString *)_name value:(NSString *)_value {
  NSLog(@"decl: i-entity %@ value %@", _name, _value);
}

@end /* MySAXHandler(Decl) */
