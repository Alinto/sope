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

#ifndef __NGFileManagerURL_H__
#define __NGFileManagerURL_H__

#if GNUSTEP_BASE_LIBRARY
#  import <Foundation/NSObjCRuntime.h> /* add GS_EXPORT .. */
#  import <Foundation/NSObject.h>      /* add NSObject .. */
#endif

#import <Foundation/NSURL.h>
#include <NGExtensions/NGFileManager.h>

/*
  A URL which works on NGFileManager's.
  
  The NSURLHandle should work, but the URL can't be serialized.
*/

@interface NGFileManagerURL : NSURL
{
  /* do *NOT* cache in filemanager - retain cycle !!! */
  id<NSObject,NGFileManager> fileManager;
  NSString *path;
}

- (id)initWithPath:(NSString *)_path
  fileManager:(id<NSObject,NGFileManager>)_fm;

/* accessors */

- (id<NSObject,NGFileManager>)fileManager;

@end

#endif /* __NGFileManagerURL_H__ */
