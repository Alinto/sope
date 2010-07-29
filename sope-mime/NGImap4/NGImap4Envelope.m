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

#include "NGImap4Envelope.h"
#include "NGImap4EnvelopeAddress.h"
#include <NGMime/NGMimeHeaderFieldParser.h>
#include "imCommon.h"

@implementation NGImap4Envelope

static NGMimeRFC822DateHeaderFieldParser *dateParser = nil;

+ (void)initialize {
  dateParser = [[NGMimeRFC822DateHeaderFieldParser alloc] init];
}

- (id)newEnvelopeAddressForEMail:(id)_email {
  if (![_email isNotNull])
    return nil;
  
  if ([_email isKindOfClass:[NGImap4EnvelopeAddress class]])
    return [_email copy];

  if ([_email isKindOfClass:[NSDictionary class]]) {
    /* 
       A body structure dictionary, contains those keys:
         hostName, mailboxName, personalName, sourceRoute
    */
    return [[NGImap4EnvelopeAddress alloc] initWithBodyStructureInfo:_email];
  }
  
  _email = [_email stringValue];
  if (![_email isNotEmpty])
    return nil;
  return [[NGImap4EnvelopeAddress alloc] initWithString:_email];
}
- (NSArray *)envelopeAddressesForEMails:(NSArray *)_emails {
  NSMutableArray *ma;
  unsigned i, count;
  
  if (_emails == nil)
    return nil;
  if ((count = [_emails count]) == 0)
    return [NSArray array];
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NGImap4EnvelopeAddress *envaddr;
    
    envaddr = [self newEnvelopeAddressForEMail:[_emails objectAtIndex:i]];
    if (![envaddr isNotNull])
      continue;
    
    [ma addObject:envaddr];
    [envaddr release];
  }
  return ma;
}

- (id)initWithMessageID:(NSString *)_msgID subject:(NSString *)_subject
  from:(NSArray *)_from replyTo:(NSArray *)_replyTo
  to:(NSArray *)_to cc:(NSArray *)_cc bcc:(NSArray *)_bcc
{
  if ((self = [self init])) {
    self->msgId   = [_msgID copy];
    self->subject = [_subject copy];
    
    self->from    = [[self envelopeAddressesForEMails:_from]    copy];
    self->replyTo = [[self envelopeAddressesForEMails:_replyTo] copy];
    self->to      = [[self envelopeAddressesForEMails:_to]      copy];
    self->cc      = [[self envelopeAddressesForEMails:_cc]      copy];
    self->bcc     = [[self envelopeAddressesForEMails:_bcc]     copy];
  }
  return self;
}

- (id)initWithBodyStructureInfo:(NSDictionary *)_info {
  id lDate;
  
  if (![_info isNotNull]) {
    [self release];
    return nil;
  }
  
  self = [self initWithMessageID:[_info valueForKey:@"messageId"]
	       subject:[_info valueForKey:@"subject"]
	       from:[_info valueForKey:@"from"]
	       replyTo:[_info valueForKey:@"reply-to"]
	       to:[_info valueForKey:@"to"]
	       cc:[_info valueForKey:@"cc"]
	       bcc:[_info valueForKey:@"bcc"]];
  if (self == nil) return nil;

  /* extended ivars */
  
  self->inReplyTo = [[_info valueForKey:@"in-reply-to"] copy];
  
  if ([(lDate = [_info valueForKey:@"date"]) isNotNull]) {
    if ([lDate isKindOfClass:[NSDate class]])
      self->date = [lDate copy];
    else
      self->date = [[dateParser parseValue:lDate ofHeaderField:@"date"] copy];
  }
  
  return self;
}

- (void)dealloc {
  [self->date      release];
  [self->subject   release];
  [self->inReplyTo release];
  [self->msgId     release];
  [self->from      release];
  [self->sender    release];
  [self->replyTo   release];
  [self->to        release];
  [self->cc        release];
  [self->bcc       release];
  [super dealloc];
}

/* accessors */

- (NSCalendarDate *)date {
  return self->date;
}
- (id)subject {
  return self->subject;
}
- (NSString *)inReplyTo {
  return self->inReplyTo;
}
- (NSString *)messageID {
  return self->msgId;
}
- (NSArray *)from {
  return self->from;
}
- (NGImap4EnvelopeAddress *)sender {
  return self->sender;
}
- (NSArray *)replyTo {
  return self->replyTo;
}
- (NSArray *)to {
  return self->to;
}
- (NSArray *)cc {
  return self->cc;
}
- (NSArray *)bcc {
  return self->bcc;
}

/* derived accessors */

- (BOOL)hasTo {
  return [self->to isNotEmpty] ? YES : NO;
}
- (BOOL)hasCC {
  return [self->cc isNotEmpty] ? YES : NO;
}
- (BOOL)hasBCC {
  return [self->bcc isNotEmpty] ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->date)      [ms appendFormat:@" date='%@'",      self->date];
  if (self->subject)   [ms appendFormat:@" subject='%@'",   self->subject];
  if (self->msgId)     [ms appendFormat:@" msgid='%@'",     self->msgId];
  if (self->inReplyTo) [ms appendFormat:@" inreplyto='%@'", self->inReplyTo];
  
  if (self->from)    [ms appendFormat:@" from=%@",     self->from];
  if (self->replyTo) [ms appendFormat:@" reply-to=%@", self->replyTo];
  if (self->sender)  [ms appendFormat:@" sender=%@",   [self->sender email]];
  
  if (self->to)  [ms appendFormat:@" to=%@",  self->to];
  if (self->cc)  [ms appendFormat:@" cc=%@",  self->cc];
  if (self->bcc) [ms appendFormat:@" bcc=%@", self->bcc];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4Envelope */
