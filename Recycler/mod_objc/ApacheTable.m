// $Id: ApacheTable.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheTable.h"
#import <Foundation/NSString.h>
#include <NGExtensions/NGExtensions.h>
#include "httpd.h"
#include "ap_alloc.h"

@implementation ApacheTable
#define AP_HANDLE ((table *)self->handle)

/* query */

- (id)objectForKey:(NSString *)_key {
  return [NSString stringWithCString:ap_table_get(AP_HANDLE, [_key cString])];
}

/* modification */

- (void)setObject:(id)_obj forKey:(NSString *)_key {
  const char *v;
  
  if ((v = [[_obj stringValue] cString]))
    ap_table_set(AP_HANDLE, [_key cString], v);
  else
    ap_table_unset(AP_HANDLE, [_key cString]);
}

- (void)mergeObject:(id)_obj forKey:(NSString *)_key {
  const char *v;
  
  if ((v = [[_obj stringValue] cString]))
    ap_table_merge(AP_HANDLE, [_key cString], v);
}
- (void)addObject:(id)_obj forKey:(NSString *)_key {
  const char *v;
  
  if ((v = [[_obj stringValue] cString]))
    ap_table_add(AP_HANDLE, [_key cString], v);
}

- (void)removeAllObjects {
  ap_clear_table(AP_HANDLE);
}
- (void)removeObjectForKey:(NSString *)_key {
  ap_table_unset(AP_HANDLE, [_key cString]);
}

#undef AP_HANDLE
@end /* ApacheTable */
