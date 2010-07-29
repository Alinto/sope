/* 
   NSPathUtilities.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <config.h>
#include <objc/objc.h>

#ifdef _POSIX_VERSION
#include <limits.h>			/* for PATH_MAX */
#else
# if HAVE_SYS_PARAM_H
#  include <sys/param.h>			/* for MAXPATHLEN */
# endif
#endif

#include <Foundation/common.h>

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSAccount.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSProcessInfo.h>

#ifndef PATH_MAX
#  ifdef _POSIX_VERSION
#    define PATH_MAX _POSIX_PATH_MAX
#  else
#    ifdef MAXPATHLEN
#      define PATH_MAX MAXPATHLEN
#    else
#      define PATH_MAX 1024
#    endif
#  endif
#endif

#if defined(HAVE_WINDOWS_H)
#  include <windows.h>
#endif

/*
 * User Account Functions
 */

NSString *NSUserName(void)
{
    return [[NSUserAccount currentAccount] accountName];
}

NSString *NSHomeDirectory(void)
{
    return [[NSUserAccount currentAccount] homeDirectory];
}

NSString *NSOpenStepRootDirectory(void)
{
#if defined(__MINGW32__)
    return @"C:\\";
#else
    return @"/";
#endif
}

NSArray *NSStandardLibraryPaths(void)
{
#if WITH_GNUSTEP
    NSMutableArray *result;
    NSDictionary   *env;
    NSString       *value;
    id             pathPrefixes;

    result = [NSMutableArray arrayWithCapacity:4];
    env    = [[NSProcessInfo processInfo] environment];
    
    pathPrefixes = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"];
    if (pathPrefixes == nil)
	pathPrefixes = [env objectForKey:@"GNUSTEP_PATHLIST"];
    
    if (pathPrefixes) {
#  if defined(__MINGW32__)
        pathPrefixes = [pathPrefixes componentsSeparatedByString:@";"];
#  else
        pathPrefixes = [pathPrefixes componentsSeparatedByString:@":"];
#  endif

        pathPrefixes = [pathPrefixes objectEnumerator];
        while ((value = [pathPrefixes nextObject])) {
            value = [value stringByAppendingPathComponent:@"Library"];
            [result addObject:value];
        }
    }
    else {
        value = [env objectForKey:@"GNUSTEP_USER_ROOT"];
        value = [value stringByAppendingPathComponent:@"Library"];
        if (value) [result addObject:value];
        value = [env objectForKey:@"GNUSTEP_LOCAL_ROOT"];
        value = [value stringByAppendingPathComponent:@"Library"];
        if (value) [result addObject:value];
        value = [env objectForKey:@"GNUSTEP_SYSTEM_ROOT"];
        value = [value stringByAppendingPathComponent:@"Library"];
        if (value) [result addObject:value];
    }
    
    [result addObject:@"/usr/local/share"];
    [result addObject:@"/usr/share"];
    
    return AUTORELEASE([result copy]);
#else
    return [NSArray arrayWithObject:@RESOURCES_PATH];
#endif
}

NSArray *NSStandardApplicationPaths(void)
{
#if WITH_GNUSTEP
    NSMutableArray *result;
    NSDictionary   *env;
    NSString       *value;
    id             pathPrefixes;

    result = [NSMutableArray arrayWithCapacity:4];
    env    = [[NSProcessInfo processInfo] environment];
    
    pathPrefixes = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"];
    if (pathPrefixes == nil)
	pathPrefixes = [env objectForKey:@"GNUSTEP_PATHLIST"];
    
    if (pathPrefixes) {
#  if defined(__MINGW32__)
        pathPrefixes = [pathPrefixes componentsSeparatedByString:@";"];
#  else
        pathPrefixes = [pathPrefixes componentsSeparatedByString:@":"];
#  endif

        pathPrefixes = [pathPrefixes objectEnumerator];
        while ((value = [pathPrefixes nextObject])) {
            value = [value stringByAppendingPathComponent:@"Apps"];
            [result addObject:value];
        }
    }
    else {
        value = [env objectForKey:@"GNUSTEP_USER_ROOT"];
        value = [value stringByAppendingPathComponent:@"Apps"];
        if (value) [result addObject:value];
        value = [env objectForKey:@"GNUSTEP_LOCAL_ROOT"];
        value = [value stringByAppendingPathComponent:@"Apps"];
        if (value) [result addObject:value];
        value = [env objectForKey:@"GNUSTEP_SYSTEM_ROOT"];
        value = [value stringByAppendingPathComponent:@"Apps"];
        if (value) [result addObject:value];
    }
    
    [result addObject:@"/usr/local/bin"];
    [result addObject:@"/usr/bin"];
    
    return AUTORELEASE([result copy]);
#else
#  if defined(__MINGW32__)
    return [NSArray arrayWithObject:
                    [NSOpenStepRootDirectory() stringByAppendingPathComponent:
                                            @"Programs"]];
#else
    return [NSArray arrayWithObject:@"/usr/local/bin"];
#endif
#endif
}

extern NSArray *
NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory _directory,
                                    NSSearchPathDomainMask _mask,
                                    BOOL _expandTilde)
{
#if WITH_GNUSTEP
    NSMutableArray *domainRoots = nil;
    NSMutableArray *results     = nil;
    NSDictionary   *env;
    NSString       *path = nil;
    int            idx, count;

    env  = [[NSProcessInfo processInfo] environment];
    if (_directory == NSUserDirectory) {
        /* The home-directories (eg /Local/Users, /Network/Users) */
        return [NSArray arrayWithObject:
                  [NSHomeDirectory() stringByDeletingLastPathComponent]];
    }
    
    /* collect root directories of domains selected with mask */

    domainRoots = [NSMutableArray arrayWithCapacity:8];

    if (_mask == NSAllDomainsMask) {
        id pathPrefixes = nil;

	pathPrefixes = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"];
	if (pathPrefixes == nil)
	    pathPrefixes = [env objectForKey:@"GNUSTEP_PATHLIST"];
	
        if (pathPrefixes != nil) {
#  if defined(__MINGW32__)
            pathPrefixes = [pathPrefixes componentsSeparatedByString:@";"];
#  else
            pathPrefixes = [pathPrefixes componentsSeparatedByString:@":"];
#  endif
            [domainRoots addObjectsFromArray:pathPrefixes];
        }
    }
    if (_mask & NSUserDomainMask) {
        if ((path = [env objectForKey:@"GNUSTEP_USER_ROOT"])) {
            if (![domainRoots containsObject:path])
                [domainRoots addObject:path];
        }
    }
    if (_mask & NSLocalDomainMask) {
        if ((path = [env objectForKey:@"GNUSTEP_LOCAL_ROOT"])) {
            if (![domainRoots containsObject:path])
                [domainRoots addObject:path];
        }
	if (![domainRoots containsObject:@"/usr/local"])
	    [domainRoots addObject:@"/usr/local"];
    }
    if (_mask & NSNetworkDomainMask) {
        if ((path = [env objectForKey:@"GNUSTEP_NETWORK_ROOT"])) {
            if (![domainRoots containsObject:path])
                [domainRoots addObject:path];
        }
    }
    if (_mask & NSSystemDomainMask) {
        if ((path = [env objectForKey:@"GNUSTEP_SYSTEM_ROOT"])) {
            if (![domainRoots containsObject:path])
                [domainRoots addObject:path];
        }
	if (![domainRoots containsObject:@"/usr"])
	    [domainRoots addObject:@"/usr"];
    }

    /* no join the specified directories with the domains */

    results = [NSMutableArray arrayWithCapacity:64];

    for (idx = 0, count = [domainRoots count]; idx < count; idx++) {
        path = [domainRoots objectAtIndex:idx];
        
        switch (_directory) {
            case NSApplicationDirectory:
            case NSAllApplicationDirectory:
                [results addObject:
                           [path stringByAppendingPathComponent:@"Apps"]];
                break;
            
            case NSLibraryDirectory:
            case NSAllLibrariesDirectory:
                [results addObject:
                           [path stringByAppendingPathComponent:@"Library"]];
                break;

            default:
                break;
        }
    }
    return results;
#else
    switch (_directory) {
        case NSApplicationDirectory:
        case NSAllApplicationDirectory:
            return NSStandardApplicationPaths();
            
        case NSLibraryDirectory:
        case NSAllLibrariesDirectory:
            return NSStandardLibraryPaths();

        case NSUserDirectory:
            /* The home-directories (eg /Local/Users, /Network/Users) */
            return [NSArray arrayWithObject:
                      [NSHomeDirectory() stringByDeletingLastPathComponent]];
            
        default:
            return nil;
    }
#endif
}

NSString *NSHomeDirectoryForUser(NSString* userName)
{
    return [[NSUserAccount accountWithName:userName] homeDirectory];
}

NSString *NSFullUserName()
{
    return [[NSUserAccount currentAccount] fullName];
}

NSString *NSTemporaryDirectory()
{
#if defined(__MINGW32__)
    // should use 'DWORD GetTempPath(DWORD len, LPTSTR path)'
    return @"C:\\TEMP";
#else
    return @"/tmp";
#endif
}

/*
 * String file naming functions
 */

#if defined(__MINGW32__)
static NSString *pathSeparator = @"\\";
#else
static NSString *pathSeparator = @"/";
#endif
static NSString *extensionSeparator = @".";
static NSString *nullSeparator = @"";
static NSString *homeSeparator = @"~";
static NSString *parentDirName = @"..";
static NSString *selfDirName = @".";

// WIN32 - must be @"C:/" on WINDOWS
#if defined(__MINGW32__)
static NSString *rootPath = @"C:\\";
#else
static NSString *rootPath = @"/";
#endif

@implementation NSString(FilePathMethods)

+ (NSString *)pathWithComponents:(NSArray *)components
{
    id str, result;
    int n = [components count];
    int i = 0;
    BOOL previousIsPathSeparator = NO;
    
    if (!n)
	return nullSeparator;
    
    result = AUTORELEASE([[NSMutableString alloc] init]);
    
    str = [components objectAtIndex:0];
    if ([str isEqualToString:nullSeparator] || 
	[str isEqualToString:pathSeparator]) {
	    [result appendString:rootPath];
	    previousIsPathSeparator = YES;
    }
    else
	[result appendString:str];
    
    for (i = 1; i < n; i++) {
        str = [components objectAtIndex:i];
        
	if (([str isEqualToString:nullSeparator]
	     || [str isEqualToString:pathSeparator])
	    && !previousIsPathSeparator) {
	    [result appendString:pathSeparator];
	    previousIsPathSeparator = YES;
	}
	else {
	    if (!previousIsPathSeparator)
		[result appendString:pathSeparator];

	    [result appendString:[components objectAtIndex:i]];
	    previousIsPathSeparator = NO;
	}
    }

    return result;
}

- (NSArray *)pathComponents
{
    NSMutableArray* components
	= [[self componentsSeparatedByString:pathSeparator] mutableCopy];
    int i;
    
    for (i = [components count]-1; i >= 0; i--)
	if ([[components objectAtIndex:i] isEqual:nullSeparator])
	    [components removeObjectAtIndex:i];
    
    if ([self hasPrefix:pathSeparator])
	[components insertObject:pathSeparator atIndex:0];

    if ([self hasSuffix:pathSeparator])
	[components addObject:nullSeparator];

    return components;
}

- (unsigned int)completePathIntoString:(NSString **)outputName
  caseSensitive:(BOOL)flag matchesIntoArray:(NSArray **)outputArray
  filterTypes:(NSArray *)filterTypes
{
    // TODO
    [self notImplemented:_cmd];
    return 0;
}

- (const char *)fileSystemRepresentation
{
    // WIN32
    return [self cString];
}

- (BOOL)getFileSystemRepresentation:(char *)buffer
  maxLength:(unsigned int)maxLength
{
    // WIN32
    NSRange left;
    
    [self getCString:buffer maxLength:maxLength
	range:NSMakeRange(0, [self length]) remainingRange:&left];
    return (left.length == 0) ? YES : NO;
}

- (BOOL)isAbsolutePath
{
    if (![self length])
	return NO;

#if defined(__MINGW32__)
    if ([self indexOfString:@":"] != NSNotFound)
        return YES;
#endif
    if ([self hasPrefix:rootPath] || [self hasPrefix:@"~"])
	return YES;

    return NO;
}

- (NSString *)lastPathComponent
{
    NSRange sepRange;
    NSRange lastRange = { 0, 0 };
    
    lastRange.length = [self length];
    if ([self hasSuffix:pathSeparator]) {
	if (lastRange.length == [pathSeparator length])
	    return nullSeparator;

	lastRange.length--;
    }

    sepRange = [self rangeOfString:pathSeparator
		     options:NSBackwardsSearch range:lastRange];
    if (sepRange.length == 0)
	return AUTORELEASE([self copyWithZone:[self zone]]);
    
    lastRange.location = sepRange.location + sepRange.length;
    lastRange.length   = lastRange.length - lastRange.location;
    
    if (lastRange.location == 0)
	return AUTORELEASE([self copyWithZone:[self zone]]);
    else
	return lastRange.length ? 
	    [self substringWithRange:lastRange] : nullSeparator;
}

- (NSString *)pathExtension
{
    NSRange  sepRange, lastRange;
    NSString *lastComponent;
    int      length;

    lastComponent = [self lastPathComponent];
    length        = [lastComponent length];
    
    sepRange = [lastComponent rangeOfString:extensionSeparator 
			      options:NSBackwardsSearch];
    if (sepRange.length == 0)
	return @"";
    
    lastRange.location = sepRange.location + sepRange.length;
    lastRange.length   = length - lastRange.location;
    
    return lastRange.length && sepRange.length ? 
    	[lastComponent substringWithRange:lastRange] : nullSeparator;
}

- (NSString *)stringByAppendingPathComponent:(NSString *)aString
{
    NSString *str;
    
    str = [self hasSuffix:pathSeparator] ? nullSeparator : pathSeparator;
    
    return [aString length]
        ? [self stringByAppendingString:
                    ([self length]
                     ? [str stringByAppendingString:aString] 
                     : aString)]
	: (NSString *)AUTORELEASE([self copyWithZone:[self zone]]);
}

- (NSArray *)stringsByAppendingPaths:(NSArray *)paths
{
    NSMutableArray *array;
    int i, n;
    
    array = [NSMutableArray array];
    
    for (i = 0, n = [paths count]; i < n; i++) {
	[array addObject:[self stringByAppendingPathComponent:
	    [paths objectAtIndex:i]]];
    }
    return array;
}

- (NSString *)stringByAppendingPathExtension:(NSString *)aString
{
    return [aString length]
        ? [self stringByAppendingString:
                    [extensionSeparator stringByAppendingString:aString]] 
	: (NSString *)AUTORELEASE([self copyWithZone:[self zone]]);
}

- (NSString *)stringByDeletingLastPathComponent
{
    NSRange range = {0, [self length]};
    
    if (range.length == 0)
	return nullSeparator;
    
    if ([self isEqualToString:pathSeparator])
	return pathSeparator;
    
    range.length--;
    range = [self rangeOfString:pathSeparator
                  options:NSBackwardsSearch range:range];

    if (range.length == 0)
	return nullSeparator;
    if (range.location == 0)
	return pathSeparator;

    return [self substringWithRange:NSMakeRange(0, range.location)];
}

- (NSString *)stringByDeletingPathExtension
{
    NSRange range = {0, [self length]};
    NSRange extSep, patSep;
    
    if (range.length == 0)
	return nullSeparator;
    
    if ([self hasSuffix:pathSeparator]) {
	if (range.length == 1)
	    return AUTORELEASE([self copyWithZone:[self zone]]);
	else
	    range.length--;
    }
    
    extSep = [self rangeOfString:extensionSeparator
		   options:NSBackwardsSearch range:range];

    if (extSep.length != 0) {
	patSep = [self rangeOfString:pathSeparator
		       options:NSBackwardsSearch range:range];
	if (patSep.length != 0) {
	    if (extSep.location > patSep.location + 1) {
		range.length = extSep.location;
	    }
	    /* else the filename begins with a dot so don't consider it as
	       being an extension; do nothing */
	}
	else {
	    range.length = extSep.location;
	}
    }
    
    return [self substringWithRange:range];
}

- (NSString *)stringByAbbreviatingWithTildeInPath
{
    NSString *home;
    int      homeLength;
    
    home       = NSHomeDirectory();
    homeLength = [home length];
    
    if (![self hasPrefix:home])
	return self;
	
    home = [self substringWithRange:
		     NSMakeRange(homeLength, [self length] - homeLength)];
    
    return [homeSeparator stringByAppendingString:
			      ([home length] > 0 ? home : pathSeparator)];
}

- (NSString *)stringByExpandingTildeInPath
{
    NSString *rest;
    NSString *home;
    unsigned int index;
    unsigned int hlen;
    
    if (![self hasPrefix:homeSeparator])
	return self;
    
    index = [self indexOfString:pathSeparator];
    hlen  = [homeSeparator length];
    
    if (index == hlen)
	home = NSHomeDirectory();
    else {
	home = NSHomeDirectoryForUser([self substringWithRange:
	    NSMakeRange(hlen, (index == NSNotFound) ?  
		[self length] - hlen : index - hlen)]);
    }
    
    if (index == NSNotFound)
	rest = nullSeparator;
    else
	rest = [self substringWithRange:
	    NSMakeRange(index + 1, [self length] - index - 1)];
    
    return [home stringByAppendingPathComponent:rest];
}

- (NSString *)stringByResolvingSymlinksInPath
{
    // WIN32 - no symlinks; just convert and stat the path using real names
#if defined(__MINGW32__)
    return (GetFileAttributes([self cString]) != -1) ? self : nil;
#else
    extern char *resolve_symlinks_in_path(const char *, char *);
    unsigned char resolved[PATH_MAX];
    const char *source;
    
    if ((source = [self cString]) == NULL) {
	fprintf(stderr, "ERROR(%s): did not get cString of string?!\n",
		__PRETTY_FUNCTION__);
	return nil;
    }
    if (!resolve_symlinks_in_path(source, (char *)resolved)) {
        /* 
	   previously returned 'nil', which is wrong according to MacOSXS
	   Spec 
	*/
#if 0
	return nil;
#else
        return self;
#endif
    }
    return [NSString stringWithCString:(char *)resolved];
#endif
}

- (NSString *)stringByStandardizingPath
{
    if ([self isAbsolutePath])
	return [self stringByResolvingSymlinksInPath];
    
    {
#if defined(__MINGW32__)
        unsigned char *buf = objc_atomic_malloc(2048);
        DWORD         len;
        LPTSTR        lastComponent;

        len = GetFullPathName([self cString], 2046, buf, &lastComponent);
        if (len > 2046) buf = objc_realloc(buf, len + 1);
        len = GetFullPathName([self cString], len, buf, &lastComponent);

	self = (len == 0) ? self : [NSString stringWithCString:buf length:len];
	objc_free(buf);
	return self;
#else
	NSString       *path;
	NSMutableArray *components;
	int            i, n;
	
        components = [[self pathComponents] mutableCopy];
	n = [components count];
	/* remove "//" and "/./" components */
	for (i = n - 1; i >= 0; i--) {
	    NSString *comp;
            
            comp = [components objectAtIndex:i];
	    
	    if ([comp length] == 0 || [comp isEqualToString:selfDirName]) {
		[components removeObjectAtIndex:i];
		continue;
	    }
	}
        
	/* compact ".../dir1/../dir2/..." into ".../dir2/..." */
        n = [components count];
	for (i = 1; i < n; i++) {
	    if ([[components objectAtIndex:i] isEqualToString:parentDirName] 
		&& i > 0 &&
	     ![[components objectAtIndex:i-1] isEqualToString:parentDirName]) {
		i -= 1;
		[components removeObjectAtIndex:i];
		[components removeObjectAtIndex:i];
	    }
	}
	
	path = [NSString pathWithComponents:components];
	RELEASE(components);
	
	return path ? path : self;
#endif
    }
}

@end /* NSString(FilePathMethods) */

@implementation NSArray(FilePathMethods)

- (NSArray *)pathsMatchingExtensions:(NSArray *)_exts
{
    /* new in MacOSX */
    NSSet          *exts;
    NSEnumerator   *e;
    NSString       *path;
    NSMutableArray *ma;
    
    exts = [[NSSet alloc] initWithArray:_exts];
    ma   = [[NSMutableArray alloc] init];
    
    e = [self objectEnumerator];
    while ((path = [e nextObject])) {
        if ([exts containsObject:[path pathExtension]])
            [ma addObject:path];
    }
    RELEASE(exts); exts = nil;
    
    self = [ma copy];
    RELEASE(ma);
    return AUTORELEASE(self);
}

@end /* NSArray(FilePathMethods) */

/*
 * Used for forcing linking of this category
 */

void __dummyNSStringFilePathfile ()
{
    __dummyNSStringFilePathfile();
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
