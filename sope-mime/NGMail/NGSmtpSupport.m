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

#include "NGSmtpSupport.h"
#include "common.h"

NSString *NGSmtpDescriptionForReplyCode(NGSmtpReplyCode _code) {
  NSString *text = nil;
  
  switch (_code) {

    // 100 codes, positive preliminary  reply

    // 200 codes, positive completion reply

    case NGSmtpSystemStatus:            // 211
      text = @"System status, or system help reply";
      break;
    case NGSmtpHelpMessage:             // 214
      text = @"Help message";
      break;
    case NGSmtpServiceReady:            // 220
      text = @"<domain> Service ready";
      break;
    case NGSmtpServiceClosingChannel:   // 221
      text = @"<domain> Service closing transmission channel";
      break;
    case NGSmtpActionCompleted:         // 250
      text = @"Requested mail action okay, completed";
      break;
    case NGSmtpUserNotLocalWillForward: // 251
      text = @"User not local; will forward to <forward-path>";
      break;

    // 300 codes, positive intermediate reply
      
    case NGSmtpStartMailInput: // 354
      text = @"Start mail input; end with <CRLF>.<CRLF>";
      break;

    // 400 codes, transient negative completion reply
      
    case NGSmtpServiceNotAvailable: // 421
      text = @"<domain> Service not available, closing transmission channel";
      break;
    case NGSmtpMailboxBusy:         // 450
      text = @"Requested mail action not taken: mailbox unavailable [E.g., mailbox busy]";
      break;
    case NGSmtpErrorInProcessing:   // 451
      text = @"Requested action aborted: local error in processing";
      break;
    case NGSmtpInsufficientStorage: // 452
      text = @"Requested action not taken: insufficient system storage";
      break;

    // 500 codes, permanent negative completion reply
      
    case NGSmtpInvalidCommand:          // 500
      text = @"Syntax error, command unrecognized "
             @"[This may include errors such as command line too long]";
      break;
    case NGSmtpInvalidParameter:        // 501
      text = @"Syntax error in parameters or arguments";
      break;
    case NGSmtpCommandNotImplemented:   // 502
      text = @"Command not implemented";
      break;
    case NGSmtpBadCommandSequence:      // 503
      text = @"Bad sequence of commands";
      break;
    case NGSmtpParameterNotImplemented: // 504
      text = @"Command parameter not implemented";
      break;
      
    case NGSmtpMailboxNotFound:           // 550
      text = @"Requested action not taken: mailbox unavailable "
             @"[E.g., mailbox not found, no access]";
      break;
    case NGSmtpUserNotLocalTryForward:    // 551
      text = @"User not local; please try <forward-path>";
      break;
    case NGSmtpExceededStorageAllocation: // 552
      text = @"Requested mail action aborted: exceeded storage allocation";
      break;
    case NGSmtpMailboxNameNotAllowed:     // 553
      text = @"Requested action not taken: mailbox name not allowed"
             @"[E.g., mailbox syntax incorrect]";
      break;
    case NGSmtpTransactionFailed:         // 554
      text = @"Transaction failed";
      break;
    
    default:
      text = [NSString stringWithFormat:@"<SMTP ReplyCode: %i>", _code];
      break;
  }
  return text;
}

@implementation NGSmtpResponse

+ (int)version {
  return 2;
}

- (id)initWithCode:(NGSmtpReplyCode)_code text:(NSString *)_text {
  if ((self = [super init])) {
    self->code = _code;
    self->text = [_text copy];
  }
  return self;
}

+ (id)responseWithCode:(NGSmtpReplyCode)_code text:(NSString *)_text {
  return [[[self alloc] initWithCode:_code text:_text] autorelease];
}

- (void)dealloc {
  [self->text release];
  [super dealloc];
}

/* accessors */

- (NGSmtpReplyCode)code {
  return self->code;
}

- (NSString *)text {
  return self->text;
}

/* values */

- (int)intValue {
  return [self code];
}
- (NSString *)stringValue {
  return [self text];
}

/* special accessors */

- (NSString *)lastLine {
  const char *cstr = [[self text] cString];
  unsigned   len   = [[self text] cStringLength];

  if (cstr) {
    cstr += len;   // goto '\0'
    cstr--; len--; // goto last char
    while ((*cstr != '\n') && (len > 0)) {
      cstr--;
      len--;
    }
  }
  else
    len = 0;
  return (len > 0) ? [NSString stringWithCString:(cstr + 1)] : (id)[self text];
}

- (BOOL)isPositive {
  return ((self->code >= 200) && (self->code < 300));
}

- (BOOL)isTransientNegative {
  return ((self->code >= 400) && (self->code < 500));
}
- (BOOL)isPermanentNegative {
  return ((self->code >= 500) && (self->code < 600));
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<SMTP-Reply: code=%i line='%@'>",
                     [self code], [self lastLine]];
}

@end /* NGSmtpResponse */
