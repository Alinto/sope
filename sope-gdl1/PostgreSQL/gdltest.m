/* 
   gdltest.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2005 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)

   This file is part of the PostgreSQL72 Adaptor Library

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
#import <EOAccess/EOAccess.h>
#include <NGExtensions/NGExtensions.h>

int main(int argc, char **argv, char **env) {
  EOModel          *m = nil;
  EOAdaptor        *a;
  EOAdaptorContext *ctx;
  EOAdaptorChannel *ch;
  NSDictionary     *conDict;
  NSString         *expr;
  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];

  NS_DURING {
  
  conDict = [NSDictionary dictionaryWithContentsOfFile:@"condict.plist"];
  NSLog(@"condict is %@", conDict);
  
  if ((a = [EOAdaptor adaptorWithName:@"PostgreSQL"]) == nil) {
    NSLog(@"found no PostgreSQL adaptor ..");
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
  
  expr = [[NSUserDefaults standardUserDefaults] stringForKey:@"sql"];

  NSLog(@"opening channel ..");

  [ch setDebugEnabled:YES];
  
  if ([ch openChannel]) {
    NSLog(@"channel is open");
    
    if ([ctx beginTransaction]) {
      NSLog(@"began tx ..");

      /* do something */
      {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        EOEntity *e;
        EOSQLQualifier *q;
        NSArray *attrs;

#if 1
        /* fetch some expr */

        if (expr) {
          if ([ch evaluateExpression:expr]) {
            NSDictionary *record;

            attrs = [ch describeResults];
            NSLog(@"results: %@", attrs);
	    
            while ((record = [ch fetchAttributes:attrs withZone:nil]))
              NSLog(@"fetched %@", record);
          }
        }
#endif
        /* fetch some doof records */

        e = [m entityNamed:@"Doof"];
        NSLog(@"entity: %@", e);
        if (e == nil)
          exit(1);
        
        q = [e qualifier];
        attrs = [e attributes];

        if ([ch selectAttributes:attrs
                describedByQualifier:q
                fetchOrder:nil
                lock:NO]) {
          NSDictionary *record;

          while ((record = [ch fetchAttributes:attrs withZone:nil])) {
            NSLog(@"fetched %@ birthday %@",
                  [record valueForKey:@"pkey"],
                  [record valueForKey:@"companyId"]);
          }
        }
        else
          NSLog(@"Could not select ..");

        /* fetch some team records */

        if ((e = [m entityNamed:@"Team"])) {
          q = [e qualifier];
          attrs = [e attributes];

          if ([ch selectAttributes:attrs
                  describedByQualifier:q
                  fetchOrder:nil
                  lock:NO]) {
            NSDictionary *record;

            while ((record = [ch fetchAttributes:attrs withZone:nil])) {
              NSLog(@"fetched %@ birthday %@",
                    [record valueForKey:@"description"],
                    [record valueForKey:@"companyId"]);
            }
          }
          else
            NSLog(@"Could not select ..");
        }
        
        /* do some update */

        if ((e = [m entityNamed:@"Person"])) {
          attrs = [e attributes];
          q = [[EOSQLQualifier alloc]
                               initWithEntity:e
                               qualifierFormat:@"%A='helge'", @"login"];
          AUTORELEASE(q);

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

        RELEASE(pool);
      }
      
      NSLog(@"committing tx ..");
      if ([ctx commitTransaction])
        NSLog(@"  could commit.");
      else
        NSLog(@"  commit failed.");
    }
    
    NSLog(@"closing channel ..");
    [ch closeChannel];
  }
  }
  NS_HANDLER {
    fprintf(stderr, "exception: %s\n", [[localException description] cString]);
    abort();
  }
  NS_ENDHANDLER;

  return 0;
}
