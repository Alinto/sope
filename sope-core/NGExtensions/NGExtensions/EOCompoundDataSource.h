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

#ifndef __NGExtensions_EOCompoundDataSource_H__
#define __NGExtensions_EOCompoundDataSource_H__

#import <EOControl/EODataSource.h>

@class NSArray;
@class EOQualifier;

@interface EOCompoundDataSource : EODataSource
{
  NSArray     *sources;
  EOQualifier *auxiliaryQualifier;
  NSArray     *sortOrderings;
}

- (id)initWithDataSources:(NSArray *)_ds;

/* accessors */

- (void)setSources:(NSArray *)_sources;
- (NSArray *)sources;

- (void)setAuxiliaryQualifier:(EOQualifier *)_q;
- (EOQualifier *)auxiliaryQualifier;
- (void)setSortOrderings:(NSArray *)_o;
- (NSArray *)sortOrderings;

@end

#endif /* __NGExtensions_EOCompoundDataSource_H__ */
