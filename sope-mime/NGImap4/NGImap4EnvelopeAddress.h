/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __NGImap4_NGImap4EnvelopeAddress_H__
#define __NGImap4_NGImap4EnvelopeAddress_H__

#import <Foundation/NSObject.h>

/*
  NGImap4EnvelopeAddress

  Wraps the raw mail address in the envelope as parsed from an IMAP4 fetch
  response.
*/

@class NSString, NSDictionary;

@interface NGImap4EnvelopeAddress : NSObject < NSCopying >
{
@public
  NSString *personalName;
  NSString *sourceRoute;
  NSString *mailbox;
  NSString *host;
}

- (id)initWithPersonalName:(NSString *)_pname sourceRoute:(NSString *)_route
  mailbox:(NSString *)_mbox host:(NSString *)_host;

- (id)initWithString:(NSString *)_str;

- (id)initWithBodyStructureInfo:(NSDictionary *)_info;

/* accessors */

- (NSString *)personalName;
- (NSString *)sourceRoute;
- (NSString *)mailbox;
- (NSString *)host;

/* derived accessors */

- (NSString *)baseEMail; /* returns just: mailbox@host */
- (NSString *)email;     /* returns: personalName <mailbox@host> */

@end

#endif /* __NGImap4_NGImap4EnvelopeAddress_H__ */
