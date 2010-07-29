/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "JSTest.h"
#include "common.h"
#import <NGScripting/NGScriptLanguage.h>
#import <NGJavaScript/NGJavaScript.h>
#import <NGExtensions/NGExtensions.h>

@implementation JSTest

- (void)setUp {
  id language;
  id global;
  
  language = [NGScriptLanguage languageWithName:@"javascript"];
  
  self->mapCtx = [language createMappingContext];
    
  if (![[self->mapCtx jsContext] loadStandardClasses])
    ;
    
  [self->mapCtx pushContext];

  global = [[[NGJavaScriptObject alloc] init] autorelease];
  [global applyStandardClasses];
  [self->mapCtx setGlobalObject:global];
}
- (void)tearDown {
  [[self->mapCtx jsContext] collectGarbage];
  [[self->mapCtx jsContext] collectGarbage];
   
  [self->mapCtx popContext];
  [self->mapCtx release];
}

- (void)print:(NSString *)_format arguments:(va_list)ap {
  NSString *value = nil;
  
  value = [[NSString alloc] initWithFormat:_format arguments:ap];
  printf("%s\n", [value cString]);
  [value release];
}
- (void)print:(NSString *)_format, ... {
  va_list ap;
  
  va_start(ap, _format);
  [self print:_format arguments:ap];
  va_end(ap);
}

- (void)printJavaScriptObjectInfo:(id)obj {
  NSEnumerator *e;
  void *jso;
  id o;

  jso = [[NGObjectMappingContext activeObjectMappingContext]
	                         handleForObject:obj];
  
  [self print:@"info on o0x%p j0x%p", obj, jso];
  [self print:@"  description: %@", obj];
  
  e = [obj keyEnumerator];
  [self print:@"  keys: (%@)", e];
  while ((o = [e nextObject]))
    [self print:@"    - '%@' <%@>", o, [o class]];
  
  e = [obj objectEnumerator];
  [self print:@"  values: (%@)", e];
  while ((o = [e nextObject]))
    [self print:@"    - '%@' <%@>", o, [o class]];
  
  e = [obj prototypeObjectChain];
  [self print:@"  prototypes: %@", e];
  while ((o = [e nextObject]))
    [self print:@"    - %@ <%@>", o, [o class]];
  
  e = [obj parentObjectChain];
  [self print:@"  parents: %@", e];
  while ((o = [e nextObject]))
    [self print:@"    - %@ <%@>", o, [o class]];
}

+ (void)testSelector:(SEL)_sel failedWithException:(NSException *)_exception {
  NSLog(@"EXCEPTION: %@", _exception);
}

+ (void)runTestSelector:(SEL)_sel {
  NSAutoreleasePool *pool;
  id fixture;
  
  pool = [[NSAutoreleasePool alloc] init];
  fixture = [[[self alloc] init] autorelease];
  [fixture setUp];
  
  printf("\n--- RUN TEST: %s --------------------\n", 
         [NSStringFromSelector(_sel) cString]);
  NS_DURING
    [fixture performSelector:_sel];
  NS_HANDLER
    [self testSelector:_sel failedWithException:localException];
  NS_ENDHANDLER;
  printf(">>> DONE\n");
  
  [fixture tearDown];
  [pool release];
}
+ (void)runTest:(NSString *)_name {
  SEL sel;
  
  _name = [@"test" stringByAppendingString:_name];
  sel = NSSelectorFromString(_name);
  [self runTestSelector:sel];
}

@end /* JSTest */
