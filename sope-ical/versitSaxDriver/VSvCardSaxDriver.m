/*
  Copyright (C) 2003-2004 Max Berger
  Copyright (C) 2004-2005 OpenGroupware.org
  
  This file is part of versitSaxDriver, written for the OpenGroupware.org
  project (OGo).
  
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

#include "VSvCardSaxDriver.h"
#include "common.h"

#define XMLNS_VSvCard \
  @"http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-03.txt"

@implementation VSvCardSaxDriver

static NSSet *defElementNames = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if(didInit)
    return;
  didInit = YES;
  
  defElementNames = [[NSSet alloc] initWithObjects:
    @"class", @"prodid", @"rev", @"uid", @"version", nil];
}

+ (NSDictionary *)xcardMapping  {
  static NSDictionary *dict = nil;
  if (dict == NULL) {
    NSMutableDictionary *xcard;

    xcard = [[NSMutableDictionary alloc] initWithCapacity:30];
    
    [xcard setObject:@"vCard" forKey:@"VCARD"];
    
    /*
     +----------------+------------+------------+----------------+
     |      Type      | Attribute  | Attribute  | Default        |
     |      Name      |    Name    |    Type    |  Value         |
     +----------------+------------+------------+----------------+
     | CLASS          | class      | enumerated | 'PUBLIC'       |
     | PRODID         | prodid     | CDATA      | IMPLIED        |
     | REV            | rev        | CDATA      | IMPLIED        |
     | UID            | uid        | CDATA      | IMPLIED        |
     | VERSION        | version    | CDATA      | IMPLIED        |
     +----------------+------------+------------+----------------+
     */
    [xcard setObject:@"class"   forKey:@"CLASS"];
    [xcard setObject:@"prodid"  forKey:@"PRODID"];
    [xcard setObject:@"rev"     forKey:@"REV"];
    [xcard setObject:@"uid"     forKey:@"UID"];
    [xcard setObject:@"version" forKey:@"VERSION"];
    
    
    /*
     Identification Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | FN             | fn         | PCDATA                      |
     | N              | n          | family*,given*,other*,      |
     |                |            |  prefix*, suffix*           |
     |                | family     | PCDATA                      |
     |                | given      | PCDATA                      |
     |                | other      | PCDATA                      |
     |                | prefix     | PCDATA                      |
     |                | suffix     | PCDATA                      |
     | NICKNAME       | nickname   | PCDATA                      |
     | PHOTO          | photo      | extref or b64bin            |
     |                | extref     | EMPTY                       |
     |                | b64bin     | PCDATA                      |
     | BDAY           | bday       | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"fn"       forKey:@"FN"];
    [xcard setObject:@"n"        forKey:@"N"];
    [xcard setObject:@"nickname" forKey:@"NICKNAME"];
    [xcard setObject:@"photo"    forKey:@"PHOTO"];
    [xcard setObject:@"bday"     forKey:@"BDAY"];
    
    
    /*
     Delivery Addressing  Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | ADR            | adr        | pobox*,extadd*,street*,     |
     |                |            |  locality*,region*,pcode*,  |
     |                |            |  country*                   |
     |                | pobox      | PCDATA                      |
     |                | extadd     | PCDATA                      |
     |                | street     | PCDATA                      |
     |                | locality   | PCDATA                      |
     |                | region     | PCDATA                      |
     |                | pcode      | PCDATA                      |
     |                | country    | PCDATA                      |
     | LABEL          | LABEL      | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"adr" forKey:@"ADR"];
    [xcard setObject:@"LABEL" forKey:@"LABEL"];
    
    /* 
    Telecommunications Addressing Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | TEL            | tel        | PCDATA                      |
     | EMAIL          | email      | PCDATA                      |
     | MAILER         | mailer     | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"tel" forKey:@"TEL"];
    [xcard setObject:@"email" forKey:@"EMAIL"];
    [xcard setObject:@"mailer" forKey:@"MAILER"];    
    
    /*
     Geographical Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | TZ             | tz         | PCDATA                      |
     | GEO            | geo        | lat,lon                     |
     |                | lat        | PCDATA                      |
     |                | lon        | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"tz" forKey:@"TZ"];
    [xcard setObject:@"geo" forKey:@"GEO"];

    /*
     Organizational Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | TITLE          | title      | PCDATA                      |
     | ROLE           | role       | PCDATA                      |
     | LOGO           | logo       | extref or b64bin            |
     |                | extref     | EMPTY                       |
     |                | b64bin     | PCDATA                      |
     | AGENT          | agent      | vCard | extref              |
     | ORG            | org        | orgnam,orgunit*             |
     |                | orgnam     | PCDATA                      |
     |                | orgunit    | PCDATA
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"title" forKey:@"TITLE"];
    [xcard setObject:@"role" forKey:@"ROLE"];
    [xcard setObject:@"logo" forKey:@"LOGO"];
    [xcard setObject:@"agent" forKey:@"AGENT"];
    [xcard setObject:@"org" forKey:@"ORG"];
    
    /*
     Explanatory Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | CATEGORIES     | categories | item*                       |
     |                | item       | PCDATA                      |
     | NOTE           | note       | PCDATA                      |
     | SORT-STRING    | sort       | PCDATA                      |
     | SOUND          | sound      | extref | b64bin             |
     |                | extref     | EMPTY                       |
     |                | b64bin     | PCDATA                      |
     | URL            | url        | PCDATA                      |
     | URI            | uri        | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcard setObject:@"categories" forKey:@"CATEGORIES"];
    [xcard setObject:@"note" forKey:@"NOTE"];
    [xcard setObject:@"sort" forKey:@"SORT-STRING"];
    [xcard setObject:@"sound" forKey:@"SOUND"];
    [xcard setObject:@"url" forKey:@"URL"];
    [xcard setObject:@"uri" forKey:@"URI"];    
    
    /*
     Security Types
     +----------------+------------+-----------------------------+
     |      vCard     |  Element   |  Element Content Model      |
     |    Type Name   |   Name     |                             |
     +----------------+------------+-----------------------------+
     | KEY            | key        | extref | b64bin             |
     |                | extref     | EMPTY                       |
     |                | b64bin     | PCDATA                      |
     +----------------+------------+-----------------------------+     
     */
    [xcard setObject:@"key" forKey:@"KEY"];
    
    dict = [xcard copy];
    [xcard release];
  }
  return dict;
}

- (void)_setVCardAttributeMappings {
  /*
   +----------------+------------+-----------+-----------------+
   |      Type      | Attribute  | Attribute | Default         |
   | Parameter Name |    Name    |   Type    |  Value          |
   +----------------+------------+-----------+-----------------+
   | ENCODING       | Not Used   | n/a       | n/a             |
   | LANGUAGE       | lang       | CDATA     | IMPLIED         |
   | TYPE for ADR   | del.type   | NMTOKENS  | 'INTL POSTAL    |
   |  and LABEL     |            |           | PARCEL WORK'    |
   | TYPE for TEL   | tel.type   | NMTOKENS  | 'VOICE'         |
   | TYPE for EMAIL | email.type | NMTOKENS  | 'INTERNET'      |
   | TYPE for PHOTO,| img.type   | CDATA     | REQUIRED        |
   |  and LOGO      |            |           |                 |
   | TYPE for SOUND | aud.type   | CDATA     | REQUIRED        |
   | VALUE          | value      | NOTATION  | See elements    |
   +----------------+------------+-----------+-----------------+   
   */
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
  
  [dict setObject:@"lang" forKey:@"LANGUAGE"];
  [dict setObject:@"value" forKey:@"VALUE"];
  [self setAttributeMapping:dict];
  [dict release];
  
  dict = [[NSMutableDictionary alloc] initWithCapacity:1];
  [dict setObject:@"del.type" forKey:@"TYPE"];
  [self setAttributeMapping:dict forElement:@"ADR"];
  [self setAttributeMapping:dict forElement:@"LABEL"];
  [dict release];
  
  dict = [[NSMutableDictionary alloc] initWithCapacity:1];
  [dict setObject:@"tel.type" forKey:@"TYPE"];
  [self setAttributeMapping:dict forElement:@"TEL"];
  [dict release];
  
  dict = [[NSMutableDictionary alloc] initWithCapacity:1];
  [dict setObject:@"email.type" forKey:@"TYPE"];
  [self setAttributeMapping:dict forElement:@"EMAIL"];
  [dict release];
  
  dict = [[NSMutableDictionary alloc] initWithCapacity:1];
  [dict setObject:@"img.type" forKey:@"TYPE"];
  [self setAttributeMapping:dict forElement:@"PHOTO"];
  [self setAttributeMapping:dict forElement:@"LOGO"];
  [dict release];
  
  dict = [[NSMutableDictionary alloc] initWithCapacity:1];
  [dict setObject:@"aud.type" forKey:@"TYPE"];
  [self setAttributeMapping:dict forElement:@"SOUND"];
  [dict release];
}

- (void)_setVCardSubItemMappings {
  NSArray *a;
  
  a = [NSArray arrayWithObjects:
    @"family",
    @"given",
    @"other",
    @"prefix",
    @"suffix",
    nil];
  [self setSubItemMapping:a forElement:@"n"];

  a = [NSArray arrayWithObjects:
    @"pobox",
    @"extadd",
    @"street",
    @"locality",
    @"region",
    @"pcode",
    @"country",
    nil];
  [self setSubItemMapping:a forElement:@"adr"];
  
  a = [NSArray arrayWithObjects:
    @"lat",
    @"lon",
    nil];
  [self setSubItemMapping:a forElement:@"geo"];
  
  a = [NSArray arrayWithObjects:
    @"orgnam",
    @"orgunit",
    nil];
  [self setSubItemMapping:a forElement:@"org"];
}

- (id)init {
  if ((self = [super init]) != nil) {
    [self setPrefixURI:XMLNS_VSvCard];
    [self setElementMapping:[[self class] xcardMapping]];
    [self setAttributeElements:defElementNames];
    [self _setVCardAttributeMappings];
    [self _setVCardSubItemMappings];
  }
  return self;
}

/* top level parsing method */

- (void)reportDocStart {
  [super reportDocStart];
  
  [self->contentHandler startElement:@"vCardSet" namespace:self->prefixURI
                        rawName:@"vCardSet" attributes:nil];
}
- (void)reportDocEnd {
  [self->contentHandler endElement:@"vCardSet" namespace:self->prefixURI
                        rawName:@"vCardSet"];
  
  [super reportDocEnd];
}

@end /* VCardSaxDriver */
