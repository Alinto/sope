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

#ifndef __NGMail_NGSmtpReplyCodes_H__
#define __NGMail_NGSmtpReplyCodes_H__

/*
  SMTP reply groups:

    1yz Positive Preliminary reply

       The command has been accepted, but the requested action is being held in
       abeyance, pending confirmation of the information in this reply. The
       sender-SMTP should send another command specifying whether to continue or
       abort the action. 

       [Note: SMTP does not have any commands that allow this type of reply, and
        so does not have the continue or abort commands.]

     2yz Positive Completion reply

       The requested action has been successfully completed. A new request may
       be initiated.

     3yz Positive Intermediate reply

       The command has been accepted, but the requested action is being held in
       abeyance, pending receipt of further information. The sender-SMTP should
       send another command specifying this information. This reply is used in
       command sequence groups.

     4yz Transient Negative Completion reply

       The command was not accepted and the requested action did not occur.
       However, the error condition is temporary and the action may be requested
       again. The sender should return to the beginning of the command sequence
       (if any). It is difficult to assign a meaning to "transient" when two
       different sites (receiver- and sender- SMTPs) must agree on the
       interpretation. Each reply in this category might have a different time
       value, but the sender-SMTP is encouraged to try again.
       A rule of thumb to determine if a reply fits into the 4yz or the 5yz
       category (see below) is that replies are 4yz if they can be repeated
       without any change in command form or in properties of the sender or
       receiver. (E.g., the command is repeated identically and the receiver
       does not put up a new implementation.)

     5yz Permanent Negative Completion reply

       The command was not accepted and the requested action did not occur. The
       sender-SMTP is discouraged from repeating the exact request (in the same
       sequence). Even some "permanent" error conditions can be corrected, so the
       human user may want to direct the sender-SMTP to reinitiate the command
       sequence by direct action at some point in the future (e.g., after the
       spelling has been changed, or the user has altered the account status).

   Second digit description:

     The second digit encodes responses in specific categories: 

     x0z Syntax 
       These replies refer to syntax errors, syntactically correct commands that
       don't fit any functional category, and unimplemented or superfluous
       commands. 

     x1z Information 
       These are replies to requests for information, such as status or help. 

     x2z Connections 
       These are replies referring to the transmission channel. 

     x3z Unspecified as yet. 
     x4z Unspecified as yet. 

     x5z Mail system 
       These replies indicate the status of the receiver mail system vis-a-vis
       the requested transfer or other mail system action. 
*/

typedef enum {
  NGSmtpInvalidReplyCode          = -1,
  
  // 100 codes, positive preliminary reply

  // 200 codes, positive completion reply
  NGSmtpSystemStatus              = 211,
  NGSmtpHelpMessage               = 214,
  NGSmtpServiceReady              = 220,
  NGSmtpServiceClosingChannel     = 221,
  NGSmtpActionCompleted           = 250,
  NGSmtpUserNotLocalWillForward   = 251,

  // 300 codes, positive intermediate reply
  NGSmtpStartMailInput            = 354,

  // 400 codes, transient negative completion reply
  NGSmtpServiceNotAvailable       = 421,
  NGSmtpMailboxBusy               = 450,
  NGSmtpErrorInProcessing         = 451,
  NGSmtpInsufficientStorage       = 452,
  
  // 500 codes, permanent negative completion reply
  NGSmtpInvalidCommand            = 500,
  NGSmtpInvalidParameter          = 501,
  NGSmtpCommandNotImplemented     = 502,
  NGSmtpBadCommandSequence        = 503,
  NGSmtpParameterNotImplemented   = 504,
  NGSmtpMailboxNotFound           = 550,
  NGSmtpUserNotLocalTryForward    = 551,
  NGSmtpExceededStorageAllocation = 552,
  NGSmtpMailboxNameNotAllowed     = 553,
  NGSmtpTransactionFailed         = 554
} NGSmtpReplyCode;

#endif /* __NGMail_NGSmtpReplyCodes_H__ */
