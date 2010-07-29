// $Id: ApacheObject.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheObject.h"
#import <Foundation/Foundation.h>

@implementation ApacheObject

static NSMapTable *proxyRegistry = NULL; // THREAD

+ (void)initialize {
  if (proxyRegistry == NULL) {
    proxyRegistry = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                     NSNonOwnedPointerMapValueCallBacks,
                                     128);
  }
}

+ (id)objectWithHandle:(void *)_handle {
  id proxy;
  
  if (_handle == NULL) return nil;
  
  if ((proxy = NSMapGet(proxyRegistry, _handle)))
    return proxy;
  
  return [[[self alloc] initWithHandle:_handle freeWhenDone:NO] autorelease];
}

- (id)initWithHandle:(void *)_handle freeWhenDone:(BOOL)_flag {
  if (_handle == NULL) {
    RELEASE(self);
    return nil;
  }
  
  self->handle = _handle;
  self->freeWhenDone = _flag;
  
  NSMapInsert(proxyRegistry, _handle, self);
  
  return self;
}
- (id)initWithHandle:(void *)_handle {
  return [self initWithHandle:_handle freeWhenDone:NO];
}
- (id)init {
  return [self initWithHandle:NULL freeWhenDone:NO];
}

- (void)dealloc {
  if (self->handle) {
    NSMapRemove(proxyRegistry, self->handle);
    
    if (self->freeWhenDone) {
      [self destroyHandle];
      self->handle = NULL;
    }
  }
  [super dealloc];
}

- (void)destroyHandle {
  [self subclassResponsibility:_cmd];
}

/* accessors */

- (void *)handle {
  return self->handle;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: apache=0x%p>",
                     self, NSStringFromClass([self class]),
                     self->handle];
}

@end /* ApacheObject */
