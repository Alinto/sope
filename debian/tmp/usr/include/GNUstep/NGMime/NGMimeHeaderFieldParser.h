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

#ifndef __NGMime_NGHeaderFieldParser_H__
#define __NGMime_NGHeaderFieldParser_H__

#import <Foundation/NSObject.h>

@class NSData, NSString, NSMutableDictionary;

@protocol NGMimeHeaderFieldParser < NSObject >

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field;

@end

@interface NGMimeHeaderFieldParser : NSObject < NGMimeHeaderFieldParser >

+ (BOOL)isMIMELogEnabled;
+ (BOOL)doesStripLeadingSpaces;

- (NSString *)removeCommentsFromValue:(NSString *)_rawValue;
- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field; // abstract

@end

@interface NGMimeContentTypeHeaderFieldParser : NGMimeHeaderFieldParser
@end

@interface NGMimeRFC822DateHeaderFieldParser : NGMimeHeaderFieldParser
@end

@interface NGMimeContentLengthHeaderFieldParser : NGMimeHeaderFieldParser
@end

/*
  Content-Disposition headers have the form:

    disposition := "Content-Disposition" ":"
                   disposition-type
                   *(";" disposition-parm)

    disposition-type := "inline"
                      / "attachment"
                      / extension-token
                      ; values are not case-sensitive

    disposition-parm := filename-parm / parameter
    filename-parm := "filename" "=" value;

  Content-Disposition values may not contain comments !
*/
@interface NGMimeContentDispositionHeaderFieldParser : NGMimeHeaderFieldParser
@end

/*
  This strips spaces at the beginning and the end of the value, then it removes
  all comments
*/
@interface NGMimeStringHeaderFieldParser : NGMimeHeaderFieldParser
{
@protected
  BOOL removeComments; // default=YES
}

- (id)initWithRemoveComments:(BOOL)_flag;
- (id)init;

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field;

@end

/*
  This stores a mapping between header field parsers and field names.
*/
@interface NGMimeHeaderFieldParserSet : NSObject <NGMimeHeaderFieldParser,NSCopying>
{
@protected
  NSMutableDictionary         *fieldNameToParser;
  id<NGMimeHeaderFieldParser> defaultParser;
}

+ (id)headerFieldParserSet;
+ (id)defaultRfc822HeaderFieldParserSet;
- (id)init;
- (id)initWithDefaultParser:(id<NGMimeHeaderFieldParser>)_parser;
- (id)initWithParseSet:(NGMimeHeaderFieldParserSet *)_set;

/* accessors */

- (void)setParser:(id<NGMimeHeaderFieldParser>)_parser
  forField:(NSString *)_name;

- (void)setDefaultParser:(id<NGMimeHeaderFieldParser>)_parser;
- (id<NGMimeHeaderFieldParser>)defaultParser;

/* operation */

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field;

@end

#endif /* __NGMime_NGHeaderFieldParser_H__ */
