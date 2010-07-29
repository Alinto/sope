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

#ifndef __NGHttp_NGHttpHeaderFieldParser_H__
#define __NGHttp_NGHttpHeaderFieldParser_H__

#import <Foundation/NSMapTable.h>
#import <NGMime/NGMimeHeaderFieldParser.h>

@interface NGHttpStringHeaderFieldParser : NGMimeHeaderFieldParser
@end

@interface NGHttpCredentialsFieldParser : NGMimeHeaderFieldParser
@end

@interface NGHttpStringArrayHeaderFieldParser : NGMimeHeaderFieldParser
{
@protected
  unsigned char splitChar; // the char to split at, usually ','
}

- (id)initWithSplitChar:(unsigned char)_splitChar;

// this methods returns a retained element of the array, nil is a valid ret-value
- (id)parseValuePart:(const char *)_bytes length:(unsigned)_len zone:(NSZone *)_zone;

@end

@interface NGHttpCharsetHeaderFieldParser : NGHttpStringArrayHeaderFieldParser
@end

@interface NGHttpTypeArrayHeaderFieldParser : NGHttpStringArrayHeaderFieldParser
@end

@interface NGHttpLanguageArrayHeaderFieldParser : NGHttpStringArrayHeaderFieldParser
@end

@interface NGHttpCookieFieldParser : NGHttpStringArrayHeaderFieldParser
{
@protected
  NSMapTable *fetchedCookies; // WARNING: parser is not reentrant !
  BOOL       isRunning;       // to check for ^^
  BOOL       foundInvalidPairs;
}

@end

@interface NGMimeHeaderFieldParserSet(HttpFieldParserSet)

+ (id)defaultHttpHeaderFieldParserSet;

@end

#endif /* __NGHttp_NGHttpHeaderFieldParser_H__ */
