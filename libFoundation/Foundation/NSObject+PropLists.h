/* 
   NSObject+PropLists.h

   Copyright (C) 1999, MDlink online service center GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#ifndef __NSObject_PropLists_H__
#define __NSObject_PropLists_H__

#include "NSObject.h"

@interface NSObject(PropertyListProtocol)

- (NSString *)descriptionWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent;
- (NSString *)descriptionWithLocale:(NSDictionary *)_locale;
- (NSString *)stringRepresentation;

/* this method is called in property-list generation methods */

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent;

@end

#endif /* __NSObject_PropLists_H__ */
