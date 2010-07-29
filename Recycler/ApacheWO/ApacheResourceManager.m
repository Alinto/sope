// $Id: ApacheResourceManager.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheResourceManager.h"
#include "AWODirectoryConfig.h"
#include <ApacheAPI/ApacheRequest.h>
#include <ApacheAPI/ApacheServer.h>
#include <ApacheAPI/ApacheTable.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@interface NSObject(UsedARPrivates)

- (void)setComponentClass:(Class)_class;

- (id)_definitionWithName:(NSString *)_name
  url:(NSURL *)_url
  baseURL:(NSURL *)_burl
  frameworkName:(NSString *)_fwname;

@end

@implementation ApacheResourceManager

static NSMutableDictionary *md = nil;

- (id)initWithURI:(NSString *)_uri {
  return self;
}
+ (id)resourceManagerForURI:(NSString *)_uri {
  ApacheResourceManager *rm;
  NSRange r;
  
  if ([_uri length] > 1) {
    r = [_uri rangeOfString:@"/" options:NSBackwardsSearch];
    if (r.length == 0) {
      NSLog(@"%s: strange uri: %@", __PRETTY_FUNCTION__, _uri);
      return nil;
    }
    
    _uri = [_uri substringToIndex:(r.location + r.length)];
  }
  
  if ((rm = [md objectForKey:_uri]))
    return rm;
  
  if ((rm = [[ApacheResourceManager alloc] initWithURI:_uri]) == nil)
    return nil;
  
  if (md == nil)
    md = [[NSMutableDictionary alloc] init];
  [md setObject:rm forKey:_uri];
  return AUTORELEASE(rm);
}

- (id)initWithApacheRequest:(ApacheRequest *)_rq
  config:(AWODirectoryConfig *)_cfg
{
  self->request = [_rq retain];
  self->config  = [_cfg retain];
  return self;
}
- (void)dealloc {
  RELEASE(self->nameToURL);
  RELEASE(self->request);
  RELEASE(self->config);
  [super dealloc];
}

/* URLs */

- (NSURL *)refererURL {
  id rurl;
  
  if ((rurl = [[self->request headersIn] objectForKey:@"Referer"]))
    rurl = [NSURL URLWithString:rurl];
  return rurl;
}

- (NSURL *)requestURL {
  ApacheServer *srv = [self->request server];
  id rurl;
  
  rurl = [NSString stringWithFormat:@"http://%@:%i%@",
		     [srv serverHostName],
		     [srv port],
		     [self->request uri]];
  rurl = [NSURL URLWithString:rurl];
  return rurl;
}

/* operations */

- (NSURL *)_templateBaseURLForComponentNamed:(id)_name {
  ApacheRequest *srq;
  NSURL *url = nil;
  
  if (_name == nil || [_name isEqual:[self->request uri]])
    return [self requestURL];
  
  if ([_name isKindOfClass:[NSURL class]]) {
    srq = [self->request subRequestLookupURI:[_name uri]];
  }
  else {
    if ([[_name pathExtension] length] == 0)
      _name = [_name stringByAppendingPathExtension:@"wox"];
    
    srq = [self->request subRequestLookupURI:_name];
  }
  
  if ([srq doesFileExist]) {
    url = [[[NSURL alloc] initWithString:[srq uri] 
			  relativeToURL:[self requestURL]] 
	                  autorelease];
  }
  else {
    [self logWithFormat:@"file does not exist: %@ (%@)",
            [srq filename], [srq fileType]];
  }
  return url;
}

- (id)definitionForComponent:(id)_name
  languages:(NSArray *)_languages
{
  id    cdef;
  NSURL *url, *baseURL;
  
  if ((baseURL = [self->nameToURL objectForKey:_name]) == nil) {
    //[self logWithFormat:@"def for component: %@)", _name];
    
    if ((baseURL = [self _templateBaseURLForComponentNamed:_name]) == nil) {
      [self logWithFormat:@"did not find template URL for component %@",_name];
      return nil;
    }
    
    if (self->nameToURL == nil)
      self->nameToURL = [[NSMutableDictionary alloc] initWithCapacity:16];
    
    [self->nameToURL setObject:baseURL forKey:_name];
  }
  
  /* lookup file for URI */
  
  if (baseURL == nil)
    return nil;
  else if ([baseURL isFileURL]) {
    [self logWithFormat:@"baseURL(%@) cannot be a file URL !", baseURL];
#if DEBUG
    exit(1);
#endif
  }
  else {
    ApacheRequest *srq;
    NSString *fn;
    
    fn = [baseURL path];
#if DEBUG
    if ([fn indexOfString:@"INTERNALLY GENERATED"] != NSNotFound) {
      [self logWithFormat:@"baseURL(%@) broken !", baseURL];
      exit(2);
    }
#endif
    
    //[self logWithFormat:@"LOOKUP: %@", fn];
    srq = [self->request subRequestLookupURI:[baseURL path] method:@"HEAD"];
    
    fn = [srq filename];
    //[self logWithFormat:@"File: %@", fn];
    
    url = [[[NSURL alloc] initFileURLWithPath:fn] autorelease];
    
    //NSLog(@"mapped:\n  base %@\n  content %@", baseURL, url);
  }
  
  /* create definition */
  
  cdef = [self _definitionWithName:_name
               url:url
               baseURL:baseURL
               frameworkName:nil];
  
  [cdef setComponentClass:[WOComponent class]];
  
  return cdef;
}

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
  request:(WORequest *)_request
{
  NSURL *compURL, *rURL;
  
  //[self logWithFormat:@"URL for resource named %@", _name];
  
  if ((compURL = [self->component baseURL]) == nil) {
    compURL = [[[[WOApplication application] context] component] baseURL];
    
    if (compURL) {
#if 0
      [self logWithFormat:@"use current component URL: %@", 
	      [compURL absoluteString]];
#endif
    }
  }
  
  if (compURL == nil) {
    compURL = [[[WOApplication application] context] baseURL];
    if (self->component)
      [self logWithFormat:@"component has no base, using context: %@",
	      [compURL absoluteString]];
    else
      [self logWithFormat:@"using component URL as base: %@",
	      [compURL absoluteString]];
  }
  
  //[self logWithFormat:@"  relative to %@", [compURL absoluteString]];
  
  rURL = [NSURL URLWithString:_name relativeToURL:compURL];
  //[self logWithFormat:@"  URL: %@", [rURL absoluteString]];
  
  return [rURL absoluteString];
}

@end /* ApacheResourceManager */
