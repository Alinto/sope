/* 
   NSFormatter.m

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
// $Id: NSFormatter.m 827 2005-06-03 14:18:27Z helge $

#include "common.h"
#include "NSFormatter.h"

@implementation NSFormatter

#if HAVE_ATTRIBUTED_STRING
- (NSAttributedString *)attributedStringForObjectValue:(id)_object
  withDefaultAttributes:(NSDictionary *)_attributes
{
    return [NSAttributedString attributedStringWithString:
                                 [self stringForObjectValue]
                               attributes:_attributes];
}
#endif

// object => string

- (NSString *)editingStringForObjectValue:(id)_object
{
    return [self stringForObjectValue:_object];
}

- (NSString *)stringForObjectValue:(id)_object
{
    return [self subclassResponsibility:_cmd];
}

// string => object

- (BOOL)getObjectValue:(id *)_object
  forString:(NSString *)_string
  errorDescription:(NSString **)_error
{
    [self subclassResponsibility:_cmd];
    return NO;
}

- (BOOL)isPartialStringValid:(NSString *)_partialString
  newEditingString:(NSString **)_newString
  errorDescription:(NSString **)_error
{
    // is this correct ?
    // (or should we call 'subclassResponsibility:..', or something similiar ?)
    return YES;
}

@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
