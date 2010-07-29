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

#include "imCommon.h"

@interface EOQualifier(PrivateMethodes)

- (NSString *)qualifierDescription;

- (NSException *)invalidImap4SearchQualifier:(NSString *)_reason;

- (NSException *)appendToImap4SearchString:(NSMutableString *)_search 
  insertNot:(BOOL)_insertNot;
- (NSException *)appendToImap4SearchString:(NSMutableString *)_search;

- (id)imap4SearchString;

@end

@implementation EOQualifier(IMAPAdditions)

- (BOOL)isImap4UnseenQualifier { /* a special key/value qualifier */
  return NO;
}

/* building search qualifiers */

static NSArray *FlagKeyWords = nil;
static NSArray *OtherKeyWords = nil;
static BOOL    debugOn = NO;

static void _initImap4SearchCategory(void) {
  NSUserDefaults *ud;
  
  if (FlagKeyWords) return;

  ud = [NSUserDefaults standardUserDefaults];
  FlagKeyWords = [[NSArray alloc] initWithObjects: @"answered", @"deleted",
                            @"draft", @"flagged", @"new", @"old", @"recent",
                            @"seen", @"unanswered", @"undeleted", @"undraft",
                            @"unflagged", @"unseen", nil];
  OtherKeyWords = [[NSArray alloc] initWithObjects:
                             @"bcc", @"body", @"cc", @"from", @"subject",
                             @"text", @"to", @"keyword", @"unkeyword", nil];
  
  debugOn = [ud boolForKey:@"ImapDebugQualifierGeneration"];
}

- (NSException *)invalidImap4SearchQualifier:(NSString *)_reason {
  if (_reason == nil) _reason = @"unknown reason";
  return [NSException exceptionWithName:@"NGImap4SearchQualifierException"
                      reason:_reason
                      userInfo:nil];
}

- (BOOL)isImap4NotQualifier {
  return NO;
}
- (BOOL)isImap4KeyValueQualifier {
  return NO;
}

- (NSException *)appendToImap4SearchString:(NSMutableString *)_search 
  insertNot:(BOOL)_insertNot
{
  return [self invalidImap4SearchQualifier:@"expected key/value qualifier"];
}
- (NSException *)appendToImap4SearchString:(NSMutableString *)_search { 
  return [self appendToImap4SearchString:_search insertNot:NO];
}

- (id)imap4SearchString { /* returns exception on fail */
  [self logWithFormat:@"ERROR(%s): subclass %@ must overide this method!",
	__PRETTY_FUNCTION__, [self class]];
  return nil;
}

@end /* EOQualifier(IMAPAdditions) */


@implementation EOAndQualifier(IMAPAdditions)

- (NSException *)appendToImap4SearchString:(NSMutableString *)_search {
  NSArray         *quals;
  unsigned        i, lCount;
  
  quals  = [self qualifiers];
  
  if ((lCount = [quals count]) == 0) /* no subqualifiers */
    return nil;
  if (lCount == 1) {
    // TODO: use appendToImap4SearchString?
    [_search appendString:[[quals objectAtIndex:0] imap4SearchString]];
    return nil;
  }
  
  for (i = 0; i < lCount; i++) {
    EOQualifier *qualifier;
    NSException *error;
    
    qualifier = [quals objectAtIndex:i];
    if (debugOn)
      [self logWithFormat:@"  append subqualifier: %@", qualifier];
    
    [_search appendString:(i == 0) ? @"(" : @" ("];
    if ((error = [qualifier appendToImap4SearchString:_search]))
      return error;
    [_search appendString:@")"];
  }
  
  return nil /* no error */;
}

- (id)imap4SearchString { /* returns exception on fail */
  NSMutableString *search;
  NSException     *error;
  unsigned        lCount;
  
  _initImap4SearchCategory();
  
  if (debugOn) {
    [self logWithFormat:
	    @"generate IMAP4 expression for AND qualifier: %@", self];
  }
  
  if ((lCount = [[self qualifiers] count]) == 0) /* no subqualifiers */
    return nil;
  if (lCount == 1)
    return [[[self qualifiers] objectAtIndex:0] imap4SearchString];
  
  search = [NSMutableString stringWithCapacity:lCount * 3];
  
  if ((error = [self appendToImap4SearchString:search]) != nil) {
    if (debugOn) [self logWithFormat:@"  error: %@", error];
    return error;
  }
  
  if (debugOn)
    [self logWithFormat:@"  generated: '%@'", search];

  return search;
}

@end /* EOAndQualifier(IMAPAdditions) */


@implementation EOOrQualifier(IMAPAdditions)

- (NSException *)appendToImap4SearchString:(NSMutableString *)_search {
  // TODO: move generation to this method
  id s;
  
  s = [self imap4SearchString];
  if ([s isKindOfClass:[NSException class]])
    return s;
  
  [_search appendString:s];
  return nil;
}

- (id)imap4SearchString { /* returns exception on fail */
  NSArray         *quals;
  NSMutableString *search;
  unsigned        i, lCount;
  NSException     *error;
  
  _initImap4SearchCategory();
  
  if (debugOn) {
    [self logWithFormat:
	    @"generate IMAP4 expression for or-qualifier: %@", self];
  }
  
  quals = [self qualifiers];

  if ((lCount = [quals count]) == 0) /* no subqualifiers */
    return nil;
  if (lCount == 1)
    return [[quals objectAtIndex:0] imap4SearchString];
  
  search = [NSMutableString stringWithCapacity:lCount * 32];
  
  /*
    Note: or queries are specified as:
            OR <search-key1> <search-key2>
          so we need to wrap more ORs in multiple "OR" IMAP4 expressions
          eg: "OR (OR (subject "abc") (subject "nbc")) from "duck""
  */
  
  if ((error = [[quals objectAtIndex:0] appendToImap4SearchString:search]))
    return error;
  
  for (i = 1; i < lCount; i++) {
    EOQualifier *qualifier;
    
    qualifier = [quals objectAtIndex:i];
    [search insertString:@"OR (" atIndex:0];
    [search appendString:@") ("];
    if ((error = [qualifier appendToImap4SearchString:search]))
      return error;
    [search appendString:@")"];
  }
  
  if (debugOn)
    [self logWithFormat:@"  generated: '%@'", search];
  return search;
}

@end /* EOOrQualifier(IMAPAdditions) */


@implementation EOKeyValueQualifier(IMAPAdditions)

- (BOOL)isImap4KeyValueQualifier {
  return YES;
}

- (BOOL)isImap4UnseenQualifier {
  // TODO: this is rather weird: flags suggests an array value!
  if (![[self key] isEqualToString:@"flags"]) 
    return NO;
  return [[self value] isEqualToString:@"unseen"];
}

- (NSException *)appendFlagsCheckToImap4SearchString:(NSMutableString *)search 
  insertNot:(BOOL)insertNot
{
  NSEnumerator *enumerator = nil;
  id       lvalue;
  SEL      lselector;
  
  lvalue    = [self value];
  lselector = [self selector];

  // TODO: add support for <> qualifier? (seen => unseen)
      
  if (sel_eq(lselector, EOQualifierOperatorEqual)) {
    lvalue = [NSArray arrayWithObject:lvalue];
  }
  else if (!sel_eq(lselector, EOQualifierOperatorContains)) {
    return [self invalidImap4SearchQualifier:
		   @"unexpected EOKeyValueQualifier selector"];
  }
  if (![lvalue isKindOfClass:[NSArray class]]) {
    return [self invalidImap4SearchQualifier:
		   @"expected an array in contains-qualifier"];
  }
  
  enumerator = [lvalue objectEnumerator];
  while ((lvalue = [enumerator nextObject]) != nil) {
    lvalue = [lvalue lowercaseString];
        
    if ([FlagKeyWords containsObject:lvalue]) {
      if (insertNot) [search appendString:@"not "];
      [search appendString:lvalue];
    }
    else {
      return [self invalidImap4SearchQualifier:
		     @"unexpected keyword for EOKeyValueQualifier"];
    }
  }
  return nil;
}

- (NSString *)imap4OperatorForDateComparisonSelector:(SEL)lselector {
  if (sel_eq(lselector, EOQualifierOperatorEqual))
    return @" senton ";
  if (sel_eq(lselector, EOQualifierOperatorGreaterThan))
    return @" sentsince ";
  if (sel_eq(lselector, EOQualifierOperatorLessThan))
    return @" sentbefore ";
  
  return nil;
}

- (NSException *)appendToImap4SearchString:(NSMutableString *)search 
  insertNot:(BOOL)insertNot
{
  // TODO: this needs to get reworked
  /* returns exception on fail */
  NSString *lkey;
  id       lvalue;
  SEL      lselector;
  
  lkey      = [[self key] lowercaseString];
  lvalue    = [self value];
  lselector = [self selector];
    
  if ([lkey isEqualToString:@"flags"]) {
    /* NOTE: special "not" processing! */
    return [self appendFlagsCheckToImap4SearchString:search 
                 insertNot:insertNot];
  }
  
  /* not a flag */
  if (insertNot) 
    [search appendString:@"not "];
  
  if ([lkey isEqualToString:@"date"]) {
    NSString *s;
    
    if (![lvalue isKindOfClass:[NSCalendarDate class]]) {
      return [self invalidImap4SearchQualifier:
		     @"expected a NSDate as value"];
    }
    
    if ((s = [self imap4OperatorForDateComparisonSelector:lselector]) == nil)
      return [self invalidImap4SearchQualifier:@"unexpected selector"];
    
    // TODO: operator created but NOT added?
    
    // TODO: much faster without descriptionWithCalendarFormat:?!
    s = [lvalue descriptionWithCalendarFormat:@"%d-%b-%Y"];
    [search appendString:s];
    return nil;
  }

  if ([lkey isEqualToString:@"uid"]) {
    if (!sel_eq(lselector, EOQualifierOperatorEqual))
      return [self invalidImap4SearchQualifier:@"unexpected qualifier 2"];
    
    [search appendString:@"uid "];
    [search appendString:[lvalue stringValue]];
    return nil;
  }
  
  if ([lkey isEqualToString:@"size"]) {
    if (sel_eq(lselector, EOQualifierOperatorGreaterThan))
      [search appendString:@"larger "];
    else if (sel_eq(lselector, EOQualifierOperatorLessThan))
      [search appendString:@"smaller "];
    else
      return [self invalidImap4SearchQualifier:@"unexpected qualifier 3"];
        
    [search appendString:[lvalue stringValue]];
    return nil;
  }
  
  if ([OtherKeyWords containsObject:lkey]) {
    // TODO: actually most keywords only allow for contains! Eg "subject abc"
    //       is a contains query, not an equal query!
    /*
       RFC 3501:
       In all search keys that use strings, a message matches the key if
       the string is a substring of the field.  The matching is
       case-insensitive.

       Would be: "a caseInsensitiveLike: '*ABC*'"
    */
    if (!sel_eq(lselector, EOQualifierOperatorEqual) &&
	!sel_eq(lselector, EOQualifierOperatorContains)) {
      [self logWithFormat:@"IMAP4 generation: got: %@, allowed: %@", 
	    NSStringFromSelector(lselector),
	    NSStringFromSelector(EOQualifierOperatorEqual)];
      return [self invalidImap4SearchQualifier:
		     @"unexpected qualifier, disallowed comparison on "
		     @"OtherKeyWords)"];
    }
    
    [search appendString:lkey];
    [search appendString:@" \""];
    [search appendString:[lvalue stringValue]];
    [search appendString:@"\""];
    return nil;
  }
  
  
  if (!sel_eq(lselector, EOQualifierOperatorEqual))
    return [self invalidImap4SearchQualifier:@"unexpected qualifier 5"];
  
  [search appendString:@"header "];
  [search appendString:lkey];
  [search appendString:@" \""];
  [search appendString:[lvalue stringValue]];
  [search appendString:@"\""];
  return nil;
}

- (id)imap4SearchString { /* returns exception on fail */
  NSMutableString *search;
  NSException     *error;
  
  _initImap4SearchCategory();

  if ([self isImap4UnseenQualifier]) {
    if (debugOn)
      [self logWithFormat:@"is unseen: %@ (%@)", self, [self class]];
    return @"unseen";
  }
  
  search = [NSMutableString stringWithCapacity:256];
  
  if ((error = [self appendToImap4SearchString:search]))
    return error;
  
  return search;
}

@end /* EOKeyValueQualifier(IMAPAdditions) */


@implementation EONotQualifier(IMAPAdditions)

- (BOOL)isImap4NotQualifier {
  return YES;
}

- (NSException *)appendToImap4SearchString:(NSMutableString *)_search { 
  /*
    TODO: we do this because the key/value qualifier can generate multiple
          queries
  */
  return [[self qualifier] appendToImap4SearchString:_search insertNot:YES];
}

- (id)imap4SearchString { /* returns exception on fail */
  NSMutableString *search;
  NSException     *error;
  
  _initImap4SearchCategory();
  
  search = [NSMutableString stringWithCapacity:256];
  
  if ((error = [self appendToImap4SearchString:search]))
    return error;
  
  return search;
}

@end /* EONotQualifier(IMAPAdditions) */
