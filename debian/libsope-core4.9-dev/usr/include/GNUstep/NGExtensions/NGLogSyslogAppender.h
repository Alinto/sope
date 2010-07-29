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

#ifndef	__NGExtensions_NGLogSyslogAppender_H_
#define	__NGExtensions_NGLogSyslogAppender_H_

/*
  NGLogSyslogAppender
  
  An appender which writes to the system's syslog facility.
 
  Use the user default key "NGLogSyslogIdentifier" to set the syslog
  identifier. The syslog identifier is a string that will be prepended to every
  message. See your operating system's manpage on syslog for details.

  Note: syslog doesn't support user provided timestamps, thus this information
        provided by NGLogEvent is silently discarded.

  The following scheme is used to map NGLogLevels to syslog's levels:
 
  NGLogLevel          syslog
  --------------------------
  NGLogLevelDebug     LOG_DEBUG
  NGLogLevelInfo      LOG_INFO
  NGLogLevelWarn      LOG_WARNING
  NGLogLevelError     LOG_ERR
  NGLogLevelFatal     LOG_ALERT
*/

#include <NGExtensions/NGLogAppender.h>

@class NSString;

@interface NGLogSyslogAppender : NGLogAppender
{
}

+ (id)sharedAppender;

/* provide syslog identifier */
- (id)initWithIdentifier:(NSString *)_ident;

@end

#endif	/* __NGExtensions_NGLogSyslogAppender_H_ */
