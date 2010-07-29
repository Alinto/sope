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

#include "NGVCardSaxHandler.h"
#include "NGVCard.h"
#include "NGVCardValue.h"
#include "NGVCardSimpleValue.h"
#include "NGVCardAddress.h"
#include "NGVCardPhone.h"
#include "NGVCardName.h"
#include "NGVCardOrg.h"
#include "NGVCardStrArrayValue.h"
#include "common.h"
#include <string.h>

#ifndef XMLNS_VCARD_XML_03
#  define XMLNS_VCARD_XML_03 \
     @"http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-03.txt"
#endif

// TODO: this is wayyy to big and complicated ;->

@implementation NGVCardSaxHandler

- (void)dealloc {
  if (self->content != NULL) free(self->content);
  [self->subvalues    release];
  [self->xtags        release];
  [self->tel          release];
  [self->adr          release];
  [self->email        release];
  [self->label        release];
  [self->url          release];
  [self->fburl        release];
  [self->caluri       release];
  [self->types        release];
  [self->args         release];
  [self->vCards       release];
  [self->vCard        release];
  [self->currentGroup release];
  [super dealloc];
}

/* results */

- (NSArray *)vCards {
  return self->vCards != nil ? [NSArray arrayWithArray:self->vCards] : nil;
}

/* state */

- (void)resetCardState {
  [self->tel    removeAllObjects];
  [self->adr    removeAllObjects];
  [self->email  removeAllObjects];
  [self->label  removeAllObjects];
  [self->url    removeAllObjects];
  [self->fburl  removeAllObjects];
  [self->caluri removeAllObjects];
  [self->xtags  removeAllObjects];
  [self->currentGroup release]; self->currentGroup = nil;
  [self->types  removeAllObjects];
  [self->args   removeAllObjects];
  [self->vCard release]; self->vCard = nil;
}

- (void)resetExceptResult {
  [self->vCard release]; self->vCard = nil;
  
  [self resetCardState];
  
  if (self->content != NULL) {
    free(self->content);
    self->content = NULL;
  }
  
  self->vcs.isInVCardSet   = 0;
  self->vcs.isInVCard      = 0;
  self->vcs.isInN          = 0;
  self->vcs.isInAdr        = 0;
  self->vcs.isInOrg        = 0;
  self->vcs.isInGroup      = 0;
  self->vcs.collectContent = 0;
}

- (void)reset {
  [self resetExceptResult];
  [self->vCards removeAllObjects];
}

/* document events */

- (void)startDocument {
  [self reset];
  
  if (self->vCards == nil)
    self->vCards = [[NSMutableArray alloc] initWithCapacity:16];

  if (self->tel == nil)
    self->tel = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->adr == nil)
    self->adr = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->email == nil)
    self->email = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->label == nil)
    self->label = [[NSMutableArray alloc] initWithCapacity:8];

  if (self->url == nil)
    self->url = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->fburl == nil)
    self->fburl = [[NSMutableArray alloc] initWithCapacity:1];
  if (self->caluri == nil)
    self->caluri = [[NSMutableArray alloc] initWithCapacity:1];
  
  if (self->types == nil)
    self->types = [[NSMutableArray alloc] initWithCapacity:4];
  if (self->args == nil)
    self->args = [[NSMutableDictionary alloc] initWithCapacity:8];
  
  if (self->subvalues == nil)
    self->subvalues = [[NSMutableDictionary alloc] initWithCapacity:16];
  if (self->xtags == nil)
    self->xtags = [[NSMutableDictionary alloc] initWithCapacity:32];
}
- (void)endDocument {
  [self resetExceptResult];
}

/* common tags */

- (void)startValueTag:(NSString *)_tag attributes:(id<SaxAttributes>)_attrs {
  /* a tag with types and attributes */
  unsigned i, count;
  
  [self->types removeAllObjects];
  [self->args  removeAllObjects];
  
  for (i = 0, count = [_attrs count]; i < count; i++) {
    NSString *n, *v;
    
    n = [_attrs nameAtIndex:i];
    v = [_attrs valueAtIndex:i];
    
    if ([n hasSuffix:@".type"] || [n isEqualToString:@"TYPE"]) {
      /*
        Note: types cannot be separated by comma! Its indeed always a space,eg
                "work pref voice"
              If you find commas, usually the vCard is broken.
      */
      NSEnumerator *e;
      NSString *k;
      
      e = [[v componentsSeparatedByString:@" "] objectEnumerator];
      while ((k = [e nextObject]) != nil) {
        k = [k uppercaseString];
        if ([self->types containsObject:k]) continue;
	[self->types addObject:k];
      }
    }
    else
      [self->args setObject:v forKey:n];
  }
}
- (void)endValueTag {
  [self->types removeAllObjects];
  [self->args  removeAllObjects];
}

/* handle elements */

- (void)startGroup:(NSString *)_name {
  self->vcs.isInGroup = 1;
  ASSIGNCOPY(self->currentGroup, _name);
}
- (void)endGroup {
  self->vcs.isInGroup = 0;
  [self->currentGroup release]; self->currentGroup = nil;
}

- (void)startN {
  [self->subvalues removeAllObjects];
  self->vcs.isInN = 1;
}
- (void)endN {
  NGVCardName *n;
  
  self->vcs.isInN = 0;

  n = [[NGVCardName alloc] initWithPropertyList:self->subvalues
			   group:self->currentGroup
			   types:self->types arguments:self->args];
  [self->vCard setN:n];
  [self->subvalues removeAllObjects];
  [n release];
}

- (void)startOrg {
  [self->subvalues removeAllObjects];
  self->vcs.isInOrg = 1;
}
- (void)endOrg {
  NGVCardOrg *o;
  NSArray *u;

  self->vcs.isInOrg = 0;

  if ((u = [self->subvalues objectForKey:@"orgunit"]) != nil) {
    if (![u isKindOfClass:[NSArray class]])
      u = [NSArray arrayWithObjects:&u count:1];
  }
  
  // TODO: pass org values!
  o = [[NGVCardOrg alloc] initWithName:[self->subvalues objectForKey:@"orgnam"]
			  units:u
			  group:self->currentGroup
			  types:self->types arguments:self->args];
  [self->vCard setOrg:o];
  [o release];
  [self->subvalues removeAllObjects];
}

- (void)startGeo {
  [self->subvalues removeAllObjects];
  self->vcs.isInGeo = 1;
}
- (void)endGeo {
  // TODO
  
  self->vcs.isInGeo = 0;
  
  [self logWithFormat:@"WARNING: not supporting geo in vCard."];
  [self->subvalues removeAllObjects];
}

- (void)startVCard:(id<SaxAttributes>)_attrs {
  NSString *uid, *version;
  NSString *t;
  
  [self->tel    removeAllObjects];
  [self->adr    removeAllObjects];
  [self->email  removeAllObjects];
  [self->label  removeAllObjects];
  [self->url    removeAllObjects];
  [self->fburl  removeAllObjects];
  [self->caluri removeAllObjects];
  [self->xtags  removeAllObjects];
  
  self->vcs.isInVCard = 1;
  if (self->vCard != nil) {
    [self->vCards addObject:self->vCard];
    [self errorWithFormat:@"vCard nesting not supported!"];
    [self->vCard release]; self->vCard = nil;
  }
  
  if ((uid = [_attrs valueForName:@"uid" uri:XMLNS_VCARD_XML_03]) == nil)
    uid = [_attrs valueForName:@"X-ABUID" uri:XMLNS_VCARD_XML_03];
  
  version = [_attrs valueForName:@"version" uri:XMLNS_VCARD_XML_03];
  
  self->vCard = [[NGVCard alloc] initWithUid:uid version:version];

  if ((t = [_attrs valueForName:@"class" uri:XMLNS_VCARD_XML_03]) != nil)
    [self->vCard setVClass:t];
  if ((t = [_attrs valueForName:@"rev" uri:XMLNS_VCARD_XML_03]) != nil) {
    [self warnWithFormat:@"vCard revision not yet supported!"];
    // TODO
  }
  if ((t = [_attrs valueForName:@"prodid" uri:XMLNS_VCARD_XML_03]) != nil)
    [self->vCard setProdID:t];
  
  [self debugWithFormat:@"started vCard: %@", self->vCard];
}
- (void)endVCard {
  self->vcs.isInVCard = 0;

  /* fill collected objects */
  
  if ([self->tel    count] > 0) [self->vCard setTel:self->tel];
  if ([self->adr    count] > 0) [self->vCard setAdr:self->adr];
  if ([self->email  count] > 0) [self->vCard setEmail:self->email];
  if ([self->label  count] > 0) [self->vCard setLabel:self->label];
  if ([self->url    count] > 0) [self->vCard setUrl:self->url];
  if ([self->fburl  count] > 0) [self->vCard setFreeBusyURL:self->fburl];
  if ([self->caluri count] > 0) [self->vCard setCalURI:self->caluri];
  if ([self->xtags  count] > 0) [self->vCard setX:self->xtags];

  [self->vCards addObject:self->vCard];
  //[self debugWithFormat:@"finished vCard: %@", self->vCard];
  
  [self resetCardState];
}

- (void)startVCardSet:(id<SaxAttributes>)_attrs {
  self->vcs.isInVCardSet = 1;
}
- (void)endVCardSet {
  self->vcs.isInVCardSet = 0;
}

- (void)endBaseContentTagWithClass:(Class)_clazz andAddTo:(NSMutableArray*)_a {
  NGVCardSimpleValue *v;

  v = [[_clazz alloc] initWithValue:[self finishCollectingContent]
		      group:self->currentGroup
		      types:self->types arguments:self->args];
  [_a addObject:v];
  
  [self endValueTag];
  [v release];
}

- (void)startTel:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"tel" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endTel {
  [self endBaseContentTagWithClass:[NGVCardPhone class] andAddTo:self->tel];
}

- (void)startAdr:(id<SaxAttributes>)_attrs {
  [self->subvalues removeAllObjects];

  self->vcs.isInAdr = 1;
  [self startValueTag:@"adr" attributes:_attrs];
}
- (void)endAdr {
  NGVCardAddress *address;

  self->vcs.isInAdr = 0;
  
  address = [[NGVCardAddress alloc] initWithPropertyList:self->subvalues
				    group:self->currentGroup
				    types:self->types arguments:self->args];
  [self->adr addObject:address];
  
  [self->subvalues removeAllObjects];
  [self endValueTag];
  [address release];
}

- (void)startEmail:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"email" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endEmail {
  [self endBaseContentTagWithClass:[NGVCardSimpleValue class]
	andAddTo:self->email];
}

- (void)startLabel:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"LABEL" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endLabel {
  [self endBaseContentTagWithClass:[NGVCardSimpleValue class]
	andAddTo:self->label];
}

- (void)startURL:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"url" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endURL {
  // TODO: use special URL class?
  [self endBaseContentTagWithClass:[NGVCardSimpleValue class]
	andAddTo:self->url];
}

/* tags with comma separated values */

- (void)startNickname:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"nickname" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endNickname {
  NGVCardStrArrayValue *v;
  NSArray *a;
  
  // comma unescaping?
  a = [[self finishCollectingContent] componentsSeparatedByString:@","];
  
  v = [[NGVCardStrArrayValue alloc] initWithArray:a
				    group:self->currentGroup
				    types:self->types arguments:self->args];
  [self->vCard setNickname:v];
  [v release]; v = nil;
  
  [self endValueTag];
}

- (void)startCategories:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"categories" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endCategories {
  NGVCardStrArrayValue *v;
  NSArray *a;
  
  // comma unescaping?
  a = [[self finishCollectingContent] componentsSeparatedByString:@","];
  
  v = [[NGVCardStrArrayValue alloc] initWithArray:a
				    group:self->currentGroup
				    types:self->types arguments:self->args];
  [self->vCard setCategories:v];
  [v release]; v = nil;
  
  [self endValueTag];
}

/* generic processing of tags with subtags */

- (void)startSubContentTag:(id<SaxAttributes>)_attrs {
  if ([_attrs count] > 0)
    [self warnWithFormat:@"loosing attrs of subtag: %@", _attrs];
  
  [self startCollectingContent];
}
- (void)endSubContentTag:(NSString *)_key {
  NSString *s;
  id o;
  
  if ((s = [[self finishCollectingContent] copy]) == nil)
    return;
  
  if ((o = [self->subvalues objectForKey:_key]) == nil) {
    [self->subvalues setObject:s forKey:_key];
  }
  else {
    /* multivalue (eg 'org') */
    if ([o isKindOfClass:[NSMutableArray class]]) {
      [o addObject:s];
    }
    else {
      NSMutableArray *a;
      
      a = [[NSMutableArray alloc] initWithCapacity:4];
      [a addObject:o];
      [a addObject:s];
      [self->subvalues setObject:a forKey:_key];
      [a release]; a = nil;
    }
  }
  [s release];
}

/* extended tags (X-) */

- (void)startX:(NSString *)_name attributes:(id<SaxAttributes>)_attrs {
  [self startValueTag:_name attributes:_attrs];
  [self startCollectingContent];
}
- (void)endX:(NSString *)_name {
  NGVCardSimpleValue *v;
  NSString *s;
  id o;
  
  s = [self finishCollectingContent];
  v = [[NGVCardSimpleValue alloc] initWithValue:s
				  group:self->currentGroup
				  types:self->types arguments:self->args];
  
  if ((o = [self->xtags objectForKey:_name]) == nil)
    [self->xtags setObject:v forKey:_name];
  else if ([o isKindOfClass:[NSMutableArray class]])
    [o addObject:v];
  else {
    NSMutableArray *a;
    
    a = [[NSMutableArray alloc] initWithCapacity:4];
    [a addObject:o];
    [a addObject:v];
    [self->xtags setObject:a forKey:_name];
    [a release];
  }
  
  [v release];
  [self endValueTag];
}

/* flat tags */

- (void)startFN:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endFN {
  [self->vCard setFn:[self finishCollectingContent]];
  [self endValueTag];
}

- (void)startRole:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endRole {
  [self->vCard setRole:[self finishCollectingContent]];
  [self endValueTag];
}

- (void)startTitle:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endTitle {
  [self->vCard setTitle:[self finishCollectingContent]];
  [self endValueTag];
}

- (void)startBDay:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endBDay {
  [self->vCard setBday:[self finishCollectingContent]];
  [self endValueTag];
}

- (void)startNote:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endNote {
  [self->vCard setNote:[self finishCollectingContent]];
  [self endValueTag];
}

- (void)startCalURI:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"CALURI" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endCalURI {
  [self endBaseContentTagWithClass:[NGVCardSimpleValue class]
	andAddTo:self->caluri];
}

- (void)startFreeBusyURL:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"FBURL" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endFreeBusyURL {
  [self endBaseContentTagWithClass:[NGVCardSimpleValue class]
	andAddTo:self->fburl];
}

- (void)startPhoto:(id<SaxAttributes>)_attrs {
  [self startValueTag:@"photo" attributes:_attrs];
  [self startCollectingContent];
}
- (void)endPhoto {
  NSString *d;
  NSData   *photo;
  unsigned count, i;

  d     = [self finishCollectingContent];
  // TODO: rfc2426 requires support for URI and other stuff!
  photo = [d dataByDecodingBase64];
  [self->vCard setPhoto:photo];
  count = [self->types count];
  for (i = 0; i < count; i++) {
    NSString *type = [self->types objectAtIndex:i];
    if ([type isEqualToString:@"BASE64"]) {
      continue;
    }
    else {
      [self->vCard setPhotoType:type];
      break;
    }
  }
  
  [self endValueTag];
}

/* OGo?? tags */

- (void)startProfile:(id<SaxAttributes>)_attrs {
  [self startCollectingContent];
}
- (void)endProfile {
  [self->vCard setProfile:[self finishCollectingContent]];
}

- (void)startSource:(id<SaxAttributes>)_attrs {
  [self startCollectingContent];
}
- (void)endSource {
  [self->vCard setSource:[self finishCollectingContent]];
}

- (void)startName:(id<SaxAttributes>)_attrs {
  [self startCollectingContent];
}
- (void)endName {
  [self->vCard setVName:[self finishCollectingContent]];
}


/* element events */

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  unichar c0 = [_localName characterAtIndex:0];

  if (c0 == 'g' && [_localName isEqualToString:@"group"])
    [self startGroup:[_attrs valueForName:@"name" uri:_ns]];
  else if (c0 == 'n' && [_localName length] == 1)
    [self startN];
  else if (c0 == 'o' && [_localName isEqualToString:@"org"])
    [self startOrg];
  else if (c0 == 't' && [_localName isEqualToString:@"tel"])
    [self startTel:_attrs];
  else if (c0 == 'u' && [_localName isEqualToString:@"url"])
    [self startURL:_attrs];
  else if (c0 == 'a' && [_localName isEqualToString:@"adr"])
    [self startAdr:_attrs];
  else if (c0 == 'e' && [_localName isEqualToString:@"email"])
    [self startEmail:_attrs];
  else if (c0 == 'L' && [_localName isEqualToString:@"LABEL"])
    [self startLabel:_attrs];
  else if (c0 == 'v' && [_localName isEqualToString:@"vCard"])
    [self startVCard:_attrs];
  else if (c0 == 'v' && [_localName isEqualToString:@"vCardSet"])
    [self startVCardSet:_attrs];
  else if (c0 == 'n' && [_localName isEqualToString:@"nickname"])
    [self startNickname:_attrs];
  else if (c0 == 'c' && [_localName isEqualToString:@"categories"])
    [self startCategories:_attrs];
  else if (c0 == 'r' && [_localName isEqualToString:@"role"])
    [self startRole:_attrs];
  else if (c0 == 't' && [_localName isEqualToString:@"title"])
    [self startTitle:_attrs];
  else if (c0 == 'b' && [_localName isEqualToString:@"bday"])
    [self startBDay:_attrs];
  else if (c0 == 'n' && [_localName isEqualToString:@"note"])
    [self startNote:_attrs];
  else if (c0 == 'C' && [_localName isEqualToString:@"CALURI"])
    [self startCalURI:_attrs];
  else if (c0 == 'F' && [_localName isEqualToString:@"FBURL"])
    [self startFreeBusyURL:_attrs];
  else if (c0 == 'f' && [_localName isEqualToString:@"fn"])
    [self startFN:_attrs];
  else if (c0 == 'g' && [_localName isEqualToString:@"geo"])
    [self startGeo];
  // TODO: following are generated by LSAddress, but not in spec?
  else if (c0 == 'P' && [_localName isEqualToString:@"PROFILE"])
    [self startProfile:_attrs];
  else if (c0 == 'p' && [_localName isEqualToString:@"photo"])
    [self startPhoto:_attrs];
  else if (c0 == 'S' && [_localName isEqualToString:@"SOURCE"])
    [self startSource:_attrs];
  else if (c0 == 'N' && [_localName isEqualToString:@"NAME"])
    [self startName:_attrs];
  else {
    if (self->vcs.isInN || self->vcs.isInOrg || self->vcs.isInAdr || 
	self->vcs.isInGeo)
      [self startSubContentTag:_attrs];
    else if (c0 == 'X')
      [self startX:_localName attributes:_attrs];
    else
      [self logWithFormat:@"U: %@", _localName];
  }
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  unichar c0 = [_localName characterAtIndex:0];

  if (c0 == 'g' && [_localName isEqualToString:@"group"])
    [self endGroup];
  else if (c0 == 'n' && [_localName isEqualToString:@"n"])
    [self endN];
  else if (c0 == 'o' && [_localName isEqualToString:@"org"])
    [self endOrg];
  else if (c0 == 't' && [_localName isEqualToString:@"tel"])
    [self endTel];
  else if (c0 == 'u' && [_localName isEqualToString:@"url"])
    [self endURL];
  else if (c0 == 'a' && [_localName isEqualToString:@"adr"])
    [self endAdr];
  else if (c0 == 'e' && [_localName isEqualToString:@"email"])
    [self endEmail];
  else if (c0 == 'L' && [_localName isEqualToString:@"LABEL"])
    [self endLabel];
  else if (c0 == 'v' && [_localName isEqualToString:@"vCard"])
    [self endVCard];
  else if (c0 == 'v' && [_localName isEqualToString:@"vCardSet"])
    [self endVCardSet];
  else if (c0 == 'n' && [_localName isEqualToString:@"nickname"])
    [self endNickname];
  else if (c0 == 'c' && [_localName isEqualToString:@"categories"])
    [self endCategories];
  else if (c0 == 'r' && [_localName isEqualToString:@"role"])
    [self endRole];
  else if (c0 == 't' && [_localName isEqualToString:@"title"])
    [self endTitle];
  else if (c0 == 'b' && [_localName isEqualToString:@"bday"])
    [self endBDay];
  else if (c0 == 'n' && [_localName isEqualToString:@"note"])
    [self endNote];
  else if (c0 == 'C' && [_localName isEqualToString:@"CALURI"])
    [self endCalURI];
  else if (c0 == 'F' && [_localName isEqualToString:@"FBURL"])
    [self endFreeBusyURL];
  else if (c0 == 'f' && [_localName isEqualToString:@"fn"])
    [self endFN];
  else if (c0 == 'g' && [_localName isEqualToString:@"geo"])
    [self endGeo];
  else if (c0 == 'P' && [_localName isEqualToString:@"PROFILE"])
    [self endProfile];
  else if (c0 == 'p' && [_localName isEqualToString:@"photo"])
    [self endPhoto];
  else if (c0 == 'S' && [_localName isEqualToString:@"SOURCE"])
    [self endSource];
  else if (c0 == 'N' && [_localName isEqualToString:@"NAME"])
    [self endName];
  else {
    if (self->vcs.isInN || self->vcs.isInOrg || self->vcs.isInAdr ||
	self->vcs.isInGeo)
      [self endSubContentTag:_localName];
    else if (c0 == 'X')
      [self endX:_localName];
  }
}

/* content */

- (void)startCollectingContent {
  if (self->content != NULL) {
    free(self->content);
    self->content = NULL;
  }
  self->vcs.collectContent = 1;
}

- (NSString *)finishCollectingContent {
  NSString *s;
  
  self->vcs.collectContent = 0;
  
  if (self->content == NULL)
    return nil;
  
  if (self->contentLength == 0)
    return @"";
  
  s = [NSString stringWithCharacters:self->content length:self->contentLength];
  if (self->content != NULL) {
    free(self->content);
    self->content = NULL;
  }
  return s;
}

- (void)characters:(unichar *)_chars length:(int)_len {
  if (_len == 0 || _chars == NULL)
    return;
  
  if (self->content == NULL) {
    /* first content */
    self->contentLength = _len;
    self->content       = calloc(_len + 1, sizeof(unichar));
    memcpy(self->content, _chars, (_len * sizeof(unichar)));
  }
  else {
    /* increase content */
    self->content = 
      realloc(self->content, (self->contentLength + _len+2) * sizeof(unichar));
    memcpy(&(self->content[self->contentLength]), _chars, 
	   (_len * sizeof(unichar)));
    self->contentLength += _len;
  }
  self->content[self->contentLength] = 0;
}

@end /* NGVCardSaxHandler */
