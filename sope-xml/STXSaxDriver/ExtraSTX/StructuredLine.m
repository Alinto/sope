/*
  Copyright (C) 2004 eXtrapola Srl

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

#import "StructuredLine.h"
#include "common.h"

@implementation StructuredLine

- (id)initWithString:(NSString *)aString level:(int)aLevel {
  if ((self = [super init])) {
    [self setText:aString];
    level = aLevel;
  }
  return self;
}

- (void)dealloc {
  [self->_text         release];
  [self->_originalText release];
  [super dealloc];
}

/* accessors */

- (NSString *)text {
  NSMutableString *result;
  NSArray *components;
  int i, count;
  
  if (self->_text)
    return self->_text;

  result     = [NSMutableString stringWithCapacity:16];
  components = [_originalText componentsSeparatedByString:@"\n"];
  count      = [components count];

  for (i = 0; i < count; i++) {
    NSString *s;
    
    if (i > 0)
      [result appendString:@" "];
    
    s = [components objectAtIndex:i];
    s = [s stringByTrimmingCharactersInSet:
	     [NSCharacterSet whitespaceCharacterSet]];
    [result appendString:s];
  }
  
  self->_text = [result copy];
  return self->_text;
}

- (NSString *)originalText {
  return self->_originalText;
}

- (void)setText:(NSString *)aString {
  BOOL     running = YES;
  int      i, length;
  NSString *ptr;
  
  numberOfSpaces = 0;
  length = [aString length];
  
  for (i = 0; i < length; i++) {
    switch (([aString characterAtIndex:i])) {
    case ' ':
    case 0x09:
      break;

    default:
      running = NO;
      break;
    }
    
    if (!running)
      break;
  }

  if (running)
    return;
  
  numberOfSpaces = i;

  ptr = _originalText;
  self->_originalText = [aString retain];

  [ptr release];
  [self->_text release]; self->_text = nil;
}

- (void)setLevel:(int)aLevel {
  level = aLevel;
}
- (int)level {
  return level;
}

- (int)numberOfSpacesAtBeginning {
  return numberOfSpaces;
}

@end /* StructuredLine */
