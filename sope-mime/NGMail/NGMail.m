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

#include "NGMail.h"
#include "NGMBoxReader.h"
#include "NGPop3Client.h"
#include "NGSmtpClient.h"
#include "NGMimeMessage.h"
#include "NGMimeMessageParser.h"
#include "NGMimeMessageGenerator.h"
#include "NGMailAddress.h"
#include "NGMailAddressList.h"
#include "NGMailAddressParser.h"

#import <NGStreams/NGStreams.h>
#import <NGMime/NGMime.h>

@implementation NGMail

/*
  all this is required when compiling on GNUstep without shared
  libraries. eg gprof profiling only works with static binaries,
  therefore this is sometimes required. sigh.
*/

- (void)_staticLinkClasses {
  [NGMailAddress          self];
  [NGMailAddressList      self];
  [NGMailAddressParser    self];
  [NGMimeMessage          self];
  [NGMimeMessageParser    self];
  [NGMimeMessageGenerator self];
  
  [NGMBoxReader self];
  [NGPop3Client self];
  [NGSmtpClient self];

  [NGMime self];
}

- (void)_staticLinkModules {
  [NGStreams class];
  [NGMime    class];
}

@end /* NGMail */
