/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOCookie.h>
#include <NGHttp/NGHttp.h>
#include "NGHttp+WO.h"
#include <NGExtensions/NSString+Ext.h>
#include <time.h>
#include "common.h"

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (id)notImplemented:(SEL)cmd;
@end
#endif

NGObjWeb_DECLARE NSString *WORequestValueData        = @"wodata";
NGObjWeb_DECLARE NSString *WORequestValueInstance    = @"woinst";
NGObjWeb_DECLARE NSString *WORequestValuePageName    = @"wopage";
NGObjWeb_DECLARE NSString *WORequestValueContextID   = @"_c";
NGObjWeb_DECLARE NSString *WORequestValueSenderID    = @"_i";
NGObjWeb_DECLARE NSString *WORequestValueSessionID   = @"wosid";
NGObjWeb_DECLARE NSString *WORequestValueFragmentID  = @"wofid";
NGObjWeb_DECLARE NSString *WONoSelectionString       = @"WONoSelectionString";

@interface WOCoreApplication(Resources)
+ (NSString *)findNGObjWebResource:(NSString *)_name ofType:(NSString *)_ext;
@end

@implementation WORequest

static BOOL debugOn = NO;

+ (int)version {
  return [super version] + 2 /* v7 */;
}

+ (void)initialize {
  static BOOL isInitialized = NO;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSDictionary   *langMap;
  NSString       *apath;

  if (isInitialized) return;
  isInitialized = YES;
  
  NSAssert2([super version] == 5,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  debugOn = [WOApplication isDebuggingEnabled];
    
  /* apply defaults on some globals ... */
    
  apath = [ud stringForKey:@"WORequestValueSessionID"];
  if ([apath isNotEmpty])
    WORequestValueSessionID = [apath copy];
  apath = [ud stringForKey:@"WORequestValueInstance"];
  if ([apath isNotEmpty])
    WORequestValueInstance = [apath copy];
  apath = [ud stringForKey:@"WONoSelectionString"];
  if ([apath isNotEmpty])
    WONoSelectionString = [apath copy];
  
  /* load language mappings */
    
  apath = [WOApplication findNGObjWebResource:@"Languages" ofType:@"plist"];
  if (apath == nil) {
    [self errorWithFormat:@"cannot find Languages.plist resource "
            @"of NGObjWeb library !"];
    langMap = nil;
  }
  else
    langMap = [NSDictionary dictionaryWithContentsOfFile:apath];
  
  if (langMap != nil) {
    NSDictionary *defs;
    
    defs = [NSDictionary dictionaryWithObject:langMap
			 forKey:@"WOBrowserLanguageMappings"];
    [ud registerDefaults:defs];
  }
  else
    [self warnWithFormat:
            @"did not register browser language mappings: %@", apath];
}

/* parse URI */

- (void)_parseURI {
  unsigned uriLen;
  char     *uriBuf;
  char     *uri;
  NSString *serverUrl;

  // TBD: do not use cString ...
  uriLen = [self->_uri cStringLength];
  
  uriBuf = uri = malloc(uriLen + 4 /* some extra safety ;-) */);
  [self->_uri getCString:uriBuf]; uriBuf[uriLen] = '\0';
  
  /* determine adaptor prefix */

  if ((serverUrl = [self headerForKey:@"x-webobjects-adaptor-prefix"]) != nil)
    self->adaptorPrefix = [serverUrl copyWithZone:NULL];
  
  if (self->adaptorPrefix == nil)
    self->adaptorPrefix = @"";
  
  /* new parse */
  
  if (uri != NULL) {
    const char *start = NULL;
      
    /* skip adaptor prefix */
    if (self->adaptorPrefix)
      uri += [self->adaptorPrefix cStringLength];
    if (*uri == '\0') goto done;

    /* parse application name */
      
    uri++; // skip '/'
    start = uri;
    while ((*uri != '\0') && (*uri != '/') && (*uri != '.'))
      uri++;

    if (*uri == '\0') {
      self->appName =
        [[NSString alloc] initWithCString:start length:(uri - start)];
      goto done;
    }
    else if (*uri == '.') {
      self->appName =
        [[NSString alloc] initWithCString:start length:(uri - start)];

      // skip appname trailer (eg .woa)
      while ((*uri != '\0') && (*uri != '/'))
        uri++;
      if (*uri == '\0') goto done;
      uri++; // skip '/'
    }
    else if (*uri == '/') {
      self->appName =
        [[NSString alloc] initWithCString:start length:(uri - start)];
      uri++; // skip '/'
    }
    else
      goto done; // invalid state !

    if (*uri == '\0') goto done;
    
    /* parse request handler key */
    
    start = uri;
    while ((*uri != '\0') && (*uri != '/') && (*uri != '?'))
      uri++;
    self->requestHandlerKey =
      [[NSString alloc] initWithCString:start length:(uri - start)];
    if (*uri == '\0') goto done;
    if(*uri == '/'){
      uri++; // skip '/'
      /* parse request handler path */
      
      start = uri;
      while (*uri != '\0' && (*uri != '?'))
        uri++;
      self->requestHandlerPath =
        [[NSString alloc] initWithCString:start length:(uri - start)];
    }
    
    /* parsing done (found '\0') */
  done:
    ; // required for MacOSX-S
    if (uriBuf != NULL) free(uriBuf);
  }
}

- (id)initWithMethod:(NSString *)_method
  uri:(NSString *)__uri
  httpVersion:(NSString *)_version
  headers:(NSDictionary *)_headers
  content:(NSData *)_body
  userInfo:(NSDictionary *)_userInfo
{
  if ((self = [super init]) != nil) {
    self->_uri   = [__uri   copy];
    self->method = [_method copy];
    [self _parseURI];
    
    /* WOMessage */
    [self setHTTPVersion:_version];
    [self setContent:_body];
    [self setUserInfo:_userInfo];
    [self setHeaders:_headers];
  }
  return self;
}

- (void)dealloc {
  [self->startDate          release];
  [self->startStatistics    release];
  [self->method             release];
  [self->_uri               release];
  [self->adaptorPrefix      release];
  [self->requestHandlerKey  release];
  [self->requestHandlerPath release];
  [self->appName            release];
  [self->formContent        release];
  [self->request            release];
  [super dealloc];
}

/* privates */

- (void)_setHttpRequest:(NGHttpRequest *)_request {
  ASSIGN(self->request, _request);
}
- (NGHttpRequest *)httpRequest {
  if (self->request == nil) {
    /* construct request 'on-demand' */
    self->request =
      [[NSClassFromString(@"NGHttpRequest") alloc] initWithWORequest:self];
  }
  return self->request;
}

/* request handler */

- (void)setRequestHandlerKey:(NSString *)_key {
  ASSIGNCOPY(self->requestHandlerKey, _key);
}
- (NSString *)requestHandlerKey { // new in WO4
  if ([self isProxyRequest])
    return @"proxy";
  return self->requestHandlerKey;
}

- (void)setRequestHandlerPath:(NSString *)_path {
  ASSIGNCOPY(self->requestHandlerPath, _path);
}
- (NSString *)requestHandlerPath { // new in WO4
  return self->requestHandlerPath;
}

- (NSArray *)requestHandlerPathArray { // new in WO4
  NSMutableArray *array = nil;
  unsigned       clen;
  char           *cstrBuf;
  register char  *cstr;
  
  clen   = [self->requestHandlerPath cStringLength];
  if (clen == 0)
    return nil;
  
  cstrBuf = cstr = malloc(clen + 1);
  [self->requestHandlerPath getCString:cstrBuf]; cstrBuf[clen] = '\0';
  
  do {
    NSString *component = nil;
    register char *tmp = cstr;

    while ((*tmp != '\0') && (*tmp != '?') && (*tmp != '/'))
      tmp++;
    
    component = ((tmp - cstr) == 0)
      ? (id)@""
      : [[NSString alloc] initWithCString:cstr length:(tmp - cstr)];

    if (component) {
      if (array == nil) array = [NSMutableArray arrayWithCapacity:64];
      [array addObject:component];
      [component release]; component = nil;
    }

    cstr = tmp;
    if (*cstr == '/') cstr++; // skip '/'
  }
  while ((*cstr != '\0') && (*cstr != '?'));

  free(cstrBuf);
  return [[array copy] autorelease];
}

/* WO methods */

- (BOOL)isFromClientComponent {
  return NO;
}

- (NSString *)sessionID { // deprecated in WO4
  return [self cookieValueForKey:self->appName];
}
- (NSString *)senderID { // deprecated in WO4
  IS_DEPRECATED;
  return [[[WOApplication application] context] senderID];
}

- (NSString *)contextID {
  return [[[WOApplication application] context] contextID];
  //return self->contextID;
}

- (NSString *)applicationName {
  return self->appName;
}
- (NSString *)applicationHost {
  return [[NSHost currentHost] name];
}

- (NSString *)adaptorPrefix {
  return self->adaptorPrefix;
}

- (NSString *)method {
  return self->method;
}
- (void)_hackSetURI:(NSString *)_vuri {
  /* be careful, used by the WebDAV dispatcher for ZideLook range queries */
  ASSIGNCOPY(self->_uri, _vuri);
}
- (NSString *)uri {
  return self->_uri;
}
- (BOOL)isProxyRequest {
  return [[self uri] isAbsoluteURL];
}

- (void)setStartDate:(NSCalendarDate *)_startDate {
  ASSIGNCOPY(self->startDate, _startDate);
}
- (NSCalendarDate *)startDate {
  return self->startDate;
}
- (id)startStatistics {
  return self->startStatistics;
}

/* forms */

- (NSStringEncoding)formValueEncoding {
  return NSUTF8StringEncoding;
}

- (void)setDefaultFormValueEncoding:(NSStringEncoding)_enc {
  if (_enc != NSUTF8StringEncoding || _enc != NSASCIIStringEncoding)
    [self notImplemented:_cmd];
}
- (NSStringEncoding)defaultFormValueEncoding {
  return NSUTF8StringEncoding;
}

- (void)setFormValueEncodingDetectionEnabled:(BOOL)_flag {
  if (_flag) [self notImplemented:_cmd];
}
- (BOOL)isFormValueEncodingDetectionEnabled {
  return NO;
}

- (void)_parseQueryParameters:(NSString *)_s intoMap:(NGMutableHashMap *)_map {
  NSEnumerator *e;
  NSString *part;
  
  e = [[_s componentsSeparatedByString:@"&"] objectEnumerator];
  while ((part = [e nextObject])) {
    NSRange  r;
    NSString *key, *value;
	  
    r = [part rangeOfString:@"="];
    if (r.length == 0) {
      /* missing value of query parameter */
      key   = [part stringByUnescapingURL];
      value = @"1";
    }
    else {
      key   = [[part substringToIndex:r.location] stringByUnescapingURL];
      value = [[part substringFromIndex:(r.location + r.length)] 
		     stringByUnescapingURL];
    }
    
    [self->formContent addObject:value forKey:key];
  }
}

- (NGHashMap *)_getFormParameters {
  if (self->formContent != nil) 
    return self->formContent;
  
  if (self->request != nil) {
    self->formContent = [[self->request formParameters] retain];
    return self->formContent;
  }
  
  {
    /*
      TODO: add parsing of form values
      
      contained in URL:
        a/blah?name=login&pwd=j
      
      contained in body:
        Content-Type: application/x-www-form-urlencoded
        browserconfig=%7BisJavaScriptEnabled%3DYES%3B%7D&login=r&button=login
    */
    NSRange  r;
    NSString *query;
    NSString *ctype;
    BOOL     isMultiPartContent = NO, isFormContent = NO;
    
    r = [self->_uri rangeOfString:@"?"];
    query = (r.length > 0)
      ? [self->_uri substringFromIndex:(r.location + r.length)]
      : (NSString *)nil;
    
    if ((ctype = [self headerForKey:@"content-type"]) != nil) {
      isFormContent = [ctype hasPrefix:@"application/x-www-form-urlencoded"];
      if (!isFormContent)
        isMultiPartContent = [ctype hasPrefix:@"multipart/form-data"];
    }
    
    if (query != nil || isFormContent || isMultiPartContent) {
      NSAutoreleasePool *pool;
      
      pool = [[NSAutoreleasePool alloc] init];
      self->formContent = [[NGMutableHashMap alloc] init];
      
      /* parse query string */
      if (query)
        [self _parseQueryParameters:query intoMap:self->formContent];
      
      /* parse content (if form content) */
      if (isFormContent) {
        [self _parseQueryParameters:[self contentAsString]
	      intoMap:self->formContent];
      }
      else if (isMultiPartContent) {
        [self errorWithFormat:@"missing NGHttpRequest, cannot parse multipart"];
      }
      
      [pool release];
    }
    else
      self->formContent = [[NGHashMap alloc] init];
  }
  return self->formContent;
}

- (NSArray *)formValueKeys {
  id paras = [self _getFormParameters];
  
  if ([paras respondsToSelector:@selector(allKeys)])
    return [paras allKeys];
  
  return nil;
}

- (NSString *)formValueForKey:(NSString *)_key {
  NSString *value;
  id paras;
  
  value = nil;
  paras = [self _getFormParameters];
  if ([paras respondsToSelector:@selector(objectForKey:)])
    value = [(NSDictionary *)paras objectForKey:_key];
  
  return value;
}
- (NSArray *)formValuesForKey:(NSString *)_key {
  id paras = [self _getFormParameters];
  return [paras respondsToSelector:@selector(objectsForKey:)]
    ? [paras objectsForKey:_key]
    : (NSArray *)nil;
}

- (NSDictionary *)formValues {
  id paras;
  
  if ((paras = [self _getFormParameters]) == nil)
    return nil;
  
  /* check class, could change with different HTTP adaptor */
  
  if ([paras isKindOfClass:[NGHashMap class]])
    return [paras asDictionaryWithArraysForValues];
  if ([paras isKindOfClass:[NSDictionary class]])
    return paras;
  
  [self errorWithFormat:@"(%s): don't know how to deal with form object: %@",
          paras];
  return nil;
}

// ******************** Headers ******************

- (NSString *)languageForBrowserLanguageCode:(NSString *)_e {
  static NSDictionary *langMap = nil;
  NSString *le, *lang;
  
  if (_e == nil) return nil;
  
  if (langMap == nil) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    langMap = [[ud dictionaryForKey:@"WOBrowserLanguageMappings"] copy];
    if (langMap == nil) {
      [self warnWithFormat:@"did not find browser language mappings!"];
    }
  }
  
  le = [_e lowercaseString];
  
  lang = [langMap objectForKey:le];
  if (lang == nil && [le length] > 2) {
    /* process constructs like 'de-ch' */
    if ([le characterAtIndex:2] == '-') {
      NSString *ek;
      
      ek = [le substringToIndex:2];
      lang = [langMap objectForKey:ek];
    }
    else {
      /* check if the code is actually the language (ex: Danish) */
      NSArray *codes;

      codes = [langMap allKeysForObject: _e];
      if ([codes count])
        lang = _e;
    }
  }
  if (lang == nil && ![_e isEqualToString:@"*"]) {
    [self debugWithFormat:@"did not find '%@' in map: %@", 
	    _e, [[langMap allKeys] componentsJoinedByString:@", "]];
  }
  return lang;
}

- (NSString *)_languageFromUserAgent {
  /*
    user-agent sometimes stores the browser-language,
    eg: Opera/5.0 (Linux 2.2.18 i686; U)  [en]
  */
  NSString *ua;
  NSRange  rng;
  NSString *tmp;
  
  if ((ua = [self headerForKey:@"user-agent"]) == nil)
    return nil;

  rng = [ua rangeOfString:@"["];
  if (rng.length == 0)
    return nil;
      
  tmp = [ua substringFromIndex:(rng.location + rng.length)];
  rng = [tmp rangeOfString:@"]"];
  if (rng.length > 0)
    tmp = [tmp substringToIndex:rng.location];

  return [self languageForBrowserLanguageCode:tmp];
}

- (NSArray *)browserLanguages { /* new in WO4 */
  static NSArray *defLangs = nil;
  NSString       *hheader;
  NSEnumerator   *e;
  NSMutableArray *languages;
  NSString       *language;
  NSString       *tmp;
  
  languages = [NSMutableArray arrayWithCapacity:8];
  
  e = [[self headersForKey:@"accept-language"] objectEnumerator];
  while ((hheader = [e nextObject]) != nil) {
    NSEnumerator *le;
    
    le = [[hheader componentsSeparatedByString:@","] objectEnumerator];
    while ((language = [le nextObject]) != nil) {
      NSString *tmp;
      NSRange  r;
      
      /* split off the quality (eg 'en;0.96') */
      r = [language rangeOfString:@";"];
      if (r.length > 0)
        language = [language substringToIndex:r.location];
      language = [language stringByTrimmingSpaces];

      if ([language length] == 0)
        continue;
      
      /* check in map */
      if ((tmp = [self languageForBrowserLanguageCode:language]))
        language = tmp;
      
      if ([languages containsObject:language])
        continue;
      
      [languages addObject:language];
    }
  }
  
  if ((tmp = [self _languageFromUserAgent]))
    [languages addObject:tmp];
  
  if (defLangs == nil) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    defLangs = [[ud arrayForKey:@"WODefaultLanguages"] copy];
  }
  [languages addObjectsFromArray:defLangs];
  
  //[self debugWithFormat:@"languages: %@", languages];
  return [[languages copy] autorelease];
}

/* cookies */

- (NSArray *)cookieValuesForKey:(NSString *)_key {
  NSEnumerator   *ecookies;
  NSMutableArray *values;
  WOCookie       *cookie;
  
  values  = [NSMutableArray arrayWithCapacity:8];
  
  ecookies = [[self cookies] objectEnumerator];
  while ((cookie = [ecookies nextObject])) {
    if ([_key isEqualToString:[cookie name]])
      [values addObject:[cookie value]];
  }
  
  return values;
}

- (NSString *)cookieValueForKey:(NSString *)_key {
  NSEnumerator *ecookies;
  WOCookie     *cookie;
  
  ecookies = [[self cookies] objectEnumerator];
  while ((cookie = [ecookies nextObject])) {
    if ([_key isEqualToString:[cookie name]])
      return [cookie value];
  }
  return nil;
}

- (NSDictionary *)cookieValues {
  NSEnumerator        *ecookies;
  NSMutableDictionary *values;
  WOCookie            *cookie;
  
  values  = [NSMutableDictionary dictionaryWithCapacity:8];
  
  ecookies = [[self cookies] objectEnumerator];
  while ((cookie = [ecookies nextObject])) {
    NSString       *name;
    NSMutableArray *vArray;
    
    name   = [cookie name];
    vArray = [values objectForKey:name];
    
    if (vArray == nil) {
      vArray = [[NSMutableArray alloc] initWithCapacity:8];
      [values setObject:vArray forKey:name];
      [vArray release];
    }
    
    [vArray addObject:[cookie value]];
  }
  
  return values;
}

/* SOPE extensions */

- (NSString *)fragmentID {
  NSString *v;
  
  v = [self formValueForKey:WORequestValueFragmentID];
  if (v == nil) return nil;
  v = [v stringByTrimmingWhiteSpaces];
  return [v isNotEmpty] ? v : (NSString *)nil;
}

- (BOOL)isFragmentIDInRequest {
  return [self fragmentID] != nil ? YES : NO;
}

/* logging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"|Rq:%@ 0x%p|", 
                     [self method], self];
}

/* description */

- (NSString *)description {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:256];
  [str appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [str appendFormat:@" method=%@",   [self method]];
  [str appendFormat:@" uri=%@",      [self uri]];
  [str appendFormat:@" app=%@",      self->appName];
  [str appendFormat:@" rqKey=%@",    [self requestHandlerKey]];
  [str appendFormat:@" rqPath=%@",   [self requestHandlerPath]];
  [str appendString:@">"];
  return str;
}

@end /* WORequest */
