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

#ifndef __SaxLocator_H__
#define __SaxLocator_H__

#import <Foundation/NSObject.h>

@class NSString;

@protocol SaxLocator

- (NSInteger)columnNumber;
- (NSInteger)lineNumber;
- (NSString *)publicId;
- (NSString *)systemId;

@end

/* sample locator */

@interface SaxLocator : NSObject < SaxLocator, NSCopying >
{
@private
  int      column;
  int      line;
  NSString *pubId;
  NSString *sysId;
}

- (id)init;
- (id)initWithLocator:(id<SaxLocator>)_locator;

- (void)setColumnNumber:(NSInteger)_col;
- (NSInteger)columnNumber;
- (void)setLineNumber:(NSInteger)_line;
- (NSInteger)lineNumber;
- (void)setPublicId:(NSString *)_pubId;
- (NSString *)publicId;
- (void)setSystemId:(NSString *)_sysId;
- (NSString *)systemId;

@end

#endif /* __SaxLocator_H__ */
