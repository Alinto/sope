/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#ifndef __NGMime_NGMimePartParser_H__
#define __NGMime_NGMimePartParser_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <NGStreams/NGStreamProtocols.h>
#include <NGMime/NGPart.h>
#include <NGMime/NGMimeHeaderFieldParser.h>
#include <NGMime/NGMimeBodyParser.h>

/*
  NGMimePartParser
  
  This is an abstract class for parsing MIME parts.
  
  Known Subclasses:
    NGMimeMessageParser  (parses RFC 822 MIME messages)
    NGMimeBodyPartParser (parses the parts contained in a multipart structure)
    NGHttpMessageParser  (parses HTTP messages)
*/

@class NSString, NSData;
@class NGMutableHashMap, NGHashMap;
@class NGByteBuffer;

typedef struct _NGMimeHeaderNames {
  NSString *accept;
  NSString *acceptLanguage;
  NSString *acceptEncoding;
  NSString *acceptCharset;
  NSString *cacheControl;
  NSString *cc;
  NSString *connection;
  NSString *contentDisposition;
  NSString *contentLength;
  NSString *contentTransferEncoding;
  NSString *contentType;
  NSString *cookie;
  NSString *date;
  NSString *from;
  NSString *host;
  NSString *keepAlive;
  NSString *messageID;
  NSString *mimeVersion;
  NSString *organization;
  NSString *received;
  NSString *returnPath;
  NSString *referer;
  NSString *replyTo;
  NSString *subject;
  NSString *to;
  NSString *userAgent;
  NSString *xMailer;
} NGMimeHeaderNames;

@interface NGMimePartParser : NSObject /* abstract */
{
@protected
  NSData       *sourceData; /* for parsing with imutable data */
  const char   *sourceBytes;
  int          dataIdx;     /* data parsing index */
  int          byteLen;
  
  NGByteBuffer *source; // for parsing with LA

  /* cached selectors */
  int (*readByte)(id, SEL);
  int (*la)(id, SEL, unsigned);
  void (*consume)(id, SEL);
  void (*consumeCnt)(id, SEL, unsigned);

  /* buffer-capacity and LA (has to be at least 4) */
  int bufLen; 

  /*
    is set to the value of content-length header field
    if contentLength == -1 -> read until EOF
  */
  int  contentLength;
  BOOL useContentLength; // should be set in subclasses
  NSString *contentTransferEncoding;
  
  id   delegate; // not retained to avoid retain cycles

  struct {
    BOOL parserWillParseHeader:1;
    BOOL parserDidParseHeader:1;
    BOOL parserKeepHeaderFieldData:1;
    BOOL parserKeepHeaderFieldValue:1;
    BOOL parserParseHeaderFieldData:1;
    BOOL parserFoundCommentInHeaderField:1;
    BOOL parserWillParseBodyOfPart:1;
    BOOL parserDidParseBodyOfPart:1;
    BOOL parserParseRawBodyDataOfPart:1;
    BOOL parserBodyParserForPart:1;
    BOOL parserDecodeBodyOfPart:1;
    BOOL parserContentTypeOfPart:1;
  } delegateRespondsTo;

  
}

+ (NSStringEncoding)defaultHeaderFieldEncoding;
+ (NGMimeHeaderNames *)headerFieldNames;

/* setting the delegate */

- (void)setDelegate:(id)_delegate;
- (id)delegate;

/* parsing the whole part */

- (id<NGMimePart>)parsePartFromStream:(id<NGStream>)_stream;
- (id<NGMimePart>)parsePartFromData:(NSData *)_data;

/* header field parsing */

- (id<NGMimeHeaderFieldParser>)parserForHeaderField:(NSString *)_name;

/* perform further parsing of the header value */

- (id)valueOfHeaderField:(NSString *)_name data:(id)_data;

// Parse headers until an empty line is seen, the delegate
// can reject header fields from being included in the HashMap
// This method can return <nil> to abort the parsing process.
- (NGHashMap *)parseHeader;

/* body parsing */

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header;

- (NSData *)decodeBody:(NSData *)_data ofPart:(id<NGMimePart>)_part;

- (id<NGMimeBodyParser>)
  parserForBodyOfPart:(id<NGMimePart>)_part data:(NSData *)_dt;

- (NGMimeType *)defaultContentTypeForPart:(id<NGMimePart>)_part;

- (void)parseBodyOfPart:(id<NGMimePart>)_part;

/* hooks for subclasses */

- (BOOL)parsePrefix; // returns NO to abort parsing
- (void)parseSuffix;
- (BOOL)prepareForParsingFromStream:(id<NGStream>)_stream;
- (void)finishParsingOfPart:(id<NGMimePart>)_part;

/* accessors */

- (void)setUseContentLength:(BOOL)_use;
- (BOOL)doesUseContentLength;

- (NSData *)applyTransferEncoding:(NSString *)_encoding onData:(NSData *)_data;

@end /* NGMimePartParser */

@interface NSObject(NGMimePartParserDelegate)

/*
  Called before the parsing of the headers begins. The delegate can return NO to
  stop parsing or YES to continue parsing.
*/
- (BOOL)parserWillParseHeader:(NGMimePartParser *)_parser;

/*
  This method is invoked when the parser finished parsing the complete header.
  Those headers are available in the HashMap which is given to the delegate.
*/
- (void)parser:(NGMimePartParser *)_parser didParseHeader:(NGHashMap *)_headers;

/*
  This method is invoked when a header field was read in. The field value is
  as raw data which may be further processed by a field-value-parser. With
  this method the delegate becomes to opportunity to parse the value itself.
  When implementing this method the delegate takes over full responsibility
  for parsing the field-value, no header-parser is invoked by the MIME parser
  automatically.
*/
- (id)parser:(NGMimePartParser *)_parser
  parseHeaderField:(NSString *)_name
  data:(NSData *)_data;

/*
  The delegate is asked whether the parser should proceed processing the header
  field or whether the header field should be thrown away. Throwing away a header
  field does not stop the parsing, it just ignores this field.
*/
- (BOOL)parser:(NGMimePartParser *)_parser
  keepHeaderField:(NSString *)_name
  data:(NSData *)_value;
  
/*
  The delegate is asked whether the parser should proceed processing the header
  field or whether the header field should be thrown away. Throwing away a header
  field does not stop the parsing, it just ignores this field.
  The value of the header is already parsed (this means in effect that the delegate
  either didn't implement parser:keepHeader:data: or that it returned YES in this
  method).
*/
- (BOOL)parser:(NGMimePartParser *)_parser
  keepHeaderField:(NSString *)_name
  value:(id)_value;

/*
  The parser found a comment in a header field. This comment could be stored for
  further processing by the delegate. Comment are usually ignored.
*/
- (void)parser:(NGMimePartParser *)_parser
  foundComment:(NSString *)_comment // can be nil, if keepComments==NO
  inHeaderField:(NSString *)_name;

/*
  When the body of a part is read in appropriate content or content-transfer
  encodings may need to be applied. Use this method to perform this operation.
*/
- (NSData *)parser:(NGMimePartParser *)_parser
  decodeBody:(NSData *)_body
  ofPart:(id<NGMimePart>)_part;

/*
  After the headers were parsed the parser creates an NGMimePart object which
  containes the headers. It will then begin to read in the body of the MIME
  message, usually first as an NSData object.
  You can return NO if you want to stop parsing (eg based on some values in the
  headers or YES if you want to have the parser read in the data of the body.
*/
- (BOOL)parser:(NGMimePartParser *)_parser
  willParseBodyOfPart:(id<NGMimePart>)_part;

/*
  The parser successfully read in the body of the part.
*/
- (void)parser:(NGMimePartParser *)_parser
  didParseBodyOfPart:(id<NGMimePart>)_part;

/*
  After the MIME parser read in the body as an NSData object the delegate can
  parse the body data and assign the result to the _part.
  The delegate can return NO if it decides not to parse the body. The builtin
  parser sequence is applied in this case.
  Instead of parsing the body itself the delegate can select an appropriate
  parser for the body using the -parser:bodyParserForPart: delegate method.
*/
- (BOOL)parser:(NGMimePartParser *)_parser
  parseRawBodyData:(NSData *)_data
  ofPart:(id<NGMimePart>)_part;

/*
  If the delegate does not parse the body itself, it can still select an
  appropriate body parser using this method.
*/
- (id<NGMimeBodyParser>)parser:(NGMimePartParser *)_parser
  bodyParserForPart:(id<NGMimePart>)_part;

- (NGMimeType *)parser:(id)_parser
  contentTypeOfPart:(id<NGMimePart>)_part;

@end /* NSObject(NGMimePartParserDelegate) */

@interface NSObject(NGMimePartParser)

- (void)parser:(NGMimePartParser *)_parser
  setOriginalHeaderFieldName:(NSString *)_name;

@end

@interface NSData(MIMEContentTransferEncoding)

- (NSData *)dataByApplyingMimeContentTransferEncoding:(NSString *)_enc;

@end

#endif /* __NGMime_NGMimePartParser_H__ */
