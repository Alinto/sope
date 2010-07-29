// $Id: ApacheWO.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWO.h"
#include "common.h"
#include <ApacheAPI/ApacheAPI.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>

@interface WOApplication(UsedPrivates)
- (id)initWithName:(NSString *)_name;
@end

@implementation ApacheWO

- (id)init {
  if ((self = [super init])) {
    self->woTxStack = [[NSMutableArray alloc] initWithCapacity:4];
  }
  return self;
}
- (void)dealloc {
  RELEASE(self->woTxStack);
  [super dealloc];
}

/* transactions */

- (ApacheWOTransaction *)currentWOTransaction {
  if ([self->woTxStack count] == 0) return nil;
  return [self->woTxStack lastObject];
}

- (BOOL)willDispatchRequest:(ApacheRequest *)_rq {
  /* this is called before a handler is invoked */
  ApacheWOTransaction *tx;
  
  if (![super willDispatchRequest:_rq])
    return NO;
  
  tx = [[ApacheWOTransaction alloc] 
	 initWithApacheRequest:_rq 
	 config:[self configForDirectory:_rq]
	 serverConfig:[self configForServer:_rq]];
  if (tx == nil)
    return NO;
  
  //[self logWithFormat:@"pushing WO transaction: %@", tx];
  
  [self->woTxStack addObject:tx];
  
  [tx activate];
  
  RELEASE(tx);
  return YES;
}

- (void)didDispatchRequest:(ApacheRequest *)_rq {
  /* this is called after a handler was invoked */
  unsigned idx;
  ApacheWOTransaction *tx;
  
  if ((idx = [self->woTxStack count]) == 0) {
    [self logWithFormat:
	    @"tx stack broken, tried to pop tx from empty stack !"];
    return;
  }
  idx--;
  
  tx = RETAIN([self->woTxStack objectAtIndex:idx]);
  //[self logWithFormat:@"popping WO transaction: %@.", tx];
  [tx deactivate];
  [self->woTxStack removeObjectAtIndex:idx];
  RELEASE(tx);
}

/* application management */

+ (WOApplication *)applicationForKey:(NSString *)_key
  className:(NSString *)_className
{
  static NSMutableDictionary *keyToApp = nil; // THREAD
  WOApplication *app;
  Class clazz;
  
  if (keyToApp == nil)
    keyToApp = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if ((app = [keyToApp objectForKey:_key]))
    return app;
  
  if (_className == nil) _className = @"WOApplication";
  if ((clazz = NSClassFromString(_className)) == nil) {
    [self logWithFormat:@"did not find class named '%@'", _className];
    return nil;
  }
  
  if ((app = [[clazz alloc] initWithName:_key]) == nil) {
    [self logWithFormat:
            @"couldn't create instance for application of class %@",
            clazz];
    return nil;
  }

  /* resource managers are request dependend with our Apache module :-) */
  [app setResourceManager:nil];
  
  //[self logWithFormat:@"added application %@ for key %@", app, _key];
  
  [keyToApp setObject:app forKey:_key];
  RELEASE(app);
  
  return app;
}

@end /* ApacheWO */
