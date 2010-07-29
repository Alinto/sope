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

#ifndef __NGiCal_NGVCardOrg_H__
#define __NGiCal_NGVCardOrg_H__

#include <NGiCal/NGVCardValue.h>

@class NSDictionary;

/*
  NGVCardOrg
  
  Represents an organization as transported in the 'ORG' vCard tag.
*/

@class NSString, NSArray;

@interface NGVCardOrg : NGVCardValue
{
  NSString *orgnam; // incorrect in dawson draft? (example mismatch)
  NSArray  *orgunits;
}

- (id)initWithName:(NSString *)_name units:(NSArray *)_units
  group:(NSString *)_grp types:(NSArray *)_tps arguments:(NSDictionary *)_args;

/* accessors */

- (NSString *)orgnam;
- (NSArray *)orgunits;

/* convenience */

- (NSString *)orgunit; /* returns the first orgunit when available */

/* values */

- (NSDictionary *)asDictionary;
- (NSArray *)asArray;

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx;
- (unsigned)count;

@end

#endif /* __NGiCal_NGVCardOrg_H__ */
