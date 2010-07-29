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

#ifndef __NGMime_NGConcreteMimeType_H__
#define __NGMime_NGConcreteMimeType_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGMimeType.h>

@class NSString, NSDictionary;

@interface NGParameterMimeType : NGMimeType
{
@protected
  NSString     *subType;
  NSDictionary *parameters;
}

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters;

@end

/*
  The "text" media type is intended for sending material which is principally
  textual in form. A "charset" parameter may be used to indicate the character
  set of the body text for "text" subtypes, notably including the subtype
  "text/plain", which is a generic subtype for plain text. Plain text does not
  provide for or allow formatting commands, font attribute specifications,
  processing instructions, interpretation directives, or content markup. Plain
  text is seen simply as a linear sequence of characters, possibly interrupted by
  line breaks or page breaks. Plain text may allow the stacking of several
  characters in the same position in the text. Plain text in scripts like Arabic
  and Hebrew may also include facilitites that allow the arbitrary mixing of text
  segments with opposite writing directions. 

  Beyond plain text, there are many formats for representing what might be
  known as "rich text". An interesting characteristic of many such 
  representations is that they are to some extent readable even without the
  software that interprets them. It is useful, then, to distinguish them, at
  the highest level, from such unreadable data as images, audio, or text
  represented in an unreadable form. In the absence of appropriate
  interpretation software, it is reasonable to show subtypes of "text" to the
  user, while it is not reasonable to do so with most nontextual data. Such 
  formatted textual data should be represented using subtypes of "text".

  The format parameter is described in:
    http://www.ietf.org/internet-drafts/draft-gellens-format-06.txt
*/
@interface NGConcreteTextMimeType : NGMimeType
{
@protected
  NSString *subType;
  NSString *charset;
  NSString *name;   // used in vcards
  NSString *format;
  NSString *method; // used in iCalendars (method=REQUEST)
  NSString *replyType; // eg value 'response'
  BOOL     delsp;
  float    quality;
}

@end

@interface NGConcreteTextVcardMimeType : NGConcreteTextMimeType
@end

/*
 The "application" media type is to be used for discrete data which do not fit in
 any of the other categories, and particularly for data to be processed by some
 type of application program.
 This is information which must be processed by an application before it is
 viewable or usable by a user. Expected uses for the "application" media type
 include file transfer, spreadsheets, data for mail-based scheduling systems, and
 languages for "active" (computational) material. (The latter, in particular, can
 pose security problems which must be understood by implementors, and are
 considered in detail in the discussion of the "application/PostScript" media type.)
*/
@interface NGConcreteApplicationMimeType : NGParameterMimeType
@end

/*
  The "octet-stream" subtype is used to indicate that a body contains arbitrary
  binary data. The set of currently defined parameters is:

   1. TYPE -- the general type or category of binary data. This is intended as
      information for the human recipient rather than for any automatic processing. 

   2. PADDING -- the number of bits of padding that were appended to the bit-stream
      comprising the actual contents to produce the enclosed 8bit byte-oriented
      data. This is useful for enclosing a bit-stream in a body when the total
      number of bits is not a multiple of 8. 

   Both of these parameters are optional. 

   An additional parameter, "CONVERSIONS", was defined in RFC 1341 but has since
   been removed. RFC 1341 also defined the use of a "NAME" parameter which gave a
   suggested file name to be used if the data were to be written to a file. This
   has been deprecated in anticipation of a separate Content-Disposition header
   field, to be defined in a subsequent RFC. 
*/
@interface NGConcreteAppOctetMimeType : NGMimeType
{
@protected
  NSString *type;         // the general type or category of binary data
  unsigned padding;       // the number of bits of padding that were appended
  NSString *conversions;
  NSString *name;
}

@end

@interface NGConcreteMultipartMimeType : NGParameterMimeType
@end

@interface NGConcreteMessageMimeType : NGParameterMimeType
@end


@interface NGConcreteImageMimeType : NGParameterMimeType
@end

@interface NGConcreteAudioMimeType : NGParameterMimeType
@end

@interface NGConcreteVideoMimeType : NGParameterMimeType
@end


@interface NGConcreteGenericMimeType : NGMimeType
{
@protected
  NSString     *type;
  NSString     *subType;
  NSDictionary *parameters;
}

@end

@interface NGConcreteWildcardType : NGMimeType
{
@protected
  NSString     *type;    // nil means wildcard
  NSString     *subType; // nil means wildcard
  NSDictionary *parameters;
}

@end

#endif /* __NGMime_NGConcreteMimeType_H__ */
