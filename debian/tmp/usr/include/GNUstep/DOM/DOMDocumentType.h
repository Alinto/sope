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

#ifndef __DOMDocumentType_H__
#define __DOMDocumentType_H__

#include <DOM/DOMNode.h>

@interface NGDOMDocumentType : NGDOMNode
{
  id parent;
}

/* attributes */

- (NSString *)name;
- (id)entities;
- (id)notations;
- (NSString *)publicId;
- (NSString *)systemId;
- (NSString *)internalSubset;

/* node */

@end

@interface NGDOMDocumentType(PrivateCtors)
/* use DOMDocument for constructing DOMDocumentType's ! */

- (id)initWithName:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId;

@end

#endif /* __DOMDocumentType_H__ */
