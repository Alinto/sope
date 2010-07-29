// $Id: WORequest+Apache.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "WORequest+Apache.h"
#include <ApacheAPI/ApacheRequest.h>
#include <ApacheAPI/ApacheTable.h>
#include <ApacheAPI/ApacheConnection.h>
#include "common.h"

@interface WORequest(ApachePrivates)

- (NSData *)readDataFromApacheRequest:(ApacheRequest *)_rq;

@end

@implementation WORequest(Apache)

- (id)initWithApacheRequest:(ApacheRequest *)_rq {
  NSMutableDictionary *headers;
  NSAutoreleasePool *pool;
  NSString     *httpVersion = nil;
  NSData       *contentData;
  NSDictionary *ui;
  NGHashMap    *form;
  
  if (_rq == nil) {
    RELEASE(self);
    return nil;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  headers = [[NSMutableDictionary alloc] initWithCapacity:32];
  
  /* the values need to be parsed ! */
  {
    ApacheTable  *hin;
    NSEnumerator *keys;
    NSString     *key;
    
    hin = [_rq headersIn];
    keys = [hin keyEnumerator];
    while ((key = [keys nextObject])) {
      NSString *value;
      
      if ((value = [hin objectForKey:key]) == nil) {
        [self logWithFormat:@"got no value for key '%@' ..", key];
        continue;
      }
      
      /* NGObjWeb expects all keys to be lowercase .. */
      key = [key lowercaseString];
      [headers setObject:value forKey:key];
    }
  }
  
  /* setup "special" headers */
  {
    ApacheConnection *con = [_rq connection];
    NSString *tmp;
    
    if ((tmp = [headers objectForKey:@"host"])) {
      tmp = [@"http://" stringByAppendingString:tmp];
      [headers setObject:tmp forKey:@"x-webobjects-server-url"];
    }
    if ([(tmp = [con remoteHost]) length] > 0)
      [headers setObject:tmp forKey:@"x-webobjects-remote-host"];
    if ([(tmp = [con user]) length] > 0)
      [headers setObject:tmp forKey:@"x-webobjects-remote-user"];
    if ([(tmp = [con authorizationType]) length] > 0)
      [headers setObject:tmp forKey:@"x-webobjects-auth-type"];
  }
  
  /* content, this is to be done ... (libapr ?, hm) */
  contentData = [self readDataFromApacheRequest:_rq];
  
  /* userinfo */
  
  ui = [NSDictionary dictionaryWithObject:_rq forKey:@"ApacheRequest"];
  
  /* form values */
  
  {
    const char *cstr = [[_rq unparsedURI] cString];
    const char *pos  = index(cstr, '?');
    
    if (pos) {
      pos++;
      form = NGDecodeUrlFormParameters(pos, strlen(pos));
    }
    else
      form = nil;
  }
  
  /* construct */
  
  self = [self initWithMethod:[_rq method]
               uri:[_rq uri]
               httpVersion:httpVersion
               headers:headers
               content:contentData
               userInfo:ui];
  ASSIGN(self->formContent, form);
  
  RELEASE(headers);
  RELEASE(pool);
  return self;
}

- (NSData *)readDataFromApacheRequest:(ApacheRequest *)_rq {
#warning read request content if available ...
  return nil;
}

- (ApacheRequest *)apacheRequest {
  return [[self userInfo] objectForKey:@"ApacheRequest"];
}

@end /* WORequest(Apache) */
