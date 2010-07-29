/* 
   NSDateFormatter.m

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

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
// $Id: NSDateFormatter.m 827 2005-06-03 14:18:27Z helge $

#include <Foundation/common.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSDate.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/NSDateFormatter.h>
#include <Foundation/NSUtilities.h>

@implementation NSDateFormatter

- (id)initWithDateFormat:(NSString *)_format allowNaturalLanguage:(BOOL)_flag
{
    if ((_format != nil) && ![_format isKindOfClass:[NSString class]]) {
        [[[InvalidArgumentException alloc]
             initWithReason:@"calendar format needs to be a string !"] raise];
    }
    
    self->format                = [_format copyWithZone:[self zone]];
    self->allowsNaturalLanguage = _flag;
    return self;
}
- (id)init
{
    return [self initWithDateFormat:nil allowNaturalLanguage:NO];
}

- (void)dealloc
{
    RELEASE(self->format);
    [super dealloc];
}

- (NSString *)dateFormat
{
    return self->format;
}
- (BOOL)allowsNaturalLanguage
{
    return self->allowsNaturalLanguage;
}

// object => string

- (NSString *)stringForObjectValue:(id)_object
{
    if ([_object respondsToSelector:@selector(descriptionWithCalendarFormat:)]) {
        // NSCalendarDate
        return [_object descriptionWithCalendarFormat:self->format];
    }
    else if ([_object respondsToSelector: 
                @selector(descriptionWithCalendarFormat:timeZone:locale:)]) {
        // NSDate
        return [_object descriptionWithCalendarFormat:self->format
                        timeZone:nil
                        locale:nil];
    }
    else {
        // not a date
        return nil;
    }
}

// string => object

- (BOOL)getObjectValue:(id *)_object
  forString:(NSString *)_string
  errorDescription:(NSString **)_error
{
    *_object = [NSCalendarDate dateWithString:_string
                               calendarFormat:self->format];
    if (*_object)
        return YES;

    if (self->allowsNaturalLanguage)
        *_error = @"Natural language parsing not implemented";
    else
        *_error = @"Could not parse date";

#if HAVE_LOCALIZED_STRING
    *_error = NSLocalizedString(*_error);
#endif
    
    return NO;
}

// NSCopying

- (id)copyWithZone:(NSZone *)_zone
{
    // formatters are immutable objects
    if (NSShouldRetainWithZone(self, _zone))
        return self;
    else {
        return [[[self class]
                       allocWithZone:_zone]
                       initWithDateFormat:self->format
                       allowNaturalLanguage:self->allowsNaturalLanguage];
    }
}

// NSCoding

- (void)encodeWithCoder:(NSCoder *)_coder
{
    [_coder encodeObject:self->format];
    [_coder encodeValueOfObjCType:@encode(BOOL)
            at:&(self->allowsNaturalLanguage)];
}

- (id)initWithCoder:(NSCoder *)_coder
{
    self->format = [[_coder decodeObject] copyWithZone:[self zone]];
    [_coder decodeValueOfObjCType:@encode(BOOL)
            at:&(self->allowsNaturalLanguage)];
    return self;
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
