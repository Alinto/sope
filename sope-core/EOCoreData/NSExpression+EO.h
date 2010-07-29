/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#ifndef __NSExpression_EO_H__
#define __NSExpression_EO_H__

#import <Foundation/NSExpression.h>

/*
  NSExpression(EO)
  
  Convert an NSExpression to an EOQualifier.
*/

@class NSExpression;
@class EOQualifier;

@interface NSExpression(EOCoreData) < EOKeyValueArchiving >

- (NSPredicate *)asPredicate;
- (NSExpression *)asExpression;

@end

#endif /* __NSExpression_EO_H__ */
