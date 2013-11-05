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

#ifndef __NGMimeGenerator_NGMimePartGenerator_H__
#define __NGMimeGenerator_NGMimePartGenerator_H__

#import <Foundation/NSObject.h>
#import <NGMime/NGPart.h>
#import <NGMime/NGMimeGeneratorProtocols.h>

@class NSMutableData, NSData, NSString, NSEnumerator;
@class NGHashMap, NGMutableHashMap;
@class NGMimeType, NGMimePartGenerator;

@interface NGMimePartGenerator : NSObject <NGMimePartGenerator>
{
@protected
  NSMutableData  *result;  // result
  id<NGMimePart> part;     // for generating
  id             delegate; // not retained to prevent retain cycles

  BOOL           useMimeData;
  
  void (*appendBytes)(id,SEL,const void*,unsigned int); /* cached method
                                                           for result */
  struct {
    BOOL generatorGenerateDataForHeaderField:1;
    BOOL generatorGeneratorForBodyOfPart:1;
    BOOL generatorGenerateDataForBodyOfPart:1;
  } delegateRespondsTo;
}

+ (id)mimePartGenerator;

/* generating mime from MimeMessage */
- (NSData *)generateMimeFromPart:(id<NGMimePart>)_part;


/* generate mime from part and store it in the returned filename */
- (NSString *)generateMimeFromPartToFile:(id<NGMimePart>)_part;

/* build data with current mime-header and the _additionalHeaders;
   _additionalHeaders come from generateBodyData (boundary, encoding, ...) */
- (NSData *)generateHeaderData:(NGHashMap *)_additionalHeaders;

/* build the body; use -generatorForBodyOfPart */
- (NSData *)generateBodyData:(NGMutableHashMap *)_additionalHeaders;

/* call generateHeaderData and generateBodyData; manage additionalHeaders */
- (void)generateData;

/* set result and other stuff */
- (BOOL)prepareForGenerationOfPart:(id<NGMimePart>)_part;

/* setting the delegate */
- (void)setDelegate:(id)_delegate;
- (id)delegate;

/* ----- hooks for subclasses ----- */

/*
  Generate a prefix and/or a suffix for a part. Can be used to write
  HTTP response lines before the part.
*/
- (BOOL)generatePrefix;
- (void)generateSuffix;

/* if no content-type is set */
- (NGMimeType *)defaultContentTypeForPart:(id<NGMimePart>)_part;

/* returns header field generator for the specified field */
- (id<NGMimeHeaderFieldGenerator>)generatorForHeaderField:(NSString *)_name;

/* build data for the specified header; employ -generatorForHeaderField */

- (NSData *)generateDataForHeaderField:(NSString *)_headerField
  value:(id)_value;

/* build data with the specified header; */

- (BOOL)isMultiValueCommaHeaderField:(NSString *)_headerField;
- (BOOL)appendHeaderField:(NSString *)_field values:(NSEnumerator *)_values
  toData:(NSMutableData *)_data;

/* looking for a NGMimeBodyGenerator in dependece to the content-type */
- (id<NGMimeBodyGenerator>)generatorForBodyOfPart:(id<NGMimePart>)_part;

/* ----- end hooks for subclasses ----- */

/* accessors */
- (id<NGMimePart>)part;

@end

@interface NSObject(NGMimePartGenerator)

/*
  The delegete has the opportunity to generate data for specified
  header-field with the given enumerator. The classes of the values depends
  on the _headerField name, normaly they are NSStrings
*/   
- (NSData *)mimePartGenerator:(id<NGMimePartGenerator>)_gen
  generateDataForHeaderField:(NSString *)_headerField
  value:(NSEnumerator *)_value;

/*
  The delegate can choose, which generator should be used, to generate
  the specified NGMimePart.
*/
- (id<NGMimeBodyGenerator>)mimePartGenerator:(id<NGMimePartGenerator>)_gen
  generatorForBodyOfPart:(id<NGMimePart>)_part;

/*
  The delegate has the opportunity to generate the whole body-part. Additional
  headers like boundary can be set in _additionalHeaders.
*/
- (NSData *)mimePartGenerator:(id<NGMimePartGenerator>)_gen
  generateDataForBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_additionalHeaders;

/*
  The delegate can set prefix and suffix for a multipart.
*/
- (NSString *)multipartBodyGenerator:(id<NGMimeBodyGenerator>)_bodyGen
  prefixForPart:(id<NGMimePart>)_part;

- (NSString *)multipartBodyGenerator:(id<NGMimeBodyGenerator>)_bodyGen
  suffixForPart:(id<NGMimePart>)_part;

/*
  The delegate can select which NGMimeBodyGenerator should de used
  for generate the given part.
*/  
- (id<NGMimePartGenerator>)multipartBodyGenerator:(id<NGMimeBodyGenerator>)
  generatorForPart:(id<NGMimePart>)_part;

- (BOOL)useMimeData;
- (void)setUseMimeData:(BOOL)_b;

@end

#endif // __NGMimeGenerator_NGMimePartGenerator_H__
