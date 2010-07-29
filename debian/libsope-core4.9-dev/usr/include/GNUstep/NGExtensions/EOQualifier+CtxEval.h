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

#ifndef __NGExtensions_EOQualifier_ContextEvaluation_H__
#define __NGExtensions_EOQualifier_ContextEvaluation_H__

#import <EOControl/EOQualifier.h>
#import <Foundation/NSArray.h>

@interface EOQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context;

@end

@interface NSArray(ContextEvaluation)

- (NSArray *)filteredArrayUsingQualifier:(EOQualifier *)_qualifier
  context:(id)_context;

@end

@interface NSObject(ContextQualifierComparisons)

- (BOOL)isEqualTo:(id)_object inContext:(id)_context;
- (BOOL)isNotEqualTo:(id)_object inContext:(id)_context;

- (BOOL)isLessThan:(id)_object inContext:(id)_context;
- (BOOL)isGreaterThan:(id)_object inContext:(id)_context;
- (BOOL)isLessThanOrEqualTo:(id)_object inContext:(id)_context;
- (BOOL)isGreaterThanOrEqualTo:(id)_object inContext:(id)_context;

- (BOOL)doesContain:(id)_object inContext:(id)_context;

- (BOOL)isLike:(NSString *)_object inContext:(id)_context;
- (BOOL)isCaseInsensitiveLike:(NSString *)_object inContext:(id)_context;

@end

#endif /* __NGExtensions_EOQualifier_ContextEvaluation_H__ */
