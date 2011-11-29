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

#include "SoWebDAVRenderer.h"
#include "SoWebDAVValue.h"
#include "SoObject+SoDAV.h"
#include "EOFetchSpecification+SoDAV.h"
#include "NSException+HTTP.h"
#include <NGObjWeb/SoObjects/SoObject.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOElement.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include <SaxObjC/XMLNamespaces.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

/*
  What HotMail uses for responses:
    <?xml version="1.0" encoding="Windows-1252"?>
    Headers:
      Server:              Microsoft-IIS/5.0
      X-Timestamp:         folders=1035823428, ACTIVE=1035813212
      Client-Response-Num: 1
      Client-Date:         <date>
      Expires:             ...
      P3P:                 BUS CUR CONo FIN IVDo ONL OUR PHY SAMo TELo
*/

#define XMLNS_INTTASK \
@"{http://schemas.microsoft.com/mapi/id/{00062003-0000-0000-C000-000000000046}/}"

static Class NSURLKlass = Nil;

@interface SoWebDAVRenderer(Privates)
- (BOOL)renderStatusResult:(id)_object withDefaultStatus:(int)_defStatus
  inContext:(WOContext *)_ctx; 
@end

@implementation SoWebDAVRenderer

static NSDictionary *predefinedNamespacePrefixes = nil;
static NSTimeZone   *gmt         = nil;
static BOOL         debugOn      = NO;
static BOOL         formatOutput = NO;
static BOOL         useRelativeURLs = YES;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  if (gmt == nil) 
    gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];

  if (predefinedNamespacePrefixes == nil) {
    predefinedNamespacePrefixes = 
      [[ud objectForKey:@"SoPreferredNamespacePrefixes"] copy];
  }
  formatOutput    = [ud boolForKey:@"SoWebDAVFormatOutput"];
  useRelativeURLs = [ud boolForKey:@"WOUseRelativeURLs"];
  
  if ((debugOn = [ud boolForKey:@"SoRendererDebugEnabled"]))
    NSLog(@"enabled debugging in SoWebDAVRenderer (SoRendererDebugEnabled)");

  NSURLKlass = [NSURL class];
}

+ (id)sharedRenderer {
  static SoWebDAVRenderer *r = nil; // THREAD
  if (r == nil) r = [[SoWebDAVRenderer alloc] init];
  return r;
}

- (NSString *)preferredPrefixForNamespace:(NSString *)_uri {
  return [predefinedNamespacePrefixes objectForKey:_uri];
}

/* key render entry-point */

- (void)_fixupResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  NSDate   *now;
  NSString *nowHttpString;
  id tmp;
  
  if ((tmp = [_r headerForKey:@"server"]) == nil) {
    // TODO: add application name as primary name
    static NSString *server = nil;

    if (server == nil) {
      server = [[NSString alloc] initWithFormat:@"SOPE %i.%i.%i/WebDAV",
				 SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION,
				 SOPE_SUBMINOR_VERSION];
    }
    
    [_r setHeader:server forKey:@"server"];
  }
  
  [_r setHeader:@"close" forKey:@"connection"];
  [_r setHeader:@"DAV"   forKey:@"Ms-Author-Via"];
  
  // what program uses that header ?
  [_r setHeader:@"200 No error" forKey:@"X-Dav-Error"];

  if ((tmp = [_r headerForKey:@"content-type"]) == nil)
    [_r setHeader:@"text/xml" forKey:@"content-type"];
    
  now = [NSDate date];
  nowHttpString = [now descriptionWithCalendarFormat:
			 @"%a, %d %b %Y %H:%M:%S GMT"
		       timeZone:gmt
		       locale:nil];
    
  if ((tmp = [_r headerForKey:@"date"]) == nil)
    [_r setHeader:nowHttpString forKey:@"date"];

#if 0 /* currently none of the clients allows zipping, retry later ... */
  /* try zipping */
  if ([_r shouldZipResponseToRequest:nil]) {
    [self logWithFormat:@"zipping DAV result ..."];
    [_r zipResponse];
  }
#endif
}

- (NSString *)mimeTypeForData:(NSData *)_data inContext:(WOContext *)_ctx {
  /* should check extension for MIME type */
  return @"application/octet-stream";
}
- (NSString *)mimeTypeForString:(NSString *)_str inContext:(WOContext *)_ctx {
  /* should check extension for MIME type */

  if ([_str hasPrefix:@"<?xml"])
    return @"text/xml; charset=\"utf-8\"";
  if ([_str hasPrefix:@"<html"])
    return @"text/html; charset=\"utf-8\"";
  
  return @"text/plain; charset=\"utf-8\"";
}

- (BOOL)renderObjectBodyResult:(id)_object inContext:(WOContext *)_ctx 
  onlyHead:(BOOL)_onlyHead
{
  WOResponse *r;
  NSString *tmp;
  unsigned char buf[128];
  
  r = [_ctx response];
  
  /*
    TODO: implement proper etag support. This probably implies that we need
          to pass in some structure or store the etag in the context?
	  We cannot use davEntityTag on the input parameter, since this is
	  usually the plain object.
  */
  if ((tmp = [r headerForKey:@"etag"]) == nil) {
    tmp = @"0"; // fallback, cannot use the thing above
    [r setHeader:tmp forKey:@"etag"]; // required for WebFolder PUTs
  }
  
  if ([_object isKindOfClass:[NSData class]]) {
    NSString *s;
    
    [r setHeader:[self mimeTypeForData:_object inContext:_ctx]
       forKey:@"content-type"];
    
#if GS_64BIT_OLD
    sprintf((char *)buf, "%d", [_object length]);
#else
    sprintf((char *)buf, "%ld", [_object length]);
#endif
    s = [[NSString alloc] initWithCString:(const char *)buf];
    if (s != nil) [r setHeader:s forKey:@"content-length"];
    [s release];
    if (!_onlyHead) [r setContent:_object];
    return YES;
  }
  
  if ([_object isKindOfClass:[NSString class]]) {
    NSData   *data;
    NSString *s;
    
    [r setHeader:[self mimeTypeForString:_object inContext:_ctx]
       forKey:@"content-type"];
    
    data = [_object dataUsingEncoding:NSUTF8StringEncoding];
    sprintf((char *)buf, "%ld", [data length]);
    s = [[NSString alloc] initWithCString:(const char *)buf];
    [r setHeader:s forKey:@"content-length"];
    [s release];
    [r setContent:data];
    return YES;
  }
  
  if ([_object respondsToSelector:@selector(appendToResponse:inContext:)]) {
    unsigned len;
    NSData   *data;
    
    [_object appendToResponse:r inContext:_ctx];
    
    data = [r content];
    if (![[r headerForKey:@"content-type"] isNotEmpty]) {
      [r setHeader:[self mimeTypeForData:data inContext:_ctx]
         forKey:@"content-type"];
    }
    len = [data length];
    if (_onlyHead) [r setContent:nil];
    data = nil;
    [r setHeader:[NSString stringWithFormat:@"%d", len]
       forKey:@"content-length"];
    return YES;
  }
  
  [self errorWithFormat:@"don't know how to render: %@", _object];
  return NO;
}

- (NSException *)renderObject:(id)_object inContext:(WOContext *)_ctx {
  NSString *m;
  unichar  c1;
  BOOL ok;
  
  if ([_object isKindOfClass:[WOResponse class]]) {
    if (_object != [_ctx response]) {
      [self logWithFormat:@"response mismatch"];
      return [NSException exceptionWithHTTPStatus:500 /* internal error */];
    }
    [self _fixupResponse:_object inContext:_ctx];
    return nil;
  }
  
  m = [[_ctx request] method];
  if ([m length] == 0) {
    return [NSException exceptionWithHTTPStatus:400 /* bad request */
			reason:@"missing method name!"];
  }
  c1 = [m characterAtIndex:0];

  ok = NO;
  switch (c1) {
  case 'B':
    if ([m isEqualToString:@"BPROPFIND"])
      ok = [self renderSearchResult:_object inContext:_ctx];
    break;
  case 'C':
    if ([m isEqualToString:@"COPY"]) {
      ok = [self renderStatusResult:_object 
		 withDefaultStatus:201 /* Created */
		 inContext:_ctx];
    }
    break;
  case 'D':
    if ([m isEqualToString:@"DELETE"])
      ok = [self renderDeleteResult:_object inContext:_ctx];
    break;
  case 'G':
    if ([m isEqualToString:@"GET"])
      ok = [self renderObjectBodyResult:_object inContext:_ctx onlyHead:NO];
    break;
  case 'H':
    if ([m isEqualToString:@"HEAD"])
      ok = [self renderObjectBodyResult:_object inContext:_ctx onlyHead:YES];
    break;
  case 'L':
    if ([m isEqualToString:@"LOCK"])
      ok = [self renderLockToken:_object inContext:_ctx];
    break;
  case 'M':
    if ([m isEqualToString:@"MKCOL"]
	|| [m isEqualToString:@"MKCALENDAR"])
      ok = [self renderMkColResult:_object inContext:_ctx];
    else if ([m isEqualToString:@"MOVE"]) {
      ok = [self renderStatusResult:_object 
		 withDefaultStatus:201 /* Created */
		 inContext:_ctx];
    }
    break;
  case 'O':
    if ([m isEqualToString:@"OPTIONS"])
      ok = [self renderOptions:_object inContext:_ctx];
    break;
  case 'P':
    if ([m isEqualToString:@"PUT"])
      ok = [self renderUploadResult:_object inContext:_ctx];
    else if ([m isEqualToString:@"PROPFIND"])
      ok = [self renderSearchResult:_object inContext:_ctx];
    else if ([m isEqualToString:@"PROPPATCH"])
      ok = [self renderPropPatchResult:_object inContext:_ctx];
    else if ([m isEqualToString:@"POLL"])
      ok = [self renderPollResult:_object inContext:_ctx];
    break;
  case 'S':
    if ([m isEqualToString:@"SEARCH"])
      ok = [self renderSearchResult:_object inContext:_ctx];
    else if ([m isEqualToString:@"SUBSCRIBE"])
      ok = [self renderSubscription:_object inContext:_ctx];
    break;
    
  default:
    ok = NO;
    break;
  }
  
  if (ok) [self _fixupResponse:[_ctx response] inContext:_ctx];
  return ok
    ? nil
    : [NSException exceptionWithHTTPStatus:500 /* server error */];
}

- (BOOL)canRenderObject:(id)_object inContext:(WOContext *)_ctx {
  if ([_object isKindOfClass:[NSException class]])
    return NO;
  return YES;
}

- (NSString *)stringForValue:(id)_value ofProperty:(NSString *)_prop 
  prefixes:(NSDictionary *)_prefixes
  requireTagValue:(BOOL)_requireTagValue
{
  NSString *davNS;

  davNS = [[_prefixes objectForKey:XMLNS_WEBDAV] stringValue];
  
  if ([_value isKindOfClass:[NSArray class]]) {
    /*
	Use arrays to allow for something like this:
          <collection/>
          <C:todos xmlns:C="urn:ietf:params:xml:ns:caldav"/>
	Item Format:
	  ( TAG )                  => tag in DAV: namespace
	  ( TAG, NS )              => tag in NS namespace
	  ( TAG, NS, PREFIX )      => tag in NS namespace with PREFIX
	  ( TAG, NS, PREFIX, val ) => tag in NS namespace with PREFIX and value
    */
    NSMutableString *ms;
    NSEnumerator *e;
    id item;

    if (![_value isNotEmpty])
      return nil;
    
    ms = [NSMutableString stringWithCapacity:16];
    e  = [_value objectEnumerator];
    while ((item = [e nextObject]) != nil) {
      NSString *tag, *ns, *pre;
      unsigned count;

      if (![item isKindOfClass:[NSArray class]]) {
	item = [item stringValue];
	if (![item isNotEmpty]) continue;

	if (_requireTagValue) {
	  [ms appendString:@"<"];
	  [ms appendString:davNS];
	  [ms appendString:@":"];
	  [ms appendString:item];
	  [ms appendString:@"/>"];
	}
	else
	  [ms appendString:[item stringByEscapingXMLString]];
	
	continue;
      }

      /* process array tags */
	  
      if ((count = [item count]) == 0)
	continue;
      
      tag = [[item objectAtIndex:0] stringValue];
      ns  = (count > 1) ? [[item objectAtIndex:1] stringValue]:(NSString*)nil;
      pre = (count > 2) ? [[item objectAtIndex:2] stringValue] : davNS;

      [ms appendString:@"<"];
      if (count != 2) {
	[ms appendString:pre];
	[ms appendString:@":"];
      }
      [ms appendString:tag];
      
      if (count == 2) {
	[ms appendString:@" xmlns=\""];
	[ms appendString:ns];
	[ms appendString:@"\""];
      }
      else if (count > 2) {
	[ms appendString:@" xmlns:"];
	[ms appendString:pre];
	[ms appendString:@"=\""];
	[ms appendString:ns];
	[ms appendString:@"\""];
      }
      
      if (count > 3) {
	id value = [item objectAtIndex:3];
	[ms appendString:@">"];

	if ([value isNotEmpty]) {
	  /* nested tag */
	  [ms appendString:[self stringForValue:value ofProperty:_prop
				 prefixes:_prefixes requireTagValue:NO]];
	}

	[ms appendString:@"</"];
	if (count != 2) {
	  [ms appendString:pre];
	  [ms appendString:@":"];
	}
	[ms appendString:tag];
	[ms appendString:@">"];
      }
      else {
	/* no value, close tag */
	[ms appendString:@"/>"];
      }
    }
    return ms;
  }
    
  _value = [_value stringValue];
  if (![_value isNotEmpty]) return nil;

  if (_requireTagValue) {
    /*
      This is for properties like 'resourcetype'. davResourceType just
      returns 'collection' but gets rendered as '<D:collection/>'
    */
    return [NSString stringWithFormat:@"<%@:%@/>", davNS, _value];
  }
  
  return _value;
}
- (NSString *)stringForValue:(id)_value ofProperty:(NSString *)_prop 
  prefixes:(NSDictionary *)_prefixes
{
  /* seems like this is the default date value */
  NSString *datefmt = @"%a, %d %b %Y %H:%M:%S GMT";
  
  if (_value == nil)
    return nil;
  if (![_value isNotNull])
    return nil;
  
  /* special processing for some properties */
  
  if ([_prop isEqualToString:@"{DAV:}resourcetype"]) {
    return [self stringForValue:_value ofProperty:_prop
		 prefixes:_prefixes requireTagValue:YES];
  }
  
  if ([_prop isEqualToString:@"{DAV:}creationdate"])
    datefmt = @"%Y-%m-%dT%H:%M:%S%zZ";

  /* special processing for some properties  */
  
  // TODO: move this to user-level code ! 
  //   HH: what is that ? it does not do anything anyway ?
  if ([_prop hasPrefix:XMLNS_INTTASK]) {
    if ([_prop hasSuffix:@"}0x00008102"]) {
    }
  }
  
  /* special processing for some classes */
  
  if ([_value isKindOfClass:[NSString class]])
    return [_value stringByEscapingXMLString];
  
  if ([_value isKindOfClass:[NSNumber class]])
    return [_value stringValue];
  
  if ([_value isKindOfClass:[NSDate class]]) {
    return [_value descriptionWithCalendarFormat:datefmt
		   timeZone:gmt
		   locale:nil];
  }
  
  if ([_value isKindOfClass:[NSArray class]]) {
    return [self stringForValue:_value ofProperty:_prop
		 prefixes:_prefixes requireTagValue:NO];
  }
  
  return [[_value stringValue] stringByEscapingXMLString];
}

- (NSString *)baseURLForContext:(WOContext *)_ctx {
  /*
    Note: Evolution doesn't correctly transfer the "Host:" header, it
    misses the port argument :-(
  */
  NSString  *baseURL;
  WORequest *rq;
  NSString  *hostport;
  id tmp;
  
  rq = [_ctx request];
  
  if ((tmp = [rq headerForKey:@"x-webobjects-server-name"])) {
    hostport = tmp;
    if ((tmp = [rq headerForKey:@"x-webobjects-server-port"]) != nil) {
      if ([tmp intValue] > 0)
	hostport = [NSString stringWithFormat:@"%@:%@", hostport, tmp];
      else {
	[self logWithFormat:@"got bogus port information from webserver: %@", 
	        hostport];
      }
    }
  }
  else if ((tmp = [rq headerForKey:@"host"]))
    hostport = tmp;
  else
    hostport = [[NSHost currentHost] name];
  
  baseURL = [NSString stringWithFormat:@"http://%@%@", hostport, [rq uri]];
  return baseURL;
}

- (NSString *)tidyHref:(id)_href baseURL:(id)baseURL {
  NSString *href;
  
  href = [_href stringValue];
  
  if (debugOn) {
    // TODO: this happens if we access using Goliath
    if ([href hasPrefix:@"http:/"] && ![href hasPrefix:@"http://"]) {
      [self logWithFormat:@"BROKEN URL: %@", _href];
      return nil;
    }
  }
  
  if (href == nil) {
    if (debugOn) {
      [self warnWithFormat:
              @"using baseURL for href, entry did not provide a URL: %@",
              baseURL];
    }
    href = [baseURL stringValue];
  }
  else if (![href isAbsoluteURL]) { // maybe only check for http[s]:// ?
    // TODO: use "real" URL processing
    if ([href hasPrefix:@"/"]) {
      if (useRelativeURLs)
	return href;
      
      [self warnWithFormat:@"href path is absolute:\n  base: %@\n  href: %@",
	      baseURL, href];
    }
    href = [baseURL stringByAppendingPathComponent:href];
  }
  return href;
}
- (id)tidyStatus:(id)stat {
  if (stat == nil)
    stat = @"HTTP/1.1 200 OK";
  else if ([stat isKindOfClass:[NSException class]]) {
    int i;
    
    if ((i = [stat httpStatus]) > 0)
      stat = [NSString stringWithFormat:@"HTTP/1.1 %i %@", i, [stat reason]];
    else {
      stat = [(NSException *)stat name];
      stat = [@"HTTP/1.1 500 " stringByAppendingString:stat];
    }
  }
  return stat;
}

- (void)renderNullProperty:(NSString *)_key
  toResponse:(WOResponse *)r inContext:(WOContext *)_ctx 
  namesOnly:(BOOL)_namesOnly isBrief:(BOOL)isBrief
  tagToPrefix:(NSDictionary *)extNameCache
  nsToPrefix:(NSDictionary *)nsToPrefix
{
  NSString *extName;
  
  extName = [extNameCache objectForKey:_key];
  
  [r appendContentCharacter:'<'];
  [r appendContentString:extName];
  [r appendContentString:@"/>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
}

- (void)renderProperty:(NSString *)_key value:(id)value
  toResponse:(WOResponse *)r inContext:(WOContext *)_ctx 
  namesOnly:(BOOL)_namesOnly
  tagToPrefix:(NSDictionary *)extNameCache
  nsToPrefix:(NSDictionary *)nsToPrefix
{
  NSString *extName;
  NSString *s;
  
  extName = [extNameCache objectForKey:_key];
  
  if (_namesOnly) {
    [r appendContentCharacter:'<'];
    [r appendContentString:extName];
    [r appendContentString:@"/>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
    return;
  }
    
  if ([value isKindOfClass:[SoWebDAVValue class]]) {
    s = [value stringForTag:_key rawName:extName
	       inContext:_ctx prefixes:nsToPrefix];
    [r appendContentString:s];
  }
  else {
    s = [self stringForValue:value ofProperty:_key prefixes:nsToPrefix];
    [r appendContentCharacter:'<'];
    [r appendContentString:extName];
    if ([s length] > 0) {
      [r appendContentCharacter:'>'];
      [r appendContentString:s];
      [r appendContentString:@"</"];
      [r appendContentString:extName];
      [r appendContentString:@">"];
    }
    else {
      [r appendContentString:@"/>"];
    }
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
}

- (void)renderSearchResultEntry:(id)entry inContext:(WOContext *)_ctx 
  namesOnly:(BOOL)_namesOnly
  attributes:(NSArray *)_attrs
  propertyMap:(NSDictionary *)_propMap
  baseURL:(NSString *)baseURL
  tagToPrefix:(NSDictionary *)extNameCache
  nsToPrefix:(NSDictionary *)nsToPrefix
{
  /* Note: the entry is an NSArray in case _namesOnly is requested! */
  // TODO: use -valueForKey: to improve NSNull handling ?
  NSMutableArray *missingProps;
  WOResponse   *r;
  NSEnumerator *keys;
  NSString     *key;
  id   href = nil;
  id   stat = nil;
  BOOL isBrief, hasSlash;

  hasSlash = [[[_ctx request] uri] hasSuffix: @"/"];
  r = [_ctx response];
  isBrief = [[[_ctx request] headerForKey:@"brief"] hasPrefix:@"t"] ? YES : NO;

  /* 
     Hack for Cadaver which shows errors when requested properties are missing.
     TODO: Might not apply to all properties, find out the minimum Cadaver set.
  */
  if (!isBrief) {
    isBrief = [[[[_ctx request] clientCapabilities] userAgentType]
		       isEqualToString:@"Cadaver"];
  }
  
  if (debugOn) {
    [self debugWithFormat:@"    render entry: 0x%p<%@>%s%s",
	  entry, NSStringFromClass([entry class]),
	  isBrief    ? " brief"      : "",
	  _namesOnly ? " names-only" : ""];
  }

  /* we do not map these DAV properties because they are very special */
  if (!_namesOnly) {
    if ((href = [entry valueForKey:@"{DAV:}href"]) == nil) {
      if ((key = [_propMap objectForKey:@"{DAV:}href"]) != nil) {
        if ((href = [entry valueForKey:key]) == nil) {
          if (debugOn) {
            [self warnWithFormat:
                    @"no value for {DAV:}href key '%@': %@", key, entry];
  	}
        }
      }
      else if (debugOn) {
        [self warnWithFormat:@"no key for {DAV:}href in property map !"];
      }
    }
    /* 
       TODO: where is this used? It doesn't make a lot of sense since one
             response can have multiple status values?! One for each
	     property.
	     So: do we actually use this special key anywhere?
    */
    if ((stat = [entry valueForKey:@"{DAV:}status"]) == nil) {
      if ((key = [_propMap objectForKey:@"{DAV:}status"]))
        stat = [entry valueForKey:key];
    }

    /* tidy href */
    if (useRelativeURLs) {
      if ([href isKindOfClass: NSURLKlass])
        href = [href path];
    }
    else
      href = [self tidyHref:href baseURL:baseURL];

    /* tidy status */
    stat = [self tidyStatus:stat];
  }
  else { /* propnames only */
    href = [baseURL stringValue];
    stat = @"HTTP/1.1 200 OK";
  }

  /* make the presence of the href slash correspond to the request slash */
  if (hasSlash) {
    /* megahack: we consider entry to be the base entry if it's an
       NSDictionary */
    if (![href hasSuffix: @"/"]
        && ([entry isFolderish]
            || [entry isKindOfClass: [NSDictionary class]])) {
      href = [href stringByAppendingString: @"/"];
    }
  }
  else {
    if ([href hasSuffix: @"/"])
      href = [href substringToIndex: [href length] - 2];
  }

  if (debugOn) {
    [self debugWithFormat:@"    status: %@", stat];
    [self debugWithFormat:@"    href:   %@", href];
  }
  
  /* start the response */
  
  [r appendContentString:@"<D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];

  /* write the href the response is for */
  
  if ([href isNotEmpty]) {
    [r appendContentString:@"<D:href>"];
    /*
      TODO: need to find out what is appropriate! While Cadaver and ZideLook
            (both Neon+Expat) seem to be fine with this, OSX reports invalid
            characters (displayed as '#') for umlauts.
            It might be that we are supposed to use *URL* escaping in any 
            case! (notably entering a directory with an umlaut doesn't seem
            to work in Cadaver either because of a URL mismatch!)
      Note: we cannot apply URL encoding in this place, because it will encode
            all URL special chars ... where are URLs escaped?
      Note: we always need to apply XML escaping (even though higher-level
            characters might be already encoded)!
    */
    [r appendContentXMLString: [NSString stringWithFormat: @"%@/%@",
					 [[href stringValue] stringByDeletingLastPathComponent],
					 [[[href stringValue] lastPathComponent] stringByEscapingURL]]];

    if ([[href stringValue] hasSuffix: @"/"])
      [r appendContentXMLString: @"/"];

    [r appendContentString:@"</D:href>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  else {
    [self warnWithFormat:@"WebDAV result entry has no valid href: %@", entry];
  }
  
  [r appendContentString:@"<D:propstat>"];

  if (stat != nil) {
    [r appendContentString:@"<D:status>"];
    [r appendContentXMLString:[stat stringValue]];
    [r appendContentString:@"</D:status>"];
  }
  
  [r appendContentString:@"<D:prop>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  /* first the available properties */

  missingProps = nil;
  keys = [_attrs objectEnumerator] ;
  while ((key = [keys nextObject]) != nil) {
    NSString *okey;
    id value;

    /* determine value */
    
    if ((okey = [_propMap objectForKey:key]) == nil)
      okey = key;
    
    value = [key isEqualToString:@"{DAV:}href"]
      ? href
      : [entry valueForKey:okey];
    
    /* always render resourcetype, otherwise Cadaver is confused */
    if (![value isNotNull] && ![key isEqualToString:@"{DAV:}resourcetype"]) {
      if (missingProps == nil)
	missingProps = [[NSMutableArray alloc] initWithCapacity:8];
      [missingProps addObject:key];
      continue;
    }
    
    /* render */
    
    [self renderProperty:key value:value
	  toResponse:r inContext:_ctx
	  namesOnly:_namesOnly
	  tagToPrefix:extNameCache nsToPrefix:nsToPrefix];
  }

  /* next the missing properties unless we are brief */

  if (!isBrief && [missingProps isNotEmpty]) {
    /* close previous propstat and open a new one */
    [r appendContentString:@"</D:prop></D:propstat>"];
    if (formatOutput) [r appendContentCharacter:'\n'];

    if (debugOn) {
      [self debugWithFormat:@"      missing: %@",
	      [missingProps componentsJoinedByString:@","]];
    }
    
    [r appendContentString:@"<D:propstat>"];
    [r appendContentString:
	 @"<D:status>HTTP/1.1 404 Not Found</D:status>"];
    [r appendContentString:@"<D:prop>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
    
    keys = [missingProps objectEnumerator] ;
    while ((key = [keys nextObject]) != nil) {
      [self renderNullProperty:key
	    toResponse:r inContext:_ctx
	    namesOnly:_namesOnly isBrief:isBrief
	    tagToPrefix:extNameCache nsToPrefix:nsToPrefix];
    }
  }
  
  [missingProps release]; missingProps = nil;
  
  [r appendContentString:@"</D:prop>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [r appendContentString:@"</D:propstat>"];
  
  
  /* finish response */
  
  [r appendContentString:@"</D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
}

- (void)buildPrefixMapForAttributes:(NSArray *)_attrs
  tagToExtName:(NSMutableDictionary *)_tagToExtName
  nsToPrefix:(NSMutableDictionary *)_nsToPrefix
{
  unichar autoPrefix[2] = { ('a' - 1), 0 };
  NSEnumerator *e;
  NSString     *fqn;
  
  e = [_attrs objectEnumerator];
  while ((fqn = [e nextObject])) {
    NSString *ns, *localName, *prefix, *extName;
    
    if ([_tagToExtName objectForKey:fqn]) continue;
    
    if (![fqn xmlIsFQN]) {
      /* hm, no namespace given :-(, using DAV */
      ns        = @"DAV:";
      localName = fqn;
    }
    else {
      ns        = [fqn xmlNamespaceURI];
      localName = [fqn xmlLocalName];
    }
    
    if ((prefix = [_nsToPrefix objectForKey:ns]) == nil) {
      if ((prefix = [self preferredPrefixForNamespace:ns]) == nil) {
	(autoPrefix[0])++;
	prefix = [NSString stringWithCharacters:&(autoPrefix[0]) length:1];
      }
      [_nsToPrefix setObject:prefix forKey:ns];
    }
    
    extName = [NSString stringWithFormat:@"%@:%@", prefix, localName];
    [_tagToExtName setObject:extName forKey:fqn];
  }
}

- (NSString *)nsDeclsForMap:(NSDictionary *)_nsToPrefix {
  NSMutableString *ms;
  NSEnumerator *nse;
  NSString *ns;
  
  ms = [NSMutableString stringWithCapacity:256];
  nse = [_nsToPrefix keyEnumerator];
  while ((ns = [nse nextObject])) {
    [ms appendString:@" xmlns:"];
    [ms appendString:[_nsToPrefix objectForKey:ns]];
    [ms appendString:@"=\""];
    [ms appendString:ns];
    [ms appendString:@"\""];
  }
  return ms;
}

- (void)renderSearchResult:(id)_entries inContext:(WOContext *)_ctx 
  namesOnly:(BOOL)_namesOnly
  attributes:(NSArray *)_attrs
  propertyMap:(NSDictionary *)_propMap
{
  NSMutableDictionary *extNameCache = nil;
  NSMutableDictionary *nsToPrefix   = nil;
  NSAutoreleasePool   *pool;
  WOResponse *r;
  unsigned   entryCount;
  
  pool = [[NSAutoreleasePool alloc] init];
  r = [_ctx response];
  
  if (![_entries isKindOfClass:[NSEnumerator class]]) {
    if ([_entries isKindOfClass:[NSArray class]]) {
      [self debugWithFormat:@"  render %i entries", [_entries count]];
      _entries = [_entries objectEnumerator];
    }
    else {
      [self debugWithFormat:@"  render a single object ..."];
      _entries = [[NSArray arrayWithObject:_entries] objectEnumerator];
    }
  }
  
  /* collect used namespaces */
  
  nsToPrefix = [NSMutableDictionary dictionaryWithCapacity:16];
  [nsToPrefix setObject:@"D" forKey:XMLNS_WEBDAV];
  
  /* 
     the extNameCache is used to map fully qualified tag names to their
     prefixed external representation 
  */
  extNameCache = [NSMutableDictionary dictionaryWithCapacity:32];
  
  // TODO: only walk attrs, if available
  /*
    Walk all attributes of all entries to collect names. We might be able
    to take a look at just the first record if it is guaranteed, that all
    records have all properties (even if the value is NSNull) ?
  */
  [self buildPrefixMapForAttributes:_attrs
	tagToExtName:extNameCache
	nsToPrefix:nsToPrefix];
  
  /* generate multistatus */
   
  [r setStatus:207 /* multistatus */];
  [r setContentEncoding:NSUTF8StringEncoding];
  [r setHeader:@"text/xml; charset=\"utf-8\"" forKey:@"content-type"];
  [r setHeader:@"no-cache" forKey:@"pragma"];
  [r setHeader:@"no-cache" forKey:@"cache-control"];
  
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
  [r appendContentString:@"<D:multistatus"];
  [r appendContentString:[self nsDeclsForMap:nsToPrefix]];
  [r appendContentString:@">"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  {
    NSString *baseURL;
    NSString *range;
    id entry;
    
    baseURL = [self baseURLForContext:_ctx];
    [self debugWithFormat:@"  baseURL: %@", baseURL];
    
    entryCount = 0; /* Note: this will clash with streamed output later */
    while ((entry = [_entries nextObject]) != nil) {
      [self renderSearchResultEntry:entry inContext:_ctx
	    namesOnly:_namesOnly attributes:_attrs propertyMap:_propMap
	    baseURL:baseURL tagToPrefix:extNameCache nsToPrefix:nsToPrefix];
      entryCount++;
    }
    [self debugWithFormat:@"  rendered %i entries", entryCount];
    
    /*
      If we got a "rows" range header, we report back the actual rows
      delivered. Since we do not really support ranges in the moment,
      we just report all rows ... 
      TODO: support for row ranges.
    */
    if ((range = [[[_ctx request] headerForKey:@"range"] stringValue])) {
      /* sample: "Content-Range: rows 0-143; total=144" */
      NSString *v;
      
      v = [[NSString alloc] initWithFormat:@"rows 0-%i; total=%i", 
                              entryCount>0?(entryCount - 1):0, entryCount];
      [r setHeader:v forKey:@"content-range"];
      [v release];
    }
  }
  [r appendContentString:@"</D:multistatus>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [pool release];
}

- (BOOL)renderSearchResult:(id)_object inContext:(WOContext *)_ctx {
  EOFetchSpecification *fs;
  NSDictionary *propMap;
  
  if ((fs = [_ctx objectForKey:@"DAVFetchSpecification"]) == nil)
    return NO;
  
  if ((propMap = [_ctx objectForKey:@"DAVPropertyMap"]) == nil)
    propMap = [_object davAttributeMapInContext:_ctx];

  if (debugOn) {
    [self debugWithFormat:@"render search result 0x%p<%@>",
            _object, NSStringFromClass([_object class])];
  }
  
  [self renderSearchResult:_object inContext:_ctx
	namesOnly:[fs queryWebDAVPropertyNamesOnly]
	attributes:[fs selectedWebDAVPropertyNames]
	propertyMap:propMap];
  
  if (debugOn) 
    [self debugWithFormat:@"finished rendering."];
  return YES;
}

- (BOOL)renderLockToken:(id)_object inContext:(WOContext *)_ctx {
  // TODO: this is fake for most parts! The object needs to be some real
  //       object describing the lock, not just the token
  WOResponse *r;
  id tmp;
  
  if (_object == nil) return NO;
  
  r = [_ctx response];
  
  [r setStatus:200 /* OK */];
  [r setContentEncoding:NSUTF8StringEncoding];
  [r setHeader:@"text/xml; charset=\"utf-8\"" forKey:@"content-type"];
  [r setHeader:[_object stringValue]          forKey:@"lock-token"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
  [r appendContentString:@"<D:prop xmlns:D=\"DAV:\">"];
  [r appendContentString:@"<D:lockdiscovery>"];
  [r appendContentString:@"<D:activelock>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  // TODO: we assume a write token and exclusive access, also check the
  //       SoObjectWebDAVDispatcher

  [r appendContentString:@"<D:locktype><D:write/></D:locktype>"];
  if (formatOutput) [r appendContentCharacter:'\n'];

  [r appendContentString:@"<D:lockscope><D:exclusive/></D:lockscope>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  /* write the depth */
  // TODO: we just give back the depth of the request ...
  
  if ([(tmp = [[_ctx request] headerForKey:@"depth"]) isNotEmpty]) {
    [r appendContentString:@"<D:depth>"];
    [r appendContentString:[tmp stringValue]];
    [r appendContentString:@"</D:depth>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  
  // TODO: owner,     eg <D:owner><D:href>...</D:href></D:owner>
  
  /* write the timeout */
  // TODO: we just give back the timeout of the request ...
  
  if ([(tmp = [[_ctx request] headerForKey:@"timeout"]) isNotEmpty]) {
    /* eg <D:timeout>Second-604800</D:timeout> */
    [r appendContentString:@"<D:timeout>"];
    [r appendContentString:[tmp stringValue]];
    [r appendContentString:@"</D:timeout>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  
  /* this is the href of the lock, not of the locked resource */

  [r appendContentString:@"<D:locktoken><D:href>"];
  [r appendContentString:[_object stringValue]];
  [r appendContentString:@"</D:href></D:locktoken>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [r appendContentString:@"</D:activelock>"];
  [r appendContentString:@"</D:lockdiscovery>"];
  [r appendContentString:@"</D:prop>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  return YES;
}

- (BOOL)renderOptions:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r;
  
  r = [_ctx response];
  [r setStatus:200 /* OK */];
  [r setHeader:@"1,2" forKey:@"DAV"]; // TODO: select protocol level
  //[r setHeader:@"" forKey:@"Etag"]; 
  
  if (![_object isNotNull])
    ;
  else if ([_object isKindOfClass:[NSArray class]]) {
    /* DEPRECATED */
    [r setHeader:[_object componentsJoinedByString:@", "] forKey:@"allow"];
  }
  else {
    [self logWithFormat:@"ERROR: unexpected options result: %@ (class=%@)", 
	    _object, [_object class]];
  }
  return YES;
}

- (BOOL)renderSubscription:(id)_object inContext:(WOContext *)_ctx {
  // TODO: this is fake, mirrors request
  WOResponse *r = [_ctx response];
  WORequest  *rq;
  NSString   *callback;
  NSString   *notificationType;
  NSString   *lifetime;
  
  rq                = [_ctx request];
  callback          = [rq headerForKey:@"call-back"];
  notificationType  = [rq headerForKey:@"notification-type"];
  lifetime          = [rq headerForKey:@"subscription-lifetime"];
  
  [r setStatus:200 /* OK */];
  if (notificationType != nil)
    [r setHeader:notificationType forKey:@"notification-type"];
  if (lifetime != nil)
    [r setHeader:lifetime         forKey:@"subscription-lifetime"];
  if (callback != nil)
    [r setHeader:callback         forKey:@"callback"];
  [r setHeader:[self baseURLForContext:_ctx] forKey:@"content-location"];
  [r setHeader:_object forKey:@"subscription-id"];
  return YES;
}

- (BOOL)renderPropPatchResult:(id)_object inContext:(WOContext *)_ctx {
  NSMutableDictionary *extNameCache = nil;
  NSMutableDictionary *nsToPrefix   = nil;
  WOResponse *r = [_ctx response];
  
  if (_object == nil) return NO;
  
  nsToPrefix = [NSMutableDictionary dictionaryWithCapacity:16];
  [nsToPrefix setObject:@"D" forKey:XMLNS_WEBDAV];
  extNameCache = [NSMutableDictionary dictionaryWithCapacity:32];
  [self buildPrefixMapForAttributes:_object
	tagToExtName:extNameCache
	nsToPrefix:nsToPrefix];
  
  [r setStatus:207 /* multistatus */];
  [r setContentEncoding:NSUTF8StringEncoding];
  [r setHeader:@"text/xml; charset=\"utf-8\"" forKey:@"content-type"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
  [r appendContentString:@"<D:multistatus"];
  [r appendContentString:[self nsDeclsForMap:nsToPrefix]];
  [r appendContentString:@">"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [r appendContentString:@"<D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"<D:href>"];
  [r appendContentString:[[_ctx request] uri]];
  [r appendContentString:@"</D:href>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"<D:propstat>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"<D:prop>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  /* encode properties */
  {
    NSEnumerator *e;
    NSString *tag;
    
    e = [_object objectEnumerator];
    while ((tag = [e nextObject])) {
      NSString *extName;
      
      extName = [extNameCache objectForKey:tag];
      [r appendContentCharacter:'<'];
      [r appendContentString:extName];
      [r appendContentString:@"/>"];
      if (formatOutput) [r appendContentCharacter:'\n'];
    }
  }
  
  [r appendContentString:@"</D:prop>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"<D:status>HTTP/1.1 200 OK</D:status>"];
  [r appendContentString:@"</D:propstat></D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"</D:multistatus>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  return YES;
}

- (BOOL)renderDeleteResult:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  
  if (_object == nil || [_object boolValue]) {
    [r setStatus:204 /* no content */];
    //[r appendContentString:@"object was deleted."];
    return YES;
  }
  
  if ([_object isKindOfClass:[NSNumber class]]) {
    [r setStatus:[_object intValue]];
    if ([r status] != 204 /* No Content */)
      [r appendContentString:@"object could not be deleted."];
  }
  else {
    [r setStatus:500 /* server error */];
    [r appendContentString:@"object could not be deleted. reason: "];
    [r appendContentHTMLString:[_object stringValue]];
  }
  return YES;
}

- (BOOL)renderStatusResult:(id)_object withDefaultStatus:(int)_defStatus
  inContext:(WOContext *)_ctx 
{
  WOResponse *r = [_ctx response];
  
  if (_object == nil) {
    [r setStatus:_defStatus /* no content */];
    return YES;
  }
  
  if ([_object isKindOfClass:[NSNumber class]]) {
    if ([_object intValue] < 100) {
      [r setStatus:_defStatus /* no content */];
      return YES;
    }
    else {
      [r setStatus:[_object intValue]];
    }
  }
  else {
    [r setStatus:_defStatus /* no content */];
  }
  return YES;
}
- (BOOL)renderUploadResult:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  
  if (_object == nil) {
    [r setStatus:204 /* no content */];
    return YES;
  }
  
  if ([_object isKindOfClass:[NSNumber class]]) {
    if ([_object intValue] < 100) {
      [r setStatus:204 /* no content */];
      return YES;
    }
    
    [r setStatus:[_object intValue]];
    if ([_object intValue] >= 300) {
      [r setHeader:@"text/html" forKey:@"content-type"];
      [r appendContentString:@"object could not be stored."];
    }
    
    return YES;
  }
  
  [r setStatus:204 /* no content */];
  return YES;
}

- (void)renderPollList:(NSArray *)_sids code:(int)_code
  inContext:(WOContext *)_ctx 
{
  WOResponse   *r = [_ctx response];
  NSEnumerator *e;
  NSString *sid;
  NSString *href;
  
  if ([_sids count] == 0) return;
  href = [self baseURLForContext:_ctx];

  [r appendContentString:@"<D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"<D:href>"];
  [r appendContentString:href];
  [r appendContentString:@"</D:href>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [r appendContentString:@"<D:status>HTTP/1.1 "];
  if (_code == 200)
    [r appendContentString:@"200 OK"];
  else if (_code == 204)
    [r appendContentString:@"204 No Content"];
  else {
    NSString *s;
    s = [NSString stringWithFormat:@"%i code%i"];
    [r appendContentString:s];
  }
  [r appendContentString:@"</D:status>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  
  [r appendContentString:@"<E:subscriptionID>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  e = [_sids objectEnumerator];
  while ((sid = [e nextObject])) {
    if (formatOutput) [r appendContentString:@"  "];
    [r appendContentString:@"<li>"];
    [r appendContentString:sid];
    [r appendContentString:@"</li>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  [r appendContentString:@"</E:subscriptionID>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
  [r appendContentString:@"</D:response>"];
  if (formatOutput) [r appendContentCharacter:'\n'];
}

- (BOOL)renderPollResult:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  
  if (_object == nil) {
    [r setStatus:204 /* no content */];
    return YES;
  }

  if ([_object isKindOfClass:[NSDictionary class]]) {
    NSArray  *pending, *inactive;
    
    pending  = [(NSDictionary *)_object objectForKey:@"pending"];
    inactive = [(NSDictionary *)_object objectForKey:@"inactive"];
    
    [r setStatus:207 /* Multi-Status */];
    [r setContentEncoding:NSUTF8StringEncoding];
    [r setHeader:@"text/xml; charset=\"utf-8\"" forKey:@"content-type"];

    [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
    [r appendContentString:@"<D:multistatus "];
    [r appendContentString:@" xmlns:D=\"DAV:\""];
    [r appendContentString:
         @" xmlns:E=\"http://schemas.microsoft.com/Exchange/\""];
    [r appendContentString:@">"];
    if (formatOutput) [r appendContentCharacter:'\n'];
    
    [self renderPollList:pending  code:200 inContext:_ctx];
    [self renderPollList:inactive code:204 inContext:_ctx];
    
    [r appendContentString:@"</D:multistatus>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  else if ([_object isKindOfClass:[NSArray class]]) {
    [r setStatus:207 /* Multi-Status */];
    [r setContentEncoding:NSUTF8StringEncoding];
    [r setHeader:@"text/xml; charset=\"utf-8\"" forKey:@"content-type"];

    [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
    [r appendContentString:@"<D:multistatus "];
    [r appendContentString:@" xmlns:D=\"DAV:\""];
    [r appendContentString:
         @" xmlns:E=\"http://schemas.microsoft.com/Exchange/\""];
    [r appendContentString:@">"];
    if (formatOutput) [r appendContentCharacter:'\n'];
    
    [self renderPollList:_object code:200 inContext:_ctx];
    
    [r appendContentString:@"</D:multistatus>"];
    if (formatOutput) [r appendContentCharacter:'\n'];
  }
  else {
    [r setStatus:204 /* no content */];
    //[r appendContentString:@"object was stored."];
  }
  return YES;
}

- (BOOL)renderMkColResult:(id)_object inContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  
  if (_object == nil || [_object boolValue]) {
    [r setStatus:201 /* Created */];
    return YES;
  }
  
  if ([_object isKindOfClass:[NSNumber class]]) {
    [r setStatus:[_object intValue]];
    [r appendContentString:@"object could not be created."];
  }
  else {
    [r setStatus:500 /* server error */];
    [r appendContentString:@"object could not be deleted. reason: "];
    [r appendContentHTMLString:[_object stringValue]];
  }
  return YES;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoWebDAVRenderer */
