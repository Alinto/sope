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

#ifndef __NGObjWeb_WOMailDelivery_H__
#define __NGObjWeb_WOMailDelivery_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray;
@class WOComponent;

@interface WOMailDelivery : NSObject
{
}

+ (id)sharedInstance;

// composing mails

- (id)composeEmailFrom:(NSString *)_senderAddress
  to:(NSArray *)_receiverAddresses
  cc:(NSArray *)_ccAddresses
  subject:(NSString *)_subject
  plainText:(NSString *)_text
  send:(BOOL)_sendFlag;

- (id)composeEmailFrom:(NSString *)_senderAddress
  to:(NSArray *)_receiverAddresses
  cc:(NSArray *)_ccAddresses
  subject:(NSString *)_subject
  component:(WOComponent *)_component
  send:(BOOL)_sendFlag;

// sending mails

- (BOOL)sendEmail:(id)_email;

@end

#endif /* __NGObjWeb_WOMailDelivery_H__ */
