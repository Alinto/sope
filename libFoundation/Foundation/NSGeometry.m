/* 
   NSGeometry.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <math.h>
#include <Foundation/common.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSString.h>
#include <Foundation/NSScanner.h>

/*
 * Useful inline functions
 */

static inline NSRect lfRECT(float x, float y, float w, float h)
{
    NSRect rect = {{x,y},{w,h}};
    return rect;
}

static inline BOOL lfVALID(NSRect aRect)
{
    return (aRect.size.width > 0 && aRect.size.height > 0);
}

/*
 * Create Basic Structures
 */

NSPoint	NSMakePoint(float x, float y)
{
    NSPoint point = {x,y};
    return point;
}

NSSize NSMakeSize(float w, float h)
{
    NSSize size = {w,h};
    return size;
}

NSRect NSMakeRect(float x, float y, float w, float h)
{
    NSRect rect = {{x,y},{w,h}};
    return rect;
}

/* 
 * Get a Rectangle's Coordinates
 */

float NSMaxX(NSRect aRect)
{
    return aRect.origin.x + aRect.size.width;
}

float NSMaxY(NSRect aRect)
{
    return aRect.origin.y + aRect.size.height;
}

float NSMidX(NSRect aRect)
{
    return aRect.origin.x + aRect.size.width / 2.0;
}

float NSMidY(NSRect aRect)
{
    return aRect.origin.y + aRect.size.height / 2.0;
}

float NSMinX(NSRect aRect)
{
    return aRect.origin.x;
}

float NSMinY(NSRect aRect)
{
    return aRect.origin.y;
}

float NSWidth(NSRect aRect)
{
    return aRect.size.width;
}

float NSHeight(NSRect aRect)
{
    return aRect.size.height;
}

/*
 * Modify a Copy of a Rectangle
 */

NSRect NSInsetRect(NSRect aRect, float dX, float dY)
{
    return lfRECT(aRect.origin.x+dX,aRect.origin.y+dY,
	    aRect.size.width-2*dX,aRect.size.height-2*dY);
}

NSRect NSOffsetRect(NSRect aRect, float dX, float dY)
{
    return lfRECT(aRect.origin.x+dX, aRect.origin.y+dY,
	    aRect.size.width, aRect.size.height);
}

void NSDivideRect(NSRect aRect, NSRect *slice, NSRect *remainder,
                  float amount, NSRectEdge edge)
{
    NSRect dummySlice, dummyRemainder;
    
    if (!slice)
	slice = &dummySlice;
    if (!remainder)
	remainder = &dummyRemainder;
    
    switch (edge) {
	case (NSMinXEdge):
	    if (amount > aRect.size.width) {
		*slice = aRect;
		*remainder = lfRECT(aRect.origin.x + aRect.size.width,
				aRect.origin.y, 
				0, aRect.size.height);
	    }
	    else {
		*slice = lfRECT(aRect.origin.x, aRect.origin.y, 
				amount, aRect.size.height);
		*remainder = lfRECT(aRect.origin.x+amount, aRect.origin.y, 
				aRect.size.width-amount, aRect.size.height);
	    }
	    break;
	case (NSMinYEdge):
		if (amount > aRect.size.height) {
		    *slice = aRect;
		    *remainder = lfRECT(aRect.origin.x, 
				    aRect.origin.y+aRect.size.height,
				    aRect.size.width, 0);
		}
		else {
		    *slice = lfRECT(aRect.origin.x, aRect.origin.y, 
				aRect.size.width, amount);
		    *remainder = lfRECT(aRect.origin.x,
				    aRect.origin.y+amount, 
				    aRect.size.width,
				    aRect.size.height-amount);
		}
		break;
	case (NSMaxXEdge):
		if (amount > aRect.size.width) {
		    *slice = aRect;
		    *remainder = lfRECT(aRect.origin.x, aRect.origin.y, 
				    0, aRect.size.height);
		}
		else {
		    *slice = lfRECT(aRect.origin.x+aRect.size.width-amount,
				    aRect.origin.y, amount, aRect.size.height);
		    *remainder = lfRECT(aRect.origin.x, aRect.origin.y, 
				    aRect.size.width-amount,
				    aRect.size.height);
		}
		break;
	case (NSMaxYEdge):
		if (amount > aRect.size.height) {
		    *slice = aRect;
		    *remainder = lfRECT(aRect.origin.x, aRect.origin.y, 
				    aRect.size.width, 0);
		}
		else {
		    *slice = lfRECT(aRect.origin.x, 
				    aRect.origin.y+aRect.size.height-amount, 
				    aRect.size.width, amount);
		    *remainder = NSMakeRect(aRect.origin.x, aRect.origin.y, 
					    aRect.size.width,
					    aRect.size.height-amount);
		}
		break;
	default:
	    ;
    }
}

NSRect NSIntegralRect(NSRect aRect)
{
    aRect.origin.x = floor(aRect.origin.x);
    aRect.origin.y = floor(aRect.origin.y);
    aRect.size.width = ceil(aRect.size.width);
    aRect.size.height = ceil(aRect.size.height);
    
    if (lfVALID(aRect))
	return aRect;
    else
	return lfRECT(0,0,0,0);
}

/* 
* Compute a third rectangle from two rectangles 
*/

NSRect NSUnionRect(NSRect aRect, NSRect bRect)
{
    float mx, my, Mx, My;
    
    if (!lfVALID(aRect) && !lfVALID(bRect))
	return lfRECT(0,0,0,0);
    if (!lfVALID(aRect)) 
	return bRect;
    if (!lfVALID(bRect))
	return aRect;
    
    mx = MIN(aRect.origin.x, bRect.origin.x); 
    my = MIN(aRect.origin.y, bRect.origin.y); 
    Mx = MAX(aRect.origin.x+aRect.size.width, 
	    bRect.origin.x+bRect.size.width);
    My = MAX(aRect.origin.y+aRect.size.height, 
	    bRect.origin.y+bRect.size.height);
    
    return lfRECT(mx, my, Mx-mx, My-my);
}

NSRect NSIntersectionRect (NSRect aRect, NSRect bRect)
{
    NSRect rect;
    
    if (NSMaxX(aRect) <= NSMinX(bRect) ||
	    NSMaxX(bRect) <= NSMinX(aRect) ||
	    NSMaxY(aRect) <= NSMinY(bRect) ||
	    NSMaxY(bRect) <= NSMinY(aRect))
	    return lfRECT(0, 0, 0, 0);
    
    if (NSMinX(aRect) <= NSMinX(bRect)) {
	rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(bRect);
	rect.origin.x = NSMinX(bRect);
    } else {
	rect.size.width = MIN(NSMaxX(aRect), NSMaxX(bRect)) - NSMinX(aRect);
	rect.origin.x = NSMinX(aRect);
    }
    
    if (NSMinY(aRect) <= NSMinY(bRect)) {
	rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(bRect);
	rect.origin.y = NSMinY(bRect);
    } else {
	rect.size.height = MIN(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(aRect);
	rect.origin.y = NSMinY(aRect);
    }
    
    return rect;
}

/* 
* Test geometrical relationships 
*/

BOOL NSEqualRects(NSRect aRect, NSRect bRect)
{
    return (aRect.origin.x == bRect.origin.x &&
		    aRect.origin.y == bRect.origin.y &&
		    aRect.size.width == bRect.size.width &&
		    aRect.size.height == bRect.size.height) ? YES : NO;
}

BOOL NSEqualSizes(NSSize aSize, NSSize bSize)
{
    return ((aSize.width == bSize.width) && (aSize.height == bSize.height));
}

BOOL NSEqualPoints(NSPoint aPoint, NSPoint bPoint)
{
    return ((aPoint.x == bPoint.x) && (aPoint.y == bPoint.y));
}

BOOL NSIsEmptyRect(NSRect aRect)
{
    return !lfVALID(aRect);
}

BOOL NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped)
{
    if (flipped)
	return ((aPoint.x >= aRect.origin.x) 
		&& (aPoint.y  >= aRect.origin.y)
		&& (aPoint.x  <  aRect.origin.x+aRect.size.width)
		&& (aPoint.y  <  aRect.origin.y+aRect.size.height));
    else
	return ((aPoint.x >= aRect.origin.x)
		&& (aPoint.y  >  aRect.origin.y)
		&& (aPoint.x  <  aRect.origin.x+aRect.size.width)
		&& (aPoint.y  <= aRect.origin.y+aRect.size.height));
}

BOOL NSPointInRect(NSPoint aPoint, NSRect aRect)
{
    return ((aPoint.x >= aRect.origin.x) 
	    && (aPoint.y  >= aRect.origin.y)
	    && (aPoint.x  <  aRect.origin.x+aRect.size.width)
	    && (aPoint.y  <  aRect.origin.y+aRect.size.height));
}

BOOL NSContainsRect(NSRect aRect, NSRect bRect)
{
    if (!lfVALID(bRect))
	return NO;
    
    return ((NSMinX(aRect) < NSMinX(bRect)) &&
		    (NSMinY(aRect) < NSMinY(bRect)) &&
		    (NSMaxX(aRect) > NSMaxX(bRect)) &&
		    (NSMaxY(aRect) > NSMaxY(bRect)));
}

/*
 * Get a String Representation
 */

NSString* NSStringFromPoint(NSPoint aPoint)
{
    return [NSString stringWithFormat:@"{x=%f; y=%f}", 
	    aPoint.x, aPoint.y];
}

NSString* NSStringFromSize(NSSize aSize)
{
    return [NSString stringWithFormat:@"{width=%f; height=%f}", 
	    aSize.width, aSize.height];
}

NSString* NSStringFromRect(NSRect aRect)
{
    return [NSString stringWithFormat:@"{x=%f; y=%f; width=%f; height=%f}", 
	    aRect.origin.x, aRect.origin.y, 
	    aRect.size.width, aRect.size.height];
}

/*
 * Reading from string representation
 */

NSPoint	NSPointFromString(NSString* string)
{
    NSScanner* scanner = [NSScanner scannerWithString:string];
    NSPoint point;

    if ([scanner scanString:@"{" intoString:NULL]
	&& [scanner scanString:@"x" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&point.x]
	&& [scanner scanString:@";" intoString:NULL]

	&& [scanner scanString:@"y" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&point.y]
	&& [scanner scanString:@"}" intoString:NULL])

	return point;
    else
	return NSMakePoint(0, 0);
}

NSSize NSSizeFromString(NSString* string)
{
    NSScanner* scanner = [NSScanner scannerWithString:string];
    NSSize size;

    if ([scanner scanString:@"{" intoString:NULL]

	&& [scanner scanString:@"width" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&size.width]
	&& [scanner scanString:@";" intoString:NULL]

	&& [scanner scanString:@"height" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&size.height]
	&& [scanner scanString:@"}" intoString:NULL])

	return size;
    else
	return NSMakeSize(0, 0);
}

NSRect NSRectFromString(NSString* string)
{
    NSScanner* scanner = [NSScanner scannerWithString:string];
    NSRect rect;

    if ([scanner scanString:@"{" intoString:NULL]
	&& [scanner scanString:@"x" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&rect.origin.x]
	&& [scanner scanString:@";" intoString:NULL]

	&& [scanner scanString:@"y" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&rect.origin.y]
	&& [scanner scanString:@";" intoString:NULL]

	&& [scanner scanString:@"width" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&rect.size.width]
	&& [scanner scanString:@";" intoString:NULL]

	&& [scanner scanString:@"height" intoString:NULL]
	&& [scanner scanString:@"=" intoString:NULL]
	&& [scanner scanFloat:&rect.size.height]
	&& [scanner scanString:@"}" intoString:NULL])

	return rect;
    else
	return NSMakeRect(0, 0, 0, 0);
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

