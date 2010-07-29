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

#ifndef __NGMime_NGMime_H__
#define __NGMime_NGMime_H__

#include <NGMime/NGMimeBodyGenerator.h>
#include <NGMime/NGMimeBodyParser.h>
#include <NGMime/NGMimeBodyPart.h>
#include <NGMime/NGMimeBodyPartParser.h>
#include <NGMime/NGMimeExceptions.h>
#include <NGMime/NGMimeGeneratorProtocols.h>
#include <NGMime/NGMimeHeaderFieldGenerator.h>
#include <NGMime/NGMimeHeaderFieldParser.h>
#include <NGMime/NGMimeHeaderFields.h>
#include <NGMime/NGMimeMultipartBody.h>
#include <NGMime/NGMimePartGenerator.h>
#include <NGMime/NGMimePartParser.h>
#include <NGMime/NGMimeType.h>
#include <NGMime/NGMimeUtilities.h>
#include <NGMime/NGPart.h>

// kit class

@interface NGMime : NSObject
+ (NSString *)libraryVersion;
@end

#define LINK_NGMime \
  static void __link_NGMime(void) { \
    [NGMime self]; \
    __link_NGMime(); \
  }

#endif /* __NGMime_NGMime_H__ */
