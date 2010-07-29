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

#include "JSBridgeTests.h"
#include "Combined.h"
#include "Blah.h"
#include "MyNum.h"
#include "common.h"
//#import <Foundation/Foundation.h>
#import <NGJavaScript/NGJavaScript.h>
#import <NGScripting/NGScriptLanguage.h>
#import <NGExtensions/NGExtensions.h>

#define SLANG @"javascript"

@implementation JSBridgeTests

NSString *testScript =
@"print('blah: ' + this.blah);\n"
@"print('blah: ' + this.blah);\n"
@"print('  s1: ' + this.blah.sequence);\n"
@"print('  s2: ' + this.blah.sequence);\n"
@"print('  s3: ' + this.blah.sequence);\n"
@"print('blah2:' + this.blah2);\n"
;

NSString *testScript2 =
@"print('blah: ' + this);\n"
@"print('  s1: ' + this.sequence);\n"
@"print('  s2: ' + this.sequence);\n"
;

#define infoobj(__X__) [self printJavaScriptObjectInfo:__X__]

- (void)testCreation {
  NSAutoreleasePool *pool;
  id jobj;
  id result;
  id global;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  global = [mapCtx globalObject];
  [self print:@"global is 0x%p %@", global, global];
  
  jobj = [[Blah alloc] init];
  [self print:@"  blah: %@ -> j0x%p", jobj, [mapCtx handleForObject:jobj]];

  [self print:@"  do: MyType()"];
  result = [jobj evaluateScript:@"MyType()" language:SLANG];
  [self print:@"  => %@", result];
  
  [self print:@"  do: new MyType()"];
  result = [jobj evaluateScript:@"new MyType()" language:SLANG];
  [self print:@"  => %@", result];
  
  [jobj release];
  [pool release];
}

- (void)testKeyValueCoding {
  NSString *testScript_KVC =
  @"print('jso:  ' + this);\n"
  @"var b = 10;\n"
  @"this.a = 100;\n"
  @"print('jso.a: ' + this.a);\n"
  @"this['a'] = 101;\n"
  @"print('jso.a: ' + this.a);\n"
  @"print('jso.b: ' + this.b);\n"
  @"print('jso.c: ' + this.c);\n"
  @"for (var i in this.a) { print('  ' + i); };\n"
  ;
  id jobj = nil;
  
  jobj = [[NGJavaScriptObject alloc] init];
  
  [jobj setObject:@"202" forKey:@"c"];
  
  [jobj evaluateScript:testScript_KVC language:SLANG];
  [self print:@"  obj.a=%@", [jobj objectForKey:@"a"]];
  [self print:@"  obj.b=%@", [jobj objectForKey:@"b"]];
  [self print:@"  obj.c=%@", [jobj objectForKey:@"c"]];
  
  infoobj(jobj);
  
  //[c evaluateScript:testScript language:SLANG];
  
  [jobj release];
}

- (void)testJSStructure {
  static NSString *testScript_struct =
    @"var dataRec = [\n"
    @" { 'a': 5,  'b': 10  },\n"
    @" { 'a': 55, 'b': 105 },\n"
    @"];\n"
  ;
  id jobj;
  jobj = [[NGJavaScriptObject alloc] init];
  [jobj evaluateScript:testScript_struct language:SLANG];
  [self print:@"  obj: %@", jobj];
  [self print:@"  obj.dataRec: %@", [jobj objectForKey:@"dataRec"]];
  [self print:@"  obj.dataRec[0]: %@", [[jobj objectForKey:@"dataRec"] objectAtIndex:0]];
  [self print:@"  obj.dataRec[0].a: %@", 
          [[[jobj objectForKey:@"dataRec"] objectAtIndex:0] objectForKey:@"a"]];
  [jobj release];
}

- (void)testDictionary {
  static NSString *testScript_dict =
    @"this.a=10;"
    @"this.b=101;"
  ;
  id jobj = nil;
  NSAutoreleasePool *pool;
  
  pool = [NSAutoreleasePool new];

  jobj = [[NSMutableDictionary alloc] init];
  
  [jobj setObject:@"202" forKey:@"c"];
  
  [jobj evaluateScript:testScript_dict language:SLANG];
  [self print:@"  obj.a=%@", [jobj objectForKey:@"a"]];
  [self print:@"  obj.b=%@", [jobj objectForKey:@"b"]];
  [self print:@"  obj.c=%@", [jobj objectForKey:@"c"]];
  
  [[mapCtx jsContext] collectGarbage];
  [pool release];
  
  //[jobj evaluateScript:testScript language:SLANG];
  
  [jobj release]; // Note: the dict may contain JS objects !
}

- (void)testSequence {
  id   blah;
  void *jso;
  int  i;
  id   global;
  
  global = [mapCtx globalObject];
  NSLog(@"global is 0x%p %@", global, global);
  
  blah = [[Blah alloc] init];
  [global setObject:blah forKey:@"blah"];
  
  jso = NGObjectMapping_GetHandleForObject(blah);
  NSLog(@"obj o0x%p j0x%p", blah, jso);

  for (i = 0; i < 3; i++) {
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    
    [blah evaluateScript:testScript2 language:SLANG];

    NSLog(@"release pool %i", i);
    [pool release];
    
    NSLog(@"GC %i", i);
    [[mapCtx jsContext] collectGarbage];
    [[mapCtx jsContext] collectGarbage];
  }
  
  [global removeObjectForKey:@"blah"];
  
  [blah release];
}

- (void)testIncTx {
  Combined *c = nil;
  void *jso;
  id   obj = nil, jobj = nil;

#if 0
  c = [[Combined alloc] init];
  [[NGObjectMappingContext activeObjectMappingContext] makeObjectCombined:c];
  
  obj = [[Blah alloc] init];
  jso = NGObjectMapping_GetHandleForObject(obj);
  NSLog(@"obj o0x%p j0x%p", obj, jso);
  [obj evaluateScript:testScript2 language:SLANG];
#endif
  
  jobj = [[NGJavaScriptObject alloc] init];
  jso = NGObjectMapping_GetHandleForObject(jobj);
  //NSLog(@"obj o0x%p j0x%p", jobj, jso);

#if 0
  [[NGObjectMappingContext activeObjectMappingContext]
                           setGlobalObject:jobj];
#endif
  
  infoobj(jobj);
  
  //[c setObject:obj forKey:@"blah2"];
  
  //[c evaluateScript:testScript language:SLANG];
  
  [jobj release];
  [c    release];
  [obj  release];
}

- (void)testStringPropAvailability {
  /* 
     if evaluation doesn't run against a NGJavaScriptObject, string objects
     do not find their properties and functions (eg .length in this case)
     why-o-why ? :-(
     
     - the NSString seems to be propertly converted into a JSString
     - maybe the object doesn't have a proper parent pointer ?
     - or the prototype of the string is broken ?
     - or the standard classes are not loaded ?

     - if I uncomment _jsGetValue in NSString+JS, I get a proper call to it's
       length property, but the typeof (obviously) is 'object' instead of
       'string' and certainly can't be used in a string context
     
     what sequence actually happens when we call "title.length" ?
     - we map 'self' to a JS object (create a JS proxy, add statics)
     - we call JS_EvaluateScript with that JS Object => makes self to this
     - control goes to SpiderMoneky
     - SpiderMonkey needs to resolve "title", which is a static
       property we defined when creating the JS proxy
     - this calls the _jsprop_title method which returns an NSString object
     - the NSString object is converted to a value using it's own method
     - SpiderMonkey should have a JS String with all methods ?
  */
  id base;
  
  base = [[Blah alloc] init];
  NSLog(@"base: %@", base);

  // this makes it dump core in getprivate
  // NSLog(@"global: %@", [[self->mapCtx jsContext] globalObject]);
  
  NSLog(@"this: %@", [base evaluateScript:@"this" language:SLANG]);
  NSLog(@"typeof this: %@", 
	[base evaluateScript:@"typeof this" language:SLANG]);
  
  NSLog(@"title: %@",        
	[base evaluateScript:@"title" language:SLANG]);
  NSLog(@"typeof title: %@",        
	[base evaluateScript:@"typeof title" language:SLANG]);
  NSLog(@"title.length: %@ (should be %i)",        
	[base evaluateScript:@"title.length" language:SLANG],
	[[base _jsprop_title] length]);
  
  NSLog(@"getContent(): %@",        
	[base evaluateScript:@"getContent()" language:SLANG]);
  NSLog(@"getContent().length: %@ (should be %i)", 
	[base evaluateScript:@"getContent().length" language:SLANG],
	[[base _jsfunc_getContent:nil] length]);
  
  NSLog(@"'hello': %@",        
	[base evaluateScript:@"'hello'" language:SLANG]);
  NSLog(@"typeof 'hello': %@",        
	[base evaluateScript:@"typeof 'hello'" language:SLANG]);
  NSLog(@"'hello'.length: %@",        
	[base evaluateScript:@"'hello'.length" language:SLANG]);
  NSLog(@"'hello'.length == null: %@",        
	[base evaluateScript:@"'hello'.length==null" language:SLANG]);
}

+ (void)runSuite {
  [self runTest:@"IncTx"];
  [self runTest:@"KeyValueCoding"];
  [self runTest:@"Sequence"];
  [self runTest:@"Creation"];
  [self runTest:@"JSStructure"];
  
  [self runTest:@"StringPropAvailability"];
  
  // currently the Dictionary test makes it dump core
  //[self runTest:@"Dictionary"];
}

@end /* JSBridgeTests */
