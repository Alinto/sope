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

#ifndef __NGMail_H__
#define __NGMail_H__

#import <Foundation/NSObject.h>
#include <NGMail/NGMBoxReader.h>
#include <NGMail/NGPop3Client.h>
#include <NGMail/NGSmtpClient.h>
#include <NGMail/NGMimeMessage.h>
#include <NGMail/NGMimeMessageGenerator.h>
#include <NGMail/NGMimeMessageParser.h>
#include <NGMail/NGMailAddress.h>
#include <NGMail/NGMailAddressList.h>
#include <NGMail/NGMailAddressParser.h>

// kit class

@interface NGMail : NSObject
@end

#define LINK_NGMail \
  static void __link_NGMail(void) { \
    [NGMail self];   \
    __link_NGMail(); \
  }

#endif /* __NGMail_H__ */
