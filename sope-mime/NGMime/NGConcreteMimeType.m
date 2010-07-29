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

#include "NGConcreteMimeType.h"
#include "common.h"

@implementation NGParameterMimeType

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters
{
  self->subType    = [_subType    copy];
  self->parameters = [_parameters copy];
  return self;
}

- (void)dealloc {
  [self->subType    release];
  [self->parameters release];
  [super dealloc];
}

/* types */

- (NSString *)type {
  [self subclassResponsibility:_cmd];
  return nil;
}
- (NSString *)subType {
  return self->subType;
}
- (BOOL)isCompositeType {
  return NO;
}

/* parameters */

- (NSEnumerator *)parameterNames {
  return [self->parameters keyEnumerator];
}

- (id)valueOfParameter:(NSString *)_parameterName {
  return [self->parameters objectForKey:_parameterName];
}

/* representations */

- (NSDictionary *)parametersAsDictionary {
  return self->parameters;
}

- (NSString *)stringValue {
  NSMutableString *str = [NSMutableString stringWithCapacity:20];
  NSString *paras;
  
  [str appendString:[self type]];
  [str appendString:@"/"];
  [str appendString:[self subType]];

  paras = [self parametersAsString];
  if (paras) [str appendString:paras];

  return str;
}

@end /* NGParameterMimeType */

@implementation NGConcreteTextMimeType

static NGConcreteTextMimeType *textPlainNoCharset = nil;

+ (void)initialize {
  BOOL isInitialized = NO;
  if (isInitialized) return;
  isInitialized = YES;
  textPlainNoCharset =
    [[NGConcreteTextMimeType alloc] initWithType:NGMimeTypeText
                                    subType:@"plain"
                                    parameters:nil];
}

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters
{
  NSAssert([_type isEqualToString:NGMimeTypeText],
           @"invalid use of concrete subclass ..");
  
  if (textPlainNoCharset) {
    if (_parameters == nil) {
      if ([_subType isEqualToString:@"plain"]) {
        [self release];
        return [textPlainNoCharset retain]; // init returns retained objects !
      }
    }
  }
  delsp   = NO;
  subType = [_subType copy];
  NSAssert(subType, @"subtype may not be nil");
  {
    NSEnumerator *keys;
    NSString     *key;
    
    keys = [_parameters keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
      NSAssert([key isKindOfClass:[NSString class]],
               @"parameter name has to be a NSString");
      
      if ([key isEqualToString:NGMimeParameterTextCharset]) {
        id tc = [[_parameters objectForKey:key] lowercaseString];
        ASSIGN(self->charset, tc);
        tc = nil;
      }
      else if ([key isEqualToString:@"name"]) {
        [self->name release]; self->name = nil;
        self->name = [[_parameters objectForKey:key] copy];
      }
      else if ([key isEqualToString:@"q"]) {
        id v;
        if ((v = [_parameters objectForKey:key]))
          self->quality = [v floatValue];
        else
          self->quality = 1.0;
      }
      else if ([key isEqualToString:@"format"]) {
        [self->format release]; self->format = nil;
        self->format = [[_parameters objectForKey:key] copy];
      }
      else if ([key isEqualToString:@"method"]) {
        [self->method release]; self->method = nil;
        self->method = [[_parameters objectForKey:key] copy];
      }
      else if ([key isEqualToString:@"reply-type"]) {
        [self->replyType release]; self->replyType = nil;
        self->replyType = [[_parameters objectForKey:key] copy];
      }
      else if ([key isEqualToString:@"delsp"]) {
        self->delsp = [[_parameters objectForKey:key] boolValue];
      }
      else {
        // TODO: how do we want to deal with extra parameters?
        BOOL printWarn = YES;
        
        if ([key hasPrefix:@"x-"]) {
          if ([key hasPrefix:@"x-mac"])
            printWarn = NO;
          else if ([key hasPrefix:@"x-unix-mode"])
            printWarn = NO;
          else if ([key hasPrefix:@"x-avg-checked"])
            // eg: 'x-avg-checked: avg-ok-12CD4A13'
            printWarn = NO;
        }
        
        if (printWarn) {
          NSLog(@"MimeType 'text/*' does not support a parameter named "
                @"'%@' with value '%@'", key, [_parameters objectForKey:key]);
        }
      }
    }
  }
  NSAssert(self, @"self is nil !");
  return self;
}

- (void)dealloc {
  [self->replyType release];
  [self->method  release];
  [self->format  release];
  [self->name    release];
  [self->subType release];
  [self->charset release];
  [super dealloc];
}

/* type */

- (NSString *)type {
  return NGMimeTypeText;
}
- (NSString *)subType {
  return self->subType;
}
- (BOOL)isCompositeType {
  return NO;
}

/* comparing types */

- (BOOL)isEqualToMimeType:(NGMimeType *)_type {
  NSDictionary *paras = nil;
    
  if (_type == nil)  return NO;
  if (_type == self) return YES;

  if (![self hasSameType:_type])
    return NO;

  paras = [_type parametersAsDictionary];
  switch ([paras count]) {
    case 0:
      if (self->charset) return NO;
      break;

    case 1: {
      id ocs = nil;
      if (self->charset == nil) return NO;
      ocs = [paras objectForKey:NGMimeParameterTextCharset];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->charset]) return NO;
      break;
    }

    case 2: {
      id ocs = nil;
      if (self->charset == nil) return NO;
      if (self->name    == nil) return NO;
      
      ocs = [paras objectForKey:NGMimeParameterTextCharset];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->charset]) return NO;

      ocs = [paras objectForKey:@"name"];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->name]) return NO;
      break;
    }

    case 3: {
      id ocs = nil;
      if (self->charset == nil) return NO;
      if (self->name    == nil) return NO;
      if (self->format  == nil) return NO;
      
      ocs = [paras objectForKey:NGMimeParameterTextCharset];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->charset]) return NO;

      ocs = [paras objectForKey:@"name"];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->name]) return NO;

      ocs = [paras objectForKey:@"format"];
      if (ocs == nil) return NO;
      if (![ocs isEqual:self->format]) return NO;
      break;
    }

    default:
      return NO;
  }

  return YES;
}

- (BOOL)hasSameGeneralType:(NGMimeType *)_other { // only the 'type' must match
  if (_other == nil)            return NO;
  if (_other == self)           return YES;
  if ([_other isCompositeType]) return NO;
  if (![[_other type] isEqualToString:NGMimeTypeText]) return NO;
  return YES;
}
- (BOOL)hasSameType:(NGMimeType *)_other { // parameters need not match
  if (_other == nil)            return NO;
  if (_other == self)           return YES;
  if ([_other isCompositeType]) return NO;
  if (![[_other type]    isEqualToString:NGMimeTypeText]) return NO;
  if (![[_other subType] isEqualToString:self->subType])  return NO;
  return YES;
}

- (BOOL)doesMatchType:(NGMimeType *)_other { // interpretes wildcards
  NSString *ot  = [_other type];
  NSString *ost = [_other subType];

  if ([ot  isEqualToString:@"*"]) ot = NGMimeTypeText;
  if (![NGMimeTypeText isEqualToString:ot]) return NO;
  
  if ([ost isEqualToString:@"*"]) ost = self->subType;
  if (![self->subType isEqualToString:ost]) return NO;

  return YES;
}

/* parameters */

- (NSString *)characterSet {
  return self->charset;
}
- (NSString *)name {
  return self->name;
}
- (NSString *)format {
  return self->format;
}
- (NSString *)method {
  return self->method;
}
- (NSString *)replyType {
  return self->replyType;
}
- (float)quality {
  return self->quality;
}
- (BOOL)delsp {
  return self->delsp;
}

- (NSEnumerator *)parameterNames {
  id  args[6];
  int argCount = 0;

  if (self->charset) {
    args[argCount] = NGMimeParameterTextCharset;
    argCount++;
  }
  if (self->name) {
    args[argCount] = @"name";
    argCount++;
  }
  if (self->format) {
    args[argCount] = @"format";
    argCount++;
  }
  if (self->method) {
    args[argCount] = @"method";
    argCount++;
  }
  if (self->replyType) {
    args[argCount] = @"reply-type";
    argCount++;
  }

  if (argCount == 0)
    return nil;

  return [[NSArray arrayWithObjects:args count:argCount] objectEnumerator];
}
- (id)valueOfParameter:(NSString *)_parameterName {
  if ([_parameterName isEqualToString:NGMimeParameterTextCharset])
    return self->charset;
  if ([_parameterName isEqualToString:@"name"])
    return self->name;
  if ([_parameterName isEqualToString:@"format"])
    return self->format;
  if ([_parameterName isEqualToString:@"method"])
    return self->method;
  if ([_parameterName isEqualToString:@"reply-type"])
    return self->replyType;
  
  return nil;
}

/* representations */

- (NSDictionary *)parametersAsDictionary {
  NSMutableDictionary *d;

  d = [NSMutableDictionary dictionaryWithCapacity:4];
  if (self->charset)
    [d setObject:self->charset forKey:NGMimeParameterTextCharset];
  if (self->name)
    [d setObject:self->name forKey:@"name"];
  if (self->format)
    [d setObject:self->format forKey:@"format"];
  if (self->method)
    [d setObject:self->method forKey:@"method"];
  if (self->replyType)
    [d setObject:self->replyType forKey:@"reply-type"];
  
  return d;
}

- (NSString *)stringValue {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:20];
  [str appendString:NGMimeTypeText];
  [str appendString:@"/"];
  [str appendString:self->subType];
  if (self->charset) {
    [str appendString:@"; "];
    [str appendString:NGMimeParameterTextCharset];
    [str appendString:@"="];
    [str appendString:self->charset];
  }
  if (self->name) {
    [str appendString:@"; name="];
    [str appendString:self->name];
  }
  if (self->format) {
    [str appendString:@"; format="];
    [str appendString:self->format];
  }
  if (self->method) {
    [str appendString:@"; method="];
    [str appendString:self->method];
  }
  if (self->replyType) {
    [str appendString:@"; reply-type="];
    [str appendString:self->replyType];
  }
  return str;
}

@end /* NGConcreteTextMimeType */

@implementation NGConcreteTextVcardMimeType
@end /* NGConcreteTextVcardMimeType */

// application type

@implementation NGConcreteApplicationMimeType

- (NSString *)type {
  return NGMimeTypeApplication;
}
- (BOOL)isCompositeType {
  return NO;
}

@end /* NGConcreteApplicationMimeType */

@implementation NGConcreteAppOctetMimeType

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters {

  NSEnumerator *keys = [_parameters keyEnumerator];
  NSString     *key  = nil;

  while ((key = [keys nextObject])) {
    NSAssert([key isKindOfClass:[NSString class]],
             @"parameter name has to be a NSString");

    if ([key isEqualToString:@"type"])
      self->type = [[_parameters objectForKey:@"type"] retain];
    else if ([key isEqualToString:@"padding"])
      self->padding = [[_parameters objectForKey:@"padding"] unsignedIntValue];
    else if ([key isEqualToString:@"conversions"])
      self->conversions = [[_parameters objectForKey:@"conversions"] retain];
    else if ([key isEqualToString:@"name"])
      self->name = [[_parameters objectForKey:@"name"] copy];
    else {
      if (![key hasPrefix:@"x-mac"]) {
	NSLog(@"MimeType 'application/*' does not support a parameter"
              @" named '%@'", key);
      }
    }
  }
  return self;
}

- (void)dealloc {
  [self->type        release];
  [self->conversions release];
  [self->name        release];
  [super dealloc];
}

/* accessors */

- (NSString *)type {
  return NGMimeTypeApplication;
}
- (NSString *)subType {
  return @"octet";
}
- (BOOL)isCompositeType {
  return NO;
}

/* parameters */

- (NSString *)typeDescription {
  return self->type;
}

- (NSEnumerator *)parameterNames {
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:5];
  if (self->type)        [array addObject:@"type"];
  if (self->padding)     [array addObject:@"padding"];
  if (self->conversions) [array addObject:@"conversions"];
  if (self->name)        [array addObject:@"name"];
  return [array isNotEmpty] ? [array objectEnumerator] : (NSEnumerator *)nil;
}

- (id)valueOfParameter:(NSString *)_parameterName {
  if ([_parameterName isEqualToString:@"type"])
    return self->type;
  if ([_parameterName isEqualToString:@"padding"])
    return [NSNumber numberWithUnsignedInt:self->padding];
  if ([_parameterName isEqualToString:@"conversions"])
    return self->conversions;
  if ([_parameterName isEqualToString:@"name"])
    return self->name;

  return nil;
}

- (NSString *)stringValue {
  NSMutableString *str;
  NSString *paras;
  
  str = [NSMutableString stringWithCapacity:20];
  [str appendString:NGMimeTypeApplication];
  [str appendString:@"/"];
  [str appendString:@"octet"];

  paras = [self parametersAsString];
  if (paras != nil) [str appendString:paras];

  return str;
}

@end /* NGConcreteAppOctetMimeType */


/* other types */

@implementation NGConcreteImageMimeType

- (NSString *)type {
  return NGMimeTypeImage;
}

// description

- (NSString *)stringValue {
  return [@"image/" stringByAppendingString:[self subType]];
}

@end /* NGConcreteImageMimeType */

@implementation NGConcreteAudioMimeType

- (NSString *)type {
  return NGMimeTypeAudio;
}

// description

- (NSString *)stringValue {
  return [@"audio/" stringByAppendingString:[self subType]];
}

@end /* NGConcreteAudioMimeType */

@implementation NGConcreteVideoMimeType

- (NSString *)type {
  return NGMimeTypeVideo;
}

// description

- (NSString *)stringValue {
  return [@"video/" stringByAppendingString:[self subType]];
}

@end /* NGConcreteVideoMimeType */

@implementation NGConcreteMultipartMimeType

- (NSString *)type {
  return NGMimeTypeMultipart;
}
- (BOOL)isCompositeType {
  return YES;
}

@end /* NGConcreteMultipartMimeType */

@implementation NGConcreteMessageMimeType

- (NSString *)type {
  return NGMimeTypeMessage;
}
- (BOOL)isCompositeType {
  return NO;
}

@end /* NGConcreteMessageMimeType */

// generic mime type

@implementation NGConcreteGenericMimeType

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters {

  self->type       = [_type       retain];
  self->subType    = [_subType    copy];
  self->parameters = [_parameters retain];
  return self;
}

- (void)dealloc {
  [self->type       release];
  [self->subType    release];
  [self->parameters release];
  [super dealloc];
}

/* accessors */

- (NSString *)type {
  return self->type;
}
- (NSString *)subType {
  return self->subType;
}
- (BOOL)isCompositeType {
  return NO;
}

/* comparing types */

- (BOOL)isEqualToMimeType:(NGMimeType *)_type {
  id p;
  
  if (_type == nil)  return NO;
  if (_type == self) return YES;

  if (![self hasSameType:_type])
    return NO;

  p = [_type parametersAsDictionary];
  if ((p == nil) && (self->parameters == nil))
    return YES;

  if (![p isNotEmpty] && ![self->parameters isNotEmpty])
    return YES;
  
  if ((p == nil) || (self->parameters == nil))
    return NO;

  if (![p isEqual:self->parameters])
    return NO;

  return YES;
}

- (BOOL)hasSameGeneralType:(NGMimeType *)_other { // only the 'type' must match
  if (_other == nil)            return NO;
  if (_other == self)           return YES;
  if ([_other isCompositeType]) return NO;
  if (![[_other type]    isEqualToString:self->type]) return NO;
  return YES;
}
- (BOOL)hasSameType:(NGMimeType *)_other { // parameters need not match
  if (_other == nil)            return NO;
  if (_other == self)           return YES;
  if ([_other isCompositeType]) return NO;
  if (![[_other type]    isEqualToString:self->type])    return NO;
  if (![[_other subType] isEqualToString:self->subType]) return NO;
  return YES;
}

- (BOOL)doesMatchType:(NGMimeType *)_other { // interpretes wildcards
  NSString *ot  = [_other type];
  NSString *ost = [_other subType];

  if ([ot  isEqualToString:@"*"]) ot  = self->type;
  if (![self->type isEqualToString:ot]) return NO;
  
  if ([ost isEqualToString:@"*"]) ost = self->subType;
  if (![self->subType isEqualToString:ost]) return NO;

  return YES;
}

/* parameters */

- (NSEnumerator *)parameterNames {
  return [self->parameters keyEnumerator];
}

- (id)valueOfParameter:(NSString *)_parameterName {
  return [self->parameters objectForKey:_parameterName];
}

- (NSDictionary *)parametersAsDictionary {
  return self->parameters;
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str = [NSMutableString stringWithCapacity:128];

  [str appendString:self->type];
  [str appendString:@"/"];
  [str appendString:self->subType];

  if ([self->parameters isNotEmpty]) {
    NSEnumerator *keys;
    id           key;
    
    keys = [self->parameters keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
      [str appendString:@"; "];
      [str appendString:key];
      [str appendString:@"=\""];
      [str appendString:[self->parameters objectForKey:key]];
      [str appendString:@"\""];
    }
  }
  return str;
}

@end /* NGConcreteGenericMimeType */

@implementation NGConcreteWildcardType 

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters
{
  self->parameters = [_parameters copy];
  self->type    = [_type    isEqualToString:@"*"] ? nil : [_type    copy];
  self->subType = [_subType isEqualToString:@"*"] ? nil : [_subType copy];
  return self;
}

- (void)dealloc {
  [self->parameters release];
  [self->type       release];
  [self->subType    release];
  [super dealloc];
}

/* accessors */

- (NSString *)type {
  return self->type != nil ? self->type : (NSString *)@"*";
}
- (NSString *)subType {
  return self->subType != nil ? self->subType : (NSString *)@"*";
}
- (BOOL)isCompositeType {
  return NO;
}

/* parameters */

- (NSEnumerator *)parameterNames {
  return [self->parameters keyEnumerator];
}

- (id)valueOfParameter:(NSString *)_parameterName {
  return [self->parameters objectForKey:_parameterName];
}

/* representations */

- (NSDictionary *)parametersAsDictionary {
  return self->parameters;
}

/* comparing types */

- (BOOL)isEqualToMimeType:(NGMimeType *)_type {
  if (_type == nil)  return NO;
  if (_type == self) return YES;

  if (![self hasSameType:_type])
    return NO;

  if (![[_type parametersAsDictionary] isEqual:[self parametersAsDictionary]])
    return NO;

  return YES;
}

- (BOOL)hasSameGeneralType:(NGMimeType *)_other { // only the 'type' must match
  if (_other == nil)  return NO;
  if (_other == self) return YES;
  if (![[_other type] isEqualToString:[self type]]) return NO;
  return YES;
}
- (BOOL)hasSameType:(NGMimeType *)_other { // parameters need not match
  if (_other == nil)            return NO;
  if (_other == self)           return YES;
  if (![[_other type]    isEqualToString:[self type]])    return NO;
  if (![[_other subType] isEqualToString:[self subType]]) return NO;
  return YES;
}

- (BOOL)doesMatchType:(NGMimeType *)_other { // interpretes wildcards
  if (self->type) {
    NSString *ot  = [_other type];
    if ([ot  isEqualToString:@"*"]) ot  = self->type;
    if (![self->type isEqualToString:ot]) return NO;
  }
  if (self->subType) {
    NSString *ost = [_other subType];
    if ([ost isEqualToString:@"*"]) ost = self->subType;
    if (![self->subType isEqualToString:ost]) return NO;
  }

  return YES;
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str = [NSMutableString stringWithCapacity:128];
  NSString *paras;
  
  [str appendString:[self type]];
  [str appendString:@"/"];
  [str appendString:[self subType]];
  
  paras = [self parametersAsString];
  if (paras) [str appendString:paras];
  
  return str;
}

@end /* NGConcreteWildcardType */
