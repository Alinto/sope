/* Test whether Objective-C runtime was compiled with thread support */

#ifndef NeXT_RUNTIME
/* Dummy NXConstantString impl for so libobjc that doesn't include it */
#include <objc/NXConstStr.h>
@implementation NXConstantString
@end
#endif

#include <objc/thr.h>
#include <objc/Object.h>

int
main()
{
  id o = [Object new];

  return (objc_thread_detach (@selector(hash), o, nil) == NULL) ? -1 : 0;
}
