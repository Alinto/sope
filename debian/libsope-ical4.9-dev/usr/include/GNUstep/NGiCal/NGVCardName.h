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

#ifndef __NGiCal_NGVCardName_H__
#define __NGiCal_NGVCardName_H__

#include <NGiCal/NGVCardValue.h>

/*
  NGVCardName
  
  Represents a vCard name as transported in the 'N' vCard tag.
*/

@class NSString, NSDictionary;

@interface NGVCardName : NGVCardValue
{
  NSString *family;
  NSString *given;
  NSString *other;
  NSString *prefix;
  NSString *suffix;
}

/* accessors */

- (NSString *)family;
- (NSString *)given;
- (NSString *)other;
- (NSString *)prefix;
- (NSString *)suffix;

/* values */

- (NSDictionary *)asDictionary;
- (NSArray *)asArray;

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx;
- (unsigned)count;

@end

#endif /* __NGiCal_NGVCardName_H__ */
