/*
  Copyright (C) 2005 Helge Hess

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

#ifndef __NGiCal_NGVCard_H__
#define __NGiCal_NGVCard_H__

#import <Foundation/NSObject.h>

/*
  NGVCard
  
  Represents a vCard object.

  XML DTD in Dawson-03 Draft:
    <!ELEMENT vCard      (%prop.man;, (%prop.opt;)*)>
    
    <!ATTLIST vCard
            %attr.lang;
            xmlns     CDATA #FIXED 
        'http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-02.txt'
            xmlns:vcf CDATA #FIXED 
        'http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-02.txt'
            version   CDATA #REQUIRED
            rev       CDATA #IMPLIED
            uid       CDATA #IMPLIED
            prodid    CDATA #IMPLIED
            class (PUBLIC | PRIVATE | CONFIDENTIAL) "PUBLIC"
            value NOTATION (VCARD) #IMPLIED>
    <!-- version - Must be "3.0" if document conforms to this spec -->
    <!-- rev - ISO 8601 formatted date or date/time string -->
    <!-- uid - UID associated with the object described by the vCard -->
    <!-- prodid - ISO 9070 FPI for product that generated vCard -->
    <!-- class - Security classification for vCard information -->
  
  Mandatory elements:
    n
    fn
*/

@class NSString, NSArray, NSDictionary, NSData;
@class NGVCardStrArrayValue, NGVCardOrg, NGVCardName, NGVCardSimpleValue;
@class NGVCardPhone, NGVCardAddress;

@interface NGVCard : NSObject
{
  NSString     *uid;
  NSString     *version;
  NSString     *vClass;
  NSString     *prodID;
  NSString     *profile;
  NSString     *source;
  NSString     *vName;
  // TODO: 'rev' (datetime)

  NSString     *fn;
  NSString     *role;
  NSString     *title;
  NSString     *bday;
  NSString     *note;

  NGVCardName  *n;
  NGVCardOrg   *org;
  
  NGVCardStrArrayValue *nickname;
  NGVCardStrArrayValue *categories;
  
  NSArray      *tel;
  NSArray      *adr;
  NSArray      *email;
  NSArray      *label;
  NSArray      *url;
  NSArray      *fburl;
  NSArray      *caluri;
  NSDictionary *x;
  
  NSData       *photo;
  NSString     *photoType; // an IANA registered name
}

+ (NSArray *)parseVCardsFromSource:(id)_src;

- (id)initWithUid:(NSString *)_uid version:(NSString *)_version;

/* accessors */

- (NSString *)version;

- (void)setUid:(NSString *)_uid;
- (NSString *)uid;

- (void)setVClass:(NSString *)_s;
- (NSString *)vClass;
- (void)setVName:(NSString *)_s;
- (NSString *)vName;
- (void)setProdID:(NSString *)_s;
- (NSString *)prodID;
- (void)setProfile:(NSString *)_s;
- (NSString *)profile;
- (void)setSource:(NSString *)_s;
- (NSString *)source;

- (void)setFn:(NSString *)_fn;
- (NSString *)fn;
- (void)setRole:(NSString *)_s;
- (NSString *)role;
- (void)setTitle:(NSString *)_title;
- (NSString *)title;
- (void)setBday:(NSString *)_bday;
- (NSString *)bday;
- (void)setNote:(NSString *)_note;
- (NSString *)note;

- (void)setN:(NGVCardName *)_v;
- (NGVCardName *)n;
- (void)setOrg:(NGVCardOrg *)_v;
- (NGVCardOrg *)org;

- (void)setNickname:(id)_v;
- (NGVCardStrArrayValue *)nickname;
- (void)setCategories:(id)_v;
- (NGVCardStrArrayValue *)categories;

- (void)setTel:(NSArray *)_tel;
- (NSArray *)tel;
- (void)setAdr:(NSArray *)_adr;
- (NSArray *)adr;
- (void)setEmail:(NSArray *)_array;
- (NSArray *)email;
- (void)setLabel:(NSArray *)_array;
- (NSArray *)label;
- (void)setUrl:(NSArray *)_url;
- (NSArray *)url;

- (void)setFreeBusyURL:(NSArray *)_v;
- (NSArray *)freeBusyURL;
- (void)setCalURI:(NSArray *)_calURI;
- (NSArray *)calURI;

- (void)setX:(NSDictionary *)_dict;
- (NSDictionary *)x;

- (void)setPhoto:(NSData *)_photo;
- (NSData *)photo;
- (void)setPhotoType:(NSString *)_photoType;
- (NSString *)photoType;

/* convenience */

- (NGVCardSimpleValue *)preferredEMail;
- (NGVCardPhone *)preferredTel;
- (NGVCardAddress *)preferredAdr;
- (NSString *)photoMimeType;

@end

#endif /* __NGiCal_NGVCard_H__ */
