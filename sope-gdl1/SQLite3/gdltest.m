/* 
   gdltest.m

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the SQLite Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#import <Foundation/Foundation.h>
#import <GDLAccess/GDLAccess.h>
#include <NGExtensions/NGExtensions.h>

static void fetchExprInChannel(NSString *expr, EOAdaptorChannel *ch) {
  NSArray      *attrs;
  NSDictionary *record;
  
  if (![ch evaluateExpression:expr]) {
    NSLog(@"ERROR: failed to evaluate: %@", expr);
    return;
  }

  attrs = [ch describeResults];
  NSLog(@"results: %@", attrs);
    
  while ((record = [ch fetchAttributes:attrs withZone:nil]) != nil)
    NSLog(@"fetched %@", record);
}

static void fetchSomePersonRecord(EOEntity *e, EOAdaptorChannel *ch) {
  EOSQLQualifier *q;
  NSArray *attrs;

    attrs = [e attributes];
    q = [[EOSQLQualifier alloc]
	  initWithEntity:e
	  qualifierFormat:@"%A='helge'", @"login"];
    [q autorelease];

    if ([ch selectAttributes:attrs
	    describedByQualifier:q
	    fetchOrder:nil
	    lock:NO]) {
      NSDictionary *record;

      record = [ch fetchAttributes:attrs withZone:nil];
    }
    else
      NSLog(@"Could not select ..");
}

static void fetchSomeTeamRecords(EOEntity *e, EOAdaptorChannel *ch) {
  EOSQLQualifier *q;
  NSArray *attrs;

  q     = [e qualifier];
  attrs = [e attributes];

  if ([ch selectAttributes:attrs describedByQualifier:q fetchOrder:nil
	  lock:NO]) {
    NSDictionary *record;
      
    while ((record = [ch fetchAttributes:attrs withZone:NULL]) != nil) {
	NSLog(@"fetched %@ birthday %@",
	      [record valueForKey:@"description"],
	      [record valueForKey:@"companyId"]);
    }
  }
  else
    NSLog(@"Could not select team records ..");
}

static void runtestInOpenChannel(EOAdaptorChannel *ch) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  EOEntity *e;
  EOSQLQualifier *q;
  NSArray *attrs;
  EOAdaptorContext *ctx;
  EOModel  *m;
  NSString *expr;

  ctx = [ch adaptorContext];
  m   = [[ctx adaptor] model];

  expr = [[NSUserDefaults standardUserDefaults] stringForKey:@"sql"];

  NSLog(@"channel is open");
  
  if (![ctx beginTransaction]) {
    NSLog(@"ERROR: could not begin transaction ...");
    return;
  }

  NSLog(@"began tx ..");

  /* do something */
  pool = [[NSAutoreleasePool alloc] init];
#if 1
  if (expr) fetchExprInChannel(expr, ch);
#endif
  
  /* fetch some MyEntity records */
  
  e = [m entityNamed:@"MyEntity"];
  NSLog(@"entity: %@", e);
  if (e == nil)
    exit(1);
        
  q     = [e qualifier];
  attrs = [e attributes];
  
  // NSLog(@"ATTRS: %@", attrs);
  
  if ([ch selectAttributes:attrs
	  describedByQualifier:q
	  fetchOrder:nil
	  lock:NO]) {
    NSDictionary *record;

    while ((record = [ch fetchAttributes:attrs withZone:nil]) != nil)
      NSLog(@"fetched record: %@", record);
  }
  else
    NSLog(@"Could not select ..");

  /* some OGo fetches */
  
  if ((e = [m entityNamed:@"Team"]) != nil)
    fetchSomeTeamRecords(e, ch);
  
  if ((e = [m entityNamed:@"Person"]) != nil)
    fetchSomePersonRecord(e, ch);

  /* tear down */
  
  [pool release];
      
  NSLog(@"committing tx ..");
  if ([ctx commitTransaction])
    NSLog(@"  could commit.");
  else
    NSLog(@"  commit failed.");
}

static void runtest(void) {
  EOModel          *m = nil;
  EOAdaptor        *a;
  EOAdaptorContext *ctx;
  EOAdaptorChannel *ch;
  NSDictionary     *conDict;
  
  NS_DURING {
  
  conDict = [NSDictionary dictionaryWithContentsOfFile:@"condict.plist"];
  NSLog(@"condict is %@", conDict);
  
  if ((a = [EOAdaptor adaptorWithName:@"SQLite3"]) == nil) {
    NSLog(@"found no SQLite3 adaptor ..");
    exit(1);
  }
  
  NSLog(@"got adaptor %@", a);
  [a setConnectionDictionary:conDict];
  NSLog(@"got adaptor with condict %@", a);
  
  ctx = [a   createAdaptorContext];
  ch  = [ctx createAdaptorChannel];

#if 1
  m = AUTORELEASE([[EOModel alloc] initWithContentsOfFile:@"test.eomodel"]);
  if (m) {
    [a setModel:m];
    [a setConnectionDictionary:conDict];
  }
#endif
  
  NSLog(@"opening channel ..");

  [ch setDebugEnabled:YES];
  
  if ([ch openChannel]) {
    runtestInOpenChannel(ch);
    
    NSLog(@"closing channel ..");
    [ch closeChannel];
  }
  }
  NS_HANDLER {
    fprintf(stderr, "exception: %s\n", [[localException description] cString]);
    abort();
  }
  NS_ENDHANDLER;
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];

  runtest();
  [pool release];
  return 0;
}
