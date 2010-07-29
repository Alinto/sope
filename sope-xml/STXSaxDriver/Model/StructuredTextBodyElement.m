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

#include "StructuredTextBodyElement.h"
#include "NSString+STX.h"
#include "common.h"

#define ST_ESCAPE_CHAR		'\\'
#define ST_UNDERLINE_CHAR	'_'
#define ST_DYNAMICKEY_CHAR	'@'
#define ST_ITALICS_CHAR		'*'
#define ST_LINK_CHAR		'"'
#define ST_LINKIMAGE_CHAR	'['

static NSString *preprocessorTag = @"##";

@implementation StructuredTextBodyElement

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"STXDebugEnabled"];
}

- (id)init {
  if ((self = [super init])) {
    self->runPreprocessor = YES;
  }
  return self;
}

- (void)dealloc {
  [self->_elements release];
  [super dealloc];
}

/* accessors */

- (NSMutableArray *)elements {
  if (_elements == nil)
    _elements = [[NSMutableArray alloc] init];

  return _elements;
}

- (void)addElement:(StructuredTextBodyElement *)anElement {
  if (anElement == nil)
    return;

  [[self elements] addObject:anElement];
}

/* operations */

- (NSString *)parseText:(NSString *)_str inContext:(NSDictionary *)_ctx {
  // TODO: too big a method
  NSMutableString *result;
  NSString	      *text;
  NSRange	        range, rangeOut;
  int		          i, length, start;

  if (debugOn) 
    NSLog(@"PARSE TEXT: '%@' (delegate=0x%p)", _str, self->_delegate);
  _str = [self preprocessText:_str inContext:_ctx];
  if (debugOn) NSLog(@"  preprocessed: '%@'", _str);
  
  result = [NSMutableString stringWithCapacity:[_str length]];
  text   = _str;
  
  for (i = start = 0, length = [text length]; i < length; i++) {
    unichar c;
    
    c = [text characterAtIndex:i];

    switch (c) {
    case ST_ESCAPE_CHAR:
      if (i - start > 0) {
        range.location = start;
        range.length   = (i - start);
        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      start = ++i;
      break;

    case '\'':
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;

        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      if (i + 1 < length) {
        c = [_str characterAtIndex:i + 1];

        if (c == '\'') {
          start = ++i;
          break;
        }
      }

      range.location = i + 1;
      range.length   = length - range.location;
      rangeOut       = [text rangeOfString:@"'" options:0 range:range];

      if (rangeOut.length > 0) {
        NSString *s;
	
        range.location = i + 1;
        range.length   = rangeOut.location - range.location;
        start      = i = rangeOut.location + 1;
	
        s = [[text substringWithRange:range] unescapedString];
        [self beginPreformattedInContext:_ctx];
        [self appendText:s inContext:_ctx];
        [self endPreformattedInContext:_ctx];
      } 
      else {
        start = i;
      }
      break;

    case ST_UNDERLINE_CHAR:
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;
        start          = i;

        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      range = [self findUnderlineSubstring:[text substringFromIndex:i + 1]];
      
      if (range.length > 0) {
        NSString *s;
	
        range.location  = i + 1;
        i              += range.length + 1;
        start           = i + 1;
	
        s = [[text substringWithRange:range] unescapedString];
        [self beginUnderlineInContext:_ctx];
        s = [self parseText:s inContext:_ctx];
        [self appendText:s inContext:_ctx];
        [self endUnderlineInContext:_ctx];
      }
      break;

    case ST_DYNAMICKEY_CHAR:
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;
        start          = i;

        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      range = [self findDynamicKeySubstring:[text substringFromIndex:i + 1]];
      if (range.length > 0) {
        NSString *s;
	
        range.location = i + 1;
        i             += range.length + 1;
        start          = i + 1;

        s = [self parseText:[text substringWithRange:range] inContext:_ctx];
        [self appendText:[self dynamicKeyText:s inContext:_ctx]
              inContext:_ctx];
      }
      break;

    case ST_ITALICS_CHAR: { // italics and bold
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;
        start          = i;

        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      if (i + 1 < length) {
        c = [text characterAtIndex:i + 1];

        if (c == ST_ITALICS_CHAR) {
          range = [self findBoldSubstring:[text substringFromIndex:i + 2]];

          if (range.length > 0) {
            NSString *s;
	    
            range.location = i + 2;
            i             += range.length + 3;
            start          = i + 1;

            s = [[text substringWithRange:range] unescapedString];
            [self beginBoldInContext:_ctx];
            s = [self parseText:s inContext:_ctx];
            [self appendText:s inContext:_ctx];
            [self endBoldInContext:_ctx];
          }
        } 
        else {
          range = [self findItalicsSubstring:[text substringFromIndex:i + 1]];
	  
          if (range.length > 0) {
            NSString *s;
	    
            range.location = i + 1;
            i             += range.length + 1;
            start          = i + 1;

            s = [[text substringWithRange:range] unescapedString];
            [self beginItalicsInContext:_ctx];
            s = [self parseText:s inContext:_ctx];
            [self appendText:s inContext:_ctx];
            [self endItalicsInContext:_ctx];
          }
        }
      }
      break;
    }

    case ST_LINKIMAGE_CHAR: // links
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;
        start          = i;

        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }

      range = [self findLinkImageSubstring:[text substringFromIndex:i + 1]];

      if (range.length > 0) {
        NSString *s;
	
        range.location = i + 1;
        i             += range.length;
        start          = i + 1;
	
        s = [self linkImage:[text substringWithRange:range] inContext:_ctx];
        [self appendText:s inContext:_ctx];
      }

      break;

    case ST_LINK_CHAR: // links
      if (i - start > 0) {
        range.location = start;
        range.length   = i - start;
        start          = i;
	
        [self appendText:[text substringWithRange:range] inContext:_ctx];
      }
      
      range = [self findLinkSubstring:[text substringFromIndex:(i + 1)]];
      if (range.length > 0) {
        NSString *s;
	
        range.location = i + 1;
        i             += range.length;
        start          = i + 1;
	
        s = [self linkText:[text substringWithRange:range] inContext:_ctx];
        [self appendText:s inContext:_ctx];

        if (debugOn) NSLog(@"found link substring: '%@'", s);
      }

      break;
    }
  }

  if (i - start > 0) {
    range.location = start;
    range.length   = i - start;

    [self appendText:[text substringWithRange:range] inContext:_ctx];
  }
  
  if (debugOn) NSLog(@"  result: '%@'", result);
  return result;
}

- (void)appendText:(NSString *)_txt inContext:(NSDictionary *)_ctx {
  [self->_delegate appendText:_txt inContext:_ctx];
}

- (void)beginItalicsInContext:(NSDictionary *)_ctx {
  [self->_delegate beginItalicsInContext:_ctx];
}
- (void)endItalicsInContext:(NSDictionary *)_ctx {
  [self->_delegate endItalicsInContext:_ctx];
}

- (void)beginUnderlineInContext:(NSDictionary *)_ctx {
  [self->_delegate beginUnderlineInContext:_ctx];
}
- (void)endUnderlineInContext:(NSDictionary *)_ctx {
  [self->_delegate endUnderlineInContext:_ctx];
}

- (void)beginBoldInContext:(NSDictionary *)_ctx {
  [self->_delegate beginBoldInContext:_ctx];
}
- (void)endBoldInContext:(NSDictionary *)_ctx {
  [self->_delegate endBoldInContext:_ctx];
}

- (void)beginPreformattedInContext:(NSDictionary *)_ctx {
  [self->_delegate beginPreformattedInContext:_ctx];
}
- (void)endPreformattedInContext:(NSDictionary *)_ctx {
  [self->_delegate endPreformattedInContext:_ctx];
}

- (void)beginParagraphInContext:(NSDictionary *)_ctx {
  [self->_delegate beginParagraphInContext:_ctx];
}
- (void)endParagraphInContext:(NSDictionary *)_ctx {
  [self->_delegate endParagraphInContext:_ctx];
}

- (NSRange)findMarkerSubstring:(NSString *)_str 
  withMarker:(unichar)aMarker markerLength:(int)markLength 
{
  NSRange range;
  int	  i, h, length;
  
  length = [_str length];
  markLength--;

  for (i = 0; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (c == aMarker && i + markLength < length) {
      BOOL foundMarker = YES;

      for (h = i + 1; h <= i + markLength; h++) {
        c = [_str characterAtIndex:h];

        if (c != aMarker) {
          foundMarker = NO;
          break;
        }
      }

      if (foundMarker) {
        range.location = 0;
        range.length = i;

        return range;
      }
    } 
    else if (c == ST_ESCAPE_CHAR) {
      i++;
    }
  }

  range.location = NSNotFound;
  range.length = 0;

  return range;
}

/* find markers */

- (NSRange)findBoldSubstring:(NSString *)_str {
  return [self findMarkerSubstring:_str 
               withMarker:ST_ITALICS_CHAR markerLength:2];
}

- (NSRange)findItalicsSubstring:(NSString *)_str {
  return [self findMarkerSubstring:_str 
               withMarker:ST_ITALICS_CHAR markerLength:1];
}

- (NSRange)findUnderlineSubstring:(NSString *)_str {
  return [self findMarkerSubstring:_str 
               withMarker:ST_UNDERLINE_CHAR markerLength:1];
}

/* operations */

- (NSRange)_findLinkBlockTargetSubstring:(NSString *)_str {
  NSRange range, rangeTarget;
  int	  length;
  unichar c;
  
  length = [_str length];
  if (debugOn) NSLog(@"  find link block target: '%s'", _str);

  c = [_str characterAtIndex:0];
  
  if (c == ':' && 1 < length) {
    c = [_str characterAtIndex:1];

    range.location = 2;
    range.length = length - range.location;

    if (c == '\'') {
      range = [_str rangeOfString:@"'" options:0 range:range];

      if (range.length == 0)
        return range;
      
      range.length = range.location + 1;

      if (range.length < length) {
        rangeTarget = [self findLinkTargetFromString:
                              [_str substringFromIndex:range.length]];

        if (rangeTarget.length > 0)
          range.length += rangeTarget.length;
      }
    } 
    else if (c == '{') {
      range = [_str rangeOfString:@"}" options:0 range:range];

      if (range.length == 0)
        return range;
      
      range.length = range.location + 1;

      if (range.length < length) {
        rangeTarget = [self findLinkTargetFromString:
                              [_str substringFromIndex:range.length]];

        if (rangeTarget.length > 0)
          range.length += rangeTarget.length;
      }
    } 
    else {
      range = [_str rangeOfString:@" " options:0 range:range];
      
      range.length = (range.length == 0) ? length : range.location;
    }
    
    range.location = 0;

    if (debugOn) NSLog(@"    range(0,%d)", range.length);
    return range;
  }
  
  range.location = NSNotFound;
  range.length   = 0;
  
  if (debugOn) NSLog(@"    not found.");
  return range;
}

- (NSRange)findLinkImageSubstring:(NSString *)_str {
  NSRange range;
  int     i, length;
  
  for (i = 0, length = [_str length]; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (!(c == ']' && i + 1 < length))
      continue;

    range = [self _findLinkBlockTargetSubstring:
		    [_str substringFromIndex:i + 1]];
      
    if (range.length > 0) {
        range.length   += (range.location + i + 1);
        range.location = 0;
    }
    
    return range;
  }

  range.location = NSNotFound;
  range.length = 0;

  return range;
}

- (NSRange)findLinkSubstring:(NSString *)_str {
  NSRange range;
  int     i, length;

  length = [_str length];
  if (debugOn) NSLog(@"find link substring: '%@'(%d)", _str, length);

  for (i = 0; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (!(c == ST_LINK_CHAR && ((i + 1) < length)))
      continue;

    range = [self _findLinkBlockTargetSubstring:
		    [_str substringFromIndex:i + 1]];
      
    if (range.length > 0) {
      range.length   += (range.location + i + 1);
      range.location = 0;
    }
    
    return range;
  }
  
  range.location = NSNotFound;
  range.length = 0;

  return range;
}

- (NSRange)findLinkTargetFromString:(NSString *)_str {
  int     i, length;
  BOOL	  tag = NO;
  NSRange range;
  
  for (i = 0, length = [_str length]; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (!tag && c == ':' && i + 1 < length) {
      c = [_str characterAtIndex:i + 1];

      if (c == ':') {
        i++;
        tag = YES;
      }
    } 
    else if (tag) {
      if (c == '\'') {
        range.location = i + 1;
        range.length = length - range.location;

        range = [_str rangeOfString:@"'" options:0 range:range];
        if (range.length == 0)
          return range;
	
        length = range.location + 1;

        break;
      } 
      else {
        range.location = i;
        range.length   = length - i;
	
        range = [_str rangeOfString:@" " options:0 range:range];
        if (range.length == 0)
          break;
	
        length = range.location;
        break;
      }
    } 
    else {
      range.location = NSNotFound;
      range.length   = 0;
      
      return range;
    }
  }

  range.location = 0;
  range.length = length;

  return range;
}

- (NSRange)findDynamicKeySubstring:(NSString *)_str {
  NSRange range;
  int     i, length;
  
  for (i = 0, length = [_str length]; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (c == ST_DYNAMICKEY_CHAR) {
      range.location = 0;
      range.length = i;

      return range;
    }
  }

  range.location = NSNotFound;
  range.length   = 0;
  return range;
}

/* links */

- (NSString *)_linkBlockTarget:(NSString *)_str withName:(NSString *)aName 
  isImage:(BOOL)isImage inContext:(NSDictionary *)_ctx 
{
  NSString *linkName = aName;
  NSRange  range;
  int	   length;
  unichar  c;
  NSArray  *components;
  NSString *link, *linkType = nil, *target = nil;
  NSRange  rangeOut;

  if (_delegate == nil)
    return _str;
  
  length = [_str length];
  if (length < 2)
    return nil;

  c = [_str characterAtIndex:0];
  if (c != ':') {
    if (debugOn) NSLog(@"no link in: '%@'", _str);
    return nil;
  }
  
  c = [_str characterAtIndex:1];

  range.location = 2;
  range.length = length - range.location;

  if (c == '\'') {
    rangeOut = [_str rangeOfString:@"'" options:0 range:range];

    if (rangeOut.length == 0)
      return nil;
      
    range.length = rangeOut.location - range.location;

    target = [self linkTargetFromString:
		     [_str substringFromIndex:rangeOut.location + 1]];
  }
  else if (c == '{') {
    rangeOut = [_str rangeOfString:@"}" options:0 range:range];

    if (rangeOut.length == 0)
      return nil;
      
    range.location--;
    range.length = rangeOut.location - range.location + 1;
      
    linkType = @"ibn";
      
    target = [self linkTargetFromString:
		     [_str substringFromIndex:rangeOut.location + 1]];
  }
  else {
    rangeOut = [_str rangeOfString:@"::" options:0 range:range];
      
    range.location--;
      
    if (rangeOut.length == 0) {
      rangeOut = [_str rangeOfString:@" " options:0 range:range];

      range.length = (rangeOut.length == 0)
	? length - range.location
	: rangeOut.location - range.location;
    } 
    else {
      range.length = rangeOut.location - range.location;
	
      target = [self linkTargetFromString:
		       [_str substringFromIndex:rangeOut.location]];
    }
  }

  link       = [_str substringWithRange:range];
  components = [link componentsSeparatedByString:@":"];

  if (!linkType)
    linkType = [components objectAtIndex:0];
    
  if (!isImage) {
    if ([linkType isEqualToString:@"mailto"]) {
      return [_delegate insertEmail:linkName withAddress:link 
			inContext:_ctx];
    } 
      
    if ([linkType isEqualToString:@"img"]) {
      NSString *url;

      url = [link substringFromIndex:[linkType length] + 1];

      return [_delegate insertImage:linkName withUrl:url inContext:_ctx];
    } 
      
    if ([linkType isEqualToString:@"ibn"]) {
      if (debugOn) NSLog(@"IBN link %@", linkName);
      return [_delegate insertExtrapolaLink:linkName 
			parameters:[link propertyList] 
			withTarget:target inContext:_ctx];
    }
      
    if (debugOn) NSLog(@"link %@: %@", linkName, link);
    return [_delegate insertLink:linkName withUrl:link target:target
		      inContext:_ctx];
  } 
  
  if (debugOn) NSLog(@"img %@: %@", linkName, link);
  return [_delegate insertImage:linkName withUrl:link inContext:_ctx];
}

- (NSString *)linkImage:(NSString *)_str inContext:(NSDictionary *)_ctx {
  NSString *linkName = nil;
  NSRange  range;
  int	   i, length, startOfTarget;

  if (_delegate == nil)
    return _str;

  length = [_str length];
  
  if (length > 1) {
    unichar c;

    range.location = 0;
    range.length = length;

    range = [_str rangeOfString:@"]" options:0 range:range];

    if (range.length == 0)
      return _str;
    
    startOfTarget = range.location + 1;

    for (i = 1; i < range.location; i++) {
      c = [_str characterAtIndex:i];

      if (c == ST_LINK_CHAR && i + 1 < length) {
        range.location = 1;
        range.length = i - 1;

        linkName = [_str substringWithRange:range];

        range.length = startOfTarget - (i + 2);
        range.location = i + 1;

        linkName = [self _linkBlockTarget:[_str substringWithRange:range]
                         withName:linkName isImage:YES inContext:_ctx];

        break;
      }
    }

    if (linkName) {
      NSString *result;

      result = [self _linkBlockTarget:
                       [_str substringFromIndex:startOfTarget] 
                     withName:linkName isImage:NO inContext:_ctx];
      
      if (result == nil)
        result = _str;
      
      return result;
    }
  }

  return _str;
}

- (NSString *)linkText:(NSString *)_str inContext:(NSDictionary *)_ctx {
  NSString *linkName;
  int	   i, length;
  
  if (_delegate == nil)
    return _str;
  
  for (i = 0, length = [_str length]; i < length; i++) {
    NSString *result;
    unichar c;

    c = [_str characterAtIndex:i];
    
    if (!(c == ST_LINK_CHAR && (i + 1 < length)))
      continue;
    
    linkName = [_str substringToIndex:i];
    
    result = [self _linkBlockTarget:[_str substringFromIndex:i + 1] 
                   withName:linkName isImage:NO inContext:_ctx];
    return result ? result : _str;
  }
  
  return _str;
}

- (NSString *)linkTargetFromString:(NSString *)_str {
  int	  i, length, start;
  BOOL	  tag = NO;
  NSRange range;

  length = [_str length];

  for (start = i = 0; i < length; i++) {
    unichar c;

    c = [_str characterAtIndex:i];

    if (!tag && c == ':' && i + 1 < length) {
      c = [_str characterAtIndex:i + 1];

      if (c == ':') {
        start = i + 2;
        i++;
        tag = YES;
      }
    } 
    else if (c == '\'') {
      range.location = i + 1;
      range.length = length - range.location;

      range = [_str rangeOfString:@"'" options:0 range:range];

      if (range.length == 0)
        break;
      
      length = range.location;
      start++;

      break;
    }
    else {
      break;
    }
  }

  range.location = start;
  range.length = length - range.location;

  if (range.length <= 0) {
    return nil;
  }

  return [_str substringWithRange:range];
}

- (NSString *)dynamicKeyText:(NSString *)_str inContext:(NSDictionary *)_ctx {
  if (_delegate)
    return [_delegate insertDynamicKey:_str inContext:_ctx];

  return _str;
}

- (NSString *)preprocessText:(NSString *)_str inContext:(NSDictionary *)_ctx {
  // TODO: breaks on libFoundation
  // TODO: need to find out what this is exactly supposed to do
  NSMutableString *result;
  NSRange rangeToCopy, range, rangeEnd;
  int     length;
  
  if (debugOn) NSLog(@"preprocess: '%@'", _str);
  
  if (!self->runPreprocessor)
    return _str;
  
  self->runPreprocessor = NO;
  
  length = [_str length];
  result = [NSMutableString stringWithCapacity:length];

  range.location = 0;
  range.length   = length;

  rangeEnd.location = 0;
  rangeEnd.length   = length;

  rangeToCopy.location = 0;
  rangeToCopy.length   = length;
  
  // TODO: the NSNotFound check might make trouble on libFoundation
  for (; range.location != NSNotFound && range.location < length;) {
    range = [_str rangeOfString:preprocessorTag options:0 range:range];
    
    if (range.length == 0) {
      if (rangeEnd.location == 0)
        return _str;
      
      rangeToCopy.location = rangeEnd.location + 2;
      rangeToCopy.length   = (length - rangeToCopy.location);
      
      [result appendString:[_str substringWithRange:rangeToCopy]];
      
      continue;
    }
    
    rangeToCopy.location = rangeEnd.location;

    if (rangeEnd.location > 0)
      rangeToCopy.location += 2;
      
    rangeEnd.location = range.location + 2;
    rangeEnd.length = length - rangeEnd.location;

    rangeEnd = [_str rangeOfString:preprocessorTag options:0 range:rangeEnd];
      
    if (rangeEnd.length > 0) {
      NSRange  keyRange;
      NSString *text;
	
      rangeToCopy.length = (range.location - rangeToCopy.location);
	
      if (rangeToCopy.length > 0) {
	NSString *s;
	  
	s = [_str substringWithRange:rangeToCopy];
	[result appendString:s];
      }

      keyRange.location = range.location + 2;
      keyRange.length = rangeEnd.location - keyRange.location;
        
      text = [_delegate insertPreprocessedTextForKey:
			  [_str substringWithRange:keyRange] 
			inContext:_ctx];
      if (text)
	[result appendString:text];
        
      range.location = rangeEnd.location + 2;
      range.length = length - range.location;

      self->runPreprocessor = YES;
    } 
    else {
      range.location = NSNotFound;

      rangeToCopy.length = length - rangeToCopy.location;
      
      [result appendString:[_str substringWithRange:rangeToCopy]];
    }
  }

  return result;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->_elements) 
    [ms appendFormat:@" #elements=%d", [self->_elements count]];

  if (self->_delegate) {
    [ms appendFormat:@" delegate=0x%p<%@>", 
	  self->_delegate, NSStringFromClass([(id)self->_delegate class])];
  }
  
  if (self->runPreprocessor)
    [ms appendFormat:@" run-preprocessor"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* StructuredTextBodyElement */
