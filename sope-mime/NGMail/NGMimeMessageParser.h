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

#ifndef __NGMime_NGMimeMessageParser_H__
#define __NGMime_NGMimeMessageParser_H__

#include <NGMime/NGMimePartParser.h>

/*
  NGMimeMessageParser
  
  This class is used to parse RFC 822 MIME messages. It's the correct
  class to parse email messages.
  
  Usage:
    data = [NSData dataWithContentsOfMappedFile:@"MyMail.eml"];
    parser = [[NGMimeMessageParser alloc] init];
    part = [parser parsePartFromData:data];
    NSLog(@"Subject: %@", [part valuesOfHeaderFieldWithName:@"subject"]);
    [parser release];
*/

@interface NGMimeMessageParser : NGMimePartParser
@end

@interface NSData(MimeQPHeaderFieldDecoding)

/*
  This method decodes header fields which contain quoted
  printable information.
  Note that the return value can be both, an NSString or
  an NSData depending on the case.

  Sample: 
   attachment; filename="langerp=?iso-8859-15?q?=FC=E4=F6=20Name=F6=F6=F6=201234456=2Exls?="
*/
- (id)decodeQuotedPrintableValueOfMIMEHeaderField:(NSString *)_field;

@end

@interface NGMimeRfc822BodyParser : NGMimeBodyParser
@end


#endif /* __NGMime_NGMimeMessageParser_H__ */

