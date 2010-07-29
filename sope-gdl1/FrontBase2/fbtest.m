// $Id: fbtest.m 1 2004-08-20 10:38:46Z znek $

#import <Foundation/Foundation.h>
#import <NGExtensions/NGExtensions.h>
#import <GDLAccess/EOAccess.h>
//#include "FBAdaptor.h"

#define ADAPTOR_LEVEL 1

unsigned txRepeatCount = 1;

static int doAdPersTest1(EOModel *m,EOAdaptorContext *ctx, EOAdaptorChannel *ch) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  EOEntity       *e;
  EOSQLQualifier *q;
  NSArray        *attrs;
  id             record;

  /* fetch some person records */
          
  e     = [m entityNamed:@"Person"];
  q     = [e qualifier];
  attrs = [e attributes];
#if 0
  NSLog(@"entity: %@", e);
  NSLog(@"qual:   %@", q);
  NSLog(@"attrs:  %@", attrs);
#endif
          
  if (attrs == nil) {
    NSLog(@"missing Person attributes in entity %@ !!!", e);
  }

  {
    NSCalendarDate *start;
    unsigned count, i;
            
    q = [[EOSQLQualifier alloc] initWithEntity:e
                                qualifierFormat:@"%A=5010", @"personId"];
            
    start = [NSCalendarDate date];

    count = 1;
    for (i = 0; i < count; i++) {
      //NSCAssert(attrs, @"missing attributes !!!");
      
      if ([ch selectAttributes:attrs
              describedByQualifier:q
               fetchOrder:nil
               lock:NO]) {            
        while ((record = [ch fetchAttributes:attrs withZone:nil])) {
#if 1
           NSLog(@"fetched %@ id %@",
                 [record valueForKey:@"pname"],
                 [record valueForKey:@"personId"]);
#endif
        }
      }
      else {
        NSLog(@"select failed ...");
        break;
      }
    }
    NSLog(@"duration: count %i %.3fs", count,
          [[NSCalendarDate date] timeIntervalSinceDate:start]);
  }
  
  RELEASE(pool);
  return 1;
}

static int doAdTest1(EOModel *m,EOAdaptorContext *ctx, EOAdaptorChannel *ch) {
{
#if !LIB_FOUNDATION_BOEHM_GC
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
#endif
  EOEntity       *e;
  EOSQLQualifier *q;
  NSArray        *attrs;

  /* fetch some team records */

  e = [m entityNamed:@"Team"];
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
    
    /* do some update */
    
    e = [m entityNamed:@"Person"];
    attrs = [e attributes];
    q = [[EOSQLQualifier alloc] initWithEntity:e
                                qualifierFormat:@"%A='helge'", @"login"];
                                
    q = AUTORELEASE(q);
    
    if ([ch selectAttributes:attrs
            describedByQualifier:q
            fetchOrder:nil
            lock:NO]) {
        NSDictionary *record;
    
        while ((record = [ch fetchAttributes:attrs withZone:nil]))
        ;
    }
    #if 0
    /* fetch some expr */
    
    if (expr) {
        if ([ch evaluateExpression:expr]) {
        NSDictionary *record;
    
        attrs = [ch describeResults];
        //NSLog(@"results: %@", attrs);
    
        while ((record = [ch fetchAttributes:attrs withZone:nil]))
            NSLog(@"fetched %@", record);
        }
    }
    #endif
    
    RELEASE(pool);
    }
  return 1;
}

static void runAdTests(NSDictionary *conDict) {
  EOModel          *m;
  EOAdaptor        *a;
  EOAdaptorContext *ctx;
  EOAdaptorChannel *ch;
  NSString         *expr;

  a = [EOAdaptor adaptorWithName:@"FrontBase2"];
  //a = [[FrontBaseAdaptor alloc] initWithName:@"FrontBase"];
  [a setConnectionDictionary:conDict];
  NSLog(@"got adaptor[%@] %@", NSStringFromClass([a class]), a);
  
  ctx = [a   createAdaptorContext];
  ch  = [ctx createAdaptorChannel];

  m = AUTORELEASE([[EOModel alloc] initWithContentsOfFile:@"test.eomodel"]);
  [a setModel:m];
  [a setConnectionDictionary:conDict];
  
  expr = [[NSUserDefaults standardUserDefaults] stringForKey:@"sql"];

  NSLog(@"opening channel ..");

  //[ch setDebugEnabled:NO];
  
  if ([ch openChannel]) {
    int txi;
    NSLog(@"channel is open");

    for (txi = 0; txi < txRepeatCount; txi++) {
      if ([ctx beginTransaction]) {
        NSLog(@"began tx (%i) ..", txi);

        /* do something */
        if (!doAdPersTest1(m, ctx, ch))
            break;

        NSLog(@"committing tx ..");
        if ([ctx commitTransaction])
          NSLog(@"  could commit.");
        else
          NSLog(@"  commit failed.");
      }
      else {
        NSLog(@"tx open failed ..");
      }
    }
    
    NSLog(@"closing channel ..");
    [ch closeChannel];
  }
  else {
    NSLog(@"open channel failed ...");
  }
}

static void runDbTests(NSDictionary *conDict) {
  EOModel           *m;
  EOAdaptor         *a;
  EODatabase	    *db;
  EODatabaseContext *ctx;
  EODatabaseChannel *ch;
  NSString          *expr;

  a = [EOAdaptor adaptorWithName:@"FrontBase2"];
  //a = [[FrontBaseAdaptor alloc] initWithName:@"FrontBase"];
  [a setConnectionDictionary:conDict];
  NSLog(@"got adaptor[%@] %@", NSStringFromClass([a class]), a);
  
  db  = [[EODatabase alloc] initWithAdaptor:a];
  ctx = [db  createContext];
  ch  = [ctx createChannel];

  m = AUTORELEASE([[EOModel alloc] initWithContentsOfFile:@"test.eomodel"]);
  [a setModel:m];
  [a setConnectionDictionary:conDict];
  
  expr = [[NSUserDefaults standardUserDefaults] stringForKey:@"sql"];

  NSLog(@"opening channel ..");

  if ([ch openChannel]) {
    int txi;
    NSLog(@"channel is open");

    for (txi = 0; txi < txRepeatCount; txi++) {
      if ([(EOAdaptorContext *)ctx beginTransaction]) {
        NSLog(@"began tx ..");

        /* do something */
        {
#if !LIB_FOUNDATION_BOEHM_GC
          NSAutoreleasePool *pool = [NSAutoreleasePool new];
#endif
          EOEntity       *e;
          EOSQLQualifier *q;
          NSArray        *attrs;
          id             record;

          /* fetch some person records */
          
          e     = [m entityNamed:@"Person"];
          q     = [e qualifier];
          attrs = [e attributes];

          if ([ch selectObjectsDescribedByQualifier:q fetchOrder:nil]) {
            while ((record = [ch fetchWithZone:nil])) {
              NSLog(@"fetched %@ birthday %@",
                    [record valueForKey:@"description"],
                    [record valueForKey:@"companyId"]);
            }
          }

          /* fetch some team records */

          e = [m entityNamed:@"Team"];
          q = [e qualifier];
          attrs = [e attributes];

          /* do some update */
          
          e = [m entityNamed:@"Person"];
          attrs = [e attributes];
          q = [[EOSQLQualifier alloc] initWithEntity:e
                                      qualifierFormat:@"%A='helge'", @"login"];
				    
          q = AUTORELEASE(q);
	
          RELEASE(pool);
        }

        NSLog(@"committing tx ..");
        if ([ctx commitTransaction])
          NSLog(@"  could commit.");
        else
          NSLog(@"  commit failed.");
      }
    }
    
    NSLog(@"closing channel ..");
    [ch closeChannel];
  }
  else {
    NSLog(@"open channel failed ...");
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSDictionary      *conDict;
  
  pool = [[NSAutoreleasePool alloc] init];
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  conDict = [NSDictionary dictionaryWithContentsOfFile:@"condict.plist"];

  runAdTests(conDict);

  RELEASE(pool);
  return 0;
}
