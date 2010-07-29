/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SaxDAVHandler.h"
#include "EOFetchSpecification+SoDAV.h"
#include <SaxObjC/XMLNamespaces.h>
#import <EOControl/EOQualifier.h>
#include "common.h"

/*
  TODO: support parsing of DASL
  basics are done, open are:
    sort orderings

  Breaks on SQL searches without Brief: T, which contain a 404 propstat:
  ---
  <a:propstat>...found args...</a:propstat>
  <a:propstat><a:status>HTTP/1.1 404 Resource Not Found</a:status><a:prop><e:namesuffix/><e:telexnumber/><e:ttytddphone/><e:bday/><e:weddinganniversary/><h:x3A1D001E/><h:x3A1A001E/></a:prop></a:propstat>
  ---
  
  a set tag can be either in a "propertyupdate" or in a "response"

  <set><prop><a>1</a></prop><prop><b>2</b></prop>
  <response><prop><a>1</a><b>2</b></prop></response>
*/

@implementation SaxDAVHandler

static BOOL debugPropValue = NO;
static BOOL heavyLog = NO;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    debugPropValue = [ud boolForKey:@"DAVParserDebugProp"];
    heavyLog       = [ud boolForKey:@"DAVParserHeavyLog"];
  }
}

- (void)dealloc {
  [self reset];
  [self->locator   release];
  [self->propNames release];
  [self->responses release];
  [self->cdata     release];
  [super dealloc];
}

/* cleanup */

- (void)parseReset {
  /* only reset non-result items */
  if (heavyLog) [self logWithFormat:@"reset parser state"];
  self->propValueNesting  = 0;
  self->in.PropFind       = 0;
  self->in.Prop           = 0;
  self->in.Response       = 0;
  self->in.MultiStatus    = 0;
  self->in.Href           = 0;
  self->in.Status         = 0;
  self->in.PropStat       = 0;
  self->in.PropertyUpdate = 0;
  self->in.Set            = 0;
  self->in.Remove         = 0;
  self->in.SearchRequest  = 0;
  self->in.basicsearch    = 0;
  self->in.select         = 0;
  self->in.from           = 0;
  self->in.scope          = 0;
  self->in.depth          = 0;
  self->in.where          = 0;
  self->in.gt             = 0;
  self->in.lt             = 0;
  self->in.gte            = 0;
  self->in.lte            = 0;
  self->in.eq             = 0;
  self->in.literal        = 0;
  self->in.orderby        = 0;
  self->in.order          = 0;
  self->in.ascending      = 0;
  self->in.target         = 0;
  
  [self->response          release]; self->response          = nil;
  [self->cdata             release]; self->cdata             = nil;
  [self->lastLiteral       release]; self->lastLiteral       = nil;
  [self->lastScopeHref     release]; self->lastScopeHref     = nil;
  [self->lastHref          release]; self->lastHref          = nil;
  [self->lastScopeDepth    release]; self->lastScopeDepth    = nil;
  [self->lastWherePropName release]; self->lastWherePropName = nil;
}
- (void)reset {
  /* reset everything, including result items */
  if (heavyLog) [self logWithFormat:@"reset"];
  [self parseReset];
  self->findAllProps  = NO;
  self->findPropNames = NO;
  [self->propNames removeAllObjects];
  [self->propSet   removeAllObjects];
  [self->responses removeAllObjects];
  [self->targets   removeAllObjects];
  [self->compoundQualStack removeAllObjects];
  [self->qualifiers release]; self->qualifiers = nil;
  [self->searchSQL  release]; self->searchSQL  = nil;
  [self->fspec      release]; self->fspec      = nil;
}

/* accessors */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

/* results */

- (BOOL)propFindAllProperties {
  return self->findAllProps;
}
- (BOOL)propFindPropertyNames {
  return self->findPropNames;
}
- (NSArray *)propFindQueriedNames {
  if ([self->propNames count] == 0) return nil;
  return [[self->propNames copy] autorelease];
}

- (NSArray *)bpropFindTargets {
  if ([self->targets count] == 0) return nil;
  return [[self->targets copy] autorelease];
}

/* proppatch results */

- (NSArray *)propPatchPropertyNamesToRemove {
  if ([self->propNames count] == 0) return nil;
  return [[self->propNames copy] autorelease];
}
- (NSDictionary *)propPatchValues {
  if ([self->propSet count] == 0) return nil;
  return [[self->propSet copy] autorelease];
}

/* search query results */

- (EOFetchSpecification *)searchFetchSpecification {
  EOFetchSpecification *fs;
  
  if (heavyLog) [self logWithFormat:@"build search fetchspec"];
  
  if (self->fspec) {
    if (heavyLog) [self logWithFormat:@"  use parsed fetchspec"];
    return self->fspec;
  }
  
  if ([self->searchSQL length] == 0) {
    if (heavyLog) [self logWithFormat:@"  no SQL to parse"];
    return nil;
  }
  
  fs = [EOFetchSpecification parseWebDAVSQLString:self->searchSQL];
  if (fs == nil) {
    [self logWithFormat:@"could not parse SQL: '%@'", self->searchSQL];
    return nil;
  }
  if (heavyLog) [self logWithFormat:@"  parsed: %@", fs];
  return fs;
}

/* positioning info */

- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_locator {
  ASSIGN(self->locator, _locator);
}

/* parsing */

- (void)startDocument {
  if (heavyLog) [self logWithFormat:@"start document"];
  [self reset];
}
- (void)endDocument {
  if (heavyLog) [self logWithFormat:@"end document"];
  [self parseReset];
}

/* dav elements */

- (void)startSQLElement {
  self->in.SQL = 1;
      
  if (self->cdata) {
    [self logWithFormat:@"some cdata collection already in progress ?"];
  }
  else
    self->cdata = [[NSMutableString alloc] initWithCapacity:256];
}
- (void)endSQLElement {
  /* TODO: could immediatly parse SQL into fetch-spec */
  self->in.SQL = 0;
  [self->searchSQL release]; self->searchSQL = nil;
  self->searchSQL = [self->cdata copy];
  [self->cdata release]; self->cdata = nil;
}

- (void)startLiteralElement {
  self->in.literal = 1;
  if (self->cdata)
    [self logWithFormat:@"some cdata collection already in progress ?"];
  else
    self->cdata = [[NSMutableString alloc] initWithCapacity:256];
}
- (void)endLiteralElement {
  self->in.literal = 0;
  [self->lastLiteral release]; self->lastLiteral = nil;
  self->lastLiteral = [self->cdata copy];
  [self->cdata release]; self->cdata = nil;
}

- (void)startHrefElement {
  self->in.Href = 1;
  if (self->in.scope || self->in.target || self->in.Response) {
    if (self->cdata)
      [self logWithFormat:@"some cdata collection already in progress ?"];
    else
      self->cdata = [[NSMutableString alloc] initWithCapacity:256];
  }
}
- (void)endHrefElement {
  self->in.Href = 0;
  if (self->in.scope) {
    [self->lastScopeHref release]; self->lastScopeHref = nil;
    self->lastScopeHref = [self->cdata copy];
    [self->cdata release]; self->cdata = nil;
  }
  else if (self->in.target && self->cdata != nil) {
    [self->targets addObject:self->cdata];
    [self->cdata release]; self->cdata = nil;
  }
  else if (self->in.Response && self->cdata != nil) {
    [self->lastHref release]; self->lastHref = nil;
    self->lastHref = [self->cdata copy];
    [self->cdata release]; self->cdata = nil;
  }
}

- (void)startDepthElement {
  self->in.depth = 1;
  if (self->in.scope) {
    if (self->cdata)
      [self logWithFormat:@"some cdata collection already in progress ?"];
    else
      self->cdata = [[NSMutableString alloc] initWithCapacity:256];
  }
}
- (void)endDepthElement {
  self->in.depth = 0;
  if (self->in.scope) {
    [self->lastScopeDepth release]; self->lastScopeDepth = nil;
    self->lastScopeDepth = [self->cdata copy];
    [self->cdata release]; self->cdata = nil;
  }
}

- (void)startBasicSearch {
  self->in.basicsearch = 1;
  if (self->fspec)
    [self logWithFormat:@"basicsearch collection already in progress ?"];
  else
    self->fspec = [[EOFetchSpecification alloc] init];
}

- (void)startPropUpdate {
  self->in.PropertyUpdate = 1;
  if (self->propNames == nil)
    self->propNames = [[NSMutableArray alloc] initWithCapacity:64];
  if (self->propSet == nil)
    self->propSet = [[NSMutableDictionary alloc] initWithCapacity:64];
}

- (void)startPropSet {
  self->in.Set = 1;
  if (self->propSet == nil)
    self->propSet = [[NSMutableDictionary alloc] initWithCapacity:64];
  if (debugPropValue)
    [self logWithFormat:@"start <set> tag ..."];
}
- (void)endPropSet {
  self->in.Set = 0;
  if (debugPropValue) {
    [self logWithFormat:@"end </set> tag (%i props in set) ...", 
            [self->propSet count]];
  }
}

- (void)startProp {
  if (self->propSet == nil)
    self->propSet = [[NSMutableDictionary alloc] initWithCapacity:64];
  
  self->in.Prop = 1;
  if (debugPropValue)
    [self logWithFormat:@"start <prop> tag ..."];
}
- (void)endProp {
  self->in.Prop = 0;
}

- (void)startTarget {
  self->in.target = 1;
  [self->targets removeAllObjects];
  if (self->targets == nil) 
    self->targets = [[NSMutableArray alloc] initWithCapacity:16];
}

- (void)startPropFindSpec:(NSString *)_localName {
  unsigned len;
  unichar  c;
  NSString *fqn;
  
  if ((len = [_localName length]) == 0)
    return;
  c = [_localName characterAtIndex:0];
    
  if (c == 'a' && len == 7) {
    if ([_localName isEqualToString:@"allprop"]) {
      self->findAllProps = 1;
      return;
    }
  }
  if (c == 'p' && len == 8) {
    if ([_localName isEqualToString:@"propname"]) {
      self->findPropNames = 1;
      return;
    }
  }
    
  fqn = [[NSString alloc] initWithFormat:@"{%@}%@", XMLNS_WEBDAV, _localName];
  [self->propNames addObject:fqn];
  [fqn release];
}

- (void)startResponseElement {
  self->in.Response = 1;
  
  if (heavyLog) [self logWithFormat:@"clearing property-set"];
  [self->propSet removeAllObjects];
}
- (void)endResponseElement {
  self->in.Response = 0;
  
  if ([self->delegate respondsToSelector:
	     @selector(davHandler:receivedProperties:forURI:)]) {
    [self->delegate
	 davHandler:self
	 receivedProperties:self->propSet
	 forURI:self->lastHref];
  }
  else if (self->response)
    [self->responses addObject:self->response];
}

- (void)endBasicSearch {
  /* only works with a single 'from', 'where' and 'select' */
  NSMutableDictionary *hints;
  
  self->in.basicsearch = 0;
  
  if (self->lastScopeHref)
    [self->fspec setEntityName:self->lastScopeHref];
  
  // qualifier
  
  hints = [[NSMutableDictionary alloc] initWithCapacity:8];
  
  if (self->lastScopeDepth) {
    if ([self->lastScopeDepth isEqualToString:@"infinity"])
      [hints setObject:@"deep" forKey:@"scope"];
    else if ([self->lastScopeDepth isEqualToString:@"1"])
      [hints setObject:@"flat+self" forKey:@"scope"];
    else if ([self->lastScopeDepth isEqualToString:@"1,noroot"])
      [hints setObject:@"flat" forKey:@"scope"];
    else if ([self->lastScopeDepth isEqualToString:@"0"])
      [hints setObject:@"self" forKey:@"scope"];
    else {
      [self logWithFormat:@"unknown search depth '%@'", self->lastScopeDepth];
      [hints setObject:self->lastScopeDepth forKey:@"scope"];
    }
  }
  
  if (self->findPropNames)
    [hints setObject:[NSNumber numberWithBool:YES] forKey:@"namesOnly"];
  if (self->propNames)
    [hints setObject:self->propNames forKey:@"attributes"];
  /* Note: "allprops" is "no attributes set" in fspec */
  
  [self->fspec setHints:hints];
  [hints release];
  
  // [self logWithFormat:@"parsed spec: %@", fspec];
}

- (void)addParsedQualifier:(EOQualifier *)_qualifier {
  if (self->qualifiers)
    [self->qualifiers addObject:_qualifier];
  else {
    //[self logWithFormat:@"got root qualifier: %@", _qualifier];
    [self->fspec setQualifier:_qualifier];
  }
}

- (void)endComparisonQualifier:(SEL)_op {
  /* 
     collect:
     <D:eq>
       <D:prop><D:sn/></D:prop>
       <D:literal>Mueller</D:literal>
     </D:eq>
  */
  EOKeyValueQualifier *kv;
  
  kv = [[EOKeyValueQualifier alloc] initWithKey:self->lastWherePropName
                                    operatorSelector:_op
                                    value:self->lastLiteral];
  [self addParsedQualifier:kv];
  [kv release];
  
  [self->lastWherePropName release]; self->lastWherePropName = nil;
  [self->lastLiteral       release]; self->lastLiteral = nil;
}

- (void)beginCompoundQualifier {
  if (self->compoundQualStack == nil)
    self->compoundQualStack = [[NSMutableArray alloc] initWithCapacity:16];
  
  self->qualifiers = [[NSMutableArray alloc] initWithCapacity:4];
  [self->compoundQualStack addObject:self->qualifiers];
}
- (void)endCompoundQualifier:(NSString *)_localName {
  EOQualifier *q;
  unsigned stackSize;
  
  if ([_localName isEqualToString:@"not"]) {
    unsigned cnt;
    
    if ((cnt = [self->qualifiers count]) == 0)
      q = nil;
    else {
      q = [self->qualifiers objectAtIndex:0];
      if (cnt != 1) {
        [self warnWithFormat:@"too many subqualifiers in not !: %@",
                self->qualifiers];
      }
    }
    q = [[EONotQualifier alloc] initWithQualifier:q];
  }
  else {
    Class qc = Nil;
    
    if ([_localName isEqualToString:@"and"])
      qc = [EOAndQualifier class];
    else if ([_localName isEqualToString:@"or"])
      qc = [EOOrQualifier class];
    else {
      [self logWithFormat:@"unknown compound qualifier: '%@'", _localName];
      qc = Nil;
    }
    
    q = [[qc alloc] initWithQualifierArray:self->qualifiers];
  }
  [self->qualifiers release]; self->qualifiers = nil;
  
  if ((stackSize = [self->compoundQualStack count]) == 0) {
    [self errorWithFormat:@"the qualifier stack is mixed up !"];
  }
  else if (stackSize > 1) {
    /* this one was not the root qualifier */
    [self->compoundQualStack removeObjectAtIndex:(stackSize - 1)];
    self->qualifiers = [self->compoundQualStack objectAtIndex:(stackSize -2 )];
  }
  else
    /* this one was the root qualifier */
    [self->compoundQualStack removeObjectAtIndex:0];
  
  if (q) [self addParsedQualifier:q];
  [q release];
}

- (void)startPropValueElement:(NSString *)_localName namespace:(NSString *)_ns {
  self->propValueNesting++;
  if (debugPropValue) {
    [self debugWithFormat:@"start[%i]: {%@}%@", self->propValueNesting,
	    _ns, _localName];
  }
      
  if (self->propValueNesting == 1) {
    /* starting value */
	
    if (self->cdata) {
      /* this can happen with nested tags ! */
      [self logWithFormat:@"some cdata collection already in progress ?"];
    }
    else
      self->cdata = [[NSMutableString alloc] initWithCapacity:256];
  }
  else {
    /* add tag to value for later parsing */
    [self->cdata appendString:@"<"];
    [self->cdata appendString:@"V:"];
    [self->cdata appendString:_localName];
    [self->cdata appendString:@" xmlns:V=\""];
    [self->cdata appendString:_ns];
    [self->cdata appendString:@"\""];
    [self->cdata appendString:@">"];
  }
}
- (void)endPropValueElement:(NSString *)_localName namespace:(NSString *)_ns {
  NSString *t;
  NSString *fqn;
  
  if (debugPropValue) {
    [self debugWithFormat:@"end[%i]: {%@}%@", self->propValueNesting,
	    _ns, _localName];
  }
  
  if (self->propValueNesting == 1) {
    fqn = [NSString stringWithFormat:@"{%@}%@", _ns, _localName];
      
    t = [self->cdata copy];
    [self->cdata release]; self->cdata = nil;
	
    if (t) 
      [self->propSet setObject:t forKey:fqn];
    else {
      [self->propSet setObject:[NSNull null] forKey:fqn];
      [self errorWithFormat:@"lost the parsing cdata (broken nesting) ?!"];
    }
    [t release];
  }
  else {
    /* add tag to value for later parsing */
    [self->cdata appendString:@"</"];
    [self->cdata appendString:@"V:"];
    [self->cdata appendString:_localName];
    [self->cdata appendString:@">"];
  }
  
  self->propValueNesting--;
}

/* dav element dispatcher */

- (void)startDavElement:(NSString *)_localName {
  unsigned len;
  unichar c;

  if ((len = [_localName length]) == 0)
    return;
  
  if ((self->in.PropFind || self->in.select) && self->in.Prop) {
    [self startPropFindSpec:_localName];
    return;
  }
  if (self->in.where && self->in.Prop) {
    /* a property in a where */
    NSString *fqn;
    fqn = [NSString stringWithFormat:@"{%@}%@", XMLNS_WEBDAV, _localName];
    ASSIGNCOPY(self->lastWherePropName, fqn);
    /* TODO: should return ? */
  }
  if (self->in.PropertyUpdate && self->in.Set && self->in.Prop) {
    [self startPropValueElement:_localName namespace:XMLNS_WEBDAV];
    return;
  }
  if (self->in.Response && self->in.PropStat && self->in.Prop) {
    [self startPropValueElement:_localName namespace:XMLNS_WEBDAV];
    return;
  }
  
  c = [_localName characterAtIndex:0];
  switch (c) {
  case 'a':
    if ([_localName isEqualToString:@"allprop"])
      self->findAllProps = 1;
    else if ([_localName isEqualToString:@"ascending"])
      self->ascending = YES;
    else if ([_localName isEqualToString:@"and"])
      [self beginCompoundQualifier];
    break;
    
  case 'b':
    if ([_localName isEqualToString:@"basicsearch"])
      [self startBasicSearch];
    break;
    
  case 'd':
    if ([_localName isEqualToString:@"depth"])
      [self startDepthElement];
    break;

  case 'e':
    if ([_localName isEqualToString:@"eq"])
      self->in.eq = 1;
    break;
    
  case 'f':
    if ([_localName isEqualToString:@"from"])
      self->in.from = 1;
    break;
    
  case 'g':
    if ([_localName isEqualToString:@"gt"])
      self->in.gt = 1;
    else if ([_localName isEqualToString:@"gte"])
      self->in.gte = 1;
    break;
    
  case 'h':
    if ([_localName isEqualToString:@"href"])
      [self startHrefElement];
    break;
    
  case 'l':
    if ([_localName isEqualToString:@"lt"])
      self->in.lt = 1;
    else if ([_localName isEqualToString:@"lte"])
      self->in.lte = 1;
    else if ([_localName isEqualToString:@"literal"])
      [self startLiteralElement];
    break;

  case 'm':
    if ([_localName isEqualToString:@"multistatus"]) {
      self->in.MultiStatus = 1;
      if (self->responses == nil)
	self->responses = [[NSMutableArray alloc] initWithCapacity:64];
    }
    break;

  case 'n':
    if ([_localName isEqualToString:@"not"])
      [self beginCompoundQualifier];
    break;

  case 'o':
    if ([_localName isEqualToString:@"order"])
      self->in.order = 1;
    else if ([_localName isEqualToString:@"orderby"])
      self->in.orderby = 1;
    else if ([_localName isEqualToString:@"or"])
      [self beginCompoundQualifier];
    break;
    
  case 'p':
    if ([_localName isEqualToString:@"propfind"]) {
      if (self->propNames == nil)
	self->propNames = [[NSMutableArray alloc] initWithCapacity:64];
      self->in.PropFind = 1;
    }
    else if ([_localName isEqualToString:@"prop"])
      [self startProp];
    else if ([_localName isEqualToString:@"propstat"])
      self->in.PropStat = 1;
    else if ([_localName isEqualToString:@"propertyupdate"])
      [self startPropUpdate];
    else if ([_localName isEqualToString:@"propname"]) {
      self->findPropNames = 1;
    }
    break;

  case 'r':
    if ([_localName isEqualToString:@"response"])
      [self startResponseElement];
    else if ([_localName isEqualToString:@"remove"])
      self->in.Remove = 1;
    break;

  case 's':
    if ([_localName isEqualToString:@"status"])
      self->in.Status = 1;
    else if ([_localName isEqualToString:@"set"])
      [self startPropSet];
    else if ([_localName isEqualToString:@"select"])
      self->in.select = 1;
    else if ([_localName isEqualToString:@"scope"])
      self->in.scope = 1;
    else if ([_localName isEqualToString:@"searchrequest"])
      self->in.SearchRequest = 1;
    else if ([_localName isEqualToString:@"sql"])
      [self startSQLElement];
    break;
    
  case 't':
    if ([_localName isEqualToString:@"target"])
      [self startTarget];
    break;
    
  case 'w':
    if ([_localName isEqualToString:@"where"])
      self->in.where = 1;
    break;
    
  default:
    break;
  }
}
- (void)endDavElement:(NSString *)_localName {
  unsigned len;
  unichar c;
  
  if ((len = [_localName length]) == 0)
    return;
  c = [_localName characterAtIndex:0];
  
  if (self->in.PropertyUpdate && self->in.Set && self->in.Prop) {
    if (![_localName isEqualToString:@"prop"]) {
      [self endPropValueElement:_localName namespace:XMLNS_WEBDAV];
      return;
    }
  }
  if (self->in.Response && self->in.PropStat && self->in.Prop) {
    if (![_localName isEqualToString:@"prop"]) {
      [self endPropValueElement:_localName namespace:XMLNS_WEBDAV];
      return;
    }
  }
  
  switch (c) {
  case 'a':
    if ([_localName isEqualToString:@"and"])
      [self endCompoundQualifier:@"and"];
    break;
  case 'b':
    if ([_localName isEqualToString:@"basicsearch"])
      [self endBasicSearch];
    break;
    
  case 'd':
    if ([_localName isEqualToString:@"depth"])
      [self endDepthElement];
    break;
    
  case 'e':
    if ([_localName isEqualToString:@"eq"]) {
      [self endComparisonQualifier:EOQualifierOperatorEqual];
      self->in.eq = 0;
    }
    break;
    
  case 'f':
    if ([_localName isEqualToString:@"from"])
      self->in.from = 0;
    break;

  case 'g':
    if ([_localName isEqualToString:@"gt"]) {
      [self endComparisonQualifier:EOQualifierOperatorGreaterThan];
      self->in.gt = 0;
    }
    else if ([_localName isEqualToString:@"gte"]) {
      [self endComparisonQualifier:EOQualifierOperatorGreaterThanOrEqualTo];
      self->in.gte = 0;
    }
    break;
    
  case 'h':
    if ([_localName isEqualToString:@"href"])
      [self endHrefElement];
    break;
    
  case 'l':
    if ([_localName isEqualToString:@"lt"]) {
      [self endComparisonQualifier:EOQualifierOperatorLessThan];
      self->in.lt = 0;
    }
    else if ([_localName isEqualToString:@"lte"]) {
      [self endComparisonQualifier:EOQualifierOperatorLessThanOrEqualTo];
      self->in.lte = 0;
    }
    else if ([_localName isEqualToString:@"literal"])
      [self endLiteralElement];
    break;
    
  case 'm':
    if ([_localName isEqualToString:@"multistatus"])
      self->in.MultiStatus = 0;
    break;
    
  case 'n':
    if ([_localName isEqualToString:@"not"])
      [self endCompoundQualifier:@"not"];
    break;

  case 'o':
    if ([_localName isEqualToString:@"order"])
      self->in.order = 0;
    else if ([_localName isEqualToString:@"orderby"])
      self->in.orderby = 0;
    else if ([_localName isEqualToString:@"or"])
      [self endCompoundQualifier:@"or"];
    break;
    
  case 'p':
    if ([_localName isEqualToString:@"propfind"])
      self->in.PropFind = 0;
    else if ([_localName isEqualToString:@"prop"])
      [self endProp];
    else if ([_localName isEqualToString:@"propstat"])
      self->in.PropStat = 0;
    else if ([_localName isEqualToString:@"propertyupdate"])
      self->in.PropertyUpdate = 0;
    break;

  case 'r':
    if ([_localName isEqualToString:@"response"])
      [self endResponseElement];
    else if ([_localName isEqualToString:@"remove"])
      self->in.Remove = 0;
    break;

  case 's':
    if ([_localName isEqualToString:@"set"])
      [self endPropSet];
    else if ([_localName isEqualToString:@"select"])
      self->in.select = 0;
    else if ([_localName isEqualToString:@"scope"])
      self->in.scope = 0;
    else if ([_localName isEqualToString:@"searchrequest"])
      self->in.SearchRequest = 0;
    
    else if ([_localName isEqualToString:@"sql"])
      [self endSQLElement];
    else if ([_localName isEqualToString:@"status"])
      self->in.Status = 0;
    break;

  case 't':
    if ([_localName isEqualToString:@"target"])
      self->in.target = 0;
    break;

  case 'w':
    if ([_localName isEqualToString:@"where"])
      self->in.where = 0;
    break;
  }
}

/* element callbacks */

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attributes
{
  if (heavyLog) [self logWithFormat:@"START {%@}%@", _ns, _localName];
  
  if ([_ns isEqualToString:XMLNS_WEBDAV]) {
    [self startDavElement:_localName];
  }
  else if (self->in.PropFind || self->in.select) {
    NSString *fqn;
    fqn = [NSString stringWithFormat:@"{%@}%@", _ns, _localName];
    [self->propNames addObject:fqn];
  }
  else if (self->in.where && self->in.Prop) {
    NSString *fqn;
    fqn = [NSString stringWithFormat:@"{%@}%@", _ns, _localName];
    ASSIGNCOPY(self->lastWherePropName, fqn);
  }
  else if (self->in.PropertyUpdate) {
    if (self->in.Set) {
      [self startPropValueElement:_localName namespace:_ns];
    }
    else if (self->in.Remove) {
      NSString *fqn;
    
      fqn = [NSString stringWithFormat:@"{%@}%@", _ns, _localName];
      [self->propNames addObject:fqn];
    }
  }
  else if (self->in.Response && self->in.PropStat && self->in.Prop)
    [self startPropValueElement:_localName namespace:_ns];
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  if (heavyLog) [self logWithFormat:@"END {%@}%@", _ns, _localName];
  
  if ([_ns isEqualToString:XMLNS_WEBDAV]) {
    [self endDavElement:_localName];
  }
  else if (self->in.PropFind) {
    /* no close tags in propfind ... */
  }
  else if (self->in.PropertyUpdate) {
    if (self->in.Set)
      [self endPropValueElement:_localName namespace:_ns];
    else if (self->in.Remove) {
      /* no close tags in remove section ... */
    }
  }
  else if (self->in.Response && self->in.PropStat && self->in.Prop)
    [self endPropValueElement:_localName namespace:_ns];
}

/* CDATA */

- (void)characters:(unichar *)_chars length:(int)_len {
  if (heavyLog) [self logWithFormat:@"got %i chars", _len];
  
  if (_len > 0 && (self->cdata != nil)) {
    NSString *s;
    
    s = [[NSString alloc] initWithCharacters:_chars length:_len];
    [self->cdata appendString:s];
    [s release];
  }
}

@end /* SaxDAVHandler */
