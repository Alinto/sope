/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NSObject+QPEval.h"
#include "common.h"

@interface NSObject(QPEvalPrivates)

- (NSArray *)evaluateQueryPathComponent:(NSString *)_pc inContext:(id)_ctx;
- (NSArray *)evaluateQueryPathComponents:(NSArray *)_pcs;

- (void)takeValue:(id)_value forQueryPath:(NSString *)_qp;
- (id)valueForQueryPath:(NSString *)_qp;
- (NSException *)setQueryPathValue:(id)_value;
- (id)queryPathValue;

@end /* NSObject(QPEval) */


@implementation NSString(QP)

- (NSArray *)queryPathComponents {
  NSMutableArray *pc;
  unsigned i, len, s;
  
  if ([self rangeOfString:@"/"].length == 0)
    return [NSArray arrayWithObject:self];
  if ([self isEqualToString:@"/"])
    return [NSArray arrayWithObject:self];
  
  pc  = [NSMutableArray arrayWithCapacity:8];
  len = [self length];
  i   = 0;

  /* add root, if absolute path */
  if ([self characterAtIndex:0] == '/') {
    i++;
    [pc addObject:@"/"];
  }
  
  for (s = i; i < len; i++) {
    if ([self characterAtIndex:i] == '/') {
      unsigned plen;
      NSString *p;
      
      plen = (i - s);
      p = [self substringWithRange:NSMakeRange(s, plen)];
      [pc addObject:p];
      s = (i + 1); /* next component begins at idx right after '/' .. */
    }
    else if ([self characterAtIndex:i] == '{') {
      unsigned j;
      
      for (j = (i + 1); j < len; j++) {
        if ([self characterAtIndex:j] == '}') {
          /* continue after closing brace .. */
          i = j;
          break;
        }
      }
    }
  }
  if (s < i) {
    NSString *p;
    
    p = [self substringWithRange:NSMakeRange(s, (i - s))];
    [pc addObject:p];
  }
  
  return pc;
}

@end /* NSString(QP) */

@implementation NSObject(QPEval)

/* special expressions */

- (id)queryPathRootObjectInContext:(id)_ctx {
  return self;
}

/* query path evaluation */

- (NSArray *)evaluateQueryPathComponent:(NSString *)_pc inContext:(id)_ctx {
  unsigned len;
  NSArray  *result;
  
  result = nil;

  if ((len = [_pc length]) == 0)
    return nil;
  else if (len == 1) {
    unichar c;
    
    c = [_pc characterAtIndex:0];
    if (c == '/') {
      id root = [self queryPathRootObjectInContext:_ctx];
      result = root ? [NSArray arrayWithObject:root] : nil;
    }
    else if (c == '.')
      result = [NSArray arrayWithObject:self];
  }
  else {
  }
  
  NSLog(@"0x%p<%@> eval QP '%@': %@", self, NSStringFromClass([self class]),
        _pc, result);
  
  return result;
}

- (NSArray *)queryPathCursorArray {
  return [NSArray arrayWithObject:self];
}
- (NSArray *)evaluateQueryPathComponents:(NSArray *)_pcs {
  NSEnumerator      *pcs;
  NSString          *pc;
  NSAutoreleasePool *pool;
  NSArray           *array;
  NSMutableDictionary *ctx;
  
  pool = [[NSAutoreleasePool alloc] init];

  ctx = [NSMutableDictionary dictionaryWithCapacity:16];

  NSLog(@"eval PCs: %@", _pcs);
  
  array = [self queryPathCursorArray];
  
  pcs = [_pcs objectEnumerator];
  while ((array != nil) && (pc = [pcs nextObject])) {
    if ((array = [array evaluateQueryPathComponent:pc inContext:ctx]) == nil)
      break;
  }
  
  array = [array retain];
  [pool release];
  
  return [array autorelease];
}

- (NSArray *)evaluateQueryPath:(NSString *)_path {
  if ([_path rangeOfString:@"/"].length == 0)
    return [self evaluateQueryPathComponents:[NSArray arrayWithObject:_path]];
  
  if ([_path isEqualToString:@"/"]) {
    static NSArray *rootElem = nil;
    if (rootElem == nil)
      rootElem = [NSArray arrayWithObject:@"/"];
    return [self evaluateQueryPathComponents:rootElem];
  }
  
  return [self evaluateQueryPathComponents:[_path queryPathComponents]];
}

/* query KVC */

- (NSException *)setQueryPathValue:(id)_value {
  if (_value == self)
    return nil;
  
  return [NSException exceptionWithName:@"QueryPathEvalException"
                      reason:@"cannot set query-path value on object"
                      userInfo:nil];
}
- (id)queryPathValue {
  return self;
}

- (void)takeValue:(id)_value forQueryPath:(NSString *)_qp {
  [[[self evaluateQueryPath:_qp] setQueryPathValue:_value] raise];
}
- (id)valueForQueryPath:(NSString *)_qp {
  return [[self evaluateQueryPath:_qp] queryPathValue];
}

@end /* NSObject(QPEval) */

@implementation NSArray(QPEval)

- (NSArray *)queryPathCursorArray {
  return self;
}
- (NSArray *)evaluateQueryPathComponent:(NSString *)_pc inContext:(id)_ctx {
  unsigned i, j, count;
  NSArray  *array;
  id       *objs;
  
  if ((count = [self count]) == 0)
    return [NSArray array];
  
  objs = calloc(count + 1, sizeof(id));
  for (i = 0, j = 0; i < count; i++) {
    id obj;
    
    obj = [self objectAtIndex:i];
    obj = [obj evaluateQueryPathComponent:_pc inContext:_ctx];

    if (obj) {
      objs[j] = obj;
      j++;
    }
  }
  array = [NSArray arrayWithObjects:objs count:j];
  if (objs) free(objs);
  return array;
}

@end /* NSArray(QPEval) */

@implementation NSSet(QPEval)

- (NSArray *)evaluateQueryPathComponent:(NSString *)_pc inContext:(id)_ctx {
  return [[self allObjects] evaluateQueryPathComponent:_pc inContext:(id)_ctx];
}
- (NSArray *)evaluateQueryPathComponents:(NSArray *)_pcs {
  return [[self allObjects] evaluateQueryPathComponents:_pcs];
}

@end /* NSSet(QPEval) */
