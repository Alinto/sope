/* 
   EOCustomValues.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef __EOCustomValues_h__
#define __EOCustomValues_h__

#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>

/*
 * Informal protocols to initialize value-instances (used as objects
 * in the dictionaries for the enterprise objects) and to convert
 * those values to string or data.
 * NOT implemented in NSObject
 */

@interface NSObject(EOCustomValues)
- (id)initWithString:(NSString*)string type:(NSString*)type;
- (NSString*)stringForType:(NSString*)type;
@end

@interface NSObject(EODatabaseCustomValues)
- (id)initWithData:(NSData*)data type:(NSString*)type;
- (NSData*)dataForType:(NSString*)type;
@end

/*
 *  These categories are added to NSString, NSData and NSNumber classes.
 */

@interface NSString(EOCustomValues)
+ stringWithString:(NSString*)string type:(NSString*)type;
- (id)initWithString:(NSString*)string type:(NSString*)type;
- (NSString*)stringForType:(NSString*)type;
- (id)initWithData:(NSData*)data type:(NSString*)type;
- (NSData*)dataForType:(NSString*)type;
@end

@interface NSData(EOCustomValues)
- initWithString:(NSString*)string type:(NSString*)type;
- (NSString*)stringForType:(NSString*)type;
- (id)initWithData:(NSData*)data type:(NSString*)type;
- (NSData*)dataForType:(NSString*)type;
@end

@interface NSNumber(EOCustomValues)
+ (id)numberWithString:(NSString*)string type:(NSString*)type;
- (id)initWithString:(NSString*)string type:(NSString*)type;
- (NSString*)stringForType:(NSString*)type;
@end

#endif /* __EOCustomValues_h__ */


/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
