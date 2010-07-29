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

#ifndef __NGiCal_NGVCardStrArrayValue_H__
#define __NGiCal_NGVCardStrArrayValue_H__

#include <NGiCal/NGVCardValue.h>

/*
  NGVCardStrArrayValue

  Represents a list of strings as used in vCards for 'category' or 'nickname'
  tags.
  
  Note: vCard apparently cannot represent categories which contain commas.
        At least Kontact and Evolution do not (no escaping of commas).
*/

@class NSArray;

@interface NGVCardStrArrayValue : NGVCardValue
{
  NSArray *values;
}

- (id)initWithArray:(NSArray *)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a;
- (id)initWithPropertyList:(id)_plist;

/* accessors */

- (NSArray *)values;

/* values */

- (NSArray *)asArray;

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx;
- (unsigned)count;

@end

#endif /* __NGiCal_NGVCardStrArrayValue_H__ */
