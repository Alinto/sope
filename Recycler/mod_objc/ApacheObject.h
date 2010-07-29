// $Id: ApacheObject.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheObject_H__
#define __ApacheObject_H__

#import <Foundation/NSObject.h>

@interface ApacheObject : NSObject
{
  void *handle;
  BOOL freeWhenDone; // if yes, call destroyHandle in -dealloc
}

+ (id)objectWithHandle:(void *)_handle;

- (id)initWithHandle:(void *)_handle freeWhenDone:(BOOL)_flag; // designated
- (id)initWithHandle:(void *)_handle; // freeWhenDone:NO

/* destroy a handle (needs to be overidden by subclasses) */
- (void)destroyHandle;

/* accessors */
- (void *)handle;

@end

#endif /* __ApacheObject_H__ */
