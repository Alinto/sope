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

#include "NGLdapSearchResultEnumerator.h"
#include "NGLdapConnection+Private.h"
#include "NGLdapAttribute.h"
#include "NGLdapEntry.h"
#include "common.h"

#include <sys/time.h>

@implementation NGLdapSearchResultEnumerator

- (id)initWithConnection:(NGLdapConnection *)_con messageID:(int)_mid {
  if ((self = [super init]) != nil) {
    self->connection = [_con retain];
    self->handle     = [_con ldapHandle];
    self->msgid      = _mid;
    
    // TODO: -timeIntervalSince1970 deprecated on Cocoa
    self->startTime  = [[NSDate date] timeIntervalSince1970];
  }
  return self;
}

- (id)init {
  return [self initWithConnection:NULL messageID:-1];
}

- (void)dealloc {
  [self->connection release];
  [super dealloc];
}

/* state */

- (int)messageID {
  return self->msgid;
}

- (NSTimeInterval)duration {
  // TODO: -timeIntervalSince1970 deprecated on Cocoa
  return [[NSDate date] timeIntervalSince1970] - self->startTime;
}

- (unsigned)index {
  return self->index;
}

- (void)setTimeout:(NSTimeInterval)_value {
  self->timeout = _value;
}
- (NSTimeInterval)timeout {
  return self->timeout;
}

/* enumerator */

- (void)cancel {
  if (self->handle) {
    int res;
    
    res = ldap_abandon(self->handle, self->msgid);
    
    self->handle = NULL;
    [self->connection release]; self->connection = nil;
  }
}

- (NSArray *)_attributesFromResult:(LDAPMessage *)result {
  NSMutableArray *attributes;
  char           *attr;
  BerElement     *ber;

  attributes = [[NSMutableArray alloc] initWithCapacity:32];
      
  for (attr = ldap_first_attribute(self->handle, result, &ber);
       attr != NULL;
       free(attr), attr = ldap_next_attribute(self->handle, result, ber)) {
    NSString        *key;
    NGLdapAttribute *attribute;
    struct berval   **values;
    unsigned        valueCount;
    NSArray         *ovalues;

    if (!(key = [[NSString alloc] initWithCString:attr]))
      /* missing attribute name */
      continue;

    /* process values */
        
    if ((values = ldap_get_values_len(self->handle, result, attr)) == NULL) {
      ovalues = [[NSArray alloc] init];
    }
    else if ((valueCount = ldap_count_values_len(values)) == 1) {
      NSData *value;
          
      value = [[NSData alloc] initWithBytes:values[0]->bv_val
                              length:values[0]->bv_len];
          
      ovalues = [[NSArray alloc] initWithObjects:&value count:1];
          
      [value release];
    }
    else {
      NSMutableArray *a;
      int j;
          
      a = [[NSMutableArray alloc] initWithCapacity:valueCount];
          
      for (j = 0; values[j]; j++) {
        NSData *data;

        data = [[NSData alloc] initWithBytes:values[j]->bv_val
                               length:values[j]->bv_len];
        [a addObject:data];
        [data release];
      }
      ovalues = [a copy];
      [a release];
    }

    if (values) {
      ldap_value_free_len(values);
      values = NULL;
    }
        
    /* create attribute */
        
    attribute =
      [[NGLdapAttribute alloc] initWithAttributeName:key values:ovalues];
        
    [key     release]; key    = nil;
    [ovalues release]; ovalues = nil;

    [attributes addObject:attribute];
    [attribute release];
  }
#if 0
  if (first) {
    ldap_memfree(first);
  }
#endif
  if (ber) {
    ber_free(ber, 0);
  }
  return attributes;
}

- (id)nextObject {
  int            res;
  struct timeval to;
  struct timeval *top;
  LDAPMessage *msg;
  id          record;

  if (self->handle == NULL)
    return nil;

  msg = NULL;
  record = nil;

  top = NULL;
  if (self->timeout > 0) {
    to.tv_sec = self->timeout;
    to.tv_usec = (long)(self->timeout * 1000.0) - (to.tv_sec * 1000);
    top = &to;
  }
  
  res = ldap_result(self->handle, self->msgid, 0, top, &msg);
  if (msg == NULL)
    return nil;
  
  switch(res) {
#if defined(LDAP_RES_SEARCH_REFERENCE)
  case LDAP_RES_SEARCH_REFERENCE: {
    int         rres;
    char        **rptr = NULL;
    LDAPControl **ctrl = NULL;

    rres = ldap_parse_reference(self->handle, msg, &rptr, &ctrl,
				0 /* don't free msg */);
    if (rres == LDAP_SUCCESS) {
    }
    else {
      /* error */
      NSLog(@"%s: couldn't parse result reference ..", __PRETTY_FUNCTION__);
    }

    NSLog(@"ERROR(%s): does not support result references yet ..",
	  __PRETTY_FUNCTION__);
        
    if (rptr != NULL) ldap_value_free(rptr);
    if (ctrl != NULL) ldap_controls_free(ctrl);
        
    break;
  }
#endif
      
  case LDAP_RES_SEARCH_ENTRY: {
    int resultCount;
        
    if ((resultCount = ldap_count_entries(self->handle, msg)) == -1) {
      /* failed */
      int err;
    
      err = ldap_result2error(self->handle, msg, 1 /* free msg */);
          
      [[self->connection _exceptionForErrorCode:err
	    operation:@"count-fetch"
	    userInfo:nil]
	raise];
      return nil;
    }
    
    if (resultCount == 1) {
      LDAPMessage *result;
      NSString    *dn = nil;
      char        *tmp;
      NSArray     *attributes;
          
      if ((result = ldap_first_entry(self->handle, msg)) == NULL) {
	/* could not get entry */
	int err;
            
	err = ldap_result2error(self->handle, msg, 1 /* free msg */);
            
	[[self->connection _exceptionForErrorCode:resultCount
	      operation:@"fetch"
	      userInfo:nil]
	  raise];
            
	return nil;
      }
    
      /* get distinguished name */
          
      if ((tmp = ldap_get_dn(self->handle, result)) != NULL) {
	// TODO: slow ..., somehow fix that.

	/* try UTF-8 (as per spec?) */

	NS_DURING {
	  dn = [[[NSString alloc] initWithUTF8String:tmp] autorelease];
	}
	NS_HANDLER {
	  fprintf(stderr, "Got exception %s while NSUTF8StringEncoding, "
		  "use defaultCStringEncoding",
		  [[localException description] cString]);
	  dn = nil;
	}
	NS_ENDHANDLER;
	
	/* try system encoding (Latin-1 on libFoundation) */
	
	if (dn == nil) // TODO: print a warning?
	  dn = [[[NSString alloc] initWithCString:tmp] autorelease];

	if (tmp != NULL) free(tmp);
      }
      
      /* get all attributes */
          
      attributes = [self _attributesFromResult:result];

      if (result != NULL) {
	// TODO: ldap_msgfree(result); // do not release result-msg ???
	result = NULL;
      }
      
      record = [[NGLdapEntry alloc] initWithDN:dn attributes:attributes];
          
      [attributes release]; attributes = nil;
    }
    else if (resultCount == 0) {
      /* no more results */
      record = nil;
    }
    break;
  }

  case LDAP_RES_SEARCH_RESULT:
    self->handle = NULL;
    [self->connection release]; self->connection = nil;
    break;

  default:
    NSLog(@"NGLdap(%s): unexpected msg-code: %X", __PRETTY_FUNCTION__,res);
    break;
  }
  if (msg != NULL)
    ldap_msgfree(msg);
  
  if (record != nil)
    self->index++;

  return [record autorelease];
}

/* description */

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:100];
  [s appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  [s appendFormat:@" msgid=%i", [self messageID]];
  [s appendFormat:@" duration=%.2fs", [self duration]];
  [s appendFormat:@" index=%i", [self index]];
  
  [s appendString:@">"];

  return s;
}

@end /* LDAPResultEnumerator */
