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

#include "NSString+Ext.h"
#include "common.h"
#include <ctype.h>

@implementation NSString(GSAdditions)

- (NSString *)stringWithoutPrefix:(NSString *)_prefix
{
    return ([self hasPrefix:_prefix])
        ? [self substringFromIndex:[_prefix length]]
        : (NSString *)[[self copy] autorelease];
}

- (NSString *)stringWithoutSuffix:(NSString *)_suffix
{
    return ([self hasSuffix:_suffix])
        ? [self substringToIndex:([self length] - [_suffix length])]
        : (NSString *)[[self copy] autorelease];
}

- (NSString *)stringByTrimmingLeadWhiteSpaces
{
    // should check 'whitespaceAndNewlineCharacterSet' ..
    unsigned len;
    
    if ((len = [self length]) > 0) {
        unichar  *buf;
        unsigned idx;
        
        buf = calloc(len + 1, sizeof(unichar));
        [self getCharacters:buf];
        
        for (idx = 0; (idx < len) && (buf[idx] == 32); idx++)
            ;
        
        self = [NSString stringWithCharacters:&(buf[idx]) length:(len - idx)];
        free(buf);
        return self;
    }
    else
        return [[self copy] autorelease];
}
- (NSString *)stringByTrimmingTailWhiteSpaces
{
    // should check 'whitespaceAndNewlineCharacterSet' ..
    unsigned len;
    
    if ((len = [self length]) > 0) {
        unichar  *buf;
        unsigned idx;
        
        buf = calloc(len + 1, sizeof(unichar));
        [self getCharacters:buf];

        for (idx = (len - 1); (idx >= 0) && (buf[idx] == 32); idx--)
            ;
        
        self = [NSString stringWithCharacters:buf length:(idx + 1)];
        free(buf);
        return self;
    }
    else
        return [[self copy] autorelease];
}

- (NSString *)stringByTrimmingWhiteSpaces
{
    return [[self stringByTrimmingTailWhiteSpaces]
                  stringByTrimmingLeadWhiteSpaces];
}

#ifndef GNUSTEP
- (NSString *)stringByReplacingString:(NSString *)_orignal
  withString:(NSString *)_replacement
{
    /* very slow solution .. */
    
    if ([self rangeOfString:_orignal].length == 0)
        return [[self copy] autorelease];
    
    return [[self componentsSeparatedByString:_orignal]
                  componentsJoinedByString:_replacement];
}

- (NSString *)stringByTrimmingLeadSpaces
{
    unsigned len;
    
    if ((len = [self length]) > 0) {
        unichar  *buf;
        unsigned idx;
        
        buf = calloc(len + 1, sizeof(unichar));
        [self getCharacters:buf];
        
        for (idx = 0; (idx < len) && isspace(buf[idx]); idx++)
            ;
        
        self = [NSString stringWithCharacters:&(buf[idx]) length:(len - idx)];
        free(buf);
        return self;
    }
    else
        return [[self copy] autorelease];
}

- (NSString *)stringByTrimmingTailSpaces
{
    unsigned len;
    
    if ((len = [self length]) > 0) {
        unichar  *buf;
        unsigned idx;
        
        buf = calloc(len + 1, sizeof(unichar));
        [self getCharacters:buf];
        
        for (idx = (len - 1); (idx >= 0) && isspace(buf[idx]); idx--)
            ;
        
        self = [NSString stringWithCharacters:buf length:(idx + 1)];
        free(buf);
        return self;
    }
    else
        return [[self copy] autorelease];
}

- (NSString *)stringByTrimmingSpaces
{
    return [[self stringByTrimmingTailSpaces]
                  stringByTrimmingLeadSpaces];
}
#endif

@end /* NSString(GSAdditions) */

#if !GNUSTEP

@implementation NSMutableString(GNUstepCompatibility)

- (void)trimLeadSpaces
{
    [self setString:[self stringByTrimmingLeadSpaces]];
}
- (void)trimTailSpaces
{
    [self setString:[self stringByTrimmingTailSpaces]];
}
- (void)trimSpaces
{
    [self setString:[self stringByTrimmingSpaces]];
}

@end /* NSMutableString(GNUstepCompatibility) */

#endif /* !GNUSTEP */

@implementation NSString(lfNSURLUtilities)

- (BOOL)isAbsoluteURL
{
    NSRange r;
    unsigned i;
    
    if ([self hasPrefix:@"mailto:"])
        return YES;
    if ([self hasPrefix:@"javascript:"])
        return YES;
    
    r = [self rangeOfString:@"://"];
    if (r.length == 0) {
        if ([self hasPrefix:@"file:"])
            return YES;
        return NO;
    }
    
    if ([self hasPrefix:@"/"])
        return NO;

    for (i = 0; i < r.location; i++) {
        if (!isalpha([self characterAtIndex:i]))
            return NO;
    }
    return YES;
}

- (NSString *)urlScheme
{
    unsigned i, count;
    unichar c = 0;
    
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

@end /* NSString(lfNSURLUtilities) */


#if !LIB_FOUNDATION_LIBRARY

@implementation NSString(KVCCompatibility)

- (id)valueForUndefinedKey:(NSString *)_key {
  NSLog(@"WARNING: tried to access undefined KVC key '%@' on str object: %@",
	_key, self);
  return nil;
}

@end

#endif
