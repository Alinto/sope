/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "common.h"
#include <SxComponents/SxComponentRegistry.h>
#include <SxComponents/SxComponentMethodSignature.h>
#include <SxComponents/SxComponentException.h>
#include <SxComponents/SxComponentInvocation.h>
#include <SxComponents/SxBasicAuthCredentials.h>
#include <unistd.h>

@interface App : NSObject
{
  int  nesting;
  BOOL terminate;
  BOOL errNewLine;
}

- (void)exit:(int)_code;
- (void)printElement:(id)_element;

- (void)printDictionary:(NSDictionary *)_dict;
- (void)printArray:(NSArray *)_array;

@end

typedef enum {
  EXIT_OK                = 0,
  EXIT_MISSING_COMPONENT = 1,
  EXIT_ARGCOUNT          = 2,
  EXIT_EXCEPTION         = 3,
  EXIT_COULD_NOT_LIST    = 4,
  EXIT_NOSIGS_FOR_METHOD = 5,
  EXIT_COULD_NOT_COERCE  = 6
} AppExitCodes;

@implementation NSObject(Printing)

- (void)printWithTool:(App *)_tool {
  printf("%s", [[self description] cString]);
}

@end

@implementation NSData(Printing)

- (void)printWithTool:(App *)_tool {
  fwrite([self bytes], [self length], 1, stdout);
}

@end

@implementation NSDictionary(Printing)

- (void)printWithTool:(App *)_tool {
  [_tool printDictionary:self];
}

@end

@implementation NSArray(Printing)

- (void)printWithTool:(App *)_tool {
  [_tool printArray:self];
}

@end

@implementation App

- (void)help:(NSString *)pn {
  fprintf(stderr,
          "usage:    %s <component-name> [<method-name>] [<arg1>,...]\n"
          "  sample: %s marvin.oracle.system bc 1 2\n"
	  " use special key <nil> or nil for creating NULL values\n"
          ,[[pn lastPathComponent] cString], [[pn lastPathComponent] cString]);
}

- (void)logFail:(NSException *)e {
  NSDictionary *ui;
  NSString *reason;
  id fault;
  
  if ([[e name] isEqualToString:@"SxInvalidCredentialsException"]) {
    fprintf(stderr, "provided credentials are invalid.\n");
    return;
  }
  
  reason = [e reason];
  ui     = [e userInfo];
  
  if ((fault = [ui valueForKey:@"faultCode"])) {
    /* it's an XML-RPC fault (name is irrelevant ?) ... */
    if ([reason length] > 0) {
      fprintf(stderr, "fault[%i]: %s\n",
	      [fault intValue],
	      [reason cString]);
    }
    else {
      fprintf(stderr, "fault[%i]\n", [fault intValue]);
    }
    return;
  }
  
  NSLog(@"Call failed:\n"
        @"  name:   %@", [e name]);
  if ([reason length] > 0)
    fprintf(stderr, "  reason: %s\n", [reason cString]);
  if ([ui count] > 0)
    fprintf(stderr, "  info:   %s\n", [[ui description] cString]);
}

/* printing objects */

- (void)printDictionary:(NSDictionary *)_dict {
  NSEnumerator *dictEnum;
  id dictKey;
  
  dictEnum = [_dict keyEnumerator];
  
  while((dictKey = [dictEnum nextObject])) {
    printf("%s=", [dictKey cString]);    
    [self printElement:[_dict objectForKey:dictKey]];
    printf("\n");
  }
}

- (void)printArray:(NSArray *)_array {
  NSEnumerator *arrayEnum;
  id arrayElem;
  
  arrayEnum = [_array objectEnumerator];
  while((arrayElem = [arrayEnum nextObject])) {
    [self printElement:arrayElem];
    printf("\n");
  }
}

- (void)printElement:(id)element {
  nesting++;
  [element printWithTool:self];
  nesting--;
}

- (void)printResult:(id)result {
  [self printElement:result];
}

/* components */

- (void)showComponent:(SxComponent *)_component {
  NSEnumerator *mt;
  NSString *m;

  mt = [[[_component listMethods]
                     sortedArrayUsingSelector:@selector(compare:)]
                     objectEnumerator];
  if (mt == nil) {
    NSLog(@"couldn't list methods of component '%@'",
          [_component componentName]);
    [self exit:EXIT_COULD_NOT_LIST];
  }
  
  printf("%s\n", [[_component componentName] cString]);
  while ((m = [mt nextObject])) {
    printf("  method %s\n", [m cString]);
  }
}

- (void)exit:(int)_code {
  exit(_code);
}

- (id)coerceBase64Argument:(id)_arg {
  if([_arg isEqualToString:@"-"]) {
    NSFileHandle *handle;
    
    handle = [NSFileHandle fileHandleWithStandardInput];
    return [handle readDataToEndOfFile];
  }
  else {
    if ([[NSFileManager defaultManager] fileExistsAtPath:_arg]) {
      return [NSData dataWithContentsOfFile:_arg];
    }
    else {
      [self logWithFormat:@"invalid input file %@", _arg];
      return nil;
    }
  }
}

- (NSDictionary *)coerceStructArgument:(id)_arg {
  NSEnumerator        *pairs;
  NSMutableDictionary *md;
  NSString *s;
  NSDictionary *d;
  
  if ([_arg isKindOfClass:[NSDictionary class]])
    return _arg;
  
  _arg = [_arg stringValue];
  
  /* try to process as property list first (most flexible) ... */
  if ((d = [_arg propertyList])) {
    if ([d isKindOfClass:[NSDictionary class]])
      return d;
  }
  
  /* process this syntax: "a=2,b=3,c=9" */

  if ([_arg rangeOfString:@"="].length == 0)
    /* not that syntax ... */
    return _arg;
  
  pairs = [[_arg componentsSeparatedByString:@","] objectEnumerator];
  md = [NSMutableDictionary dictionaryWithCapacity:16];
    
  while ((s = [pairs nextObject])) {
    NSRange r;
    NSString *key, *value;
      
    r = [s rangeOfString:@"="];
    if (r.length == 0) {
      md = nil;
      break;
    }
    
    key   = [s substringToIndex:r.location];
    value = [s substringFromIndex:(r.location + r.length)];
      
    [md setObject:value forKey:key];
  }
  return md;
}

- (NSArray *)coerceArrayArgument:(id)_arg {
  NSArray *a;
  
  if ([_arg isKindOfClass:[NSArray class]])
    return _arg;

  _arg = [_arg stringValue];

  /* try to process as property list first (most flexible) ... */
  if ((a = [_arg propertyList])) {
    if ([a isKindOfClass:[NSArray class]])
      return a;
  }

  /* process arg as comma separate list .. */
  a = [_arg componentsSeparatedByString:@","];
  
  return _arg;
}

- (NSDate *)coerceDateArgument:(id)_arg {
  NSCalendarDate *date;
  static NSString *fmts[] = {
    @"%Y%m%d%H%M%S%Z",
    @"%Y%m%d%H%M%S",
    @"%Y-%m-%d %H:%M:%S %Z",
    @"%Y-%m-%d %H:%M:%S",
    @"%Y%m%d",
    @"%Y-%m-%d",
    nil
  };
  int i;
  
  if ([_arg isKindOfClass:[NSDate class]])
    return _arg;
  
  _arg = [_arg stringValue];
  
  if ([_arg isEqualToString:@"now"])
    return [NSCalendarDate calendarDate];
  if ([_arg isEqualToString:@"nil"])
    return (id)[NSNull null];
  
  if ((date = [NSCalendarDate dateWithString:_arg]))
    return date;
  
  for (i = 0; fmts[i]; i++) {
    if ((date = [NSCalendarDate dateWithString:_arg calendarFormat:fmts[i]]))
      return date;
  }
  
  return date;
}

- (NSNumber *)coerceIntArgument:(id)_arg {
  int i;
  
  if ((i = [_arg intValue]) == 0) {
    if ([[_arg stringValue] isEqualToString:@"nil"])
      return (id)[NSNull null];
  }
  return [NSNumber numberWithInt:i];
}
- (NSNumber *)coerceBoolArgument:(id)_arg {
  return [NSNumber numberWithBool:[_arg boolValue]];
}

- (id)coerceArgument:(id)_arg forType:(NSString *)_type {
  if ([_type isEqualToString:@"string"]) {
    if ([_arg isKindOfClass:[NSString class]]) {
      if ([_arg isEqualToString:@"<nil>"])
	_arg = [NSNull null];
    }
    else
      _arg = [_arg stringValue];
  }
  else if ([_type isEqualToString:@"base64"])
    _arg = [self coerceBase64Argument:_arg];
  else if ([_type isEqualToString:@"date"])
    _arg = [self coerceDateArgument:_arg];
  else if ([_type isEqualToString:@"int"] || [_type isEqualToString:@"i4"])
    _arg = [self coerceIntArgument:_arg];
  else if ([_type hasPrefix:@"bool"])
    _arg = [self coerceBoolArgument:_arg];
  else if ([_type hasPrefix:@"struct"])
    _arg = [self coerceStructArgument:_arg];
  else if ([_type hasPrefix:@"array"])
    _arg = [self coerceArrayArgument:_arg];
  else {
    [self logWithFormat:@"WARNING: "
	    @"passing through argument '%@' for type %@",
	    _arg, _type];
  }
#if 0
  NSLog(@"coerced %@ to %@ <%@>", 
	_type, _arg, NSStringFromClass([_arg class]));
#endif
  return _arg;
}

- (NSArray *)coerceArguments:(NSArray *)_args
  withSignatures:(NSArray *)_sigs
{
  NSEnumerator               *sigEnum;
  SxComponentMethodSignature *signature;
  NSMutableArray             *result;
  int                        numberOfArguments;
  int                        i;
  
  numberOfArguments = [_args count];
  result = [NSMutableArray arrayWithCapacity:[_args count]];
  
  sigEnum = [_sigs objectEnumerator];
  while((signature = [sigEnum nextObject])) {
    if ([signature numberOfArguments] == numberOfArguments) {
      break;
    }
  }

  for (i = 0; i < [signature numberOfArguments]; i++) {
    id object;

    object = [self coerceArgument:[_args objectAtIndex:i]
                   forType:[signature argumentTypeAtIndex:i]];
    
    if (object == nil) object = [NSNull null];
    [result addObject:object];
  }
  
  return result;
}

- (NSString *)prompt:(NSString *)_prompt {
  NSString *login;
  char clogin[256];
  
  printf("%s", [_prompt cString]);
  fflush(stdout);
  fgets(clogin, 200, stdin);
  clogin[strlen(clogin) - 1] = '\0';
  login = [NSString stringWithCString:clogin];
  return login;
}
- (NSString *)promptPassword:(NSString *)_prompt {
  NSString *pwd;
  char     *cpwd;

  cpwd = getpass("password: ");
  pwd = [NSString stringWithCString:cpwd];
  return pwd;
}

- (SxComponentRegistry *)registry {
  return [SxComponentRegistry defaultComponentRegistry];
}

- (BOOL)_fillCredentials:(id)_creds {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *pwd, *login;
  
  login = [ud stringForKey:@"login"];
  if ([login length] == 0)
    login = [self prompt:@"login:    "];
  if ([login length] == 0) return NO;
  
  pwd = [ud stringForKey:@"password"];
  if (pwd == nil)
    pwd = [self promptPassword:@"password: "];
  
  [_creds setCredentials:login password:pwd];
  
  return YES;
}

- (BOOL)runAsync {
  static int async = -1;
  if (async == -1)
    async = [[NSUserDefaults standardUserDefaults] boolForKey:@"async"]? 1 : 0;
  return async;
}

- (id)_waitForResult:(id)result {
  if (![result isAsyncResultPending])
    return result;
  
  while ([result isAsyncResultPending]) {
    printf("#");
    fflush(stdout);
    sleep(1);
  }
  printf("\n");
  NSLog(@"async result ready: %@", result);
  return result;
}

- (void)resultReady:(NSNotification *)_notification {
  /* called for async results ... */
  SxComponentInvocation *inv;
  NSException *e;
  id result;
  
  //[self logWithFormat:@"result ready ..."];
  
  inv = [_notification object];
  result = [inv returnValue];
  
  if ((e = [inv lastException]) == nil) {
    result = [inv returnValue];
    if (result == nil) {
      [self logWithFormat:@"result is nil ..."];
      self->terminate = YES;
    }
  }
  else if ([e isCredentialsRequiredException]) {
    /* authorization failed */
    SxBasicAuthCredentials *creds;
      
    if ((creds = [(SxAuthException *)e credentials]) == nil) {
      [self logWithFormat:@"no credentials to fill ..."];
      self->terminate = YES;
    }
    else {
      if (![self _fillCredentials:creds]) {
	self->terminate = YES;
      }
      else {
	[inv setCredentials:creds];
#if 0
	e = nil;
	return;
#else
	if (![inv asyncInvoke]) {
	  NSLog(@"cred asyncInvoke failed ...");
	  self->terminate = YES;
	}
	else {
	  e = nil;
	  return;
	}
#endif
      }
    }
  }
  
  if (self->errNewLine) {
    fprintf(stderr, "\n");
    fflush(stderr);
    self->errNewLine = NO;
  }
  
  if (result == nil && e == nil)
    [self logWithFormat:@"both, exception and result are nil ??"];
  
  if (e) {
    [self logFail:e];
    [self exit:EXIT_EXCEPTION];
  }
  else {
    [self printResult:result];
    self->terminate = YES;
  }
}

- (void)printProgress:(NSTimer *)_timer {
  fprintf(stderr, "#");
  fflush(stderr);
  self->errNewLine = YES;
}

- (void)runAsyncMethod:(NSString *)_method
  onComponent:(SxComponent *)component
  withArguments:(NSArray *)_args
{
  SxComponentInvocation *inv;
  NSException *e;
  id          result;
  NSTimer     *timer;
  
  terminate = NO;
  
  inv = [component invocationForMethodNamed:_method
                   arguments:_args];

  timer = [NSTimer scheduledTimerWithTimeInterval:1.0
		   target:self selector:@selector(printProgress:)
		   userInfo:nil repeats:YES];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self selector:@selector(resultReady:)
    name:SxAsyncResultReadyNotificationName object:inv];
  
  if (![inv asyncInvoke]) {
    /* should check result ... */
    [self logWithFormat:@"async invoke failed ..."];
  }
  else {
    NSRunLoop *loop;
    NSAutoreleasePool *pool;
    
    pool = [[NSAutoreleasePool alloc] init];
    result = nil;
    e      = nil;
      
    loop = [NSRunLoop currentRunLoop];
    
    do {
      NSAutoreleasePool *pool2;
      
      pool2 = [[NSAutoreleasePool alloc] init];
      {
	NSDate *limitDate = nil;
	
	limitDate = [loop limitDateForMode:NSDefaultRunLoopMode];
	[loop runMode:NSDefaultRunLoopMode beforeDate:limitDate];
      }
      RELEASE(pool2);
    }
    while (!self->terminate);
    
    RELEASE(pool);
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)runMethod:(NSString *)_method
  onComponent:(SxComponent *)component
  withArguments:(NSArray *)_args
{
  SxComponentInvocation *inv;
  NSException *e;
  id result;

  if ([self runAsync]) {
    [self runAsyncMethod:_method onComponent:component withArguments:_args];
    return;
  }
  
#if 0
  /* call method */
  result = [component call:_method arguments:_args];
  
  e = result ? nil : [component lastException];
  
  /* check for missing auth */
  while ([e isCredentialsRequiredException]) {
    id creds;
    
    if ((inv = [(SxAuthException *)e invocation]) == nil) {
      //[self logWithFormat:@"missing invocation !"];
      break;
    }
    if ((creds = [(SxAuthException *)e credentials]) == nil) {
      [self logWithFormat:@"missing credentials template !"];
      break;
    }
    
    if (![self _fillCredentials:creds])
      break;
    
    [inv setCredentials:creds];
    NSAssert([inv credentials] == creds, @"credentials lost ???");
    
    if (![inv invoke]) {
      /* should check result ... */
      //[self logWithFormat:@"invoke failed ..."];
      e = [inv lastException];
    }
    else
      e = nil;
    result = [inv returnValue];
  }
  
#else
  /* now invoke ... */
  
  inv = [component invocationForMethodNamed:_method
                   arguments:_args];
  
  do {
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    result = nil;
    e      = nil;
    
    if (![inv invoke]) {
      /* should check result ... */
      //[self logWithFormat:@"invoke failed ..."];
    }
    
    if ((e = [inv lastException]) == nil) {
      result = [inv returnValue];
      if (result == nil) {
        [self logWithFormat:@"result is nil ..."];
        break;
      }
    }
    else if ([e isCredentialsRequiredException]) {
      /* authorization failed */
      SxBasicAuthCredentials *creds;
      
      if ((creds = [(SxAuthException *)e credentials]) == nil) {
        [self logWithFormat:@"no credentials to fill ..."];
      }
      else {
        if (![self _fillCredentials:creds])
          break;
        [inv setCredentials:creds];
        e = nil;
      }
    }
    
    RELEASE(pool);
  }
  while ((e == nil) && (result == nil));
  
#endif

  if (result == nil && e == nil)
    [self logWithFormat:@"both, exception and result are nil ??"];
  
  if (e) {
    [self logFail:e];
    [self exit:EXIT_EXCEPTION];
  }
  else {
    [self printResult:result];
  }
}

- (void)runWithArguments:(NSArray *)args {
  SxComponentRegistry *reg;
  SxComponent         *component;
  NSArray  *rpcargs, *sigs;
  NSString *mn;
  
  reg = [self registry];
  
  if ([args count] < 2) {
    [self help:[args objectAtIndex:0]];
    [self exit:EXIT_ARGCOUNT];
  }
  
  /* lookup component */

  if ((component = (SxComponent *)[reg getComponent:[args objectAtIndex:1]]) == nil) {
    NSLog(@"did not find component named '%@'.",
          [args objectAtIndex:1]);
    [self exit:EXIT_MISSING_COMPONENT];
  }
  
  if ([args count] == 2) {
    /* do reflection */
    [self showComponent:component];
    [self exit:EXIT_OK];
  }

  /* make a call */
  
  mn = [args objectAtIndex:2];
  sigs = [component signaturesForMethodNamed:mn];
  if ([sigs count] == 0) {
    [self logWithFormat:@"got no signatures for method: %@", mn];
    [self exit:EXIT_NOSIGS_FOR_METHOD];
    return;
  }
  
  rpcargs = [args subarrayWithRange:NSMakeRange(3,[args count] - 3)];
  rpcargs = [self coerceArguments:rpcargs withSignatures:sigs];
  if (rpcargs == nil) {
    [self logWithFormat:@"couldn't coerce arguments: %@", rpcargs];
    [self exit:EXIT_COULD_NOT_COERCE];
    return;
  }
  
  [self runMethod:mn onComponent:component withArguments:rpcargs];
}

@end /* App */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  id app;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  app = [[App alloc] init];
  [app runWithArguments:
         [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  [app release];
  
  RELEASE(pool);
  exit(0);
  return 0;
}
