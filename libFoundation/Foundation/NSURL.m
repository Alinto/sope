/* 
   NSURL.m

   Copyright (C) 2000 MDlink GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/NSURL.h>
#include <Foundation/NSException.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include "common.h"

LF_DECLARE NSString *NSURLFileScheme = @"file";

/*
  I was just working with NSURL yesterday and I got it so that I can load
  the HTML of a web page.  Here is a simple example:

  - (void) getHTMLFromURL
  {
    NSURL *theURL;
    NSURLHandle *theURLHandle;
    NSData *theData;
    NSString *tempString;
    
    theURL = [NSURL URLWithString:@"http://www.apple.com/"];
    theURLHandle = [theURL URLHandleUsingCache:NO];
    
    theData = [theURLHandle resourceData];  // retrieves page HTML
    tempString = [[NSString alloc] initWithData:theData
                                   encoding:NSASCIIStringEncoding];
  }
*/

@interface _NSAbsoluteURL : NSURL
{
}
@end

@interface _NSAbsoluteHTTPURL : _NSAbsoluteURL
{
    NSString *path;
    NSString *host;
    NSString *fragment;
    NSString *query;
    NSString *login;
    NSString *password;
    unsigned port;
    BOOL     isSSL;
}

@end

@interface _NSAbsoluteFileURL : _NSAbsoluteURL
{
    NSString *path;
}
@end

@interface _NSAbsoluteMailToURL : _NSAbsoluteURL
{
    NSString *mailto;
}
@end

@interface _NSAbsoluteGenericURL : _NSAbsoluteURL
{
    NSString *scheme;
    NSString *path;
    NSString *host;
    NSString *fragment;
    NSString *query;
    NSString *login;
    NSString *password;
    unsigned port;
}
@end

@interface _NSRelativeURL : NSURL
{
    NSURL    *baseURL;
    NSString *relString;
    NSString *relPath;
    NSString *fragment;
    NSString *query;
}
@end

@interface NSURL(Privates)
- (NSString *)_pathForRelativeURL:(NSURL *)_relurl;
- (NSString *)_absoluteStringForRelativeURL:(NSURL *)_relurl;
@end

@implementation NSString(NSURLUtilities)

- (BOOL)isAbsoluteURL
{
    unsigned idx;
    unsigned i;
    
    if ([self hasPrefix:@"mailto:"])
        return YES;
    if ([self hasPrefix:@"javascript:"])
        return YES;
    
    if ((idx = [self indexOfString:@"://"]) == NSNotFound) {
        if ([self hasPrefix:@"file:"])
            return YES;
        return NO;
    }
    
    if ([self hasPrefix:@"/"])
        return NO;

    for (i = 0; i < idx; i++) {
        if (!isalpha([self characterAtIndex:i]))
            return NO;
    }
    return YES;
}

- (NSString *)urlScheme
{
    register unsigned i, count;
    register unichar c = 0;
    
    if ((count = [self length]) == 0)
        return nil;
    
    for (i = 0; i < count; i++) {
        c = [self characterAtIndex:i];
        
        if (!isalpha(c))
            break;
    }
    if ((c != ':') || (i < 1))
        return nil;
    
    return [self substringToIndex:i];
}

@end /* NSString(NSURLUtilities) */

@implementation NSURL

static NSMutableDictionary *schemeToURLClass = nil; // THREAD

static Class _NSAbsoluteURLClass = Nil;
static Class _NSRelativeURLClass = Nil;

+ (void)initialize
{
    if (_NSAbsoluteURLClass == Nil)
        _NSAbsoluteURLClass = [_NSAbsoluteURL class];
    if (_NSRelativeURLClass == Nil)
        _NSRelativeURLClass = [_NSRelativeURL class];
    
    if (schemeToURLClass == nil) {
        schemeToURLClass = [[NSMutableDictionary alloc] initWithCapacity:8];
        
        [schemeToURLClass setObject:[_NSAbsoluteFileURL class]
                          forKey:NSURLFileScheme];
        [schemeToURLClass setObject:[_NSAbsoluteHTTPURL class]
                          forKey:@"http"];
        [schemeToURLClass setObject:[_NSAbsoluteHTTPURL class]
                          forKey:@"httpu"];
        [schemeToURLClass setObject:[_NSAbsoluteMailToURL class]
                          forKey:@"mailto"];
    }
}

/* relative URLs */

- (NSURL *)_makeRelativeURLWithString:(NSString *)_str
{
    return [_NSRelativeURL URLWithString:_str relativeToURL:self];
}

+ (id)URLWithString:(NSString *)_str
{
    if ([_str length] == 0)
        /* empty URL */
        return nil;
    
    return [_NSAbsoluteURL URLWithString:_str];
}

+ (id)URLWithString:(NSString *)_str relativeToURL:(NSURL *)_base
{
    if (_base == nil)
        return [self URLWithString:_str];

    if ([_str length] == 0)
        return AUTORELEASE(RETAIN(_base));
    
    if ([_str isAbsoluteURL])
        return [self URLWithString:_str];
    
    return [_base _makeRelativeURLWithString:_str];
}

+ (id)fileURLWithPath:(NSString *)_path
{
    return [[[self alloc] initFileURLWithPath:_path] autorelease];
}

- (id)initFileURLWithPath:(NSString *)_path
{
    /* may need to transform path */
    return [self initWithScheme:NSURLFileScheme
                 host:nil
                 path:_path];
}

- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    if ([self class] != _NSAbsoluteURLClass) {
        Class clazz;
        
        RELEASE(self);
        
        if ((clazz = [schemeToURLClass objectForKey:_scheme]) == Nil)
            clazz = [_NSAbsoluteGenericURL class];
        
        return [[clazz alloc] initWithScheme:_scheme
                              host:_host
                              path:_path];
    }
    return self;
}

- (id)initWithString:(NSString *)_string relativeToURL:(NSURL *)_baseURL
{
    if ([self class] != _NSAbsoluteURLClass) {
        RELEASE(self);

        return [[NSURL URLWithString:_string relativeToURL:_baseURL] retain];
    }
    return self;
}
- (id)initWithString:(NSString *)_string
{
    return [self initWithString:_string relativeToURL:nil];
}

/* relative URLs */

- (NSURL *)baseURL
{
    return [self subclassResponsibility:_cmd];
}

- (NSString *)relativePath
{
    return [self path];
}
- (NSString *)relativeString
{
    return [self absoluteString];
}
- (NSString *)absoluteString
{
    return [self subclassResponsibility:_cmd];
}

- (NSString *)_pathForRelativeURL:(NSURL *)_relurl
{
    NSString *relPath;
    NSString *s;
    
    relPath = [_relurl relativePath];
    
    if ([relPath hasPrefix:@"/"]) {
	/* the relative URI has an absolute path */
        s = relPath;
    }
    else if ([relPath length] > 0) {
	/* the relative URI has some path */
	
        s = [self path];
	
	if ([self isFileURL]) {
	    /* auto-add trailing slash for directories ... */
	    NSFileManager *fm = [NSFileManager defaultManager];
	    BOOL isDir;
	    
	    if ([fm fileExistsAtPath:s isDirectory:&isDir]) {
		if (isDir) {
		    if (![s hasSuffix:@"/"]) 
			s = [s stringByAppendingString:@"/"];
		}
	    }
	}
	
	if ([s hasSuffix:@"/"]) {
	    /* base is a "folder" */
	    s = [s stringByAppendingString:relPath];
	}
	else {
	    NSRange r;
	    
	    r = [s rangeOfString:@"/" options:NSBackwardsSearch];
	    s = [s substringToIndex:(r.location + r.length)];
	    s = [s stringByAppendingString:relPath];
	}
    }
    else
	/* the relative URI has no path */
        s = [self path];
    
    return s;
}
- (NSString *)_absoluteStringForRelativeURL:(NSURL *)_relurl
{
    NSMutableString *ms;
    NSString *s;
    
    ms = [[NSMutableString alloc] initWithCapacity:100];
    
    [ms appendString:[_relurl scheme]];
    [ms appendString:@"://"];
    
    if ((s = [_relurl user])) {
        [ms appendString:s];
        if ((s = [_relurl password])) {
            [ms appendString:@":"];
            [ms appendString:s];
        }
        [ms appendString:@"@"];
    }
    
    if ((s = [_relurl host])) {
        NSNumber *n;
        
        [ms appendString:s];
        if ((n = [_relurl port])) {
            [ms appendString:@":"];
            [ms appendString:[n stringValue]];
        }
    }
    else if ((s = [self host])) {
        NSNumber *n;
        
        [ms appendString:s];
        if ((n = [self port])) {
            [ms appendString:@":"];
            [ms appendString:[n stringValue]];
        }
    }
    
    [ms appendString:[_relurl path]];
    
    if ((s = [_relurl fragment])) {
        [ms appendString:@"#"];
        [ms appendString:s];
    }
    if ((s = [_relurl query])) {
        [ms appendString:@"?"];
        [ms appendString:s];
    }
    
    s = [ms copy];
    RELEASE(ms);
    
    return AUTORELEASE(s);
}

/* properties */

- (NSString *)fragment
{
    return [self subclassResponsibility:_cmd];
}
- (NSString *)query
{
    return [self subclassResponsibility:_cmd];
}

- (NSString *)host
{
    return [self subclassResponsibility:_cmd];
}
- (NSString *)path
{
    return [self subclassResponsibility:_cmd];
}
- (NSString *)scheme
{
    return [self subclassResponsibility:_cmd];
}

- (NSNumber *)port
{
    return nil;
}
- (NSString *)user
{
    return nil;
}
- (NSString *)password
{
    return nil;
}

- (BOOL)isFileURL
{
    return [[self scheme] isEqualToString:NSURLFileScheme];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone
{
    /* NSURL's are immutable objects */
    return RETAIN(self);
}

/* equality */

- (unsigned)hash
{
    return [[self path] hash];
}
- (BOOL)isEqualToURL:(NSURL *)_other
{
    if (![[_other scheme] isEqualToString:[self scheme]])
        return NO;

    return [[_other absoluteString] isEqualToString:[self absoluteString]];
}
- (BOOL)isEqual:(id)_other
{
    if (_other == nil)
        return NO;
    if ([_other isKindOfClass:[NSURL class]])
        return [_other isEqualToURL:self];
    return NO;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder
{
}
- (id)initWithCoder:(NSCoder *)_decoder
{
    return [self subclassResponsibility:_cmd];
}

/* NSURLHandleClient */

- (void)URLHandleResourceDidBeginLoading:(NSURLHandle *)_handler
{
}
- (void)URLHandleResourceDidCancelLoading:(NSURLHandle *)_handler
{
}
- (void)URLHandleResourceDidFinishLoading:(NSURLHandle *)_handler
{
}

- (void)URLHandle:(NSURLHandle *)_handler
  resourceDataDidBecomeAvailable:(NSData *)_data
{
}
- (void)URLHandle:(NSURLHandle *)_handler
  resourceDidFailLoadingWithReason:(NSString *)_reason
{
}

/* fetching */

- (NSURLHandle *)URLHandleUsingCache:(BOOL)_useCache
{
    Class       handleClass;
    NSURLHandle *handle;
    
    if ((handleClass = [NSURLHandle URLHandleClassForURL:self]) == Nil) {
        NSLog(@"%s: missing handler for URL '%@'", __PRETTY_FUNCTION__, self);
        return nil;
    }
    
    handle = [[handleClass alloc] initWithURL:self cached:_useCache];
    if (handle == nil) {
        NSLog(@"%s: couldn't create handle of class %@ for URL '%@'",
              __PRETTY_FUNCTION__, handleClass, self);
        return nil;
    }
    
    return AUTORELEASE(handle);
}
- (void)loadResourceDataNotifyingClient:(id)_client usingCache:(BOOL)_useCache
{
    NSURLHandle *handle;
    
    NSAssert(self->currentClient == nil, @"already loading resource ..");
    self->currentClient = _client;
    
    handle = [self URLHandleUsingCache:_useCache];
    [handle addClient:self];
    [handle loadInBackground];
    [handle removeClient:self];
    
    self->currentClient = nil;
}

- (NSData *)resourceDataUsingCache:(BOOL)_useCache
{
    return [[self URLHandleUsingCache:_useCache] resourceData];
}

- (BOOL)setResourceData:(NSData *)_data
{
    NSURLHandle *handle;
    
    if ((handle = [self URLHandleUsingCache:YES]) == nil)
        return NO;
    
    return [handle writeData:_data];
}

/* description */

- (NSString *)stringValue
{
    return [self absoluteString];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ 0x%08x: '%@'>",
                       NSStringFromClass([self class]), self,
                       [self absoluteString]];
}

@end /* NSURL */

@implementation _NSAbsoluteURL

+ (id)URLWithString:(NSString *)_str
{
    NSString *scheme;
    Class clazz;
    
    if ([_str length] == 0) {
        /* empty URL */
#if 0
        NSLog(@"%s: passed empty string", __PRETTY_FUNCTION__);
#endif
        return nil;
    }

    if ((scheme = [_str urlScheme]) == nil) {
        /* missing URL scheme .. */
        if ([_str hasPrefix:@"/"]) {
            return [[[_NSAbsoluteFileURL alloc]
                                         initWithScheme:@"file"
                                         host:nil
                                         path:_str]
                                         autorelease];
        }
        
#if 0
        NSLog(@"%s: missing URL scheme in string '%@'",
              __PRETTY_FUNCTION__, _str);
#endif
        return nil;
    }
    
    if ((clazz = [schemeToURLClass objectForKey:scheme]) == Nil)
        clazz = [_NSAbsoluteGenericURL class];
    
    return [clazz URLWithString:_str];
}

- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

/* stuff for relative URLs */

- (NSURL *)baseURL
{
    return nil;
}
- (NSString *)relativePath
{
    return [self path];
}
- (NSString *)relativeString
{
    return [self absoluteString];
}
- (NSString *)absoluteString
{
    NSMutableString *ms;
    NSString *s;
    
    ms = [[NSMutableString alloc] initWithCapacity:100];
    
    [ms appendString:[self scheme]];
    [ms appendString:@"://"];

    if ((s = [self user])) {
        [ms appendString:s];
        if ((s = [self password])) {
            [ms appendString:@":"];
            [ms appendString:s];
        }
        [ms appendString:@"@"];
    }
    
    if ((s = [self host])) {
        NSNumber *n;
        
        [ms appendString:s];
        if ((n = [self port])) {
            [ms appendString:@":"];
            [ms appendString:[n stringValue]];
        }
    }
    
    [ms appendString:[self path]];
    
    if ((s = [self fragment])) {
        [ms appendString:@"#"];
        [ms appendString:s];
    }
    if ((s = [self query])) {
        [ms appendString:@"?"];
        [ms appendString:s];
    }
    
    s = [ms copy];
    RELEASE(ms);
    return AUTORELEASE(s);
}

/* properties */

- (NSString *)fragment
{
    return nil;
}
- (NSString *)query
{
    return nil;
}
- (NSString *)host
{
    return nil;
}
- (NSString *)path
{
    return nil;
}
- (NSString *)scheme
{
    return nil;
}

- (NSString *)user
{
    return nil;
}
- (NSString *)password
{
    return nil;
}
- (NSNumber *)port
{
    return nil;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder
{
    [_coder encodeObject:[self absoluteString]];
}
- (id)initWithCoder:(NSCoder *)_decoder
{
    NSString *as;
    
    as = [_decoder decodeObject];
    RELEASE(self);
    return RETAIN([[self class] URLWithString:as]);
}

@end /* _NSAbsoluteURL */

@implementation _NSAbsoluteHTTPURL

/*
  HTTP Urls:

    httpaddress : 'http://' { loginpwd '@' } 
                  hostport { '/' path } { '?' search }
    loginpwd    : login { ':' pwd }
    hostport    : hostname { ':' port }
    login       : alpha ( xalpha )*
    pwd         : alpha ( xalpha )*
    hostname    : alpha ( xalpha )*
    port        : ( digit )+
    path        : void | (xpalpha)+ { '/' path }
    search      : ( xalpha )+ { '+' search }
    xalpha      : alpha | digit | safe | extra | escape
    xpalpha     : xalpha | +

  Description:
  
    Xpalpha are chars that can occure in a path. Notably this includes the
    '+' char which has a different meaning the search part, where the plus
    separated the search components.

  Examples:

    http://www.mdlink.de/search.cgi?hallo=23&
*/

+ (id)URLWithString:(NSString *)_str
{
    unsigned char *urlbuf, *buf, *cur, *tmp;
    unsigned len, idx;
    NSString *uscheme = nil, *hostName = nil, *ulogin = nil, *pwd = nil;
    unsigned uport = 0;
    NSString *upath = nil, *ufrag = nil, *uquery = nil;
    _NSAbsoluteHTTPURL *url;
    
    if (![_str hasPrefix:@"http://"] && 
        ![_str hasPrefix:@"https://"] &&
        ![_str hasPrefix:@"httpu://"])
        return nil;
    
    // TODO: use UTF-8?
    len    = [_str cStringLength];
    urlbuf = calloc(len + 4 /* required for peek! */, sizeof(unsigned char));
    [_str getCString:(char *)urlbuf]; urlbuf[len] = '\0';
    cur = urlbuf;
    
    buf = malloc(len + 4);
    
    /* scan scheme */
    
    for (idx = 0, buf[idx] = '\0'; (idx<len) && (*cur != '\0'); idx++,cur++) {
        if ((cur[0] == ':') && (cur[1] == '/') && (cur[2] == '/')) {
	    buf[idx] = '\0';
            uscheme = [NSString stringWithCString:(char *)buf length:idx];
            idx = 0;
            cur += 3; // skip '://'
            break; // leave loop
        }
        buf[idx] = *cur;
    }
    if (*cur == '\0') goto done;

    //NSLog(@"after scheme %@, CUR: '%s'", uscheme, cur);
    
    /* scan login/password */
    
    if ((tmp = (unsigned char *)index((char *)cur, '@')) != NULL) {
	/* avoid issues with this: '/localhost/user@blah/' */
	if ((unsigned char *)tmp < (unsigned char *)index((char *)cur, '/')) {
	    /* donald:duck@localhost:13 */
	    unsigned char *s;
	    BOOL foundColon = NO;
	
	    pwd = @"";
	    buf[idx] = '\0';
	    for (idx = 0, s = cur; s < tmp; s++) {
		if (*s == ':') {
		    /* next is pwd */
		    buf[idx] = '\0';
		    ulogin = [NSString stringWithCString:(char *)buf
				       length:idx];
		    idx = 0;
		    foundColon = YES;
		}
		else if (*s == '@') {
		    /* found end marker */
		    break;
		}
		else {
		    buf[idx] = *s;
		    idx++;
		}
	    }
	    if (foundColon) {
		buf[idx] = '\0';
		pwd = [NSString stringWithCString:(char *)buf length:idx];
	    }
	    if (*s == '@') s++;
	    cur = s;
	}
    }
    if (*cur == '\0') goto done;

    //NSLog(@"after login %@/pwd %@, CUR: '%s'", ulogin, pwd, cur);
    
    /* scan hostname & port */
    
    for (idx = 0, buf[idx] = '\0'; YES; idx++, cur++) {
        if (*cur == ':') {
            /* found host/port breakup (eg myhost:80) */
            buf[idx] = '\0';
            hostName = [NSString stringWithCString:(char *)buf length:idx];
            
            idx = 0;
            cur++; // skip ':'
            
            /* parse port number */
            uport = 0;
            while (isdigit(*cur) && (*cur != '\0')) {
                uport *= 10;
                uport += *cur - '0';
                cur++;
            }
            
            break;
        }
        else if ((*cur == '/') || (*cur == '\0')) {
            /* reached end of host/port combo */
            buf[idx] = '\0';
            hostName = [NSString stringWithCString:(char *)buf length:idx];
            uport    = 0;
            
            break;
        }
        else {
            /* continue */
            buf[idx] = *cur;
        }
    }
    if (*cur == '\0') goto done;
    
    /* scan path */
    
    for (idx = 0, buf[idx] = '\0'; YES; idx++, cur++) {
        if (*cur == '#') {
            /* found fragment */
            buf[idx] = '\0';
            upath  = [NSString stringWithCString:(char *)buf length:idx];

            /* parse fragment */
            cur++; // skip '#'
            for (idx = 0, buf[idx] = '\0'; (*cur != '?' && *cur != '\0');
                 idx++, cur++) {
                buf[idx] = *cur;
            }
            ufrag = [NSString stringWithCString:(char *)buf length:idx];

            if (*cur == '?') {
                /* parse query */
                cur++; // skip '?'
                uquery = [NSString stringWithCString:(char *)cur];
            }
            
            break;
        }
        else if (*cur == '?') {
            /* found query */
            buf[idx] = '\0';
            upath = [NSString stringWithCString:(char *)buf length:idx];
            ufrag = nil;
            
            /* parse query */
            cur++; // skip '?'
            uquery = [NSString stringWithCString:(char *)cur];
            break;
        }
        else if (*cur == '\0') {
            /* found end */
            buf[idx] = '\0';
            upath  = [NSString stringWithCString:(char *)buf length:idx];
            ufrag  = nil;
            uquery = nil;
            break;
        }
        buf[idx] = *cur;
    }
    if (*cur == '\0') goto done;
    
 done:
    if (buf)    free(buf);
    if (urlbuf) free(urlbuf);
    
    /* resolve '..' and '.' in path */
    if ((upath != nil) && [upath indexOfString:@".."] != NSNotFound) {
        NSArray *pc;
        NSMutableArray *nc;
        unsigned i, count;
        
        pc    = [upath pathComponents];
        count = [pc count];
        nc    = [NSMutableArray arrayWithCapacity:count];

        for (i = 0; i < count; i++) {
            NSString *pcc;
            
            pcc = [pc objectAtIndex:i];
            if ([pcc isEqualToString:@".."]) {
                unsigned ncount;
                
                if ((ncount = [nc count]) > 0)
                    [nc removeObjectAtIndex:(ncount - 1)];
                else
                    /* invalid absolute path .. */
                    [nc addObject:pcc];
            }
            else if ([pcc isEqualToString:@"."]) {
                /* do not add '.' */
            }
            else
                [nc addObject:pcc];
        }
    }
    
    if (upath == nil)
        upath = @"/";
    
    url = [[_NSAbsoluteHTTPURL alloc] initWithScheme:uscheme
                                      host:hostName
                                      path:upath];
    url->port     = uport > 0 ? uport : 80;
    url->fragment = [ufrag  copy];
    url->query    = [uquery copy];
    url->login    = [ulogin copy];
    url->password = [pwd    copy];
    
    return AUTORELEASE(url);
}

- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    if ([_scheme isEqualToString:@"https"]) {
	self->isSSL = YES;
    }
    else if (![_scheme hasPrefix:@"http"]) {
        RELEASE(self);
        return nil;
    }
    
    if ((self = [super initWithScheme:_scheme host:_host path:_path])) {
        self->host = [_host copy];
        self->path = [_path length] > 0 ? [_path copy] : (id)@"/";
    }
    return self;
}

- (void)dealloc
{
    RELEASE(self->login);
    RELEASE(self->password);
    RELEASE(self->fragment);
    RELEASE(self->query);
    RELEASE(self->path);
    RELEASE(self->host);
    [super dealloc];
}

/* component accessors */

- (NSNumber *)port
{
    return self->port > 0
	? [NSNumber numberWithUnsignedInt:self->port]
	: (NSNumber *)nil;
}

- (NSString *)fragment
{
    return self->fragment;
}
- (NSString *)query
{
    return self->query;
}
- (NSString *)host
{
    return self->host;
}
- (NSString *)path
{
    return self->path;
}
- (NSString *)scheme
{
    return self->isSSL ? @"https" : @"http";
}
- (NSString *)user
{
    return self->login;
}
- (NSString *)password
{
    return self->password;
}

@end /* _NSAbsoluteHTTPURL */

@implementation _NSAbsoluteGenericURL

+ (id)URLWithString:(NSString *)_str
{
    // TODO: UNICODE, based on cString
    // TODO: does not properly parse login/pwd! (eg for IMAP4 URLs)
    unsigned char *urlbuf, *buf, *cur;
    unsigned len, idx;
    NSString *uscheme, *hostName;
    unsigned uport;
    NSString *upath, *ufrag, *uquery, *ulogin, *upwd;
    NSRange  r;
    _NSAbsoluteGenericURL *url;
    
    uscheme  = nil;
    hostName = nil;
    uport    = 0;
    upath    = nil;
    ufrag    = nil;
    uquery   = nil;
    
    len    = [_str cStringLength];
    urlbuf = calloc(len + 4, sizeof(unsigned char));
    [_str getCString:(char *)urlbuf]; urlbuf[len] = '\0';
    cur = urlbuf;
    
    buf = malloc(len + 1);
    
    /* scan scheme */
    
    for (idx = 0, buf[idx] = '\0'; (idx<len) && (*cur != '\0'); idx++, cur++) {
        if ((cur[0] == ':') && (cur[1] == '/') && (cur[2] == '/')) {
	    buf[idx] = '\0';
            uscheme = [NSString stringWithCString:(char *)buf length:idx];
            idx = 0;
            cur += 3; // skip '://'
            break; // leave loop
        }
        buf[idx] = *cur;
    }
    if (*cur == '\0') goto done;
    
    /* scan hostname & port */
    
    for (idx = 0, buf[idx] = '\0'; YES; idx++, cur++) {
        if (*cur == ':') {
            /* found host/port breakup (eg myhost:80) */
            buf[idx] = '\0';
            hostName = [NSString stringWithCString:(char *)buf length:idx];
            
            idx = 0;
            cur++; // skip ':'
            
            /* parse port number */
            uport = 0;
            while (isdigit(*cur) && (*cur != '\0')) {
                uport *= 10;
                uport += *cur - '0';
                cur++;
            }
            
            break;
        }
        else if ((*cur == '/') || (*cur == '\0')) {
            /* reached end of host/port combo */
            buf[idx] = '\0';
            hostName = [NSString stringWithCString:(char *)buf length:idx];
            uport    = 0;
            
            break;
        }
        else {
            /* continue */
            buf[idx] = *cur;
        }
    }
    if (*cur == '\0') goto done;
    
    /* scan path */
    
    for (idx = 0, buf[idx] = '\0'; YES; idx++, cur++) {
        if (*cur == '#') {
            /* found fragment */
            buf[idx] = '\0';
            upath  = [NSString stringWithCString:(char *)buf length:idx];

            /* parse fragment */
            cur++; // skip '#'
            for (idx = 0, buf[idx] = '\0'; (*cur != '?' && *cur != '\0');
                 idx++, cur++) {
                buf[idx] = *cur;
            }
            ufrag = [NSString stringWithCString:(char *)buf length:idx];

            if (*cur == '?') {
                /* parse query */
                cur++; // skip '?'
                uquery = [NSString stringWithCString:(char *)cur];
            }
            
            break;
        }
        else if (*cur == '?') {
            /* found query */
            buf[idx] = '\0';
            upath = [NSString stringWithCString:(char *)buf length:idx];
            ufrag = nil;
            
            /* parse query */
            cur++; // skip '?'
            uquery = [NSString stringWithCString:(char *)cur];
            break;
        }
        else if (*cur == '\0') {
            /* found end */
            buf[idx] = '\0';
            upath  = [NSString stringWithCString:(char *)buf length:idx];
            ufrag  = nil;
            uquery = nil;
            break;
        }
        buf[idx] = *cur;
    }
    if (*cur == '\0') goto done;
    
 done:
    if (buf)    free(buf);
    if (urlbuf) free(urlbuf);
    
    /* resolve '..' and '.' in path */
    if ((upath != nil) && [upath indexOfString:@".."] != NSNotFound) {
        NSArray *pc;
        NSMutableArray *nc;
        unsigned i, count;
        
        pc    = [upath pathComponents];
        count = [pc count];
        nc    = [NSMutableArray arrayWithCapacity:count];

        for (i = 0; i < count; i++) {
            NSString *pcc;
            
            pcc = [pc objectAtIndex:i];
            if ([pcc isEqualToString:@".."]) {
                unsigned ncount;
                
                if ((ncount = [nc count]) > 0)
                    [nc removeObjectAtIndex:(ncount - 1)];
                else
                    /* invalid absolute path .. */
                    [nc addObject:pcc];
            }
            else if ([pcc isEqualToString:@"."]) {
                /* do not add '.' */
            }
            else
                [nc addObject:pcc];
        }
    }
    
    if (upath == nil)
        upath = @"/";
    
    /* extract login/password */
    
    ulogin = nil;
    upwd   = nil;
    r = [hostName rangeOfString:@"@"];
    if (r.length > 0) {
	ulogin   = [hostName substringToIndex:r.location];
	hostName = [hostName substringFromIndex:(r.location + r.length)];

	r = [ulogin rangeOfString:@":"];
	if (r.length > 0) {
	    upwd   = [ulogin substringToIndex:r.location];
	    ulogin = [ulogin substringFromIndex:(r.location + r.length)];
	}
    }
    
    /* create object */
    
    url = [[_NSAbsoluteGenericURL alloc] initWithScheme:uscheme
                                         host:hostName
                                         path:upath];
    url->port     = uport > 0 ? uport : 0;
    url->fragment = [ufrag  copy];
    url->query    = [uquery copy];
    url->login    = [ulogin copy];
    url->password = [upwd   copy];
    
    return AUTORELEASE(url);
}

- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    if ((self = [super initWithScheme:_scheme host:_host path:_path])) {
        self->scheme = [_scheme copy];
        self->host   = [_host copy];
        self->path   = [_path length] > 0 ? [_path copy] : (id)@"/";
    }
    return self;
}

- (void)dealloc
{
    RELEASE(self->login);
    RELEASE(self->password);
    RELEASE(self->scheme);
    RELEASE(self->fragment);
    RELEASE(self->query);
    RELEASE(self->path);
    RELEASE(self->host);
    [super dealloc];
}

/* component accessors */

- (NSNumber *)port
{
    return self->port > 0
	? [NSNumber numberWithUnsignedInt:self->port]
	: (NSNumber *)nil;
}

- (NSString *)fragment
{
    return self->fragment;
}
- (NSString *)query
{
    return self->query;
}
- (NSString *)host
{
    return self->host;
}
- (NSString *)path
{
    return self->path;
}
- (NSString *)scheme
{
    return self->scheme;
}
- (NSString *)user
{
    return self->login;
}
- (NSString *)password
{
    return self->password;
}

@end /* _NSAbsoluteGenericURL */

@implementation _NSAbsoluteFileURL

+ (id)URLWithString:(NSString *)_str
{
    NSURL    *url;
    NSString *ps;
    
    if (![_str hasPrefix:@"file:"]) {
        NSLog(@"%s: string is not a file URL '%@'", __PRETTY_FUNCTION__, _str);
        return nil;
    }
    
    ps = [_str substringFromIndex:5];
    if ([ps length] == 0) {
        NSLog(@"ERROR: missing path in URL '%@' !", _str);
        return nil;
    }
    
    if ([ps hasPrefix:@"//"])
        ps = [ps substringFromIndex:2];
    if ([ps length] == 0)
        ps = @"/";
    
    url = [[self alloc] initWithScheme:@"file"
                        host:nil
                        path:ps];
    return AUTORELEASE(url);
}

- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    if (![_scheme isEqualToString:@"file"]) {
        RELEASE(self);
        return nil;
    }
    
    if ((self = [super initWithScheme:_scheme host:_host path:_path])) {
        if (![_path isAbsolutePath]) {
            _path = [[[NSFileManager defaultManager] currentDirectoryPath]
                                     stringByAppendingPathComponent:_path];
        }
        self->path = [[_path stringByStandardizingPath] copy];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(self->path);
    [super dealloc];
}

/* component accessors */

- (NSString *)path
{
    return self->path;
}
- (NSString *)scheme
{
    return @"file";
}

- (NSString *)absoluteString
{
    NSMutableString *ms;
    NSString *s;
    
    ms = [[NSMutableString alloc] initWithCapacity:100];
    
    [ms appendString:[self scheme]];
    [ms appendString:@"://"];
    [ms appendString:[self path]];

    s = [ms copy];
    RELEASE(ms);
    return AUTORELEASE(s);
}

@end /* _NSAbsoluteFileURL */

@implementation _NSAbsoluteMailToURL

+ (id)URLWithString:(NSString *)_str
{
    NSURL    *url;
    NSString *ps;
    
    if (![_str hasPrefix:@"mailto:"]) {
        NSLog(@"%s: string is not a file URL '%@'", __PRETTY_FUNCTION__, _str);
        return nil;
    }
    
    ps = [_str substringFromIndex:7];
    if ([ps length] == 0) {
        NSLog(@"ERROR: missing address in URL '%@' !", _str);
        return nil;
    }
    
    url = [[self alloc] initWithScheme:@"mailto"
                        host:nil
                        path:ps];
    return AUTORELEASE(url);
}
- (id)initWithScheme:(NSString *)_scheme
  host:(NSString *)_host
  path:(NSString *)_path
{
    if (![_scheme isEqualToString:@"mailto"]) {
        RELEASE(self);
        return nil;
    }

    self->mailto = [_path copy];
    return self;
}

- (void)dealloc
{
    RELEASE(self->mailto);
    [super dealloc];
}

- (NSString *)path
{
    return self->mailto;
}
- (NSString *)scheme
{
    return @"mailto";
}
- (NSString *)absoluteString
{
    return [@"mailto:" stringByAppendingString:[self path]];
}

@end /* _NSAbsoluteMailToURL */

@implementation _NSRelativeURL

+ (id)URLWithString:(NSString *)_str relativeToURL:(NSURL *)_base
{
    if ([_str length] == 0)
        return AUTORELEASE(RETAIN(_base));
    
    return AUTORELEASE([[self alloc] initWithString:_str relativeToURL:_base]);
}

- (id)initWithString:(NSString *)_string relativeToURL:(NSURL *)_baseURL
{
    unsigned fidx, qidx;
    
    self->baseURL   = RETAIN(_baseURL);
    self->relString = [_string  copy];
    
    fidx = [self->relString indexOfString:@"#"];
    qidx = [self->relString indexOfString:@"?"];

    if ((fidx == NSNotFound) && (qidx == NSNotFound)) {
        /* no query and fragment components */
        self->relPath = RETAIN(self->relString);
    }
    else if (fidx == NSNotFound) {
        /* query component */
        self->relPath = [[self->relString substringToIndex:qidx] copy];
        self->query   = [[self->relString substringFromIndex:(qidx + 1)] copy];
    }
    else if (qidx == NSNotFound) {
        /* fragment component */
        self->relPath  = [[self->relString substringToIndex:fidx] copy];
        self->fragment = [[self->relString substringFromIndex:(fidx + 1)] copy];
    }
    else {
        /* both, query and fragment components */
        self->relPath = [[self->relString substringToIndex:fidx] copy];
        
        if (fidx > qidx) {
            /* hm, invalid URL ! (query must follow fragment !) */
            self->fragment =
                [[self->relString substringFromIndex:(fidx + 1)] copy];
        }
        else {
            self->fragment = [[[self->relString substringToIndex:qidx]
                                                substringFromIndex:fidx]
                                                copy];
            
            self->query = [[self->relString substringFromIndex:(qidx + 1)] copy];
        }
    }
    
    return self;
}

- (void)dealloc
{
    RELEASE(self->fragment);
    RELEASE(self->query);
    RELEASE(self->relPath);
    RELEASE(self->relString);
    RELEASE(self->baseURL);
    [super dealloc];
}

/* stuff for relative URLs */

- (NSURL *)baseURL
{
    return self->baseURL;
}

- (NSString *)relativePath
{
    /* may need to strip fragments&queries */
    return self->relPath;
}
- (NSString *)relativeString
{
    return self->relString;
}

- (NSString *)absoluteString
{
    return [[self baseURL] _absoluteStringForRelativeURL:self];
}

/* properties */

- (NSString *)fragment
{
    return self->fragment;
}
- (NSString *)query
{
    return self->query;
}
- (NSString *)host
{
    return [[self baseURL] host];
}
- (NSString *)path
{
    return [[self baseURL] _pathForRelativeURL:self];
}
- (NSString *)scheme
{
    return [[self baseURL] scheme];
}
- (NSNumber *)port
{
    return [[self baseURL] port];
}

- (BOOL)isFileURL
{
    return [[self baseURL] isFileURL];
}

- (NSString *)user
{
    return [[self baseURL] user];
}
- (NSString *)password
{
    return [[self baseURL] password];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder
{
    [_coder encodeObject:[self baseURL]];
    [_coder encodeObject:[self relativeString]];
    [self notImplemented:_cmd];
}
- (id)initWithCoder:(NSCoder *)_decoder
{
    NSURL    *ibase;
    NSString *istring;

    ibase   = [_decoder decodeObject];
    istring = [_decoder decodeObject];
    [self notImplemented:_cmd];

    return [self initWithString:istring relativeToURL:ibase];
}

/* description */

- (NSString *)description
{
    return [NSString stringWithFormat:
                       @"<%@ 0x%08x: abs='%@',rel='%@' relative to %@>",
                       NSStringFromClass([self class]), self,
                       [self absoluteString], [self relativeString],
                       [self baseURL]];
}

@end /* _NSRelativeURL */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
