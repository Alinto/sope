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

#include "JSArchivingTests.h"
#include "Blah.h"
#include "MyNum.h"
#include "common.h"

#import <NGJavaScript/NGJavaScript.h>
#import <NGScripting/NGScriptLanguage.h>
#import <NGExtensions/NGExtensions.h>

@implementation JSArchivingTests

+ (void)runSuite {
  [self runTest:@"Archiving"];
  [self runTest:@"JSArrayArchiveEvalProblem"];
}

- (void)testArchiving {
  static NSString *testScript = 
    @"var c = 30;\n"
    @"var myArray=[1,2,3];\n"
    @"function doIt(sender) {\n"
    @"  print('doIt, a='+a+', b='+b+', c='+c);\n"
    @"}\n"
    ;
  id original, copy;
  NSData *archive;
  
  original = [[NGJavaScriptObject alloc] init];
  [original setObject:@"10" forKey:@"a"];
  [original setObject:@"20" forKey:@"b"];
  [original evaluateScript:testScript language:@"javascript"];
  [self print:@"  a: %@", [original objectForKey:@"a"]];
  [self print:@"  b: %@", [original objectForKey:@"b"]];
  [self print:@"  doIt: %@", [original objectForKey:@"doIt"]];
  
  [self print:@"archive object %@ (keys=%@) ...", 
          original, 
          [[original allKeys] componentsJoinedByString:@","]];
  
  archive = [NSArchiver archivedDataWithRootObject:original];
  [self print:@"archived to data, size %i", [archive length]];
  
  copy = [NSUnarchiver unarchiveObjectWithData:archive];
  [self print:@"unarchived object %@ (keys=%@)", 
          copy,
          [[copy allKeys] componentsJoinedByString:@","]];
  [self print:@"  a: %@", [copy objectForKey:@"a"]];
  [self print:@"  b: %@", [copy objectForKey:@"b"]];
  [self print:@"  doIt: %@", [copy objectForKey:@"doIt"]];
  [self print:@"  myArray: %@ (%@)", 
	[copy objectForKey:@"myArray"],
	[[copy objectForKey:@"myArray"] class]];
  
  [original release];
}


- (void)testJSArrayArchiveEvalProblem {
  static NSString *testScriptA =
    @"try {\n"
    @"var counter=0;\n"
    @"var dataRec = [\n"
    @"  { 'a': 5, 'b': 10 }\n"
    @"];\n"
    @"} catch (exc) {\n"
    @"  print('JS CODE CATCHED: '+exc);\n"
    @"}\n"
    ;
  id wrapper, copy;
  NSData *archive;
  
  /* create an object */
  
  wrapper = [[[NGJavaScriptObject alloc] init] autorelease];
  [self print:@"object: %@ (keys=%@)", wrapper, [wrapper allKeys]];
  
  [wrapper evaluateScript:testScriptA language:@"javascript"];
  [self print:@"object: %@ (keys=%@)", wrapper, [wrapper allKeys]];
  [self printJavaScriptObjectInfo:wrapper];
  
  /* do the archiving/unarchiving transaction to create a copy */
  
  archive = [NSArchiver archivedDataWithRootObject:wrapper];
  NSAssert1([archive length] > 0, 
            @"archiver didn't generate a proper archive: %@",
            archive);
  
  copy = [NSUnarchiver unarchiveObjectWithData:archive];
  NSAssert(copy != nil, @"couldn't unarchive the object at all");
  NSAssert1([copy isKindOfClass:[NGJavaScriptObject class]],
            @"unexpected object class: %@", [copy class]);
  
  [self print:@"copy: %@ (keys=%@)", copy, [copy allKeys]];
  [self printJavaScriptObjectInfo:wrapper];
  
  /*
    the following broke with: "JS ERROR(<string>:1): null" which is
    why we have this test
  */
  [copy evaluateScript:testScriptA language:@"javascript"];
}

@end /* JSArchivingTests */
