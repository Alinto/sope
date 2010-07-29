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

#ifndef __NGStreams_NGStreamCoder_H__
#define __NGStreams_NGStreamCoder_H__

#import <Foundation/NSCoder.h>

#if !(MAC_OS_X_VERSION_10_2 <= MAC_OS_X_VERSION_MAX_ALLOWED)
#  define USE_SERIALIZER 1
#  import <Foundation/NSSerialization.h>
#endif

#import <Foundation/NSMapTable.h>
#import <Foundation/NSHashTable.h>
#include <NGStreams/NGStreamProtocols.h>

@interface NGStreamCoder : NSCoder 
#if USE_SERIALIZER
  < NSObjCTypeSerializationCallBack >
#endif
{
@protected
  id<NGSerializer,NGStream> stream;   // destination/source stream
  NGIOSafeReadMethodType    readIMP;  // safe read method
  NGIOSafeWriteMethodType   writeIMP; // safe write method

  // used during encoding
  NSHashTable *outObjects;          // objects written so far
  NSHashTable *outConditionals;     // conditional objects
  NSHashTable *outPointers;         // set of pointers
  NSMapTable  *replacements;        // src-object to replacement
  BOOL        traceMode;            // YES if finding conditionals
  BOOL        didWriteHeader;
  SEL         classForCoder;        // default: classForCoder:
  SEL         replObjectForCoder;   // default: replacementObjectForCoder:
  BOOL        encodingRoot;

  // used during decoding
  unsigned    inArchiverVersion;    // archiver's version that wrote the data
  NSMapTable  *inObjects;           // decoded objects: key -> object
  NSMapTable  *inClasses;           // decoded classes: key -> class info
  NSMapTable  *inPointers;          // decoded pointers: key -> pointer
  NSMapTable  *inClassAlias;        // archive name -> decoded name
  NSMapTable  *inClassVersions;     // archive name -> class info
  NSZone      *objectZone;
  BOOL        decodingRoot;
  BOOL        didReadHeader;
}

+ (id)coderWithStream:(id<NGSerializer,NGStream>)_stream;
- (id)initWithStream:(id<NGSerializer,NGStream>)_stream;

// accessors

- (id<NGStream>)stream;
- (NSString *)coderSignature; // ID of the coder used
- (int)coderVersion;          // Version of the coder used

// encoding

- (void)encodeConditionalObject:(id)_object;
- (void)encodeRootObject:(id)_object;

// decoding

- (unsigned int)systemVersion;
- (id)decodeObject;

// Substituting One Class for Another

+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)nameInArchive;
+ (void)decodeClassName:(NSString *)nameInArch asClassName:(NSString *)trueName;
- (NSString *)classNameDecodedForArchiveClassName:(NSString *)nameInArchive;
- (void)decodeClassName:(NSString *)nameInArch asClassName:(NSString *)trueName;

@end

#endif /* __NGStreams_NGStreamCoder_H__ */
