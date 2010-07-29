/* 
   NSGeometry.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#ifndef __NSGeometry_h__
#define __NSGeometry_h__

#include <objc/objc.h>

/* Geometry */

@class NSString;

typedef struct _NSPoint {float x; float y;} NSPoint;
typedef struct _NSSize  {float width; float height;} NSSize;
typedef struct _NSRect {NSPoint origin;NSSize size;} NSRect;

typedef enum {NSMinXEdge, NSMinYEdge,  NSMaxXEdge, NSMaxYEdge} NSRectEdge;

// Constants

#define NSZeroPoint ((NSPoint){0,0})
#define NSZeroRect ((NSRect){{0,0},{0,0}})
#define NSZeroSize ((NSSize){0,0})

// Create Basic Structures
LF_EXPORT NSPoint	NSMakePoint(float x, float y);
LF_EXPORT NSSize	NSMakeSize(float w, float h);
LF_EXPORT NSRect	NSMakeRect(float x, float y, float w, float h);

// Get a Rectangle's Coordinates
LF_EXPORT float NSMaxX(NSRect aRect);
LF_EXPORT float NSMaxY(NSRect aRect);
LF_EXPORT float NSMidX(NSRect aRect);
LF_EXPORT float NSMidY(NSRect aRect);
LF_EXPORT float NSMinX(NSRect aRect);
LF_EXPORT float NSMinY(NSRect aRect);
LF_EXPORT float NSWidth(NSRect aRect);
LF_EXPORT float NSHeight(NSRect aRect);

// Modify a Copy of a Rectangle
LF_EXPORT NSRect 	NSInsetRect(NSRect aRect, float dX, float dY);
LF_EXPORT NSRect 	NSOffsetRect(NSRect aRect, float dx, float dy);
LF_EXPORT void 	NSDivideRect(NSRect aRect, NSRect *slice, NSRect *remainder,
			     float amount, NSRectEdge edge);
LF_EXPORT NSRect 	NSIntegralRect(NSRect aRect);

// Compute a Third Rectangle from Two Rectangles
LF_EXPORT NSRect 	NSUnionRect(NSRect aRect, NSRect bRect);
LF_EXPORT NSRect   NSIntersectionRect (NSRect aRect, NSRect bRect);


// Test Geometric Relationships
LF_EXPORT BOOL 	NSEqualRects(NSRect aRect, NSRect bRect);
LF_EXPORT BOOL 	NSEqualSizes(NSSize aSize, NSSize bSize);
LF_EXPORT BOOL 	NSEqualPoints(NSPoint aPoint, NSPoint bPoint);
LF_EXPORT BOOL 	NSIsEmptyRect(NSRect aRect);
LF_EXPORT BOOL 	NSMouseInRect(NSPoint aPoint, NSRect aRect, BOOL flipped);
LF_EXPORT BOOL 	NSPointInRect(NSPoint aPoint, NSRect aRect);
LF_EXPORT BOOL 	NSContainsRect(NSRect aRect, NSRect bRect);
LF_EXPORT BOOL	NSIntersectsRect(NSRect aRect, NSRect bRect);

// Get a String Representation

LF_EXPORT NSString* NSStringFromPoint(NSPoint aPoint);
LF_EXPORT NSString* NSStringFromRect(NSRect aRect);
LF_EXPORT NSString* NSStringFromSize(NSSize aSize);

// Make from String Representation

LF_EXPORT NSPoint	NSPointFromString(NSString* string);
LF_EXPORT NSSize	NSSizeFromString(NSString* string);
LF_EXPORT NSRect	NSRectFromString(NSString* string);

#endif /* __NSGeometry_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
