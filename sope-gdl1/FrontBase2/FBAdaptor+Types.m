/* 
   FBAdaptor+Types.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
// $Id: FBAdaptor+Types.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#include "FrontBase2Adaptor.h"
#include "FBChannel.h"
#include "FBContext.h"

@interface FrontBase2Adaptor(DomainResolver)
- (BOOL)fetchDomainInfo;
@end

@implementation FrontBase2Adaptor(DomainResolver)

typedef struct _InternalTypeMapping {
  int      code;
  NSString *name;
} InternalTypeMapping;

static InternalTypeMapping internalTypeMappings[] = {
  { FB_PrimaryKey,   @"PRIMARYKEY" },
  { FB_Boolean,      @"BOOLEAN"  },
  { FB_Integer,      @"INTEGER"  },
  { FB_SmallInteger, @"SMALLINT" },
  { FB_Float,        @"FLOAT"    },
  { FB_Real,         @"REAL"     },
  { FB_Double,       @"DOUBLE"   },
  { FB_Numeric,      @"NUMERIC"  },
  { FB_Decimal,      @"DECIMAL"  },
  { FB_Character,    @"CHAR"     },
  { FB_VCharacter,   @"VARCHAR"  },
  { FB_Bit,          @"BIT"      },
  { FB_VBit,         @"VARBIT"   },
  { FB_Date,         @"DATE"     },
  { FB_Time,         @"TIME"     },
  { FB_TimeTZ,       @"TIME WITH TIME ZONE"      },
  { FB_Timestamp,    @"TIMESTAMP"                },
  { FB_TimestampTZ,  @"TIMESTAMP WITH TIME ZONE" },
  { FB_YearMonth,    @"INTERVAL YEAR TO MONTH"   },
  { FB_DayTime,      @"INTERVAL DAY TO SECOND"   },
  { FB_CLOB,         @"CLOB" },
  { FB_BLOB,         @"BLOB" },
  { -1, nil } // end marker
};

static NSString *DomainQuery =
  @"SELECT \"DOMAIN_NAME\" FROM INFORMATION_SCHEMA.domains";

- (void)_resetTypeMapping {
  if (self->typeNameToCode) {
    NSFreeMapTable(self->typeNameToCode);
    self->typeNameToCode = NULL;
  }
  if (self->typeCodeToName) {
    NSFreeMapTable(self->typeCodeToName);
    self->typeCodeToName = NULL;
  }
}

- (void)_loadStandardTypes {
  register InternalTypeMapping *mapping;
  
  if (self->typeNameToCode == NULL) {
    self->typeNameToCode = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSIntMapValueCallBacks,
                                            64);
  }
  if (self->typeCodeToName == NULL) {
    self->typeCodeToName = NSCreateMapTable(NSIntMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            64);
  }

  mapping = &(internalTypeMappings[1]);

  while (mapping->name != nil) {
    NSMapInsert(self->typeCodeToName,
                (void *)(mapping->code),
                (void *)mapping->name);
    NSMapInsert(self->typeNameToCode,
                (void *)mapping->name,
                (void *)(mapping->code));
    mapping++;
  }
}

- (BOOL)fetchDomainInfo {
  FrontBaseContext *ctx;
  FrontBaseChannel *channel;
  BOOL result;

  if (self->typeNameToCode == NULL)
    [self _loadStandardTypes];

  result  = NO;
  ctx     = (FrontBaseContext *)[self createAdaptorContext];
  channel = (FrontBaseChannel *)[ctx  createAdaptorChannel];

  if ([channel openChannel]) {
    if ([ctx beginTransaction]) {
      if ([channel evaluateExpression:DomainQuery]) {
        NSArray        *attributes;
        NSDictionary   *record;
        NSMutableArray *domains;

        attributes = [channel describeResults];
        domains    = nil;

        while ((record = [channel fetchAttributes:attributes withZone:NULL])) {
          NSString *domainName;

          if ((domainName = [record objectForKey:@"domainName"])) {
            if (![domainName hasPrefix:@"T_"])
              continue;
            
            if (domains == nil)
              domains = [NSMutableArray arrayWithCapacity:32];
            [domains addObject:domainName];
          }
          else
            NSLog(@"no domain name in record %@ ?", record);
        }

        /* no get the meta-info of the domains */

        if ([domains count] > 0) {
          /* we need to resolve domains, construct a VALUES expression .. */
          NSMutableString *expr;
          NSEnumerator *e;
          NSString     *domainName;
          BOOL         isFirst = YES;

          expr = [NSMutableString stringWithCapacity:512];
          [expr appendString:@"VALUES("];
          
          e = [domains objectEnumerator];
          while ((domainName = [e nextObject])) {
            if (isFirst) isFirst = NO;
            else [expr appendString:@","];

            [expr appendString:@"CAST(NULL AS \""];
            [expr appendString:domainName];
            [expr appendString:@"\")"];
          }

          [expr appendString:@")"];

          //NSLog(@"expr: %@", expr);
          
          /* now execute expression */

          if ([channel evaluateExpression:expr]) {
            int *dc = channel->datatypeCodes;
            int i;

            for (i = 0; i < channel->numberOfColumns; i++) {
              if (dc[i] > 0) {
                NSString *domainName;

                domainName = [[domains objectAtIndex:i] uppercaseString];
                
                //NSMapInsert(self->typeCodeToName, (void *)dc[i], domainName);
                NSMapInsert(self->typeNameToCode, domainName, (void *)dc[i]);
#if 0
                NSLog(@"domain %@ is code %i type %@",
                      domainName,
                      dc[i],
                      NSMapGet(self->typeCodeToName, (void*)dc[i]));
#endif
              }
            }
            
            [channel cancelFetch];
            
            result = YES;
            if (![ctx commitTransaction])
              NSLog(@"couldn't common tx for domain-resolver ..");
          }
          else
            NSLog(@"couldn't evaluate expression: %@", expr);
        }
      }
      else
        NSLog(@"couldn't evaluate expression: %@", DomainQuery);
      if (!result) [ctx rollbackTransaction];
    }
    else
      NSLog(@"couldn't begin tx for domain-resolver ..");

    [channel closeChannel];
  }
  else
    NSLog(@"couldn't open channel for domain-resolver ..");
  
  return result;
}

@end

@implementation FrontBase2Adaptor(ExternalTyping)

- (int)typeCodeForExternalName:(NSString *)_typeName {
  int code;

  _typeName = [_typeName uppercaseString];
  
  if (self->typeNameToCode == NULL)
    [self fetchDomainInfo];

  if (self->typeNameToCode == NULL)
    return FB_VCharacter;

  if ((code = (int)NSMapGet(self->typeNameToCode, _typeName)))
    return code;

  return FB_VCharacter;
}

- (NSString *)externalNameForTypeCode:(int)_typeCode {
  if (_typeCode == 0)
    return nil;

  if (self->typeCodeToName == NULL)
    [self fetchDomainInfo];
  
  return NSMapGet(self->typeCodeToName, (void *)_typeCode);
}

- (BOOL)isInternalBlobType:(int)_type {
  switch (_type) {
    case FB_BLOB:
    case FB_CLOB:
      return YES;

    default:
      return NO;
  }
}

- (BOOL)isBlobAttribute:(EOAttribute *)_attr {
  int fbType;
  
  NSAssert(_attr, @"missing attribute parameter");

  fbType = [self typeCodeForExternalName:[_attr externalType]];
  
  return [self isInternalBlobType:fbType];
}

- (BOOL)isValidQualifierType:(NSString *)_typeName {
  switch ([self typeCodeForExternalName:_typeName]) {
    case FB_BLOB:
    case FB_CLOB:
      return NO;

    default:
      return YES;
  }
}

- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr {
  NSAssert(_attr, @"missing attribute parameter");
  return YES;
}

@end
