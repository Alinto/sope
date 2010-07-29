/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __OFS_OFSFile_H__
#define __OFS_OFSFile_H__

#include <SoOFS/OFSBaseObject.h>

/*
  OFSFile
  
  OFSFile represents file objects in OFS (child nodes, non-folders). Files
  have a BLOB and can have associated meta-attributes (usually the filesystem
  attributes given by the filemanager)
  
  OFSFile contains a basic implementation of WebDAV support methods and 
  properties.
*/

@class NSDictionary;
@class OFSFactoryContext;
@class WOContext;

@interface OFSFile : OFSBaseObject
{
  NSDictionary *attrCache;
}

/* writing content */

- (NSException *)writeState:(id)_value;
- (NSString *)contentAsString;

/* implemented actions */

- (NSString *)contentTypeInContext:(WOContext *)_ctx;
- (id)GETAction:(WOContext *)_ctx;
- (id)viewAction:(WOContext *)_ctx;
- (id)PUTAction:(WOContext *)_ctx;

/* factory */

+ (id)instantiateInFactoryContext:(OFSFactoryContext *)_ctx;

@end

#endif /* __OFS_OFSFile_H__ */
