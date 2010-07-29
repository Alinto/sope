// $Id: SOPEXWebConnection.m,v 1.3 2004/05/02 16:27:46 znek Exp $

#include "SOPEXWebConnection.h"
#include "SOPEXWebMetaParser.h"
#include "NSString+Ext.h"
#include "NSBundle+Ext.h"
#include "common.h"

@implementation SOPEXWebConnection

static NGLogger *logger = nil;

+ (void)initialize {
  NGLoggerManager *lm;
  static BOOL     didInit = NO;

  if(didInit) return;

  didInit = YES;
  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey:@"SOPEXDebugWebConnection"];
}

- (id)initWithURL:(id)_url localResourceBundle:(NSBundle *)_resourceBundle {
  if ((self = [super init])) {
    NSArray  *pathComponents;
    NSString *appName;

    if ([_url isKindOfClass:[NSURL class]])
      self->url = [_url copy];
    else
      self->url = [[NSURL alloc] initWithString:_url];
    
    if(_resourceBundle == nil)
      _resourceBundle = [NSBundle mainBundle];
    self->localResourceBundle = [_resourceBundle retain];
    self->resourceCache       = [[NSMutableDictionary alloc] init];
    
    pathComponents = [[self->url path] pathComponents];
    if ([pathComponents count] == 0) {
      [self errorWithFormat:@"Cannot determine application prefix properly?!"];
      appName = @"UNKNOWN_APPNAME";
    }
    else {
      appName = [pathComponents objectAtIndex:0];
    }

    self->appPrefix = [[NSString stringWithFormat:@"/%@", appName] retain];
  }
  return self;
}

- (id)init {
  return [self initWithURL:nil localResourceBundle:nil];
}

- (void)dealloc {
  [self->resourceCache       release];
  [self->localResourceBundle release];
  [self->url       release];
  [self->sessionID release];
  [self->appPrefix release];
  [super dealloc];
}

/* accessors */

- (NSURL *)url {
  return self->url;
}
- (NSString *)sessionID {
  return self->sessionID;
}
- (NSBundle *)localResourceBundle {
  return self->localResourceBundle;
}

/* session tracking */

- (void)_useSessionID:(NSString *)_sid {
  ASSIGNCOPY(self->sessionID, _sid);
}

- (void)handleNoSessionInResponse:(NSURLResponse *)_r {
  if(logger)
    [self debugWithFormat:@"%s: NO session-id", __PRETTY_FUNCTION__];
}
- (void)handleInitialSessionID:(NSString *)_s inResponse:(NSURLResponse *)_r {
  if(logger)
    [self debugWithFormat:@"%s: initial sid: %@", __PRETTY_FUNCTION__, _s];
  [self _useSessionID:_s];
}
- (void)handleChangedSessionID:(NSString *)_s inResponse:(NSURLResponse *)_r {
  if(logger)
    [self debugWithFormat:@"%s: changed sid: %@", __PRETTY_FUNCTION__, _s];
  [self _useSessionID:_s];
}

- (void)processSessionID:(NSString *)_sid ofResponse:(NSURLResponse *)_r {
  if (_sid) {
    if (self->sessionID && ![self->sessionID isEqualToString:_sid])
      [self handleChangedSessionID:_sid inResponse:_r];
    else if (self->sessionID == nil)
      [self handleInitialSessionID:_sid inResponse:_r];
  }
  else {
    [self handleNoSessionInResponse:_r];
  }
}

/* operations */

- (void)processHTML:(NSString *)_html ofResponse:(NSURLResponse *)_r {
  NSArray      *links;
  NSDictionary *meta;
  
  [[SOPEXWebMetaParser sharedWebMetaParser]
      processHTML:_html meta:&meta links:&links];
#if 0
  if(logger)
    [self debugWithFormat:@"%s: meta: %@\n  links: %@",
                            __PRETTY_FUNCTION__,
                            [meta descriptionInStringsFileFormat],
                            links];
#endif
  [self processSessionID:[meta objectForKey:@"OGoSessionID"] ofResponse:_r];
}

- (void)processResponse:(NSURLResponse *)_r data:(NSData *)_data {
  NSString *s;
  
  if (![[_r MIMEType] hasPrefix:@"text/html"])
    return;
  
  s = [[NSString alloc] initWithData:_data encoding:NSISOLatin1StringEncoding];
  if (s == nil)
    return;
  
  [self processHTML:s ofResponse:_r];
  [s release];
}

- (BOOL)shouldRewriteRequestURL:(NSURL *)_url {
  NSString *path;
  BOOL shouldRewrite = NO;
  
  if(logger)
    [self debugWithFormat:@"%s testing if I should rewrite:%@",
                            __PRETTY_FUNCTION__, _url];
  
  if ([_url isFileURL])
    return shouldRewrite;
  
  if ((path = [_url path]) == nil) {
    if(logger)
      [self debugWithFormat:@"%s could not get path for URL: %@",
                              __PRETTY_FUNCTION__, path];
    return shouldRewrite;
  }
  
  shouldRewrite = ([path rangeOfString:@"WebServerResources"].location != NSNotFound || (![path hasPrefix:self->appPrefix]));
  if(logger)
    [self debugWithFormat:@"%s shouldRewrite:%@ ->%@",
                            __PRETTY_FUNCTION__, _url,
                            shouldRewrite ? @"YES" : @"NO"];
  return shouldRewrite;
}

- (NSURL *)rewriteRequestURL:(NSURL *)_url
{
  NSString *resourcePath, *urlPath;
  NSURL    *cacheURL;
  
  if ([_url isFileURL])
    return _url;
  
  urlPath = [_url path];
#if 0
  if([urlPath hasPrefix:self->appPrefix])
    return _url;
#endif
  if(logger)
    [self debugWithFormat:@"%s [_url path] will be rewritten:%@",
                            __PRETTY_FUNCTION__, _url];
  
  cacheURL = [self->resourceCache objectForKey:urlPath];
  if(logger && cacheURL)
    [self debugWithFormat:@"%s found cached URL for resource:%@",
                            __PRETTY_FUNCTION__, urlPath];
  if(cacheURL)
    return cacheURL;
  
  if(logger)
    [self debugWithFormat:@"%s trying to find resource:%@",
                            __PRETTY_FUNCTION__, urlPath];
  
  resourcePath= [self->localResourceBundle pathForResourceWithURLPath:urlPath];
  if(resourcePath == nil) {
    if(logger)
      [self debugWithFormat:@"%s didn't find resource:%@ in bundle:%@",
                              __PRETTY_FUNCTION__, urlPath,
                              self->localResourceBundle];
    /* not cached locally */
    return _url;
  }
  if(logger)
    [self debugWithFormat:@"%s found resource:%@",
                            __PRETTY_FUNCTION__, urlPath];
  
  cacheURL = [NSURL fileURLWithPath:resourcePath];
  [self->resourceCache setObject:cacheURL forKey:urlPath];
  
  return cacheURL;
}

/* description */

- (NSString *)description {
  NSMutableString *ms = [NSMutableString stringWithCapacity:32];
  
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" url=%@", [self->url absoluteString]];
  
  if (self->sessionID)
    [ms appendFormat:@" sid=%@", self->sessionID];
  else
    [ms appendString:@" no-sid"];
  
  [ms appendString:@">"];
  return ms;
}

/* Logging */

- (id)debugLogger {
  return logger;
}

@end /* SOPEXWebConnection */
