/*
  Copyright (C) 2005 Helge Hess

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

#ifndef __NGiCal_NGVCardSimpleValue_H__
#define __NGiCal_NGVCardSimpleValue_H__

#include <NGiCal/NGVCardValue.h>

#import <Foundation/NSString.h>

/*
  NGVCardSimpleValue
  
  An object to represent simple vCard string values.
*/

@interface NGVCardSimpleValue : NGVCardValue
{
  NSString *value;
}

- (id)initWithValue:(NSString *)_value group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_args;

/* fake being an NSString */

- (unsigned int)length;
- (unichar)characterAtIndex:(unsigned)_idx;

@end

#endif /* __NGiCal_NGVCardSimpleValue_H__ */
