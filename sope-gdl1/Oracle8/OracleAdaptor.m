/*
**  OracleAdaptor.h
**
**  Copyright (c) 2007  Inverse groupe conseil inc. Ludovic Marcotte
**
**  Author: Ludovic Marcotte <ludovic@inverse.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#include "OracleAdaptor.h"

#import "OracleAdaptorChannel.h"
#import "OracleAdaptorContext.h"
#import "OracleSQLExpression.h"
#import "OracleValues.h"

//
//
//
@interface OracleAdaptor (Private)

- (ub2) typeForName: (NSString *) theName;

@end

@implementation OracleAdaptor (Private)

- (ub2) typeForName: (NSString *) theName
{
  ub2 t;

  theName = [theName uppercaseString];

  if ([theName isEqualToString: @"VARCHAR"])
    {
      t = SQLT_CHR;
    }
  else if ([theName isEqualToString: @"CLOB"])
    {
      t = SQLT_CLOB;
    }
  else if ([theName isEqualToString: @"DATE"])
    {
      t = SQLT_DAT;
    }
  else if ([theName isEqualToString: @"INTEGER"])
    {
      t = SQLT_INT;
    }
  else if ([theName isEqualToString: @"NUMBER"])
    {
      t = SQLT_NUM;
    }
  else if ([theName isEqualToString: @"STRING"])
    {
      t = SQLT_STR;
    }
  else if ([theName isEqualToString: @"TIMESTAMP"])
    {
      t = SQLT_TIMESTAMP;
    }
  else if ([theName isEqualToString: @"TIMESTAMP WITH TIME ZONE"])
    {
      t = SQLT_TIMESTAMP_TZ;
    }
  else if ([theName isEqualToString: @"TIMESTAMP WITH LOCAL TIME ZONE"])
    {
      t = SQLT_TIMESTAMP_LTZ;
    }

  return t;
}

@end


//
//
//
@implementation OracleAdaptor

- (id) initWithName: (NSString *) theName
{
  if ((self = [super initWithName: theName]))
    {
      // On Oracle, we must set the NLS_LANG in order to let Oracle perform
      // charset transformations for us. Since, when we write data to the database
      // and when we read data from it we assume that we are using UTF-8, we
      // set NLS_LANG to the proper value.
      setenv("NLS_LANG", "AMERICAN_AMERICA.UTF8", 1);
      
      return self;
    }
  
  return nil;
}

//
//
//
- (id) copyWithZone: (NSZone *) theZone
{
  return [self retain];
}

//
//
//
- (Class) adaptorContextClass
{
  return [OracleAdaptorContext class];
}

//
//
//
- (Class) adaptorChannelClass
{
  return [OracleAdaptorChannel class];
}

//
//
//
- (Class) expressionClass
{
  return [OracleSQLExpression class];
}

//
//
//
- (EOAdaptorContext *) createAdaptorContext
{
  return AUTORELEASE([[OracleAdaptorContext alloc] initWithAdaptor: self]);
}

//
//
//
- (NSString *) databaseName
{
  return [[self connectionDictionary] objectForKey: @"databaseName"];
}

//
//
//
- (id) formatValue: (id) theValue  forAttribute: (EOAttribute *) theAttribute
{
  NSString *s;
  
  s = [theValue stringValueForOracleType: [self typeForName: [theAttribute externalType]]
		attribute: theAttribute];
  
  NSLog(@"Formatted %@ (%@) to %@ (NSString)", theValue, NSStringFromClass([theValue class]), s);

  return s;
}

//
// We don't check the values inside the connection
// dictionary for now.s
//
- (BOOL) hasValidConnectionDictionary
{
  return ([self connectionDictionary] ? YES : NO);
}

//
//
//
- (BOOL) isValidQualifierType: (NSString *) theTypeName
{
  return YES;
}

//
//
//
- (NSString *) loginName;
{
  return [[self connectionDictionary] objectForKey: @"userName"];
}

//
//
//
- (NSString *) loginPassword
{
  return [[self connectionDictionary] objectForKey: @"password"];
}

//
//
//
- (NSString *) port
{
  return [[self connectionDictionary] objectForKey: @"port"];
}

//
//
//
- (NSString *) serverName
{
  return [[self connectionDictionary] objectForKey: @"hostName"];
}

@end
