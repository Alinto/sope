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

#ifndef __NGMime_NGMimeHeaderFields_H__
#define __NGMime_NGMimeHeaderFields_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGMimeDecls.h>

@class NSString, NSDictionary;

/*
  NGMimeContentDispositionHeaderField
  
  This class is a special value object for holding (and parsing)
  the content of a content-disposition MIME header field (primarily
  used for attachments).
*/

NGMime_EXPORT NSString *NGMimeContentDispositionInlineType;
NGMime_EXPORT NSString *NGMimeContentDispositionAttachmentType;
NGMime_EXPORT NSString *NGMimeContentDispositionFormType;

@interface NGMimeContentDispositionHeaderField : NSObject
{
@protected
  NSString     *type;
  NSDictionary *parameters;
}

- (id)initWithString:(NSString *)_value;

/* accessors */

- (NSString *)type;

/* parameters */

- (NSString *)name;
- (NSString *)filename;
- (NSString *)valueOfParameterWithName:(NSString *)_name;

- (NSString *)stringValue;
- (NSString *)parametersAsString;
- (BOOL)valueNeedsQuotes:(NSString *)_parameterValue;

@end

#endif /* __NGMime_NGMimeHeaderFields_H__ */
