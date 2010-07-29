/* 
   NSUserDefaults.h

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

#ifndef __NSUserDefaults_h__
#define __NSUserDefaults_h__

#include <Foundation/NSObject.h>

@class NSString, NSData;
@class NSArray, NSMutableArray;
@class NSDictionary, NSMutableDictionary;
@class NSMutableSet;

@interface NSUserDefaults : NSObject
{
    NSString            *directoryForSaving;
    NSString            *appDomain;
    NSMutableDictionary *persistentDomains;
    NSMutableDictionary *volatileDomains;
    NSMutableArray      *searchList;
    NSMutableSet        *domainsToRemove;
    NSMutableSet        *dirtyDomains;
}

/* Creation of defaults */

+ (NSUserDefaults *)standardUserDefaults;
+ (void)synchronizeStandardUserDefaults:(id)sender;

/* Getting and Setting a Default */

- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
- (NSData *)dataForKey:(NSString *)defaultName;
- (NSArray *)stringArrayForKey:(NSString *)defaultName;
- (NSString *)stringForKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;
- (int)integerForKey:(NSString *)defaultName;

- (id)objectForKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (void)setInteger:(int)value forKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;

/* Initializing the User Defaults */

- (id)init;
- (id)initWithUser:(NSString *)userName;
- (id)initWithPath:(NSString *)pathName;
- (void)makeStandardDomainSearchList;

/* Returning the Search List */

- (void)setSearchList:(NSArray *)_array;
- (NSArray *)searchList;

/* Maintaining Persistent Domains */

- (NSDictionary *)persistentDomainForName:(NSString *)domainName;
- (NSArray *)persistentDomainNames;
- (void)removePersistentDomainForName:(NSString *)domainName;
- (void)setPersistentDomain:(NSDictionary *)domain
  forName:(NSString *)domainName;
- (BOOL)synchronize;
- (void)persistentDomainHasChanged:(NSString *)domainName;

/* Maintaining Volatile Domains */

- (void)removeVolatileDomainForName:(NSString *)domainName;
- (void)setVolatileDomain:(NSDictionary *)domain  
  forName:(NSString *)domainName;
- (NSDictionary *)volatileDomainForName:(NSString *)domainName;
- (NSArray *)volatileDomainNames;

/* Making Advanced Use of Defaults */

- (NSDictionary *)dictionaryRepresentation;
- (void)registerDefaults:(NSDictionary *)dictionary;

@end

/* Defaults domains */
LF_EXPORT NSString *NSArgumentDomain;
LF_EXPORT NSString *NSGlobalDomain;
LF_EXPORT NSString *NSRegistrationDomain;

/* Defaults Domains */
LF_EXPORT  NSString *NSArgumentDomain;
LF_EXPORT  NSString *NSGlobalDomain;
LF_EXPORT  NSString *NSRegistrationDomain;
/* Notification name */
LF_EXPORT  NSString *NSUserDefaultsDidChangeNotification;
/* Defaults names */
LF_EXPORT  NSString *NSWeekDayNameArray;	
LF_EXPORT  NSString *NSShortWeekDayNameArray;
LF_EXPORT  NSString *NSMonthNameArray;
LF_EXPORT  NSString *NSShortMonthNameArray;
LF_EXPORT  NSString *NSTimeFormatString;
LF_EXPORT  NSString *NSDateFormatString;
LF_EXPORT  NSString *NSTimeDateFormatString;
LF_EXPORT  NSString *NSShortTimeDateFormatString;
LF_EXPORT  NSString *NSCurrencySymbol;
LF_EXPORT  NSString *NSDecimalSeparator;
LF_EXPORT  NSString *NSThousandsSeparator;
LF_EXPORT  NSString *NSInternationalCurrencyString;
LF_EXPORT  NSString *NSCurrencyString;
LF_EXPORT  NSString *NSDecimalDigits;
LF_EXPORT  NSString *NSAMPMDesignation;
LF_EXPORT  NSString *NSHourNameDesignations;
LF_EXPORT  NSString *NSYearMonthWeekDesignations;
LF_EXPORT  NSString *NSEarlierTimeDesignations;
LF_EXPORT  NSString *NSLaterTimeDesignations;
LF_EXPORT  NSString *NSThisDayDesignations;
LF_EXPORT  NSString *NSNextDayDesignations;
LF_EXPORT  NSString *NSNextNextDayDesignations;
LF_EXPORT  NSString *NSPriorDayDesignations;
LF_EXPORT  NSString *NSDateTimeOrdering;
LF_EXPORT  NSString *NSShortDateFormatString;
LF_EXPORT  NSString *NSPositiveCurrencyFormatString;
LF_EXPORT  NSString *NSNegativeCurrencyFormatString;

#endif /* __NSUserDefaults_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
