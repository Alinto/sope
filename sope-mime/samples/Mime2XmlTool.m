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

#import "Mime2XmlTool.h"
#import "common.h"
#import <NGStreams/NGStreams.h>
#import <NGMime/NGMime.h>
#import <NGMail/NGMail.h>

@interface Mime2XmlTool(Privates)
- (BOOL)_outputPartAsXML:(id<NGMimePart>)_part;
@end

@implementation Mime2XmlTool

- (NSUserDefaults *)userDefaults {
  return [NSUserDefaults standardUserDefaults];
}

/* part generation */

- (void)indent {
  unsigned i;
  for (i = 0; i < self->outIndent; i++)
    printf("  ");
}

- (BOOL)_outputMultipartBody:(NGMimeMultipartBody *)_body {
  NSEnumerator *e;
  id<NGMimePart> part;
  
  self->outIndent++;

  e = [[_body parts] objectEnumerator];
  while ((part = [e nextObject]))
    [self _outputPartAsXML:part];
  
  self->outIndent--;
  return YES;
}

- (BOOL)_outputStringBody:(NSString *)body {
  [self indent];
  printf("<body charlen='%i'>", [body length]);
  if ([body length] > 256) {
    body = [body substringToIndex:255];
    printf("%s", [body cString]);
  }
  printf("</body>\n");
  return YES;
}
- (BOOL)_outputDataBody:(NSData *)body {
  [self indent];
  printf("<body><data size='%i'>...</data></body>\n",
	 [body length]);
  return YES;
}
- (BOOL)_outputPartBody:(id<NGMimePart>)body {
  [self indent];
  printf("<body>\n");
  [self _outputPartAsXML:(id<NGMimePart>)body];
  [self indent];
  printf("</body>\n");
  return YES;
}
- (BOOL)_outputMultiPartBody:(id<NGMimePart>)body {
  [self indent];
  printf("<body multipart='true'>\n");
	
  [self _outputMultipartBody:(id)body];
	
  [self indent];
  printf("</body>\n");
  return YES;
}

- (BOOL)_outputHeaderField:(NSString *)_field value:(id)_value {
  Class    clazz;
  NSString *s;
  [self indent];
  
  clazz = [_value class];
  printf("<h name=\"%s\"", [_field cString]);
  printf(">");
  
  s = [_value stringValue];
  s = [s stringByEscapingXMLString];
  printf("%s", [s cString]);
  
  printf("</h>\n");
  return YES;
}
- (BOOL)_outputPartHeaders:(id<NGMimePart>)_part {
  NSEnumerator *headerFields;
  NSString *headerField;
  
  headerFields = [_part headerFieldNames];
  while ((headerField = [headerFields nextObject])) {
    NSEnumerator *vals;
    id value;
    
    vals = [_part valuesOfHeaderFieldWithName:headerField];
    while ((value = [vals nextObject])) {
      [self _outputHeaderField:headerField value:value];
    }
  }
  return YES;
}

- (BOOL)_outputPartAsXML:(id<NGMimePart>)_part {
  id tmp;
  id body;
  
  if (_part == nil) {
    NSLog(@"got no part ...");
    return NO;
  }
  
  [self indent];
  printf("<part ptr='0x%p'", (unsigned int)_part);
  
  if ([_part conformsToProtocol:@protocol(NGMimePart)]) {
    if ((tmp = [_part contentType]))
      printf(" content-type='%s'", [[tmp stringValue] cString]);
    if ((tmp = [_part encoding]))
      printf(" encoding='%s'", [[tmp stringValue] cString]);
    if ((tmp = [_part contentId]))
      printf(" content-id='%s'", [[tmp stringValue] cString]);
    if ((tmp = [_part contentLanguage]))
      printf(" content-language='%s'", [[tmp stringValue] cString]);
    if ((tmp = [_part contentMd5]))
      printf(" content-md5='%s'", [[tmp stringValue] cString]);
  }  
  printf(">\n");
  self->outIndent++;
  {
    /* output header */
    [self _outputPartHeaders:_part];
    
    /* output body */
    
    if ((body = [_part body])) {
      if ([body isKindOfClass:[NSString class]])
	[self _outputStringBody:body];
      else if ([body isKindOfClass:[NSData class]])
	[self _outputDataBody:body];
      else if ([body conformsToProtocol:@protocol(NGMimePart)]) {
	/*
	  Note: an NSData is also a MIME part, because of this
	  a check for NSData needs to be done first ! 
	*/
	[self _outputPartBody:body];
      }
      else if ([body isKindOfClass:[NGMimeMultipartBody class]]) {
	[self _outputMultiPartBody:body];
      }
      else
	NSLog(@"unknown body class: %@", NSStringFromClass(body));
    }
  }
  self->outIndent--;
  [self indent];
  printf("</part>\n");
  return YES;
}

- (BOOL)outputPartAsXML:(id<NGMimePart>)_part {
  self->outIndent = 0;
  printf("<?xml version='1.0' encoding='ISO-8859-1'?>\n");
  return [self _outputPartAsXML:_part];
}

- (BOOL)outputPartAsMime:(id<NGMimePart>)_part {
  return NO;
}

- (BOOL)outputPart:(id<NGMimePart>)_part {
  NSUserDefaults *ud = [self userDefaults];
  NSAutoreleasePool *pool;
  NSString *out;
  BOOL result;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  out = [ud stringForKey:@"out"];
  if ([out length] == 0)
    result = YES;
  else if ([out isEqualToString:@"xml"])
    result = [self outputPartAsXML:_part];
  else if ([out isEqualToString:@"mime"]) 
    result = [self outputPartAsMime:_part];
  else {
    NSLog(@"unknown output module: %@", out);
    result = NO;
  }
  [pool release];
  return result;
}

/* MIME delegate */

#if 0
- (id)parser:(NGMimePartParser *)_parser
  parseHeaderField:(NSString *)_name
  data:(NSData *)_data
{
  if (self->rejectAllFields) {
    if ([_name hasPrefix:@"content-"]) {
      NSString *s;
      
      s = [[NSString alloc] initWithData:_data 
			    encoding:NSISOLatin1StringEncoding];
      return [s autorelease];
    }
    return nil;
  }
  
  return _data;
}
#endif

- (void)parser:(NGMimePartParser *)_parser
  didParseHeader:(NGHashMap *)_header
{
  //NSLog(@"got header: %@", _header);
}
- (BOOL)parser:(NGMimePartParser *)_parser
  keepHeaderField:(NSString *)_name
  value:(id)_value
{
  if ([_name hasPrefix:@"content-"])
    return YES;
  
  return self->rejectAllFields ? NO : YES;
}

/* MIME parsing */

- (id<NGMimePart>)parseFile:(NSString *)_path useStreams:(BOOL)_streams {
  NSAutoreleasePool *pool;
  NGMimePartParser  *parser;
  id<NGMimePart>    part;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    id  input;
    SEL sel;
    
    parser = [[[NGMimeMessageParser alloc] init] autorelease];
    
    if (self->useDelegate)
      [parser setDelegate:self];
    
    /* create input object */
    
    if (_streams) {
      NGFileStream *stream;
      
      stream = [[[NGFileStream alloc] initWithPath:_path] autorelease];
      if (![stream openInMode:@"r"]) {
	NSLog(@"could not open stream for reading: '%@'\n  exception: %@", 
	      _path, [stream lastException]);
	return NO;
      }
      
      sel   = @selector(parsePartFromStream:);
      input = stream;
    }
    else {
      NSData *data;
    
      if ((data = [NSData dataWithContentsOfMappedFile:_path]) == nil) {
	NSLog(@"could not get data for path: '%@'", _path);
	return NO;
      }
      
      sel   = @selector(parsePartFromData:);
      input = data;
    }

    /* do parsing */
    
    if ([[self userDefaults] boolForKey:@"noparse"])
      part = nil;
    else
      part = [parser performSelector:sel withObject:input];
    
    part = [part retain];
  }
  [pool release];
  return [part autorelease];
}

- (BOOL)processFile:(NSString *)_path {
  NSProcessInfo     *pi = [NSProcessInfo processInfo];
  NSUserDefaults    *ud = [self userDefaults];
  id<NGMimePart>    part;
  NSAutoreleasePool *pool;
  
  NSLog(@"process: %@", _path);

  /* parsing */
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    NSTimeInterval startTime, endTime;
    unsigned int   startSize, endSize;
    int i, preRepeatCount;
    
    /* first some useless parsing for profiling */
    
    preRepeatCount = self->preloops;
    for (i = 0; i < preRepeatCount; i++) {
      NSAutoreleasePool *pool;
      
      startTime = [[NSDate date] timeIntervalSince1970];
      startSize = [pi virtualMemorySize];
      
      pool = [[NSAutoreleasePool alloc] init];
      part = [self parseFile:_path useStreams:[ud boolForKey:@"streams"]];
      [pool release];
      
      endSize = [pi virtualMemorySize];
      endTime = [[NSDate date] timeIntervalSince1970];
      
      /* statistics */
      
      if ([ud boolForKey:@"statistics"]) {
	fprintf(stderr, 
		"parsing time [%2i]: %.3fs, "
		"vmem-diff: %8i (%4iK,%4iM), vmem: %8i (%4iK,%4iM))\n", 
		i, (endTime-startTime), 
		(endSize - startSize), 
		(endSize - startSize) / 1024, 
		(endSize - startSize) / 1024 / 1024, 
		endSize, endSize/1024, endSize/1024/1024);
      }
    }

    /* the "real" parser (remembers the part ...) */
    
    startTime = [[NSDate date] timeIntervalSince1970];
    startSize = [pi virtualMemorySize];
    part = [self parseFile:_path useStreams:[ud boolForKey:@"streams"]];
    endSize = [pi virtualMemorySize];
    endTime = [[NSDate date] timeIntervalSince1970];
    
    /* statistics */
    
    if ([ud boolForKey:@"statistics"]) {
      fprintf(stderr, 
	      "parsing time: %.3fs, vmem-diff: %8i, vmem: %8i\n", 
	      (endTime-startTime), (endSize - startSize), endSize);
    }
  }
  part = [part retain];
  [pool release];
  part = [part autorelease];
  
  if (part == nil) {
    NSLog(@"could not parse a part from path: '%@'", _path);
    return NO;
  }
  
  /* generating */
  [self outputPart:part];
  return YES;
}

/* tool operation */

- (int)usage {
  fprintf(stderr, "usage: mime2xml <file>*\n");
  fprintf(stderr, "  -preloops    <n>\n");
  fprintf(stderr, "  -statistics  YES|NO\n");
  fprintf(stderr, "  -streams     YES|NO\n");
  fprintf(stderr, "  -noparse     YES|NO\n");
  fprintf(stderr, "  -delegate    YES|NO\n");
  fprintf(stderr, "  -parsefields YES|NO\n");
  return 1;
}

- (int)runWithArguments:(NSArray *)_args {
  NSUserDefaults *ud = [self userDefaults];
  NSEnumerator *e;
  NSString *f;

  self->parseFields     = [ud boolForKey:@"parsefields"];
  self->useDelegate     = [ud boolForKey:@"delegate"];
  self->preloops        = [ud integerForKey:@"preloops"];
  self->rejectAllFields = [ud boolForKey:@"rejectAllFields"];
  
  _args = [_args subarrayWithRange:NSMakeRange(1, [_args count] - 1)];
  if ([_args count] == 0)
    return [self usage];
  
  e = [_args objectEnumerator];
  while ((f = [e nextObject])) {
    NSAutoreleasePool *pool;
    
    pool = [[NSAutoreleasePool alloc] init];
    [self processFile:f];
    [pool release];
  }
  
  return 0;
}

@end /* Mime2XmlTool */
