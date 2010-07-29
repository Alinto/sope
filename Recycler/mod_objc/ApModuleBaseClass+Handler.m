// $Id: ApModuleBaseClass+Handler.m,v 1.1 2004/06/08 11:15:58 helge Exp $

#include "ApModuleBaseClass.h"
#include <httpd.h>
#include "http_config.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#include "ApacheServer.h"
#include "ApacheResourcePool.h"
#include "ApacheModule.h"
#include "ApacheRequest.h"

@implementation ApModuleBaseClass(HandlerCallback)

+ (BOOL)logHandlerRegistration {
  return NO;
}

+ (handler_rec *)apacheHandlerTable {
  /*
    KNOWN problem: this method produces memory leaks !!
    
    How to map selectors to handlers ?

    There are two-kinds, content-type handlers and named handlers:
    
       text/plain ->
         - (int)handleTextPlainRequest:(ApacheRequest *)_rq;
       ngobjweb-adaptor ->
         - (int)performNgobjwebAdaptorRequest:(ApacheRequest *)_rq;
    
    // This structure records the existence of handlers in a module...

    typedef struct {
      const char *content_type;	// MUST be all lower case
      int (*handler) (request_rec *);
    } handler_rec;
  */
  ApacheModule *bundleHandler = [self bundleHandler];
  handler_rec *handlerTable = NULL;
  unsigned    count, capacity;
  Class c;

  if (bundleHandler == nil)
    return NULL;
  
  count        = 0;
  capacity     = 16;
  handlerTable = calloc(capacity + 1, sizeof(handler_rec));
  
#if GNU_RUNTIME
  /* for the class and each superclass ... */
  for (c = [bundleHandler class]; c != Nil; c = c->super_class) {
    struct objc_method_list *cm;
    
    /* for each method list of the class */
    for (cm = c->methods; cm != NULL; cm = cm->method_next) {
      register unsigned i;
      
      /* for each method in the list */
      for (i = 0; i < cm->method_count; i++) {
        const char *methodName;
        
        if ((methodName = sel_get_name(cm->method_list[i].method_name))) {
          if (strstr(methodName, "handle") == methodName) {
            /* could be a MIME-type handler ... */
            const unsigned char *rq, *spec;
            unsigned j, len, n, bufLen;
            unsigned char *buf;
            
            if ((rq = strstr(methodName, "Request:")) == NULL)
              continue;
            
            spec = methodName + 6; /* skip 'handle' */
            if ((len = (rq - spec)) == 0) {
              /* type spec too long or too short ... */
              continue;
            }

            bufLen = len * 2 + 2;
            buf = malloc(bufLen);
            
            buf[0] = tolower(spec[0]);
            for (j = 1, n = 1; j < len; j++) {
              if (isupper(spec[j])) {
                buf[n] = '/';
                n++;
                buf[n] = tolower(spec[j]);
                n++;
              }
              else {
                buf[n] = spec[j];
                n++;
              }
            }
            buf[n] = '\0';

            if (count >= capacity) {
              /* resize handler table ... */
              handler_rec *old = handlerTable;
              unsigned oldCapacity = capacity;
              
              capacity *= 2;
              handlerTable = calloc(capacity + 1,sizeof(handler_rec));
              memcpy(handlerTable, old, oldCapacity * sizeof(handler_rec));
              if (old) free(old);
            }

            /* memory dup'ed is currently never freed ! */
            
            handlerTable[count].content_type = buf;
            handlerTable[count].handler = [self handleRequestStubFunction];
            count++;
            
            if ([self logHandlerRegistration]) {
              printf("%s: found method '%s' for MIME handler '%s' ...\n",
                     __PRETTY_FUNCTION__, methodName, buf);
            }
          }
          else if (strstr(methodName, "perform") == methodName) {
            /* could be a named handler ... */
            const unsigned char *rq, *spec;
            unsigned j, len, n, bufLen;
            unsigned char *buf;
            
            if ((rq = strstr(methodName, "Request:")) == NULL)
              continue;
            spec = methodName + 7; /* skip 'perform' */
            if ((len = (rq - spec)) == 0) {
              /* type spec too long or too short ... */
              continue;
            }
            
            bufLen = len * 2 + 2;
            buf = malloc(bufLen);
            
            buf[0] = tolower(spec[0]);
            for (j = 1, n = 1; j < len; j++) {
              if (isupper(spec[j])) {
                buf[n] = '-';
                n++;
                buf[n] = tolower(spec[j]);
                n++;
              }
              else {
                buf[n] = spec[j];
                n++;
              }
            }
            buf[n] = '\0';
            
            if (count >= capacity) {
              /* resize handler table ... */
              handler_rec *old = handlerTable;
              unsigned oldCapacity = capacity;
              
              capacity *= 2;
              handlerTable = calloc(capacity + 1,sizeof(handler_rec));
              memcpy(handlerTable, old, oldCapacity * sizeof(handler_rec));
              if (old) free(old);
            }
            
            /* memory dup'ed is currently never freed ! */
            
            handlerTable[count].content_type = buf;
            handlerTable[count].handler = [self handleRequestStubFunction];
            count++;
            
            if ([self logHandlerRegistration]) {
              printf("%s: found method '%s' for named handler '%s' ...\n",
                     __PRETTY_FUNCTION__, methodName, buf);
            }
          }
        }
      }
    }
  }
  
#else
#  warning not ported to this runtime yet ...
#endif
  
  if (count == 0) {
    /* found no handlers ... */
    if (handlerTable) {
      free(handlerTable);
      handlerTable = NULL;
    }
  }
#if 0
  printf("found %i handlers ...\n", count);
#endif
  return handlerTable;
}

/* the request dispatcher */

+ (int)_handleRequest:(void *)_request {
  request_rec *req = _request;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return 500;
  }
  
  result = DECLINED;
  
  if (req->handler) {
    /* dispatch based on handler set ... */
    unsigned len;
    
    if ((len = strlen(req->handler)) > 0) {
      unsigned char *buf;
      unsigned i, j;
      int (*h)(id,SEL,id);
      SEL  sel;
      BOOL nextUpper;
      
      buf = calloc(len + 64, sizeof(char));
      strcpy(buf, "perform");
      for (i = 0, j = strlen(buf), nextUpper = YES; i < len; i++) {
        if (req->handler[i] == '-') {
          /* skip dash and add next char in uppercase */
          nextUpper = YES;
        }
        else {
          buf[j] = (nextUpper)
            ? toupper(req->handler[i])
            : req->handler[i];
          j++;
          nextUpper = NO;
        }
      }
      buf[j] = '\0';
      strcat(buf, "Request:");
      sel = sel_get_any_uid(buf);
      free(buf);
      buf = NULL;

#if 0
      printf("CALL: %s\n", sel_get_name(sel));
      fflush(stdout);
#endif
      
      if (sel == NULL) {
        fprintf(stderr,
                "%s: did not find selector for handler '%s' !\n",
                __PRETTY_FUNCTION__, req->handler);
        result = 500;
      }
      else if ((h = (void *)[bundleHandler methodForSelector:sel])) {
        NSAutoreleasePool *pool;
        ApacheRequest *or;
        
        pool = [[NSAutoreleasePool alloc] init];
        or   = [[ApacheRequest alloc] initWithHandle:_request];
        
        result = h(bundleHandler, sel, or);
        
        if (result == ApacheDeclineRequest)
          result = DECLINED;
        else if (result == ApacheHandledRequest)
          result = OK;
        
        RELEASE(or);
        RELEASE(pool);
      }
      else {
        fprintf(stderr,
                "%s: did not find handler method '%s' for name '%s' !\n",
                __PRETTY_FUNCTION__, sel_get_name(sel), req->handler);
        result = 500;
      }
    }
  }
  else if (req->content_type) {
    /* dispatch based on MIME-type ... */
    unsigned len;
    
    if ((len = strlen(req->content_type)) > 0) {
      unsigned char *buf;
      unsigned i, j;
      int (*h)(id,SEL,id);
      SEL  sel;
      BOOL nextUpper;
      
      buf = calloc(len + 64, sizeof(char));
      strcpy(buf, "handle");
      for (i = 0, j = strlen(buf), nextUpper = YES; i < len; i++) {
        if (req->content_type[i] == '/') {
          /* skip slash and add next char in uppercase */
          nextUpper = YES;
        }
        else {
          buf[j] = (nextUpper)
            ? toupper(req->content_type[i])
            : req->content_type[i];
          j++;
          nextUpper = NO;
        }
      }
      buf[j] = '\0';
      strcat(buf, "Request:");
      sel = sel_get_any_uid(buf);
      free(buf);
      buf = NULL;
      
#if 0
      printf("CALL: %s\n", sel_get_name(sel));
      fflush(stdout);
#endif
      
      if (sel == NULL) {
        fprintf(stderr,
                "%s: did not find selector for mime type '%s' !\n",
                __PRETTY_FUNCTION__, req->content_type);
        result = 500;
      }
      else if ((h = (void *)[bundleHandler methodForSelector:sel])) {
        NSAutoreleasePool *pool;
        ApacheRequest *or;
        
        pool = [[NSAutoreleasePool alloc] init];
        or   = [[ApacheRequest alloc] initWithHandle:_request];
        
        result = h(bundleHandler, sel, or);
        
        if (result == ApacheDeclineRequest)
          result = DECLINED;
        else if (result == ApacheHandledRequest)
          result = OK;
        
        RELEASE(or);
        RELEASE(pool);
      }
      else {
        fprintf(stderr,
                "%s: did not find handler method '%s' for mime type '%s' !\n",
                __PRETTY_FUNCTION__, sel ? sel_get_name(sel) : "<NULL>",
                req->content_type);
        result = 500;
      }
    }
  }
  else {
    /* nothing to dispatch on ... */
    fprintf(stderr,
            "%s: found nothing to dispatch on "
            "(neither handler type nor name) !\n",
            __PRETTY_FUNCTION__);
    result = DECLINED;
  }
  return result;
}

@end /* ApModuleBaseClass(HandlerCallback) */
