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

#include "EOSQLParser.h"
#include "EOQualifier.h"
#include "EOFetchSpecification.h"
#include "EOSortOrdering.h"
#include "EOClassDescription.h"
#include "common.h"

// TODO: better error output

@interface EOSQLParser(Logging) /* this is available in NGExtensions */
- (void)logWithFormat:(NSString *)_fmt,...;
@end

@implementation EOSQLParser

+ (id)sharedSQLParser {
  static EOSQLParser *sharedParser = nil; // THREAD
  if (sharedParser == nil)
    sharedParser = [[EOSQLParser alloc] init];
  return sharedParser;
}

- (void)dealloc {
  [super dealloc];
}

/* top level parsers */

- (EOFetchSpecification *)parseSQLSelectStatement:(NSString *)_sql {
  EOFetchSpecification *fs;
  unichar  *us, *pos;
  unsigned len, remainingLen;
  
  if ((len = [_sql length]) == 0) return nil;

  us  = calloc(len + 10, sizeof(unichar));
  [_sql getCharacters:us];
  us[len] = 0;
  pos = us;
  remainingLen = len;
  
  if (![self parseSQL:&fs from:&pos length:&remainingLen strict:NO])
    [self logWithFormat:@"parsing of SQL failed."];
  
  free(us);
  
  return [fs autorelease];
}

- (EOQualifier *)parseSQLWhereExpression:(NSString *)_sql {
  // TODO: process %=>* and %%, and $
  unichar  *buf;
  unsigned i, len;
  BOOL     didReplace;
  if ((len = [_sql length]) == 0) return nil;
  
  // TODO: improve, real parsing in qualifier parser !
  
  buf = calloc(len + 3, sizeof(unichar));
  NSAssert(buf, @"could not allocate char buffer");
  
  [_sql getCharacters:buf];
  for (i = 0, didReplace = NO; i < len; i++) {
    if (buf[i] != '%') {
      if (buf[i] == '*') {
        NSLog(@"WARNING(%s): SQL string contains a '*': %@",
              __PRETTY_FUNCTION__, _sql);
      }
      continue;
    }
    buf[i] = '%';    
    didReplace = YES;
  }
  if (didReplace)
    _sql = [NSString stringWithCharacters:buf length:len];
  if (buf) free(buf);
  
  return [EOQualifier qualifierWithQualifierFormat:_sql];
}

/* parsing parts (exported for overloading in subclasses) */

static inline BOOL
uniIsCEq(unichar *haystack, const unsigned char *needle, unsigned len) 
{
  register unsigned idx;
  for (idx = 0; idx < len; idx++) {
    if (*needle == '\0')               return YES;
    if (toupper(haystack[idx]) != needle[idx]) return NO;
  }
  return YES;
}
static inline void skipSpaces(unichar **pos, unsigned *len) {
  while (*len > 0) {
    if (!isspace(*pos[0])) return;
    (*len)--;
    (*pos)++;
  }
}
static void printUniStr(unichar *pos, unsigned len) __attribute__((unused));
static void printUniStr(unichar *pos, unsigned len) {
  unsigned i;
  for (i = 0; i < len && i < 80; i++)
    putchar(pos[i]);
  putchar('\n');
}

static inline BOOL isTokStopChar(unichar c) {
  switch (c) {
  case 0:
  case ')': case '(': case '"': case '\'':
    return YES;
  default:
    if (isspace(c)) return YES;
    return NO;
  }
}

- (BOOL)parseToken:(const unsigned char *)tk
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume
{
  /* ...[space] (strlen(tk)+1 chars) */
  unichar  *scur;
  unsigned slen, tlen;
  
  tlen = strlen((const char *)tk);
  scur=*pos; slen=*len; // begin transaction
  skipSpaces(&scur, &slen);
  
  if (slen < tlen)
    return NO;
  if (toupper(scur[0]) != tk[0])
    return NO;
  if (tlen < slen) { /* if tok is not at the end */
    if (!isTokStopChar(scur[tlen]))
      return NO; /* not followed by a token stopper */
  }
  if (!uniIsCEq(scur, tk, tlen)) 
    return NO;
  
  scur+=tlen; slen-=tlen;
  
  if (consume) { *pos = scur; *len = slen; } // end tx
  return YES;
}

- (BOOL)parseIdentifier:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume
{
  /* "attr" or attr (at least 1 char or 2 for ") */
  unichar  *scur;
  unsigned slen;
  
  if (result) *result = nil;
  scur=*pos; slen=*len; // begin transaction
  skipSpaces(&scur, &slen);
  
  if (*scur == '"') {
    /* quoted attr */
    unichar *start;
    
    //printf("try quoted attr\n");
    if (slen < 2) return NO;
    scur++; slen--; /* skip quote */
    if (*scur == '"') {
      /* empty name */
      scur++; slen--;
      if (consume) { *pos = scur; *len = slen; } // end transaction
      *result = @"";
      //printf("is empty quoted\n");
      return YES;
    }
    if (slen < 2) return NO;
    
    start = scur;
    while ((slen > 0) && (*scur != '"')) {
      if (*scur == '\\' && (slen > 1)) {
	/* quoted char */
	scur++; slen--; // skip one more (still needs to be filtered in result
      }
      scur++; slen--;
    }
    if (slen > 0) { scur++; slen--; } /* skip quote */
    
    // TODO: xhandle contained quoted chars ?
    *result = 
      [[NSString alloc] initWithCharacters:start length:(scur-start-1)];
    //NSLog(@"found qattr: %@", *result);
  }
  else {
    /* non-quoted attr */
    unichar *start;
    
    if (slen < 1) return NO;
    
    if ([self parseToken:(const unsigned char *)"FROM" 
	      from:&scur length:&slen consume:NO]) {
      /* not an attribute, the from starts ... */
      // printf("rejected unquoted attr, is a FROM\n");
      return NO;
    }
    if ([self parseToken:(const unsigned char *)"WHERE" 
	      from:&scur length:&slen consume:NO]) {
      /* not an attribute, the where starts ... */
      // printf("rejected unquoted attr, is a WHERE\n");
      return NO;
    }
    
    start = scur;
    while ((slen > 0) && !isspace(*scur) && (*scur != ',')) {
      slen--;
      scur++;
    }
    *result = [[NSString alloc] initWithCharacters:start length:(scur-start)];
    //NSLog(@"found attr: %@ (len=%i)", *result, (scur-start));
  }
  if (consume && result) { *pos = scur; *len = slen; } // end transaction
  return *result ? YES : NO;
}
- (BOOL)parseColumnName:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume
{
  return [self parseIdentifier:result from:pos length:len consume:consume];
}
- (BOOL)parseTableName:(NSString **)result
  from:(unichar **)pos length:(unsigned *)len
  consume:(BOOL)consume
{
  return [self parseIdentifier:result from:pos length:len consume:consume];
}

- (BOOL)parseIdentifierList:(NSArray **)result
  from:(unichar **)pos length:(unsigned *)len
  selector:(SEL)_sel
{
  /* attr[,attr] */
  NSMutableArray *attrs = nil;
  unichar  *scur;
  unsigned slen;
  id       attr;
  BOOL (*parser)(id, SEL, NSString **, unichar **, unsigned *, BOOL);
  
  if (result) *result = nil;
  scur=*pos; slen=*len; // begin transaction
  skipSpaces(&scur, &slen);
  parser = (void *)[self methodForSelector:_sel];
  
  if (slen < 1) return NO; // not enough chars
  
  if (*scur == '*') {
    /* a wildcard list, return 'nil' as result */
    //printf("try wildcard\n");
    scur++; slen--; // skip '*'
    if (!(slen == 0 || isspace(*scur))) {
      /* not followed by space or at end */
      return NO;
    }
    *pos = scur; *len = slen; // end transaction
    *result = nil;
    return YES;
  }
  
  if (!parser(self, _sel, &attr,&scur,&slen,YES))
    /* well, we need at least one attribute to make it a list */
    return NO;
  
  attrs = [[NSMutableArray alloc] initWithCapacity:32];
  [attrs addObject:attr]; [attr release];
  
  /* all the remaining attributes must be prefixed with a "," */
  while (slen > 1) {
    //printf("try next list attr comma\n");
    skipSpaces(&scur, &slen);
    if (slen < 2) break;
    if (*scur != ',') break;
    scur++; slen--; // skip ','
    
    //printf("try next list attr\n");
    if (!parser(self, _sel, &attr,&scur,&slen,YES))
      break;
    
    [attrs addObject:attr]; [attr release];
  }
  
  *pos = scur; *len = slen; // end transaction
  *result = attrs;
  return YES;
}

- (BOOL)parseContainsQualifier:(EOQualifier **)q_
  from:(unichar **)pos length:(unsigned *)len
{
  /* contains('"hh@"') [12+ chars] */
  unichar  *scur;
  unsigned slen;
  NSString *s;
  if (q_) *q_ = nil;
  skipSpaces(&scur, &slen);
  
  if (slen < 12) return NO; // not enough chars
  
  if (![self parseToken:(const unsigned char *)"CONTAINS" 
	     from:pos length:len consume:YES])
    return NO;
  skipSpaces(&scur, &slen);
  [self parseToken:(const unsigned char *)"('" 
	from:&scur length:&slen consume:YES];
  
  if (![self parseIdentifier:&s from:&scur length:&slen consume:YES])
    return NO;
  
  skipSpaces(&scur, &slen);
  [self parseToken:(const unsigned char *)"')" 
	from:&scur length:&slen consume:YES];
  
  *q_ = [[EOQualifier qualifierWithQualifierFormat:
			@"contentAsString doesContain: %@", s] retain];
  if (*q_) {
    *pos = scur; *len = slen; // end transaction
    return YES;
  }
  else
    return NO;
}

- (BOOL)parseQualifier:(EOQualifier **)result
  from:(unichar **)pos length:(unsigned *)len
{
  unichar  *scur;
  unsigned slen;
  
  if (result) *result = nil;
  scur=*pos; slen=*len; // begin transaction
  skipSpaces(&scur, &slen);
  
  if (slen < 3) return NO; // not enough chars
  
  // for now should scan till we find either ORDER BY order GROUP BY
  {
    unichar *start = scur;
    
    while (slen > 0) {
      if (*scur == 'O' || *scur == 'o') {
	if ([self parseToken:(const unsigned char *)"ORDER" 
		  from:&scur length:&slen consume:NO]) {
	  //printf("FOUND ORDER TOKEN ...\n");
	  break;
	}
      }
      else if (*scur == 'G' || *scur == 'g') {
	if ([self parseToken:(const unsigned char *)"GROUP" 
		  from:&scur length:&slen consume:NO]) {
	  //printf("FOUND GROUP TOKEN ...\n");
	  break;
	}
      }
      
      scur++; slen--;
    }

    {
      EOQualifier *q;
      NSString *s;
      
      s = [[NSString alloc] initWithCharacters:start length:(scur-start)];
      if ([s length] == 0) {
	[s release];
	return NO;
      }
      if ((q = [self parseSQLWhereExpression:s]) == nil) {
	[s release];
	return NO;
      }
      *result = [q retain];
      [s release];
    }
  }
  
  *pos = scur; *len = slen; // end transaction
  return YES;
}

- (BOOL)parseScope:(NSString **)_scope:(NSString **)_entity
  from:(unichar **)pos length:(unsigned *)len
{
  /* 
    "('shallow traversal of "..."')"
    "('hierarchical traversal of "..."')"
  */
  unichar  *scur;
  unsigned slen;
  NSString *entityName;
  BOOL isShallow = NO;
  BOOL isDeep    = NO;
  
  if (_scope)  *_scope  = nil;
  if (_entity) *_entity = nil;
  scur=*pos; slen=*len; // begin transaction
  skipSpaces(&scur, &slen);
  if (slen < 14) return NO; // not enough chars
  
  if (*scur != '(') return NO; // does not start with '('
  scur++; slen--; // skip '('
  skipSpaces(&scur, &slen);
  
  if (*scur != '\'') return NO; // does not start with '(''
  scur++; slen--; // skip single quote
  
  /* next the depth */
  
  if ([self parseToken:(const unsigned char *)"SHALLOW" 
	    from:&scur length:&slen consume:YES])
    isShallow = YES;
  else if ([self parseToken:(const unsigned char *)"HIERARCHICAL" 
		 from:&scur length:&slen consume:YES])
    isDeep = YES;
  else if ([self parseToken:(const unsigned char *)"DEEP" 
		 from:&scur length:&slen consume:YES])
    isDeep = YES;
  else
    /* unknown traveral key */
    return NO;
  
  /* some syntactic sugar (not strict about that ...) */
  [self parseToken:(const unsigned char *)"TRAVERSAL" 
	from:&scur length:&slen consume:YES];
  [self parseToken:(const unsigned char *)"OF"        
	from:&scur length:&slen consume:YES];
  if (slen < 1) return NO; // not enough chars
  
  /* now the entity */
  skipSpaces(&scur, &slen);
  if (![self parseTableName:&entityName from:&scur length:&slen consume:YES])
    return NO; // failed to parse entity from scope

  /* trailer */
  skipSpaces(&scur, &slen);
  if (slen > 0 && *scur == '\'') {
    scur++; slen--; // skip single quote
  }
  skipSpaces(&scur, &slen);
  if (slen > 0 && *scur == ')') {
    scur++; slen--; // skip ')'
  }
  
  if (_scope)  *_scope  = isShallow ? @"flat" : @"deep";
  if (_entity) *_entity = entityName;
  *pos = scur; *len = slen; // end transaction
  return YES;
}

- (BOOL)parseSELECT:(EOFetchSpecification **)result
  from:(unichar **)pos length:(unsigned *)len
  strict:(BOOL)beStrict
{
  EOFetchSpecification *fs;
  NSMutableDictionary *lHints;
  NSString *scope     = nil;
  NSArray  *attrs     = nil;
  NSArray  *fromList  = nil;
  NSArray  *orderList = nil;
  NSArray  *lSortOrderings = nil;
  EOQualifier *q = nil;
  BOOL hasSelect = NO;
  BOOL hasFrom   = NO;
  BOOL missingByOfOrder = NO;
  BOOL missingByOfGroup = NO;
  
  *result = nil;
  
  if (![self parseToken:(const unsigned char *)"SELECT" 
	     from:pos length:len consume:YES]) {
    /* must begin with SELECT */
    if (beStrict) return NO;
  }
  else
    hasSelect = YES;
  
  if (![self parseIdentifierList:&attrs from:pos length:len
	     selector:@selector(parseColumnName:from:length:consume:)]) {
    [self logWithFormat:@"missing ID list .."];
    return NO;
  }
  //[self debugWithFormat:@"parsed attrs (%i): %@", [attrs count], attrs];
  
  /* now a from is expected */
  if ([self parseToken:(const unsigned char *)"FROM" 
	    from:pos length:len consume:YES])
    hasFrom = YES;
  else {
    if (beStrict) return NO;
  }
  
  /* check whether it's followed by a scope */
  if ([self parseToken:(const unsigned char *)"SCOPE" 
	    from:pos length:len consume:YES]) {
    NSString *scopeEntity = nil;
    
    if (![self parseScope:&scope:&scopeEntity from:pos length:len]) {
      if (beStrict) return NO;
    }
#if DEBUG_PARSING
    else
      [self logWithFormat:@"FOUND SCOPE: '%@'", scope];
#endif
    
    if (scopeEntity)
      fromList = [[NSArray alloc] initWithObjects:scopeEntity, nil];
    [scopeEntity release];
  }
  else {
    if (![self parseIdentifierList:&fromList from:pos length:len
	       selector:@selector(parseTableName:from:length:consume:)]) {
      [self logWithFormat:@"missing from list .."];
      return NO;
    }
#if DEBUG_PARSING
    [self logWithFormat:@"parsed FROM list (%i): %@",
	  [fromList count], fromList];
#endif
  }
  
  /* check where */
  if ([self parseToken:(const unsigned char *)"WHERE" 
	    from:pos length:len consume:YES]) {
    /* parse qualifier ... */
    
    if ([self parseToken:(const unsigned char *)"CONTAINS" 
	      from:pos length:len consume:NO]) {
      if (![self parseContainsQualifier:&q from:pos length:len]) {
	if (beStrict) return NO;
      }
    }
    else if (![self parseQualifier:&q from:pos length:len]) {
      if (beStrict) return NO;
    }
#if DEBUG_PARSING
    [self logWithFormat:@"FOUND Qualifier: '%@'", q];
#endif
  }
  
  /* check order-by */
  if ([self parseToken:(const unsigned char *)"ORDER" 
	    from:pos length:len consume:YES]) {
    if (![self parseToken:(const unsigned char *)"BY" 
	       from:pos length:len consume:YES]) {
      if (beStrict) return NO;
      missingByOfOrder = YES;
    }
    
    if (![self parseIdentifierList:&orderList from:pos length:len
	       selector:@selector(parseColumnName:from:length:consume:)])
      return NO;
#if DEBUG_PARSING
    [self logWithFormat:@"parsed ORDER list (%i): %@", 
	    [orderList count], orderList];
#endif
  }
  
  /* check group-by */
  if ([self parseToken:(const unsigned char *)"GROUP" 
	    from:pos length:len consume:YES]) {
    if (![self parseToken:(const unsigned char *)"BY" 
	       from:pos length:len consume:YES]) {
      if (beStrict) return NO;
      missingByOfGroup = YES;
    }
  }
  
  //printUniStr(*pos, *len); // DEBUG
  
  if (!hasSelect) [self logWithFormat:@"missing SELECT !"];
  if (!hasFrom)   [self logWithFormat:@"missing FROM !"];
  if (missingByOfOrder) [self logWithFormat:@"missing BY in ORDER BY !"];

  /* build fetchspec */

  lHints = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if (scope) {
    [lHints setObject:scope forKey:@"scope"];
    [scope release]; scope = nil;
  }
  if (attrs) {
    [lHints setObject:attrs forKey:@"attributes"];
    [attrs release]; attrs = nil;
  }
  if (orderList) {
    NSMutableArray *ma;
    unsigned i, len;
    
    len = [orderList count];
    ma = [[NSMutableArray alloc] initWithCapacity:len];
    for (i = 0; i < len; i++) {
      EOSortOrdering *so;
      
      so = [EOSortOrdering sortOrderingWithKey:[orderList objectAtIndex:i]
			   selector:EOCompareAscending];
    }
    lSortOrderings = [ma shallowCopy];
    [ma release];
    [orderList release]; orderList = nil;
  }
  
  fs = [[EOFetchSpecification alloc]
	 initWithEntityName:[fromList componentsJoinedByString:@","]
	 qualifier:q
	 sortOrderings:lSortOrderings
	 usesDistinct:NO isDeep:NO hints:lHints];
  [lHints release];
  [q release];
  [fromList release];
  
  *result = fs;
  return fs ? YES : NO;
}

- (BOOL)parseSQL:(id *)result
  from:(unichar **)pos length:(unsigned *)len
  strict:(BOOL)beStrict
{
  if (*len < 1) return NO;
  
  if ([self parseToken:(const unsigned char *)"SELECT" 
	    from:pos length:len consume:NO])
    return [self parseSELECT:result from:pos length:len strict:beStrict];
  
  //if ([self parseToken:"UPDATE" from:pos length:len consume:NO])
  //if ([self parseToken:"INSERT" from:pos length:len consume:NO])
  //if ([self parseToken:"DELETE" from:pos length:len consume:NO])
  
  [self logWithFormat:@"tried to parse an unsupported SQL statement."];
  return NO;
}

@end /* EOSQLParser */

@implementation EOSQLParser(Tests)

+ (void)testDAVQuery {
  EOFetchSpecification *fs;
  NSString *sql;
  
  NSLog(@"testing: %@ --------------------", self);

  sql = @"\n"
  @"select \n"
  @"  \"http://schemas.microsoft.com/mapi/proptag/x0e230003\",        \n"
  @"  \"urn:schemas:mailheader:subject\",        \n"
  @"  \"urn:schemas:mailheader:from\",\n"
  @"  \"urn:schemas:mailheader:to\",        \n"
  @"  \"urn:schemas:mailheader:cc\",        \n"
  @"  \"urn:schemas:httpmail:read\",        \n"
  @"  \"urn:schemas:httpmail:hasattachment\",        \n"
  @"  \"DAV:getcontentlength\",        \n"
  @"  \"urn:schemas:mailheader:date\",        \n"
  @"  \"urn:schemas:httpmail:date\",      \n"
  @"  \"urn:schemas:mailheader:received\",        \n"
  @"  \"urn:schemas:mailheader:message-id\",        \n"
  @"  \"urn:schemas:mailheader:in-reply-to\",        \n"
  @"  \"urn:schemas:mailheader:references\"      \n"
  @"from \n"
  @"  scope('shallow traversal of \"http://127.0.0.1:9000/o/ol/helge/INBOX\"')\n"
  @"where \n"
  @"  \"DAV:iscollection\" = False \n"
  @"  and \n"
  @"  \"http://schemas.microsoft.com/mapi/proptag/x0c1e001f\" != 'SMTP'\n"
  @"  and \n"
  @"  \"http://schemas.microsoft.com/mapi/proptag/x0e230003\" > 0  \n"
  @"  \n";
  fs = [[self sharedSQLParser] parseSQLSelectStatement:sql];
  
  NSLog(@"  FS: %@", fs);
  if (fs == nil) {
    NSLog(@"  ERROR: could not parse SQL: %@", sql);
  }
  else {
    EOQualifier *q;
    NSString *scope;
    NSArray  *props;
    
    if ((scope = [[fs hints] objectForKey:@"scope"]) == nil)
      NSLog(@"  INVALID: got no scope !");
    if (![scope isEqualToString:@"flat"])
      NSLog(@"  INVALID: got scope %@, expected flat !", scope);

#if 0    
    if ([fs queryWebDAVPropertyNamesOnly])
      NSLog(@"  INVALID: name query only, but queried several attrs !");
#endif
    
    /* check qualifier */
    if ((q = [fs qualifier]) == nil)
      NSLog(@"  INVALID: got not qualifier (expected one) !");
    else if (![q isKindOfClass:[EOAndQualifier class]]) {
      NSLog(@"  INVALID: expected AND qualifier, got %@ !",
	    NSStringFromClass([q class]));
    }
    else if ([[(EOAndQualifier *)q qualifiers] count] != 3) {
      NSLog(@"  INVALID: expected 3 subqualifiers, got %i !",
	    [[(EOAndQualifier *)q qualifiers] count]);
    }

    /* check sortordering */
    if ([fs sortOrderings] != nil) {
      NSLog(@"  INVALID: got sort orderings, specified none: %@ !",
	    [fs sortOrderings]);
    }
    
    /* attributes */
    if ((props = [[fs hints] objectForKey:@"attributes"]) == nil)
      NSLog(@"  INVALID: got not attributes (expected some) !");
    else if (![props isKindOfClass:[NSArray class]]) {
      NSLog(@"  INVALID: attributes not delivered as array ?: %@",
	    NSStringFromClass([props class]));
    }
    else if ([props count] != 14) {
      NSLog(@"  INVALID: invalid attribute count, expected 14, got %i.",
	    [props count]);
    }
  }
  
  NSLog(@"done test: %@ ------------------", self);
}

@end /* EOSQLParser(Tests) */
