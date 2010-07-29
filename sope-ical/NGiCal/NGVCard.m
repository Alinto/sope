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

#include "NGVCard.h"
#include "NGVCardSaxHandler.h"
#include "NGVCardStrArrayValue.h"
#include "NGVCardName.h"
#include "NGVCardOrg.h"
#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxXMLReaderFactory.h>
#include "common.h"

@implementation NGVCard

static id<NSObject,SaxXMLReader> parser = nil; // THREAD
static NGVCardSaxHandler         *sax   = nil; // THREAD

+ (id<NSObject,SaxXMLReader>)vCardParser {
  if (sax == nil)
    sax = [[NGVCardSaxHandler alloc] init];
  
  if (parser == nil) {
    parser =
      [[[SaxXMLReaderFactory standardXMLReaderFactory] 
	                     createXMLReaderForMimeType:@"text/x-vcard"]
                             retain];
    if (parser == nil) {
      NSLog(@"ERROR(%s): did not find a parser for text/x-vcard!",
	    __PRETTY_FUNCTION__);
      return nil;
    }
    
    [parser setContentHandler:sax];
    [parser setErrorHandler:sax];
  }
  
  return parser;
}

+ (NSArray *)parseVCardsFromSource:(id)_src {
  static id<NSObject,SaxXMLReader> parser;
  NSArray *vCards;
  
  if ((parser = [self vCardParser]) == nil)
    return nil;
  
  [parser parseFromSource:_src];
  vCards = [[sax vCards] retain];
  [sax reset];
  return [vCards autorelease];
}

- (id)initWithUid:(NSString *)_uid version:(NSString *)_version {
  if ((self = [super init]) != nil) {
    self->uid     = [_uid     copy];
    self->version = [_version copy];
  }
  return self;
}
- (id)init {
  return [self initWithUid:nil version:@"3.0"];
}

- (void)dealloc {
  [self->profile    release];
  [self->source     release];
  [self->vName      release];
  [self->n          release];
  [self->org        release];
  [self->nickname   release];
  [self->categories release];
  [self->caluri     release];
  [self->fburl      release];
  [self->role       release];
  [self->fn         release];
  [self->title      release];
  [self->bday       release];
  [self->note       release];
  [self->vClass     release];
  [self->prodID     release];
  [self->x          release];
  [self->tel        release];
  [self->url        release];
  [self->adr        release];
  [self->email      release];
  [self->label      release];
  [self->version    release];
  [self->uid        release];
  [super dealloc];
}

/* accessors */

- (NSString *)version {
  return self->version;
}

- (void)setUid:(NSString *)_uid {
  ASSIGNCOPY(self->uid, _uid);
}
- (NSString *)uid {
  return self->uid;
}

- (void)setVClass:(NSString *)_vClass {
  ASSIGNCOPY(self->vClass, _vClass);
}
- (NSString *)vClass {
  return self->vClass;
}

- (void)setVName:(NSString *)_value {
  ASSIGNCOPY(self->vName, _value);
}
- (NSString *)vName {
  return self->vName;
}

- (void)setProdID:(NSString *)_prodID {
  ASSIGNCOPY(self->prodID, _prodID);
}
- (NSString *)prodID {
  return self->prodID;
}

- (void)setProfile:(NSString *)_value {
  ASSIGNCOPY(self->profile, _value);
}
- (NSString *)profile {
  return self->profile;
}

- (void)setSource:(NSString *)_value {
  ASSIGNCOPY(self->source, _value);
}
- (NSString *)source {
  return self->source;
}

- (void)setFn:(NSString *)_fn {
  ASSIGNCOPY(self->fn, _fn);
}
- (NSString *)fn {
  return self->fn;
}

- (void)setRole:(NSString *)_role {
  ASSIGNCOPY(self->role, _role);
}
- (NSString *)role {
  return self->role;
}

- (void)setTitle:(NSString *)_title {
  ASSIGNCOPY(self->title, _title);
}
- (NSString *)title {
  return self->title;
}

- (void)setBday:(NSString *)_bday {
  ASSIGNCOPY(self->bday, _bday);
}
- (NSString *)bday {
  return self->bday;
}

- (void)setNote:(NSString *)_note {
  ASSIGNCOPY(self->note, _note);
}
- (NSString *)note {
  return self->note;
}


- (void)setN:(NGVCardName *)_v {
  ASSIGNCOPY(self->n, _v);
}
- (NGVCardName *)n {
  return self->n;
}

- (void)setOrg:(NGVCardOrg *)_v {
  ASSIGNCOPY(self->org, _v);
}
- (NGVCardOrg *)org {
  return self->org;
}


- (void)setNickname:(id)_v {
  if (![_v isKindOfClass:[NGVCardStrArrayValue class]] && [_v isNotNull])
    _v = [[[NGVCardStrArrayValue alloc] initWithPropertyList:_v] autorelease];
  
  ASSIGNCOPY(self->nickname, _v);
}
- (NGVCardStrArrayValue *)nickname {
  return self->nickname;
}

- (void)setCategories:(id)_v {
  if (![_v isKindOfClass:[NGVCardStrArrayValue class]] && [_v isNotNull])
    _v = [[[NGVCardStrArrayValue alloc] initWithPropertyList:_v] autorelease];
  
  ASSIGNCOPY(self->categories, _v);
}
- (NGVCardStrArrayValue *)categories {
  return self->categories;
}


- (void)setTel:(NSArray *)_tel {
  ASSIGNCOPY(self->tel, _tel);
}
- (NSArray *)tel {
  return self->tel;
}

- (void)setAdr:(NSArray *)_adr {
  ASSIGNCOPY(self->adr, _adr);
}
- (NSArray *)adr {
  return self->adr;
}

- (void)setEmail:(NSArray *)_email {
  ASSIGNCOPY(self->email, _email);
}
- (NSArray *)email {
  return self->email;
}

- (void)setLabel:(NSArray *)_label {
  ASSIGNCOPY(self->label, _label);
}
- (NSArray *)label {
  return self->label;
}

- (void)setUrl:(NSArray *)_url {
  ASSIGNCOPY(self->url, _url);
}
- (NSArray *)url {
  return self->url;
}


- (void)setFreeBusyURL:(NSArray *)_v {
  ASSIGNCOPY(self->fburl, _v);
}
- (NSArray *)freeBusyURL {
  return self->fburl;
}
- (void)setCalURI:(NSArray *)_v {
  ASSIGNCOPY(self->caluri, _v);
}
- (NSArray *)calURI {
  return self->caluri;
}


- (void)setX:(NSDictionary *)_dict {
  ASSIGNCOPY(self->x, _dict);
}
- (NSDictionary *)x {
  return self->x;
}

- (void)setPhoto:(NSData *)_photo {
  ASSIGNCOPY(self->photo, _photo);
}
- (NSData *)photo {
  return self->photo;
}
- (void)setPhotoType:(NSString *)_photoType {
  ASSIGNCOPY(self->photoType, _photoType);
}
- (NSString *)photoType {
  return self->photoType;
}

/* convenience */

- (id)preferredValueInArray:(NSArray *)_values {
  unsigned i, count;
  
  if ((count = [_values count]) == 0)
    return nil;
  if (count == 1)
    return [_values objectAtIndex:0];
  
  /* scan for preferred value */
  for (i = 0; i < count; i++) {
    if ([[_values objectAtIndex:i] isPreferred])
      return [_values objectAtIndex:i];
  }
  
  /* just take first in sequence */
  return [_values objectAtIndex:0];
}

- (NGVCardSimpleValue *)preferredEMail {
  return [self preferredValueInArray:self->email];
}
- (NGVCardPhone *)preferredTel {
  return [self preferredValueInArray:self->tel];
}
- (NGVCardAddress *)preferredAdr {
  return [self preferredValueInArray:self->adr];
}
- (NSString *)photoMimeType {
  NSString *t;
  
  t = [self photoType];
  if (![t isNotNull]) return @"image/octet-stream";
  return [NSString stringWithFormat:@"image/%@", [t lowercaseString]];
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (self->uid   != nil) [_ms appendFormat:@" uid='%@'", self->uid];
  
  if ([self->tel   count] > 0) [_ms appendFormat:@" tel=%@",   self->tel];
  if ([self->adr   count] > 0) [_ms appendFormat:@" adr=%@",   self->adr];
  if ([self->email count] > 0) [_ms appendFormat:@" email=%@", self->email];
  if ([self->label count] > 0) [_ms appendFormat:@" label=%@", self->label];
  if ([self->x     count] > 0) [_ms appendFormat:@" x=%@",     self->x];
}

- (NSString *)description {
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:str];
  [str appendString:@">"];
  return str;
}

@end /* NGVCard */
