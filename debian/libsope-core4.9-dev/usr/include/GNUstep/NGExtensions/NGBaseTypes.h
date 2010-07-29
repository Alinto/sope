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

#ifndef __NGExtensions_NGBaseTypes_H__
#define __NGExtensions_NGBaseTypes_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

static inline NSNumber *shortObj(short _s) {
  return [NSNumber numberWithShort:_s];
}

static inline NSNumber *intObj(int _i) {
  return [NSNumber numberWithInt:_i];
}

static inline NSNumber *floatObj(float _f) {
  return [NSNumber numberWithFloat:_f];
}

static inline NSNumber *doubleObj(double _d) {
  return [NSNumber numberWithDouble:_d];
}

static inline NSString *cstrObj(const char *_c) {
  return [NSString stringWithCString:_c];
}

#endif /* __NGExtensions_NGBaseTypes_H__ */
