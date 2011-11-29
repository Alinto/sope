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

#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOCookie.h>
#include <NGExtensions/NSData+gzip.h>
#import <EOControl/EOControl.h>
#include "common.h"

@implementation WOResponse

static Class         NSStringClass = Nil;
static unsigned char OWDefaultZipLevel = 3;
static unsigned int  OWMinimumZipSize  = 1024;
static BOOL          dontZip  = NO;
static BOOL          debugZip = NO;

+ (int)version {
  return [super version] + 1 /* v6 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  NSAssert2([super version] == 5,
	    @"invalid superclass (%@) version %i !",
	    NSStringFromClass([self superclass]), [super version]);
  
  dontZip  = [ud boolForKey:@"WODontZipResponse"];
  debugZip = [ud boolForKey:@"WODebugZipResponse"];
}

+ (WOResponse *)responseWithRequest:(WORequest *)_request {
  return [[(WOResponse *)[self alloc] initWithRequest:_request] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    [self setStatus:200];
    [self setHTTPVersion:@"HTTP/1.1"];
    //[self setHeader:@"text/html" forKey:@"content-type"];
  }
  return self;
}

- (id)initWithRequest:(WORequest *)_request {
  if ((self = [self init])) {
    // don't fake being the request protocol, but rather stay to the truth ;-)
    // [self setHTTPVersion:[_request httpVersion]];
  }
  return self;
}

/* HTTP */

- (void)setStatus:(unsigned int)_status {
  self->status = _status;
}
- (unsigned int)status {
  return self->status;
}

/* client caching */

static __inline__ char *weekdayName(int dow) {
  switch (dow) {
    case 0: return "Sun"; case 1: return "Mon"; case 2: return "Tue";
    case 3: return "Wed"; case 4: return "Thu"; case 5: return "Fri";
    case 6: return "Sat"; case 7: return "Sun";
    default: return "UNKNOWN DAY OF WEEK !";
  }
}
static __inline__ char *monthName(int m) {
  switch (m) {
    case  1:  return "Jan"; case  2:  return "Feb"; case  3:  return "Mar";
    case  4:  return "Apr"; case  5:  return "May"; case  6:  return "Jun";
    case  7:  return "Jul"; case  8:  return "Aug"; case  9:  return "Sep";
    case 10:  return "Oct"; case 11:  return "Nov"; case 12:  return "Dec";
    default: return "UNKNOWN MONTH !";
  }
}

- (void)disableClientCaching {
  /*
    OSX Prof: 7.1% of WOSession -appendToResponse !
  */
  /* HTTP/1.1 caching directive, prevents browser from caching dynamic pages */
  static NSTimeZone *gmt = nil;
  
  if (gmt == nil) gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
#if DEBUG && 0
  [self logWithFormat:@"disabled client caching: %@ ..", self];
#endif
  
  /*
    Set expire time to one hour before now to catch inconsitencies between
    client and server time. Not using -description of NSCalendarDate to
    avoid locales and to improve performance.
  */
  {
    NSCalendarDate *now;
    NSString *s;
    char buf[32];
    
    now = [[NSCalendarDate alloc] initWithTimeIntervalSinceNow:-3600.0];
    [now setTimeZone:gmt];
    
    sprintf(buf,
#if GS_64BIT_OLD
            "%s, %02i %s %04i %02i:%02i:%02i GMT",
#else
            "%s, %02li %s %04li %02li:%02li:%02li GMT",
#endif
            weekdayName([now dayOfWeek]),
            [now dayOfMonth], 
            monthName([now monthOfYear]),
            [now yearOfCommonEra],
            [now hourOfDay], [now minuteOfHour], [now secondOfMinute]);
    [now release];
    
    s = [[NSString alloc] initWithCString:buf];
    [self setHeader:s forKey:@"expires"];
    [s release];
  }
  [self setHeader:@"no-cache" forKey:@"cache-control"];
  [self setHeader:@"no-cache" forKey:@"pragma"];
}

/* WO methods */

- (NSString *)contentString {
  NSString *s;
  
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  s = [[NSStringClass alloc] initWithData:[self content]
                             encoding:[self contentEncoding]];
  return [s autorelease];
}

/* WOActionResults */

- (WOResponse *)generateResponse {
  return self;
}

/* zipping */

- (BOOL)shouldZipResponseToRequest:(WORequest *)_rq {
  NSString *contentType;
  NSString *acceptEncoding;
  id       body;
  
  if (dontZip) {
    if (debugZip) [self logWithFormat:@"Zipping of response disabled"];
    return NO;
  }
  
  if ((body = [self content]) == nil)  
    return NO;
  if (![body isKindOfClass:[NSData class]])
    return NO;
  if ([body length] < OWMinimumZipSize) {
    if (debugZip) {
      [self logWithFormat:
	      @"content length is below minimum size for zipping (%i vs %i)",
	      [body length], OWMinimumZipSize];
    }
    return NO;
  }
  
  contentType = [self headerForKey:@"content-type"];
  
  if ([self headerForKey:@"content-encoding"] != nil) {
    /* already applied some content-encoding */
    if (debugZip)
      [self logWithFormat:@"Do not zip, already has a 'content-encoding'!"];
    return NO;
  }
  if ([contentType hasPrefix:@"application"]) {
    /* browser often seem to have problems with zipped bodies */
    if (debugZip)
      [self logWithFormat:@"Do not zip, is 'application/' MIME type."];
    return NO;
  }
  if ([contentType hasPrefix:@"image"]) {
    /* do not zip images (usually already compressed ...) */
    if (debugZip)
      [self logWithFormat:@"Do not zip, is an image."];
    return NO;
  }
  
  if (_rq == nil)
    return YES;
  
  acceptEncoding = [[_rq headerForKey:@"accept-encoding"] stringValue];
  if (acceptEncoding == nil) {
    if (debugZip) {
      [self logWithFormat:
	      @"Do not zip, browser sent no 'accept-encoding' header."];
    }
    return NO;
  }
  // TODO: improve naive parsing of accept header
  if ([acceptEncoding rangeOfString:@"gzip"].length == 0) {
    if (debugZip) {
      [self logWithFormat:
	      @"Do not zip, browser does not understand 'gzip' encoding: %@",
	      acceptEncoding];
    }
    return NO;
  }
  return YES;
}

- (NSData *)zipResponse {
  NSMutableDictionary *ui;
  NSNumber *zlen;
  NSData *zipped = nil;
  int    len;
  id     body;
  
  if ((body = [self content]) == nil) return nil;
  
  len = [body length];

  /* zip body data */
  
  if ((zipped = [body gzipWithLevel:OWDefaultZipLevel]) == nil) {
    if (debugZip)
      [self logWithFormat:@"gzip refused to zip body ..."];
    return body;
  }
  
  /* check if it's smaller */
  if ((int)[zipped length] >= len) {
    if (debugZip) {
      [self logWithFormat:
	      @"zipped length is larger than raw length (%i vs %i)",
	      [zipped length], len];
    }
    return body; /* it's not */
  }
  
  /* it is smaller .. */
      
  if (debugZip) {
    [self logWithFormat:
	    @"zipped content %i => %i bytes (gain: %-.2g%%).",
	    len, [zipped length],
            (double)(100.0 - (((double)[zipped length]) /
                              (((double)len) / 100.0)))];
  }
  
  body = zipped;
  [self setHeader:@"gzip" forKey:@"content-encoding"];

  /* statistics */
  
  if ((ui = [[self userInfo] mutableCopy]) == nil)
    ui = [[NSMutableDictionary alloc] initWithCapacity:2];
  
  [ui setObject:zipped forKey:@"WOZippedContent"];
  zlen = [NSNumber numberWithUnsignedInt:len];
  [ui setObject:zlen   forKey:@"WOResponseUnzippedLength"];
  zlen = [NSNumber numberWithUnsignedInt:[zipped length]];
  [ui setObject:zlen   forKey:@"WOResponseZippedLength"];
  
  [self setUserInfo:ui];
  [ui release]; ui = nil;
  [self setContent:zipped];
  
  return zipped;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  NSData *data;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  [ms appendFormat:@" status=%i",  [self status]];
  [ms appendFormat:@" headers=%@", [self headers]];

  if ((data = [self content])) {
    if ([data length] == 0)
      [ms appendString:@" empty-content"];
    else
      [ms appendFormat:@" content-size=%i", [data length]];
  }
  else
    [ms appendString:@" no-content"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* WOResponse */
