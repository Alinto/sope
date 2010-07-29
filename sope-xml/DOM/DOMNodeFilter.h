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

#ifndef __DOMNodeFilter_H__
#define __DOMNodeFilter_H__

#import <Foundation/NSObject.h>

typedef enum {
  DOM_FILTER_ACCEPT = 1,
  DOM_FILTER_REJECT = 2,
  DOM_FILTER_SKIP   = 3
} DOMNodeFilterType;

/* constants for whatToShow */

#define DOM_SHOW_ALL                    0xFFFFFFFF
#define DOM_SHOW_ELEMENT                0x00000001
#define DOM_SHOW_ATTRIBUTE              0x00000002
#define DOM_SHOW_TEXT                   0x00000004
#define DOM_SHOW_CDATA_SECTION          0x00000008
#define DOM_SHOW_ENTITY_REFERENCE       0x00000010
#define DOM_SHOW_ENTITY                 0x00000020
#define DOM_SHOW_PROCESSING_INSTRUCTION 0x00000040
#define DOM_SHOW_COMMENT                0x00000080
#define DOM_SHOW_DOCUMENT               0x00000100
#define DOM_SHOW_DOCUMENT_TYPE          0x00000200
#define DOM_SHOW_DOCUMENT_FRAGMENT      0x00000400
#define DOM_SHOW_NOTATION               0x00000800

@interface NGDOMNodeFilter : NSObject

- (DOMNodeFilterType)acceptNode:(id)_node;

@end

#endif /* __DOMNodeFilter_H__ */
