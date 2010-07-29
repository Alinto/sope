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

#ifndef __SaxNamespaceSupport_H__
#define __SaxNamespaceSupport_H__

#import <Foundation/NSObject.h>

@class NSString, NSEnumerator, NSArray;

/*
  New in SAX2, defined in helpers/NamespaceSupport

  Encapsulate Namespace logic for use by SAX drivers. 

  This class encapsulates the logic of Namespace processing: it tracks
  the declarations currently in force for each context and automatically
  processing raw XML 1.0 names into their Namespace parts.

  Namespace support objects are reusable, but the reset method must be
  invoked between each session.

  Here is a simple session:
  
      String parts[] = new String[3];
      SaxNamespaceSupport support;

      support = [[SaxNamespaceSupport alloc] init];
      
      [support pushContext];
      [support declarePrefix:@""   uri:@"http://www.w3.org/1999/xhtml"];
      [support declarePrefix:@"dc" uri:@"http://www.purl.org/dc#"];
      
      String parts[] = support.processName("p", parts, false);
      System.out.println("Namespace URI: " + parts[0]);
      System.out.println("Local name: " + parts[1]);
      System.out.println("Raw name: " + parts[2]);
     
      String parts[] = support.processName("dc:title", parts, false);
      System.out.println("Namespace URI: " + parts[0]);
      System.out.println("Local name: " + parts[1]);
      System.out.println("Raw name: " + parts[2]);
     
      [support popContext];
 
  Note that this class is optimized for the use case where most elements
  do not contain Namespace declarations: if the same prefix/URI mapping
  is repeated for each context (for example), this class will be somewhat
  less efficient.
*/

extern NSString *SaxXMLNS;

@interface SaxNamespaceSupport : NSObject
{
@private
}

/* start a new ns context */
- (void)pushContext;

/* revert to previous ns context */
- (void)popContext;

/* Declare a Namespace prefix. */
- (BOOL)declarePrefix:(NSString *)_prefix uri:(NSString *)_uri;

/* Return an enumeration of all prefixes declared in this context. */
- (NSEnumerator *)prefixEnumerator;

/* Look up a prefix and get the currently-mapped Namespace URI. */
- (NSString *)getUriForPrefix:(NSString *)_prefix;

/* Reset this Namespace support object for reuse. */
- (void)reset;

/*
  Process a raw XML 1.0 name.
  
  This method processes a raw XML 1.0 name in the current context by
  removing the prefix and looking it up among the prefixes currently
  declared. The return value will be the array supplied by the caller,
  filled in as follows:

    parts[0] The Namespace URI, or an empty string if none is in use. 
    parts[1] The local name (without prefix). 
    parts[2] The original raw name.
    
  All of the strings in the array will be internalized. If the raw name
  has a prefix that has not been declared, then the return value will be
  null.

  Note that attribute names are processed differently than element names:
  an unprefixed element name will received the default Namespace (if any),
  while an unprefixed element name will not.
*/
- (NSArray *)processName:(NSString *)_rawName
  parts:(NSArray *)_parts
  isAttribute:(BOOL)_isAttribute;

@end

#endif /* __SaxNamespaceSupport_H__ */
