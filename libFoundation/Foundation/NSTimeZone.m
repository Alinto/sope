/* 
   NSTimeZone.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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
#include <Foundation/NSDate.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>

#include "NSConcreteTimeZone.h"

/*
 * NSTimeZone cluster abstract class
 */

static NSString            *timeZoneInfoFilesPath  = nil;
static NSMutableDictionary *abbreviationDictionary = nil;
static NSArray             *timeZoneArray          = nil;
static NSMutableDictionary *regionsByOffset        = nil;
static NSMutableDictionary *timeZonesByName        = nil;
static NSTimeZone          *defaultTimeZone        = nil;
static NSTimeZone          *localTimeZone          = nil;

@implementation NSTimeZone

+ (NSTimeZone *)_createTimeZoneWithName:(NSString *)name
  checkDuplicates:(BOOL)checkDuplicates
{
    NSString   *filename;
    NSTimeZone *concreteTimeZone;

    if (checkDuplicates) {
	if ([timeZonesByName objectForKey:name])
	    return nil;
    }
    
    filename = [[[timeZoneInfoFilesPath
		    stringByAppendingPathComponent:@"TimeZoneInfo"]
		    stringByAppendingPathComponent:name]
		    stringByResolvingSymlinksInPath];

    if (filename) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:filename])
            filename = nil;
    }
    
    if ((filename == nil) || [filename length] == 0) {
	fprintf(stderr,
                "%s: Cannot find the time zone description file '%s' in "
		"resource directory '%s'\n",
                __PRETTY_FUNCTION__,
		[name cString], [timeZoneInfoFilesPath cString]);
	return nil;
    }
    
    concreteTimeZone = AUTORELEASE([[NSConcreteTimeZoneFile alloc]
                                       initFromFile:filename withName:name]);
    [timeZonesByName setObject:concreteTimeZone forKey:name];

    return concreteTimeZone;
}

+ (void)initialize
{
    static BOOL didInit = NO;

    if (didInit)
	return;

    didInit = YES;

    {
        NSDictionary *regionsDictionary;
        id           regionsFile = nil;
        NSString     *offset;
        NSEnumerator *enumerator;
        NSString     *abbreviation;
        CREATE_AUTORELEASE_POOL(pool);
	
        timeZonesByName = [[NSMutableDictionary alloc] init];
        regionsFile = [NSBundle _fileResourceNamed:@"RegionsDictionary"
                                extension:nil
                                inDirectory:@"TimeZoneInfo"];
        
        if (regionsFile == nil || [regionsFile length] == 0) {
            fprintf(stderr,
                    "ERROR(%s): Cannot find the "
		    "'TimeZoneInfo/RegionsDictionary' "
                    "resource file for NSTimeZone\n",
		    __PRETTY_FUNCTION__);
            return;
        }
        timeZoneInfoFilesPath
            = RETAIN([[regionsFile stringByDeletingLastPathComponent]
                         stringByDeletingLastPathComponent]);
        regionsDictionary = [[NSString stringWithContentsOfFile:regionsFile]
                                propertyList];
        
        regionsByOffset = [[regionsDictionary objectForKey:@"RegionsByOffset"]
                              mutableCopy];
        if (regionsByOffset == nil) {
            fprintf(stderr,
                    "ERROR: No regions by offset in the '%s' resource file ("
                    "under key 'RegionsByOffset')\n", [regionsFile cString]);
            return;
        }
        
        timeZoneArray = RETAIN([[regionsDictionary
                                    objectForKey:@"RegionsByOffset"]
                                   allValues]);
        enumerator = [regionsByOffset keyEnumerator];
        while ((offset = [enumerator nextObject])) {
            NSMutableArray *longitudinalRegions
                = AUTORELEASE([[regionsByOffset objectForKey:offset]
                                  mutableCopy]);
            int j, count2;

            [regionsByOffset setObject:longitudinalRegions forKey:offset];
            for (j = 0, count2 = [longitudinalRegions count]; j < count2; j++){
                NSString* timeZoneName = [longitudinalRegions objectAtIndex:j];
                NSTimeZone* timeZone;

                timeZone = [timeZonesByName objectForKey:timeZoneName];
                if (!timeZone)
                    timeZone = [self _createTimeZoneWithName:timeZoneName
                                     checkDuplicates:NO];

                [longitudinalRegions replaceObjectAtIndex:j
                                     withObject:timeZone];
            }
        }

        abbreviationDictionary = [[regionsDictionary
                                      objectForKey:@"Abbreviations"]
                                     mutableCopy];
        if (abbreviationDictionary == nil) {
            fprintf(stderr,
                    "ERROR: No abbreviation dictionary in the '%s' "
                    "resource file (under key 'Abbreviations')\n", 
                    [regionsFile cString]);
            return;
        }
        enumerator = [abbreviationDictionary keyEnumerator];
        while ((abbreviation = [enumerator nextObject])) {
            NSString* timeZoneName
		= [abbreviationDictionary objectForKey:abbreviation];
            NSTimeZone* timeZone = [timeZonesByName objectForKey:timeZoneName];

            if (timeZone == nil) {
                fprintf(stderr,
                        "warning: time zone '%s' is not declared in the "
                        "'RegionsByOffset' dictionary in resource file '%s'\n",
                        [timeZoneName cString], [regionsFile cString]);
                timeZone = [self _createTimeZoneWithName:timeZoneName
                                 checkDuplicates:NO];
            }

            if (timeZone)
                [abbreviationDictionary setObject:timeZone
                                        forKey:abbreviation];
        }

        RELEASE(pool);
    }
}

+ (void)setDefaultTimeZone:(NSTimeZone*)aTimeZone
{
#if SYNC_DEF_TZ
    NSUserDefaults* userDef = [NSUserDefaults standardUserDefaults];
#endif

    ASSIGN(defaultTimeZone, aTimeZone);
    ASSIGN(localTimeZone,   aTimeZone);

#if SYNC_DEF_TZ
    [userDef setObject:[defaultTimeZone timeZoneName] forKey:@"TimeZoneName"];
    [userDef synchronize];
#endif
}

+ (NSTimeZone *)defaultTimeZone
{
    if (defaultTimeZone == nil) {
	NSUserDefaults *userDef;
	NSString       *zName;
	static BOOL isSettingTZ = NO; /* protect against recursion */
	
	if (isSettingTZ) {
	    /* do not use NSLog, which uses NSTimeZone => recursion ... */
	    fprintf(stderr, 
		    "ERROR(%s): recursive call! (libFoundation setup is "
		    "probably mixed up)\n", 
		    __PRETTY_FUNCTION__);
	    return nil;
	}
	
	isSettingTZ = YES;
	
	userDef = [NSUserDefaults standardUserDefaults];
	zName   = [userDef stringForKey:@"TimeZoneName"];
	defaultTimeZone = RETAIN([self timeZoneWithName:zName]);
	
	if (defaultTimeZone == nil)
	    defaultTimeZone = RETAIN([self timeZoneWithAbbreviation:zName]);
	
	if (defaultTimeZone == nil)
	    defaultTimeZone = RETAIN([self timeZoneWithAbbreviation:@"GMT"]);
	isSettingTZ = NO;
    }

    return defaultTimeZone;
}

+ (NSTimeZone *)localTimeZone
{
    if (localTimeZone == nil) {
	// TODO : subclass NS*TimeZone to have a special encoding class
	localTimeZone = RETAIN([self defaultTimeZone]);
    }
    
    return localTimeZone;
}

+ (NSDictionary *)abbreviationDictionary
{
    return abbreviationDictionary;
}

+ (NSArray *)timeZoneArray
{
    return timeZoneArray;
}

+ (NSTimeZone *)timeZoneWithName:(NSString *)name
{
    NSTimeZone* timezone;

    if (!name)
	return nil;

    if (!(timezone = [timeZonesByName objectForKey:name]))
	timezone = [self _createTimeZoneWithName:name checkDuplicates:NO];

    return timezone;
}

+ (NSTimeZone *)timeZoneWithAbbreviation:(NSString *)abbreviation
{
    return [abbreviationDictionary objectForKey:abbreviation];
}

+ (NSTimeZone *)timeZoneForSecondsFromGMT:(int)seconds
{
    BOOL              isNegative = (seconds < 0);
    int               hours, minutes;
    NSString*         offset;
    NSArray*          timeZoneArray;
    NSArray*          details;
    NSTimeZoneDetail* detail;
    NSTimeZone*       timeZone;
    int               i, j, count1, count2;
    char              buf[16];
    
    hours   = abs (seconds) / 3600;
    minutes = (abs (seconds) - hours * 3600) / 60;
    
    sprintf(buf, "%c%02d%02d", (isNegative ? '-' : '+'), hours, minutes);
    offset = [NSString stringWithCString:buf];
    
    timeZoneArray = [regionsByOffset objectForKey:offset];

    /* If there is no matching zone create an instance of NSConcreteTimeZone
       with a single detail whose offset is `seconds'. */
    if (timeZoneArray == nil)
	return [NSConcreteTimeZone timeZoneWithOffset:seconds];

    /* Do a search to find a zone that has a detail with no daylight
       saving which has the offset equal with `seconds'. */
    for (i = 0, count1 = [timeZoneArray count]; i < count1; i++) {
	timeZone = [timeZoneArray objectAtIndex:i];
	details = [timeZone timeZoneDetailArray];

	/* Find a time zone that has a detail which is not daylight saving
	   and has the offset equal with `seconds'. If no such detail is
	   found the search either continues or ends depending on the offset
	   of detail. */
	for (j = 0, count2 = [details count]; j < count2; j++) {
	    detail = [details objectAtIndex:j];
	    if (![detail isDaylightSavingTimeZone]
		&& [detail timeZoneSecondsFromGMT] == seconds)
		    return timeZone;
	}
    }

    fprintf(stderr,
            "warning: unexpected failure of +timeZoneForSecondsFromGMT: "
	    "method. All the timezones specified for offset %s do not "
	    "contain a detail whose non daylight saving offset is equal to "
	    "%s!\n", [offset cString], [offset cString]);

    /* Return something useful even if there was an error! */
    return [NSConcreteTimeZone timeZoneWithOffset:seconds];
}

- (NSString *)timeZoneName
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSArray *)timeZoneDetailArray
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSTimeZoneDetail *)timeZoneDetailForDate:(NSDate *)date
{
    /* deprecated in MacOSXS */
    return (id)[self timeZoneForDate:date];
}
- (NSTimeZone *)timeZoneForDate:(NSDate *)date
{
    /* new in MacOSXS */
    [self subclassResponsibility:_cmd];
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSString *)description
{
    return [[self timeZoneName] description];
}

// New methods in MacOSX

- (NSString *)abbreviation
{
    return [self abbreviationForDate:[NSCalendarDate date]];
}
- (NSString *)abbreviationForDate:(NSDate *)_date
{
    return [[self timeZoneForDate:_date] timeZoneAbbreviation];
}

- (BOOL)isDaylightSavingTime
{
    return [self isDaylightSavingTimeForDate:[NSCalendarDate date]];
}
- (BOOL)isDaylightSavingTimeForDate:(NSDate *)_date
{
    return [[self timeZoneForDate:_date] isDaylightSavingTimeZone];
}

- (int)secondsFromGMT
{
    return [self secondsFromGMTForDate:[NSCalendarDate date]];
}
- (int)secondsFromGMTForDate:(NSDate *)_date
{
    return [[self timeZoneForDate:_date] timeZoneSecondsFromGMT];
}

- (int)timeZoneSecondsFromGMT
{	
    [self subclassResponsibility:_cmd];
    return 0;
}

- (NSString *)timeZoneAbbreviation
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (BOOL)isDaylightSavingTimeZone
{
    [self subclassResponsibility:_cmd];
    return NO;
}

/* equality */

- (BOOL)isEqual:(id)anObject
{
    if (anObject == self) return YES;

    return ([super isEqual:anObject]
	// this checks to ensure that they're the same class
	&& [[self timeZoneName] isEqual:[anObject timeZoneName]]
	&& [[self timeZoneAbbreviation] 
		isEqual:[anObject timeZoneAbbreviation]]
	&& [self isDaylightSavingTimeZone] 
		== [anObject isDaylightSavingTimeZone]
	&& [self timeZoneSecondsFromGMT] 
		== [anObject timeZoneSecondsFromGMT]);
}

- (unsigned)hash
{
    // This should be sufficient for hashing
    return [self timeZoneSecondsFromGMT];
}

/* NSCoding */

- (Class)classForCoder
{
    return [NSTimeZone class];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[self timeZoneName]];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *timeZoneName = [aDecoder decodeObject];
    return [NSTimeZone timeZoneWithName:timeZoneName];
}

@end /* NSTimeZone */

/*
 * NSTimeZone detail (concrete non-mutable subclass of NSTimeZone)
 */

@implementation NSTimeZoneDetail /* deprecated in MacOSXS */

@end /* NSTimeZoneDetail */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
