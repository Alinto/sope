/* 
   EOKeySortOrdering.m

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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import "common.h"
#import "EOKeySortOrdering.h"
#import <EOControl/EOKeyValueCoding.h>

@implementation EOKeySortOrdering

+ keyOrderingWithKey:(NSString*)aKey ordering:(NSComparisonResult)anOrdering
{
    return AUTORELEASE([[EOKeySortOrdering alloc]
                           initWithKey:aKey ordering:anOrdering]);
}

- initWithKey:(NSString*)aKey ordering:(NSComparisonResult)anOrdering
{
    ASSIGN(key, aKey);
    ordering = anOrdering;
    return self;
}

- (NSString*)key			{return key;}
- (NSComparisonResult)ordering		{return ordering;}

@end

// TODO : integrate this function in the two methods above and optimize
//        object creation and method calls for objects that provide quick
//        access to their values - do not use nested functions

static NSComparisonResult _keySortCompare(id obj1, id obj2, NSArray* order)
     __attribute__((unused));

static NSComparisonResult _keySortCompare(id obj1, id obj2, NSArray* order) {
    int i, n;
    
    for (i = 0, n = [order count]; i < n; i++) {
	id val1, val2, key, kar;
	NSComparisonResult ord, vord;
	EOKeySortOrdering* kso = [order objectAtIndex:i];
	
	key = [kso key];
	ord = [kso ordering];
	kar = [NSArray arrayWithObject:key];
	
	val1 = [[obj1 valuesForKeys:kar] objectForKey:key];
	val2 = [[obj2 valuesForKeys:kar] objectForKey:key];
	
	if (!val1 && !val2)
	    continue;
	
	if (!val1 && val2)
	    return ord == NSOrderedAscending ? 
		   NSOrderedAscending : NSOrderedDescending;
	
	if (val1 && !val2)
	    return ord == NSOrderedAscending ? 
		   NSOrderedDescending : NSOrderedAscending;
	
	vord = [(NSString *)val1 compare:val2];
	
	if (vord == NSOrderedSame)
	    continue;
	
	if (vord == NSOrderedAscending)
	    return ord == NSOrderedAscending ? 
		   NSOrderedAscending : NSOrderedDescending;
	else
	    return ord == NSOrderedAscending ? 
		   NSOrderedDescending : NSOrderedAscending;
    }
    
    return NSOrderedSame;
}

#if 0

@implementation NSArray(EOKeyBasedSorting)

- (NSArray*)sortedArrayUsingKeyOrderArray:(NSArray*)orderArray
{
    NSArray* arry;
    CREATE_AUTORELEASE_POOL(pool);
    
    arry = [self sortedArrayUsingFunction:
                     (int(*)(id, id, void*))_keySortCompare
                 context:orderArray];
    RELEASE(pool);
    return arry;
}

@end

@implementation NSMutableArray(EOKeyBasedSorting)

- (void)sortUsingKeyOrderArray:(NSArray*)orderArray
{
    CREATE_AUTORELEASE_POOL(pool);

    [self sortUsingFunction:
              (int(*)(id, id, void*))_keySortCompare
          context:orderArray];
    RELEASE(pool);
}

@end

#endif

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

