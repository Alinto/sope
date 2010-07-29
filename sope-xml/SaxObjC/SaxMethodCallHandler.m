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

#include "SaxMethodCallHandler.h"
#include "common.h"

@interface NSObject(ToBeFixed)

- (id)performSelector:(SEL)_sel
  withObject:(id)_arg1
  withObject:(id)_arg2
  withObject:(id)_arg3;

@end

@implementation SaxMethodCallHandler

static BOOL debugOn = NO;

- (id)init {
  if ((self = [super init]) != nil) {
    self->delegate = self;
    
    self->fqNameToStartSel = 
      NSCreateMapTable(NSObjectMapKeyCallBacks,
		       NSNonOwnedPointerMapValueCallBacks,
		       64);
    self->selName     = [[NSMutableString alloc] initWithCapacity:64];
    self->tagStack    = [[NSMutableArray alloc] initWithCapacity:16];
    
    self->startKey            = @"start_";
    self->endKey              = @"end_";
    self->unknownNamespaceKey = @"any_";

    self->ignoreLevel = -1;
  }
  return self;
}

- (void)dealloc {
  NSFreeMapTable(self->fqNameToStartSel);
  [self->tagStack       release];
  [self->unknownNamespaceKey release];
  [self->startKey       release];
  [self->endKey         release];
  [self->selName        release];
  [self->namespaceToKey release];
  [super dealloc];
}

- (void)registerNamespace:(NSString *)_namespace withKey:(NSString *)_key {
  if (self->namespaceToKey == nil)
    self->namespaceToKey = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  [self->namespaceToKey setObject:_key forKey:_namespace];
}

- (void)setDelegate:(id)_delegate {
  NSResetMapTable(self->fqNameToStartSel);
  
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

- (void)setStartKey:(NSString *)_s {
  id o = self->startKey;
  self->startKey = [_s copy];
  [o release];
}
- (NSString *)startKey {
  return self->startKey;
}

- (void)setEndKey:(NSString *)_s {
  id o = self->endKey;
  self->endKey = [_s copy];
  [o release];
}
- (NSString *)endKey {
  return self->endKey;
}

- (void)setUnknownNamespaceKey:(NSString *)_s {
  id o = self->unknownNamespaceKey;
  self->unknownNamespaceKey = [_s copy];
  [o release];
}
- (NSString *)unknownNamespaceKey {
  return self->unknownNamespaceKey;
}

- (NSArray *)tagStack {
  return self->tagStack;
}
- (unsigned)depth {
  return [self->tagStack count];
}

- (void)ignoreChildren {
  if (self->ignoreLevel == -1)
    self->ignoreLevel = [self depth];
}
- (BOOL)doesIgnoreChildren {
  if (self->ignoreLevel == -1)
    return NO;
  
  return (int)[self depth] >= self->ignoreLevel ? YES : NO;
}

/* standard Sax callbacks */

- (void)endDocument {
  [super endDocument];
  [selName setString:@""];
}

static inline void _selAdd(SaxMethodCallHandler *self, NSString *_s) {
  [self->selName appendString:_s];
}
static inline void _selAddEscaped(SaxMethodCallHandler *self, NSString *_s) {
  register unsigned i, len;
  unichar *buf16;
  BOOL needsEscape = NO;
    unichar *buf;
    unsigned j;
    NSString *s;
  
  if ((len = [_s length]) == 0)
    return;
  
  buf16 = calloc(len + 2, sizeof(unichar));
  for (i = 0; i < len; i++) {
    // TODO: does isalnum work OK for Unicode? (at least it takes an int)
    if (!(isalnum(buf16[i]) || (buf16[i] == '_'))) {
      needsEscape = YES;
      break;
    }
  }
  
  if (!needsEscape) { /* no escaping required, stop processing */
    if (buf16 != NULL) free(buf16);
    [self->selName appendString:_s];
    return;
  }
  
  /* strip out all non-ASCII, non-alnum or _ chars */
  
  buf = calloc(len + 2, sizeof(unichar));
  for (i = 0, j = 0; i < len; i++) {
    register unichar c = buf16[i];
      
    // TODO: isalnum() vs Unicode
    if (isalnum((int)c) || (c == '_')) {
      if (i > 0) {
	if (buf16[i - 1] == '-')
	  c = toupper(c);
      }
      buf[j] = c;
      j++;
    }
    /* else: do nothing, leave out non-ASCII char */
  }
  buf[j] = '\0';
  
  if (buf16 != NULL) free(buf16);
  
  s = [[NSString alloc] initWithCharacters:buf length:j];
  if (buf != NULL) free(buf);
  
  [self->selName appendString:s];
  [s release];
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  NSString *fqName;
  NSString *nskey;
  SEL      sel;
  
  fqName = [[NSString alloc] initWithFormat:@"{%@}%@", _ns, _localName];
  [self->tagStack addObject:fqName];
  [fqName release]; // still retained by tagStack
  
  if ((int)[self depth] > self->ignoreLevel)
    return;
  
  if ((nskey = [self->namespaceToKey objectForKey:_ns]) == nil) {
    /* unknown namespace */
    if (debugOn)
      NSLog(@"unknown namespace key %@ (tag=%@)", _ns, _rawName);

    [self->selName setString:@""];
    _selAdd(self, self->startKey);
  }
  else if ((sel = NSMapGet(self->fqNameToStartSel, fqName))) {
    /* cached a selector .. */
    [self->delegate performSelector:sel withObject:_attrs];
    goto found;
  }
  else {
    [self->selName setString:self->startKey];
    _selAdd(self, nskey);
    _selAddEscaped(self, _localName);
    _selAdd(self, @":");
    
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found correct selector */
      [self->delegate performSelector:sel withObject:_attrs];
      NSMapInsert(self->fqNameToStartSel, fqName, sel);
      goto found;
    }
    
    /* check for 'start_nskey_unknownTag:attributes:' */
    [self->selName setString:self->startKey];
    _selAdd(self, nskey);
    _selAdd(self, @"unknownTag:attributes:");
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found selector */
      [self->delegate performSelector:sel
                      withObject:_localName
                      withObject:_attrs];
      goto found;
    }
    
    /* check for 'start_tag:namespace:attributes:' */
    [self->selName setString:self->startKey];
    _selAdd(self, @"tag:namespace:attributes:");
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found selector */
      [self->delegate performSelector:sel
                      withObject:_localName withObject:_ns
                      withObject:_attrs];
      goto found;
    }
    
    /* ignore tag */
  }
  
  if (debugOn) {
    NSLog(@"%s: ignore tag: %@, sel %@", __PRETTY_FUNCTION__,
	  fqName, self->selName);
  }
  return;

 found:
  ; // required for MacOSX gcc
}

- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  NSString *nskey;
  SEL      sel;
  
  if ((int)[self depth] > self->ignoreLevel) {
    [self->tagStack removeLastObject];
    return;
  }
  self->ignoreLevel = -1;
  
  if ((nskey = [self->namespaceToKey objectForKey:_ns]) == nil) {
    /* unknown namespace */
    if (debugOn)
      NSLog(@"unknown namespace key %@ (tag=%@)", _ns, _rawName);
    [selName setString:self->endKey];
  }
  else {
    [selName setString:self->endKey];
    _selAdd(self, nskey);
    _selAdd(self, _localName);
    
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found correct selector */
      [self->delegate performSelector:sel];
      goto found;
    }
    
    /* check for 'end_nskey_unknownTag:' */
    [self->selName setString:self->endKey];
    _selAdd(self, nskey);
    _selAdd(self, @"unknownTag:");
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found selector */
      [self->delegate performSelector:sel withObject:_localName];
      goto found;
    }
    
    /* check for 'end_tag:namespace:attributes:' */
    [self->selName setString:self->endKey];
    _selAdd(self, @"tag:namespace:");
    sel = NSSelectorFromString(self->selName);
    if ([self->delegate respondsToSelector:sel]) {
      /* ok, found selector */
      [self->delegate performSelector:sel withObject:_localName withObject:_ns];
      goto found;
    }

    /* didn't find end tag .. */
  }
  
  [self->tagStack removeLastObject];
  return;
  
 found:
  [self->tagStack removeLastObject];
}

@end /* SaxMethodCallHandler */
