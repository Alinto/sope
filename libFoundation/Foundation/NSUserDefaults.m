/* 
   NSUserDefaults.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@net-community.com>

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSDistributedLock.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#if HAVE_WINDOWS_H
#include <windows.h>
#endif

/*
 * User defaults strings
 */

/* Defaults Domains */
NSString *NSArgumentDomain     = @"NSArgumentDomain";
NSString *NSGlobalDomain       = @"NSGlobalDomain";
NSString *NSRegistrationDomain = @"NSRegistrationDomain";

/* Notification name */
NSString*  NSUserDefaultsDidChangeNotification =
@"NSUserDefaultsDidChangeNotification";

/* Defaults names */
LF_DECLARE NSString *NSWeekDayNameArray            = @"NSWeekDayNameArray";
LF_DECLARE NSString *NSShortWeekDayNameArray       = @"NSShortWeekDayNameArray";
LF_DECLARE NSString *NSMonthNameArray              = @"NSMonthNameArray";
LF_DECLARE NSString *NSShortMonthNameArray         = @"NSShortMonthNameArray";
LF_DECLARE NSString *NSTimeFormatString            = @"NSTimeFormatString";
LF_DECLARE NSString *NSDateFormatString            = @"NSDateFormatString";
LF_DECLARE NSString *NSTimeDateFormatString        = @"NSTimeDateFormatString";
LF_DECLARE NSString *NSShortTimeDateFormatString   = @"NSShortTimeDateFormatString";
LF_DECLARE NSString *NSCurrencySymbol              = @"NSCurrencySymbol";
LF_DECLARE NSString *NSDecimalSeparator            = @"NSDecimalSeparator";
LF_DECLARE NSString *NSThousandsSeparator          = @"NSThousandsSeparator";
LF_DECLARE NSString *NSInternationalCurrencyString = @"NSInternationalCurrencyString";
LF_DECLARE NSString *NSCurrencyString              = @"NSCurrencyString";
LF_DECLARE NSString *NSDecimalDigits               = @"NSDecimalDigits";
LF_DECLARE NSString *NSAMPMDesignation             = @"NSAMPMDesignation";
LF_DECLARE NSString *NSHourNameDesignations        = @"NSHourNameDesignations";
LF_DECLARE NSString *NSYearMonthWeekDesignations   = @"NSYearMonthWeekDesignations";
LF_DECLARE NSString *NSEarlierTimeDesignations     = @"NSEarlierTimeDesignations";
LF_DECLARE NSString *NSLaterTimeDesignations       = @"NSLaterTimeDesignations";
LF_DECLARE NSString *NSThisDayDesignations         = @"NSThisDayDesignations";
LF_DECLARE NSString *NSNextDayDesignations         = @"NSNextDayDesignations";
LF_DECLARE NSString *NSNextNextDayDesignations     = @"NSNextNextDayDesignations";
LF_DECLARE NSString *NSPriorDayDesignations        = @"NSPriorDayDesignations";
LF_DECLARE NSString *NSDateTimeOrdering            = @"NSDateTimeOrdering";
LF_DECLARE NSString *NSShortDateFormatString       = @"NSShortDateFormatString";
LF_DECLARE NSString *NSPositiveCurrencyFormatString = @"NSPositiveCurrencyFormatString";
LF_DECLARE NSString *NSNegativeCurrencyFormatString = @"NSNegativeCurrencyFormatString";

/* 
 * User defaults shared class 
 */


#define CREATE_DEFAULT_PATH_ON_DEMAND 1

@interface NSUserDefaults(Internals)
- (BOOL)_checkPathNameCreate:(BOOL)_create;
@end /*NSUserDefaults(Internals) */

@interface NSSharedUserDefaults : NSUserDefaults
{
}
@end

@implementation NSSharedUserDefaults
- (id)retain      {return self;}
- (id)autorelease {return self;}
- (void)release   {}
- (unsigned int)retainCount {return 1;}
@end

/* 
 * User defaults class 
 */

@implementation NSUserDefaults

/* Getting and Setting a Default */

- (NSArray*)arrayForKey:(NSString*)defaultName
{
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSArray class]])
	return obj;
    return nil;
}

- (NSDictionary*)dictionaryForKey:(NSString*)defaultName
{
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSDictionary class]])
	return obj;
    return nil;
}

- (NSData*)dataForKey:(NSString*)defaultName;
{
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSData class]])
	return obj;
    return nil;
}

- (NSArray*)stringArrayForKey:(NSString*)defaultName
{
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSArray class]]) {
	int n;
	Class strClass = [NSString class];
	
	for (n = [obj count]-1; n >= 0; n--)
	    if (![[obj objectAtIndex:n] isKindOfClass:strClass])
		return nil;

	return obj;
    }
    return nil;
}

- (NSString*)stringForKey:(NSString*)defaultName
{
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSString class]])
	return obj;
    return nil;
}

- (BOOL)boolForKey:(NSString*)defaultName
{
    id obj;

    if ((obj = [self objectForKey:defaultName])) {
      if ([obj isKindOfClass:[NSString class]]) {
	if ([obj compare:@"YES" options:NSCaseInsensitiveSearch] == 
            NSOrderedSame) {
          return YES;
        }
      }
      if ([obj respondsToSelector:@selector(intValue)])
          return [obj intValue] ? YES : NO;
    }
    return NO;
}

- (float)floatForKey:(NSString*)defaultName
{
    id obj = [self stringForKey:defaultName];
    if (obj) 
	return [obj floatValue];
    return 0;
}

- (int)integerForKey:(NSString*)defaultName
{
    id obj = [self stringForKey:defaultName];
    if (obj) 
	return [obj intValue];
    return 0;
}

- (void)setBool:(BOOL)value forKey:(NSString*)defaultName
{
    [self setObject:(value ? @"YES" : @"NO") 
	    forKey:defaultName];
}

- (void)setFloat:(float)value forKey:(NSString*)defaultName
{
    [self setObject:[NSString stringWithFormat:@"%f", value]
	    forKey:defaultName];
}

- (void)setInteger:(int)value forKey:(NSString*)defaultName
{
    [self setObject:[NSString stringWithFormat:@"%d", value] 
	    forKey:defaultName];
}

/* Accessing app domain defaults */

- (id)objectForKey:(NSString*)defaultName
{
    int i, n = [self->searchList count];
    
    for (i = 0; i < n; i++) {
	NSString     *name   = [self->searchList objectAtIndex:i];
	NSDictionary *domain = nil;
	id           obj;
        
	if ((domain = [self->volatileDomains objectForKey:name])) {
	    if (domain && (obj = [domain objectForKey:defaultName]))
		return obj;
        }
	if ((domain = [self->persistentDomains objectForKey:name])) {
	    if (domain && (obj = [domain objectForKey:defaultName]))
		return obj;
        }
    }
    return nil;
}

- (void)setObject:(id)value forKey:(NSString*)defaultName
{
    NSMutableDictionary *domain;
    
    domain = (NSMutableDictionary *)[self persistentDomainForName:appDomain];
    if (value == nil) {
        fprintf(stderr,
                "WARNING: attempt to set nil value for "
                "default %s in domain %s\n",
                [defaultName cString], [appDomain cString]);
    }
    [domain setObject:value forKey:defaultName];
    [self persistentDomainHasChanged:appDomain];
}

- (void)removeObjectForKey:(NSString*)defaultName
{
    NSMutableDictionary *domain = (NSMutableDictionary *)
	[self persistentDomainForName:appDomain];
    [domain removeObjectForKey:defaultName];
    [self persistentDomainHasChanged:appDomain];
}

/* Returning the Search List */

- (void)setSearchList:(NSArray *)_searchList
{
#if !LIB_FOUNDATION_BOEHM_GC
    id old = self->searchList;
#endif
    self->searchList = [_searchList mutableCopyWithZone:[self zone]];
    RELEASE(old);
}
- (NSArray *)searchList
{
    return self->searchList;
}

/* Making Advanced Use of Defaults */

- (NSDictionary*)dictionaryRepresentation
{
    NSMutableDictionary *dict;
    int i, n;
    
    dict = AUTORELEASE([[NSMutableDictionary alloc] init]);
    n = [searchList count];
    
    for (i = n - 1; i >= 0; i--) {
	NSString     *name;
        NSDictionary *domain;
        
        name = [searchList objectAtIndex:i];
	
	if ((domain = [volatileDomains objectForKey:name]))
	    [dict addEntriesFromDictionary:domain];
	if ((domain = [persistentDomains objectForKey:name]))
	    [dict addEntriesFromDictionary:domain];
    }

    return dict;
}

- (void)registerDefaults:(NSDictionary *)dictionary
{
    NSMutableDictionary *regDomain;
    
    regDomain = (NSMutableDictionary *)
        [self volatileDomainForName:NSRegistrationDomain];
    
    if ([self->searchList indexOfObjectIdenticalTo:regDomain] == NSNotFound)
	[self->searchList addObject:NSRegistrationDomain];
    
    [regDomain addEntriesFromDictionary:dictionary];
}

/* Maintaining Volatile Domains */

- (void)removeVolatileDomainForName:(NSString*)domainName
{
    /* apparently in MacOSX-S the name isn't removed from the search list */
    [self->searchList removeObject:domainName];
    [self->volatileDomains removeObjectForKey:domainName];
}

- (void)setVolatileDomain:(NSDictionary *)domain  
  forName:(NSString *)domainName
{
    if ([volatileDomains objectForKey:domainName]) {
	[[[InvalidArgumentException alloc]
		    initWithFormat:@"volatile domain %@ already exists",
				    domainName] raise];
    }
    
    [volatileDomains setObject:
                       [[NSMutableDictionary alloc] initWithDictionary:domain] 
                     forKey:domainName];
}

- (NSDictionary *)volatileDomainForName:(NSString *)domainName
{
    return [volatileDomains objectForKey:domainName];
}

- (NSArray *)volatileDomainNames
{
    return [volatileDomains allKeys];
}

/* Maintaining Persistent Domains */

- (NSDictionary *)loadPersistentDomainNamed:(NSString*)domainName
{
#if USE_LOCKING
    int n;
    NSDistributedLock *lock = nil;
#endif
    NSDictionary *dict = nil;
    NSString     *domainPath;
    NSString     *path;

#if CREATE_DEFAULT_PATH_ON_DEMAND
    domainPath = nil;
    path       = nil;
    if ([self _checkPathNameCreate:NO]) {
#endif
    domainPath = [[self->directoryForSaving 
                       stringByAppendingPathComponent:domainName] 
	               stringByAppendingPathExtension:@"plist"];
#if CREATE_DEFAULT_PATH_ON_DEMAND    
    }
#endif
    
    /* Take the address of `path' to force the compiler to not allocate it
       in a register. */
    *(&path) = [domainPath stringByResolvingSymlinksInPath];
    if (path) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            path = nil;
    }
    if (path) {
#if USE_LOCKING
	lock = [NSDistributedLock lockWithPath:
	    [[path stringByDeletingPathExtension]
		stringByAppendingPathExtension:@"lock"]];
	for (n = 0;  n < 3; n++)
	    if ([lock tryLock])
		break;
	    else
		sleep(1);

	if (n >= 3) {
	    NSLog(@"could not lock user defaults domain %@", domainName);
	    return nil;
	}
#endif

        NS_DURING
            dict = [NSDictionary dictionaryWithContentsOfFile:path];
        NS_HANDLER {
	    fprintf (stderr,
                     "caught exception '%s' with reason '%s' "
                     "while loading user defaults domain '%s'\n",
                     [[localException name] cString],
                     [[localException reason] cString],
                     [domainName cString]);
	    dict = nil;
        }
        NS_ENDHANDLER;

#if 0
        if (dict == nil) {
	   fprintf(stderr,
                   "could not load user defaults domain %s from path %s.\n",
                   [domainName cString], [path cString]);
        }
#endif
      
#if USE_LOCKING
	[lock unlock];
#endif
    }
    
    if ((path == nil) || (dict == nil)) {
	path = [NSBundle _fileResourceNamed:domainName
                         extension:@"plist"
                         inDirectory:@"Defaults"];

	if (path) {
            NS_DURING
                dict = [NSDictionary dictionaryWithContentsOfFile:path];
            NS_HANDLER
		fprintf (stderr,
                         "caught exception '%s' with reason '%s' "
                         "while loading user defaults domain '%s'\n",
                         [[localException name] cString],
                         [[localException reason] cString],
                         [domainName cString]);
		dict = nil;
            NS_ENDHANDLER
	}
#if 0
	else {
	   fprintf(stderr,
                   "could not load user defaults domain %s from path %s.\n",
                   [domainName cString], [path cString]);
        }
#endif
    }
    
    if (dict == nil)
	return nil;
    
    dict = [[NSMutableDictionary alloc] initWithDictionary:dict];
    return AUTORELEASE(dict);
}

- (BOOL)savePersistentDomainNamed:(NSString*)domainName
{
    BOOL ok = YES;
#if USE_LOCKING
    int n;
    NSDistributedLock* lock = nil;
#endif
    NSDictionary *dict = nil;
    NSString     *path = nil;

#if CREATE_DEFAULT_PATH_ON_DEMAND
    [self _checkPathNameCreate:YES];
#endif
    
    dict = [self->persistentDomains objectForKey:domainName];
    path = [[self->directoryForSaving stringByAppendingPathComponent:domainName]
                                      stringByAppendingPathExtension:@"plist"];

    if ([path length] < 1) {
        NSLog(@"Could not save persistent domain %@: invalid path '%@', "
              @"directory for saving is '%@'.",
              domainName, path, self->directoryForSaving);
        return NO;
    }

#if USE_LOCKING
    lock = [NSDistributedLock lockWithPath:
                                [path stringByAppendingPathExtension:@"lock"]];
    for (n = 0;  n < 3; n++)
	if (![lock tryLock])
	    sleep(1);
	else
	    break;
    if (n >= 3) {
	NSLog(@"could not lock user defaults domain %@", domainName);
	return NO;
    }
#endif

    NS_DURING
	ok = [dict writeToFile:path atomically:YES];
    NS_HANDLER
	fprintf (stderr,
                 "caught exception '%s' with reason '%s' "
                 "while saving user defaults domain '%s'\n",
		 [[localException name]   cString],
		 [[localException reason] cString],
		 [domainName cString]);
	ok = NO;
    NS_ENDHANDLER
    
#if USE_LOCKING
    [lock unlock];
#endif

    if (!ok) {
        NSLog(@"Could not save persistent domain %@ (in path '%@').",
              domainName, path);
    }
    return ok;
}

- (void)removePersistentDomainForName:(NSString*)domainName
{
    [domainsToRemove addObject:domainName];
    [persistentDomains removeObjectForKey:domainName];
    [self persistentDomainHasChanged:domainName];
}

- (NSDictionary *)persistentDomainForName:(NSString*)domainName
{
    NSDictionary *domain;
    
    domain = [persistentDomains objectForKey:domainName];
    
    if (domain == nil) {
	domain = [[self loadPersistentDomainNamed:domainName] mutableCopy];
	if (domain)
	    [persistentDomains setObject:domain forKey:domainName];
        RELEASE(domain);
    }
    return domain;
}

- (void)setPersistentDomain:(NSDictionary*)domain
  forName:(NSString*)domainName
{
    if ([self->persistentDomains objectForKey:domainName]) {
	[[[InvalidArgumentException alloc]
		    initWithFormat:@"persistent domain %@ already exists",
				    domainName] raise];
    }
    if (domain == nil) {
        fprintf(stderr,
                "WARNING: attempt to set nil for persistent domain %s.\n",
                [domainName cString]);
    }
    [self->persistentDomains setObject:domain forKey:domainName];
    [self->domainsToRemove removeObject:domainName];
    [self persistentDomainHasChanged:domainName];
}

- (NSArray*)persistentDomainNames
{
    NSArray *knownDomains;
    int     i, count;

#if CREATE_DEFAULT_PATH_ON_DEMAND
    if (![self _checkPathNameCreate:NO])
        return nil;
#endif

    knownDomains =
        [[NSFileManager defaultManager]
                        directoryContentsAtPath:self->directoryForSaving];
    count = [knownDomains count];
    
    if (count > 0) {
	NSString *domainNames[count];

	for (i = 0; i < count; i++) {
	    domainNames[i] = [[knownDomains objectAtIndex:i]
                                            stringByDeletingPathExtension];
        }
	return [NSArray arrayWithObjects:domainNames count:count];
    }
    return nil;
}

/* Creation of defaults */

static NSUserDefaults* sharedDefaults    = nil;
static NSString*       sharedDefaultsDir = nil;

+ (void)setStandardDefaultsDirectory:(NSString*)dir
{
    ASSIGN(sharedDefaultsDir, dir);
}

+ (NSUserDefaults *)standardUserDefaults
{
    if (sharedDefaults == nil) {
	if (sharedDefaultsDir) {
            sharedDefaults = (id)
                [(NSSharedUserDefaults *)[NSSharedUserDefaults alloc]
                                       initWithPath:sharedDefaultsDir];
	}
	else {
	    NSString *defdir;

#if WITH_GNUSTEP
            NSDictionary *env;
            
            env = [[NSProcessInfo processInfo] environment];
            defdir = [env objectForKey:@"GNUSTEP_DEFAULTS_ROOT"];
            if ([defdir length] == 0)
                defdir = [env objectForKey:@"GNUSTEP_USER_ROOT"];
#else
            defdir = nil;
#endif

            if ([defdir length] == 0) {
                if ((defdir = NSHomeDirectory()) == nil) {
                    NSString *user = NSUserName();
                
                    fprintf(stderr,
                            "WARNING: could not get home "
                            "directory of user %s !\n",
                            user ? [user cString] : "<null>");
                }
            }
            
            defdir =
                [defdir stringByAppendingPathComponent:@".libFoundation"];
            defdir =
                [defdir stringByAppendingPathComponent:@"Defaults"];
            
#if !CREATE_DEFAULT_PATH_ON_DEMAND
	    if (([defdir stringByResolvingSymlinksInPath] == nil) ||
                (![[NSFileManager defaultManager] fileExistsAtPath:defdir])) {
		if (![[NSFileManager defaultManager]
                                     createDirectoryAtPath:defdir
                                     attributes:nil]) {
                    fprintf(stderr,
                            "WARNING: could not create user defaults directory"
                            " at path %s !\n",
                            defdir ? [defdir cString] : "<null>");
                }
            }
#endif            

	    sharedDefaults = (id)
                [(NSSharedUserDefaults *)[NSSharedUserDefaults alloc] 
					 initWithPath:defdir];
	}
	[sharedDefaults makeStandardDomainSearchList];
    }
    return sharedDefaults;
}

+ (void)synchronizeStandardUserDefaults:(id)sender
{
    [sharedDefaults synchronize];
}

/* Initializing the User Defaults */

- (id)init
{
    return [self initWithUser:NSUserName()];
}

- (id)initWithUser:(NSString*)aUserName
{
    return [self initWithPath:[[NSHomeDirectoryForUser(aUserName)
		    stringByAppendingPathComponent:@".libFoundation"]
		    stringByAppendingPathComponent:@"Defaults"]];
}

- (NSDictionary *)_collectArgumentDomain {
    NSMutableDictionary *defArgs = nil;
    NSArray             *args;
    int           i, n;

    args    = [[NSProcessInfo processInfo] arguments];
    *(&n)   = [args count];
    defArgs = [NSMutableDictionary dictionaryWithCapacity:(n / 2)];

    for (*(&i) = 0; i < n; i++) {
            NSString *argument;

            *(&argument) = [args objectAtIndex:i];

            if ([argument hasPrefix:@"-"] && [argument length] > 1) {
                // found option
                if ((i + 1) == n) { // is last option ?
                    fprintf(stderr,
                            "Missing value for command line default '%s'.\n",
                            [[argument substringFromIndex:1] cString]);
                }
                else { // is not the last option
                    id value = [args objectAtIndex:(i + 1)];

                    argument = [argument substringFromIndex:1];

                    // parse property list value
                    NS_DURING {
                        *(&value) = [value propertyList];
                    }
                    NS_HANDLER {}
                    NS_ENDHANDLER;

                    if (value == nil) {
                        fprintf(stderr,
                                "Could not process value %s "
                                "of command line default '%s'.\n",
                                [argument cString],
                                [[args objectAtIndex:(i + 1)] cString]);
                    }
                    else {
                        [defArgs setObject:value forKey:argument];
                    }
                    i++; // skip value
                }
            }
    }
    return defArgs;
}

- (id)initWithPath:(NSString*)pathName
{
    NSDictionary* dict;
    NSArray*      languages;
    int           i, n;
    NSZone        *z = [self zone];
    
    self->directoryForSaving = [pathName copyWithZone:z];

    self->persistentDomains = 
        [[NSMutableDictionary allocWithZone:z] initWithCapacity:8];
    self->volatileDomains = 
        [[NSMutableDictionary allocWithZone:z] initWithCapacity:4];

    self->domainsToRemove= [[NSMutableSet allocWithZone:z] initWithCapacity:2];
    self->dirtyDomains   = [[NSMutableSet allocWithZone:z] initWithCapacity:2];
    
    self->searchList = [[NSMutableArray allocWithZone:z] initWithCapacity:8];
    self->appDomain  = RETAIN([[NSProcessInfo processInfo] processName]);
    
    [self setVolatileDomain:[self _collectArgumentDomain]
          forName:NSArgumentDomain];
    
    [self setVolatileDomain:[NSMutableDictionary dictionaryWithCapacity:128] 
          forName:NSRegistrationDomain];
    
    if ((dict = [self persistentDomainForName:appDomain]) == nil) {
	[self setPersistentDomain:
                  [NSMutableDictionary dictionaryWithCapacity:16] 
              forName:appDomain];
    }
    if ((dict = [self persistentDomainForName:NSGlobalDomain]) == nil) {
	[self setPersistentDomain:
                  [NSMutableDictionary dictionaryWithCapacity:64] 
              forName:NSGlobalDomain];
    }
    
    languages = [[self persistentDomainForName:NSGlobalDomain] 
                       objectForKey:@"Languages"];
    if ((languages != nil) && ![languages isKindOfClass:[NSArray class]])
        languages = [NSArray arrayWithObjects:&languages count:1];
    for (i = 0, n = [languages count]; i < n; i++) {
	dict = [self persistentDomainForName:[languages objectAtIndex:i]];
	if (dict != nil)
	    break;
    }
    
    return self;
}

- (void)dealloc
{
    RELEASE(self->directoryForSaving);
    RELEASE(self->appDomain);
    RELEASE(self->persistentDomains);
    RELEASE(self->volatileDomains);
    RELEASE(self->searchList);
    RELEASE(self->domainsToRemove);
    RELEASE(self->dirtyDomains);
    [super dealloc];
}

- (void)makeStandardDomainSearchList
{
    int i,n;
    NSArray* languages;
    
    /* make clear list */
    [searchList removeAllObjects];
    
    /* make argument domain */
    [searchList addObject:NSArgumentDomain];
    
    /* make app domain */
    [searchList addObject:appDomain];
    
    /* make global domain */
    [searchList addObject:NSGlobalDomain];
    
    /* add languages domains */
    languages = [[self persistentDomainForName:NSGlobalDomain] 
                       objectForKey:@"Languages"];
    if (languages != nil && ![languages isKindOfClass:[NSArray class]]) 
        languages = [NSArray arrayWithObject:languages];
    else if (languages == nil)
	languages = [NSArray arrayWithObject:@"English"];
    
    for (i = 0, n = [languages count]; i < n; i++) {
	NSString* lang = [languages objectAtIndex:i];
	/* check that the domain exists */
	if ([self persistentDomainForName:lang]) {
	    [searchList addObject:lang];
	}
    }

    /* add catch-all registration domain */
    [searchList addObject:NSRegistrationDomain];
}

- (BOOL)synchronize
{
    NSEnumerator *enumerator;
    NSString     *domainName;
    BOOL         allOk = YES;
    
    enumerator = [self->dirtyDomains objectEnumerator];
    while ((domainName = [enumerator nextObject]))
	allOk = allOk && [self savePersistentDomainNamed:domainName];
    
    enumerator = [self->domainsToRemove objectEnumerator];

#if CREATE_DEFAULT_PATH_ON_DEMAND
    [self _checkPathNameCreate:YES];
#endif

    while ((domainName = [enumerator nextObject])) {
	NSString* path = [[self->directoryForSaving
			    stringByAppendingPathComponent:domainName]
			    stringByAppendingPathExtension:@"plist"];

	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
    }
    return allOk;
}

- (void)persistentDomainHasChanged:(NSString*)domainName
{
    if (![self->dirtyDomains containsObject:domainName]) {
	[self->dirtyDomains addObject:domainName];
	[[NSNotificationCenter defaultCenter]
	    postNotificationName:NSUserDefaultsDidChangeNotification
	    object:self
	    userInfo:nil];
    }
}

@end

@implementation NSUserDefaults(Internals)

- (BOOL)_checkPathNameCreate:(BOOL)_create
{
    NSString *defDir;

    defDir = self->directoryForSaving;
    
    if (([defDir stringByResolvingSymlinksInPath] == nil) ||
        (![[NSFileManager defaultManager] fileExistsAtPath:defDir])) {

        if (_create) {
            if (![[NSFileManager defaultManager]
                                 createDirectoryAtPath:defDir
                                 attributes:nil]) {
                fprintf(stderr,
                        "WARNING: could not create user defaults directory"
                        " at path %s !\n",
                        defDir
                        ? [defDir cString] : "<null>");
            }
        }
        else
            return NO;
    }
    return YES;
}

@end /* NSUserDefaults(Internals) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

