/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

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

#import "common.h"
#import "EOAttribute.h"
#import "EOModel.h"
#import "EOEntity.h"
#import "EORelationship.h"
#import "EOExpressionArray.h"
#import "EOCustomValues.h"
#import <EOControl/EONull.h>
#import "EOFExceptions.h"

@interface NSString(BeautifyAttributeName)

- (NSString *)_beautifyAttributeName;

@end

@implementation EOAttribute

static NSString *defaultCalendarFormat = @"%b %d %Y %H:%M";
static EONull   *null = nil;

+ (void)initialize {
  if (null == nil)
    null = [[EONull null] retain];
}

- (id)initWithName:(NSString*)_name {
  if ((self = [super init])) {
    ASSIGN(self->name,_name);
    self->entity = nil;
  }
  return self;
}
- (id)init {
  return [self initWithName:nil];
}

- (void)dealloc {
  [self->name           release];
  [self->calendarFormat release];
  [self->clientTimeZone release];
  [self->serverTimeZone release];
  [self->columnName     release];
  [self->externalType   release];
  [self->valueClassName release];
  [self->valueType      release];
  [self->userDictionary release];
  self->entity = nil; /* non-retained */
  [super dealloc];
}

// These methods should be here to let the library work with NeXT foundation
- (id)copy {
  return [self retain];
}
- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

// Is equal only if same name; used to make aliasing ordering stable
- (unsigned)hash {
  return [self->name hash];
}

- (BOOL)setName:(NSString*)_name {
  if([name isEqual:_name])
    return YES;

  if([entity attributeNamed:_name])
    return NO;

  ASSIGN(name, _name);
  return YES;
}

+ (BOOL)isValidName:(NSString*)_name {
  return [EOEntity isValidName:_name];
}

- (BOOL)referencesProperty:(id)property { // TODO: still used?
  return NO;
}

- (NSString *)expressionValueForContext:(id<EOExpressionContext>)context {
  return (context != nil)
    ? [context expressionValueForAttribute:self]
    : columnName;
}

- (void)setEntity:(EOEntity*)_entity {
  self->entity = _entity; /* non-retained */
}
- (EOEntity *)entity {
  return self->entity;
}
- (void)resetEntity {
  self->entity = nil;
}
- (BOOL)hasEntity {
  return (self->entity != nil) ? YES : NO;
}

- (void)setCalendarFormat:(NSString*)format {
  ASSIGN(self->calendarFormat, format);
}
- (NSString *)calendarFormat {
  return self->calendarFormat;
}

- (void)setClientTimeZone:(NSTimeZone*)tz {
  ASSIGN(self->clientTimeZone, tz);
}
- (NSTimeZone *)clientTimeZone {
  return self->clientTimeZone;
}

- (void)setServerTimeZone:(NSTimeZone*)tz {
  ASSIGN(self->serverTimeZone, tz);
}
- (NSTimeZone *)serverTimeZone {
  return self->serverTimeZone;
}

- (void)setColumnName:(NSString *)_name {
  ASSIGNCOPY(self->columnName, _name);
}
- (NSString *)columnName {
  return self->columnName;
}

- (void)setExternalType:(NSString *)type {
  ASSIGNCOPY(self->externalType, type);
}
- (NSString *)externalType {
  return self->externalType;
}

- (void)setValueClassName:(NSString *)_name {
  ASSIGNCOPY(self->valueClassName, _name);
}
- (NSString *)valueClassName {
  return self->valueClassName;
}

- (void)setValueType:(NSString *)type {
  ASSIGN(self->valueType, type);
}
- (NSString *)valueType {
  return self->valueType;
}

- (void)setUserDictionary:(NSDictionary *)dict {
  ASSIGN(self->userDictionary, dict);
}
- (NSDictionary *)userDictionary {
  return self->userDictionary;
}

+ (NSString *)defaultCalendarFormat {
  return defaultCalendarFormat;
}
- (NSString *)name {
  return self->name;
}

/* description */

- (NSString *)description {
  return [[self propertyList] description];
}

/* EOAttributePrivate */

+ (EOAttribute*)attributeFromPropertyList:(id)propertyList {
  NSDictionary *plist = propertyList;
  EOAttribute *attribute = nil;
  NSString    *timeZoneName;
  id          tmp;
  
  attribute = [[[EOAttribute alloc] init] autorelease];
  
  [attribute setName:[plist objectForKey:@"name"]];
  [attribute setCalendarFormat:[plist objectForKey:@"calendarFormat"]];

  timeZoneName = [plist objectForKey:@"clientTimeZone"];
  if (timeZoneName)
    [attribute setClientTimeZone:[NSTimeZone timeZoneWithName:timeZoneName]];

  timeZoneName = [plist objectForKey:@"serverTimeZone"];
  if (timeZoneName)
    [attribute setServerTimeZone:[NSTimeZone timeZoneWithName:timeZoneName]];
  
  [attribute setColumnName:    [plist objectForKey:@"columnName"]];
  [attribute setExternalType:  [plist objectForKey:@"externalType"]];
  [attribute setValueClassName:[plist objectForKey:@"valueClassName"]];
  [attribute setValueType:     [plist objectForKey:@"valueType"]];
  [attribute setUserDictionary:[plist objectForKey:@"userDictionary"]];
  
  if ((tmp = [plist objectForKey:@"allowsNull"]))
    [attribute setAllowsNull:[tmp isEqual:@"Y"]];
  else
    [attribute setAllowsNull:YES];
  
  [attribute setWidth:[[plist objectForKey:@"width"] unsignedIntValue]];
  return attribute;
}

/* WARNING: You should call this method from entity after the relationships
   were constructed and after the `attributes' array contains the real
   attributes. */
- (void)replaceStringsWithObjects {
}

- (id)propertyList {
  NSMutableDictionary *propertyList;

  propertyList = [NSMutableDictionary dictionaryWithCapacity:16];
  [self encodeIntoPropertyList:propertyList];
  return propertyList;
}

- (int)compareByName:(EOAttribute *)_other {
  return [[(EOAttribute *)self name] compare:[_other name]];
}

/* ValuesConversion */

- (id)convertValue:(id)aValue toClass:(Class)aClass forType:(NSString*)_type {
  // Check nil/EONull
  if (aValue == nil)
    return nil;
  if (aValue == null)
    return aValue;
  
  // Check if we need conversion; we use is kind of because 
  // a string is not a NSString but some concrete class, so is NSData,
  // NSNumber and may be other classes
  if ([aValue isKindOfClass:aClass])
    return aValue;
    
  // We have to convert the aValue
  
  // Try EOCustomValues
  if ([aValue respondsToSelector:@selector(stringForType:)]) {
    // Special case if aClass is NSNumber
    if (aClass == [NSNumber class]) {
      return [NSNumber numberWithString:[aValue stringForType:_type]
		       type:_type];
    }
        
    // Even more Special case if aClass is NSCalendar date
    if (aClass == [NSCalendarDate class]) {
      /* we enter this section even if the value is a NSDate object, or
	 NSCFDate on Cocoa */
      NSCalendarDate *date;
      NSString       *format;
      
      format = [self calendarFormat];
      if (format == nil)
        format = [EOAttribute defaultCalendarFormat];
      
      if ([aValue isKindOfClass:[NSDate class]]) {
	// TBD: this does not catch NSCFDate?!
	date = [NSCalendarDate dateWithTimeIntervalSince1970:
				 [(NSDate *)aValue timeIntervalSince1970]];
      }
      else {
	date = [NSCalendarDate dateWithString:[aValue stringForType:_type]
			       calendarFormat:format];
	if (date == nil) {
	  NSLog(@"WARN: could not create NSCalendarDate using format %@ "
		@"from value: %@", format, aValue);
	}
      }
      
      [date setCalendarFormat:format];
      return date;
    }
    
    // See if we can alloc a new aValue and initilize it
    if ([aClass instancesRespondToSelector:
                @selector(initWithString:type:)]) {
      // Note: this is still problematic! Eg NSString instances respond to
      //       initWithString:type:, but NSTemporaryString doesn't.
      //       EOCustomValues contains a lF specific for that situation.

      return AUTORELEASE([[aClass alloc] 
                                  initWithString:[aValue stringForType:_type]
                                  type:_type]);
    }
  }
    
  // Try EODatabaseCustomValues
  if ([aValue respondsToSelector:@selector(dataForType:)]) {
    // See if we can alloc a new aValue and initilize it
    if ([aClass instancesRespondToSelector:
                @selector(initWithData:type:)]) {
      return AUTORELEASE([[aClass alloc] 
                                  initWithData:[aValue dataForType:_type]
                                  type:_type]);
    }
  }
    
  // Could not convert if got here
  return nil;
}

- (id)convertValueToModel:(id)aValue {
  id aValueClassName;
  Class aValueClass;
  
  // Check value class from attribute
  aValueClassName = [self valueClassName];
  aValueClass     = NSClassFromString(aValueClassName);
  if (aValueClass == Nil)
    return aValue;
    
  return [self convertValue:aValue 
               toClass:aValueClass forType:[self valueType]];
}

@end /* EOAttribute */

@implementation NSString(EOAttributeTypeCheck)

- (BOOL)isNameOfARelationshipPath {
  BOOL result = NO;
  char buf[[self cStringLength] + 1];
  const char *s;
  
  s = buf;
  [self getCString:buf];
  
  if(!isalnum((int)*s) && *s != '@' && *s != '_' && *s != '#')
    return NO;

  for(++s; *s; s++) {
    if(!isalnum((int)*s) && *s != '@' && *s != '_' && *s != '#' && *s != '$'
       && *s != '.')
      return NO;
    if(*s == '.')
      result = YES;
  }

  return result;
}

@end /* NSString(EOAttributeTypeCheck) */

@implementation EOAttribute(PropertyListCoding)

static inline void _addToPropList(NSMutableDictionary *propertyList,
                                  id _value, NSString *key) {
  if (_value != nil) [propertyList setObject:_value forKey:key];
}

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist {
  _addToPropList(_plist, self->name,           @"name");
  _addToPropList(_plist, self->calendarFormat, @"calendarFormat");
  _addToPropList(_plist, self->columnName,     @"columnName");
  _addToPropList(_plist, self->externalType,   @"externalType");
  _addToPropList(_plist, self->valueClassName, @"valueClassName");
  _addToPropList(_plist, self->valueType,      @"valueType");
  _addToPropList(_plist, self->userDictionary, @"userDictionary");
  
  if (self->clientTimeZone) {
#if !LIB_FOUNDATION_LIBRARY
    [_plist setObject:[self->clientTimeZone name]
            forKey:@"clientTimeZone"];
#else
    [_plist setObject:[self->clientTimeZone timeZoneName]
            forKey:@"clientTimeZone"];
#endif
  }
  if (self->serverTimeZone) {
#if !LIB_FOUNDATION_LIBRARY
    [_plist setObject:[self->serverTimeZone name]
            forKey:@"serverTimeZone"];
#else
    [_plist setObject:[self->serverTimeZone timeZoneName]
            forKey:@"serverTimeZone"];
#endif
  }

  if (self->width != 0) {
    [_plist setObject:[NSNumber numberWithUnsignedInt:self->width]
            forKey:@"width"];
  }
  if (self->flags.allowsNull) {
    [_plist setObject:[NSString stringWithCString:"Y"]
            forKey:@"allowsNull"];
  }
}

@end /* EOAttribute(PropertyListCoding) */

@implementation EOAttribute(EOF2Additions)

- (void)beautifyName {
  [self setName:[[self name] _beautifyAttributeName]];
}

/* constraints */

- (void)setAllowsNull:(BOOL)_flag {
  self->flags.allowsNull = _flag ? 1 : 0;
}
- (BOOL)allowsNull {
  return self->flags.allowsNull ? YES : NO;
}

- (void)setWidth:(unsigned)_width {
  self->width = _width;
}
- (unsigned)width {
  return self->width;
}

- (NSException *)validateValue:(id *)_value {
  if (_value == NULL) return nil;
  
  /* check NULL constraint */
  if (!self->flags.allowsNull) {
    if ((*_value == nil) || (*_value == null)) {
      NSException *e;
      NSDictionary *ui;
      
      ui = [NSDictionary dictionaryWithObjectsAndKeys:
                           *_value ? *_value : (id)null, @"value",
                           self,                     @"attribute",
                           nil];
      
      e = [NSException exceptionWithName:@"EOValidationException"
                       reason:@"violated not-null constraint"
                       userInfo:ui];
      return e;
    }
  }
  
  /* check width constraint */
  
  if (self->width != 0) {
    static Class NSDataClass   = Nil;
    static Class NSStringClass = Nil;

    if (NSDataClass   == nil) NSDataClass   = [NSData   class];
    if (NSStringClass == nil) NSStringClass = [NSString class];
    
    if ([(NSObject *)[*_value class] isKindOfClass:NSDataClass]) {
      unsigned len;
      
      len = [*_value length];
      if (len > self->width) {
        NSException *e;
        NSDictionary *ui;
        
        ui = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedInt:self->width],
                             @"maxWidth",
                             [NSNumber numberWithUnsignedInt:len], @"width",
			     *_value ? *_value : (id)null,         @"value",
                             self,                                 @"attribute",
                             nil];
        
        e = [NSException exceptionWithName:@"EOValidationException"
                         reason:@"data value exceeds allowed attribute width"
                         userInfo:ui];
        return e;
      }
    }
    else if ([(NSObject *)[*_value class] isKindOfClass:NSStringClass]) {
      unsigned len;
      
      len = [*_value cStringLength];
      if (len > self->width) {
        NSException *e;
        NSDictionary *ui;
        
        ui = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedInt:self->width],
                             @"maxWidth",
                             [NSNumber numberWithUnsignedInt:len], @"width",
			   *_value ? *_value : (id)null,           @"value",
                             self,                                 @"attribute",
                             nil];
        
        e = [NSException exceptionWithName:@"EOValidationException"
                         reason:@"string value exceeds allowed attribute width"
                         userInfo:ui];
        return e;
      }
    }
  }
  
  return nil;
}

@end /* EOAttribute(EOF2Additions) */

@implementation NSString(BeautifyAttributeName)

- (NSString *)_beautifyAttributeName {
  // DML Unicode
  unsigned clen = 0;
  char     *s   = NULL;
  unsigned cnt, cnt2;

  if ([self length] == 0)
    return @"";

  clen = [self cStringLength];
#if GNU_RUNTIME
  s = objc_atomic_malloc(clen + 4);
#else
  s = malloc(clen + 4);
#endif

  [self getCString:s maxLength:clen];
    
  for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
      if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
        s[cnt2] = toupper(s[cnt + 1]);
        cnt++;
      }
      else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
        s[cnt2] = s[cnt];
        cnt++;
        cnt2++;
        s[cnt2] = toupper(s[cnt]);
      }
      else
        s[cnt2] = tolower(s[cnt]);
  }
  s[cnt2] = '\0';

#if !LIB_FOUNDATION_LIBRARY
  {
      NSString *os;

      os = [NSString stringWithCString:s];
      free(s);
      return os;
  }
#else
  return [NSString stringWithCStringNoCopy:s freeWhenDone:YES];
#endif
}

@end /* NSString(BeautifyAttributeName) */
