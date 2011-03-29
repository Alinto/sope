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

#include <NGObjWeb/WOHTMLDynamicElement.h>
#include "WOElement+private.h"
#include "decommon.h"
#include <string.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSDateFormatter.h>

/*
  Usage:
    MyString: WOString {
      value      = myCalendarDate;
      dateformat = "%B %Y %T";
      insertBR   = NO;
      nilString  = "no date is set !";
      escapeHTML = YES;
    };

  Hierarchy:
    WOHTMLDynamicElement
      WOString
        _WOSimpleStaticString
        _WOSimpleStaticASCIIString
        _WOComplexString
*/

@interface WOString : WOHTMLDynamicElement
@end /* WOString */

@interface _WOTemporaryString : NSObject
@end

@interface _WOSimpleStaticString : WOString
{
  NSString *value;
}
@end /* WOSimpleStaticString */

@interface _WOSimpleStaticASCIIString : WOString
{
  const unsigned char *value;
}
@end /* _WOSimpleStaticASCIIString */

@interface _WOSimpleDynamicString : WOString
{
  WOAssociation *value;
}
@end /* WOSimpleStaticString */

@interface _WOComplexString : WOString
{
  WOAssociation *value;          // object
  WOAssociation *escapeHTML;     // BOOL
  WOAssociation *numberformat;   // string
  WOAssociation *dateformat;     // string
  WOAssociation *formatter;      // WO4: NSFormatter object
  WOAssociation *valueWhenEmpty; // WO4.5
  
  // non-WO attributes
  WOAssociation *insertBR;   // insert <BR> tags for newlines
  WOAssociation *nilString;  // string to use if value is nil - DEPRECATED!
  WOAssociation *style;      // insert surrounding <span class="style">
  // TODO: also add 'id' for span? (JavaScript tagging?)
}

@end /* WOComplexString */

@implementation WOString

+ (int)version {
  return [super version] + 1 /* v3 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

+ (id)allocWithZone:(NSZone *)zone {
  static Class WOStringClass = Nil;
  static _WOTemporaryString *temporaryString = nil;
  
  if (WOStringClass == Nil)
    WOStringClass = [WOString class];
  if (temporaryString == nil)
    temporaryString = [_WOTemporaryString allocWithZone:zone];
  
  return (self == WOStringClass)
    ? (id)temporaryString
    : (id)NSAllocateObject(self, 0, zone);
}

@end /* WOString */


@implementation _WOSimpleDynamicString

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->value = OWGetProperty(_config, @"value");
  }
  return self;
}

- (void)dealloc {
  [self->value release];
  [super dealloc];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  if (![_ctx isRenderingDisabled])
    [_resp appendContentHTMLString:[self->value stringValueInContext:_ctx]];
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@" value='%@'", self->value];
}

@end /* _WOSimpleDynamicString */

@implementation _WOSimpleStaticString

- (id)initWithValue:(WOAssociation *)_value escapeHTML:(BOOL)_flag {
  if ((self = [super initWithName:nil associations:nil template:nil])) {
    NSString *v;
    unsigned length;

    v = [_value stringValueInComponent:nil];
    length = [v length];

    if (length == 0) {
      v = @"";
    }
    else if (_flag) {
      unichar buffer[length * 6]; /* longest-encoding: '&quot;' */
      unichar     *cbuf;
      register unichar *cstr;
      register unsigned i;
      register unichar *bufPtr;

#if NeXT_Foundation_LIBRARY
      cbuf = malloc((length + 1) * sizeof (unichar));
#else
      cbuf = NGMallocAtomic((length + 1) * sizeof (unichar));
#endif
      [v getCharacters:cbuf]; cbuf[length] = '\0';
      cstr = cbuf;
      
      for (i = 0, bufPtr = buffer; i < length; i++) {
        switch (cstr[i]) {
          case '&': /* &amp; */
            bufPtr[0] = '&'; bufPtr[1] = 'a'; bufPtr[2] = 'm'; bufPtr[3] = 'p';
            bufPtr[4] = ';';
            bufPtr += 5;
            break;
            
          case '<': /* &lt;   */
            bufPtr[0] = '&'; bufPtr[1] = 'l'; bufPtr[2] = 't'; bufPtr[3] = ';';
            bufPtr += 4;
            break;
            
          case '>': /* &gt;   */
            bufPtr[0] = '&'; bufPtr[1] = 'g'; bufPtr[2] = 't'; bufPtr[3] = ';';
            bufPtr += 4;
            break;
            
          case '"': /* &quot; */
            bufPtr[0] = '&'; bufPtr[1] = 'q'; bufPtr[2] = 'u';
            bufPtr[3] = 'o'; bufPtr[4] = 't'; bufPtr[5] = ';';
            bufPtr += 6;
            break;
            
          default:
            *bufPtr = cstr[i];
            bufPtr++;
            break;
        }
      }
#if NeXT_Foundation_LIBRARY
      if (cbuf) free(cbuf);
#else
      if (cbuf) NGFree(cbuf);
#endif
      self->value = [[NSString allocWithZone:[self zone]]
                      initWithCharacters: buffer
                                  length: (bufPtr - buffer)];
    }
    else {
      self->value = [v copyWithZone:[self zone]];
    }
  }
  return self;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    WOAssociation *avalue, *aescape;
    BOOL doEscape;
    
    avalue  = OWGetProperty(_config, @"value");
    aescape = OWGetProperty(_config, @"escapeHTML");
    
    doEscape = (aescape != nil) ? [aescape boolValueInComponent:nil] : YES;
    self = [self initWithValue:avalue escapeHTML:doEscape];
    [avalue release];
    [aescape release];
  }
  return self;
}

- (void)dealloc {
  [self->value release];
  [super dealloc];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (![_ctx isRenderingDisabled])
    WOResponse_AddString(_response, self->value);
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@" value='%@'", self->value];
}

@end /* WOSimpleStaticString */

@implementation _WOSimpleStaticASCIIString

- (id)initWithValue:(WOAssociation *)_value escapeHTML:(BOOL)_flag {
  if ((self = [super initWithName:nil associations:nil template:nil])) {
    // ENCODING, UNICODE
    NSString *v;
    unsigned length;
    
    v = [_value stringValueInComponent:nil];
    length = [v cStringLength];
    
    if (length == 0) {
      self->value = NULL;
    }
    else if (_flag) {
      unsigned char *buffer;
      register unsigned char *cbuf;
      register unsigned char *bufPtr;
      register unsigned      i;
      unsigned clen;
      BOOL didEscape = NO;
      
      clen = [v cStringLength];
      cbuf = malloc(clen + 2);
      [v getCString:(char *)cbuf]; cbuf[clen] = '\0';
      
      buffer = malloc(clen * 6 + 2); /* longest-encoding: '&quot;' */
      
      for (i = 0, bufPtr = buffer; i < length; i++) {
        switch (cbuf[i]) {
          case '&': /* &amp; */
            bufPtr[0] = '&'; bufPtr[1] = 'a'; bufPtr[2] = 'm'; bufPtr[3] = 'p';
            bufPtr[4] = ';';
            bufPtr += 5;
            didEscape = YES;
            break;
            
          case '<': /* &lt;   */
            bufPtr[0] = '&'; bufPtr[1] = 'l'; bufPtr[2] = 't'; bufPtr[3] = ';';
            bufPtr += 4;
            didEscape = YES;
            break;
            
          case '>': /* &gt;   */
            bufPtr[0] = '&'; bufPtr[1] = 'g'; bufPtr[2] = 't'; bufPtr[3] = ';';
            bufPtr += 4;
            didEscape = YES;
            break;
            
          case '"': /* &quot; */
            bufPtr[0] = '&'; bufPtr[1] = 'q'; bufPtr[2] = 'u';
            bufPtr[3] = 'o'; bufPtr[4] = 't'; bufPtr[5] = ';';
            bufPtr += 6;
            didEscape = YES;
            break;
            
          default:
            if ((*bufPtr = cbuf[i]) > 127) {
              NSLog(@"WARNING: string is not ASCII as required for "
                    @"SimpleStaticASCIIString !!! '%@'", v);
            }
            bufPtr++;
            break;
        }
      }
      if (didEscape) {
        if (cbuf) free(cbuf);
        clen = (bufPtr - buffer);
        self->value = malloc(clen + 2);
        strncpy((char *)self->value, (const char *)buffer, clen);
        ((unsigned char *)self->value)[clen] = '\0';
      }
      else {
        self->value = cbuf;
      }
      if (buffer) free(buffer);
    }
    else {
      self->value = malloc(length + 2);
      [v getCString:(char*)self->value];
    }
  }
  return self;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    WOAssociation *avalue, *aescape;
    BOOL doEscape;
    
    avalue  = OWGetProperty(_config, @"value");
    aescape = OWGetProperty(_config, @"escapeHTML");
    
    doEscape = (aescape != nil) ? [aescape boolValueInComponent:nil] : YES;
    self = [self initWithValue:avalue escapeHTML:doEscape];
    [avalue release];
    [aescape release];
  }
  return self;
}

- (void)dealloc {
  if (self->value) free((char *)self->value);
  [super dealloc];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (![_ctx isRenderingDisabled] && self->value)
    if (self->value) WOResponse_AddCString(_response, self->value);
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@" value='%s'", 
                     self->value ? self->value : (void*)""];
}

@end /* WOSimpleStaticASCIIString */

@implementation _WOComplexString

static NSNumber      *yesNum = nil;
static WOAssociation *yesAssoc = nil;

+ (void)initialize {
  if (yesNum   == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
  if (yesAssoc == nil) 
    yesAssoc = [[WOAssociation associationWithValue:yesNum] retain];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->value          = OWGetProperty(_config, @"value");
    self->escapeHTML     = OWGetProperty(_config, @"escapeHTML");
    self->insertBR       = OWGetProperty(_config, @"insertBR");
    self->nilString      = OWGetProperty(_config, @"nilString");
    self->valueWhenEmpty = OWGetProperty(_config, @"valueWhenEmpty");
    self->style          = OWGetProperty(_config, @"style");

    if (self->nilString != nil && self->valueWhenEmpty != nil) {
      [self logWithFormat:
	      @"WARNING: 'valueWhenEmpty' AND 'nilString' bindings are set, "
	      @"use only one! ('nilString' is deprecated!)"];
    }
    else if (self->nilString != nil) {
      [self debugWithFormat:
	      @"Note: using deprecated 'nilString' binding, "
	      @"use 'valueWhenEmpty' instead."];
    }
    
    self->formatter    = OWGetProperty(_config, @"formatter");
    self->numberformat = OWGetProperty(_config, @"numberformat");
    self->dateformat   = OWGetProperty(_config, @"dateformat");
    
    if (self->formatter == nil) {
      if ([_config objectForKey:@"formatterClass"]) {
        WOAssociation *assoc;
        NSString      *className;
        NSFormatter   *fmt = nil;
        Class         clazz;
        
        assoc = [OWGetProperty(_config, @"formatterClass") autorelease];
        if (![assoc isValueConstant])
          [self logWithFormat:@"non-constant 'formatterClass' binding!"];
        className = [assoc stringValueInComponent:nil];
        clazz     = NSClassFromString(className);
        
        if ((assoc = [OWGetProperty(_config, @"format") autorelease])) {
          NSString *format = nil;
          
          if (![assoc isValueConstant])
            [self logWithFormat:@"non-constant 'format' binding!"];
          format = [assoc stringValueInComponent:nil];
          
          if ([clazz instancesRespondToSelector:@selector(initWithString:)])
            fmt = [[clazz alloc] initWithString:format];
          else {
            [self logWithFormat:
                    @"cannot instantiate formatter with format: '%@'", format];
            fmt = [[clazz alloc] init];
          }
        }
        else
          fmt = [[clazz alloc] init];
        
        self->formatter = [[WOAssociation associationWithValue:fmt] retain];
        [fmt release];
      }
    }

    if (self->escapeHTML == nil)
      self->escapeHTML = [yesAssoc retain];
    
    /* check formats */
    {
      int num = 0;
      if (self->formatter)    num++;
      if (self->numberformat) num++;
      if (self->dateformat)   num++;
      if (num > 1)
        NSLog(@"WARNING: more than one formats specified in element %@", self);
    }
  }
  return self;
}

- (id)initWithValue:(WOAssociation *)_value escapeHTML:(BOOL)_flag {
  if ((self = [super initWithName:nil associations:nil template:nil])) {
    self->value      = [_value retain];
    self->escapeHTML = _flag
      ? yesAssoc
      : [WOAssociation associationWithValue:[NSNumber numberWithBool:NO]];
    self->escapeHTML = [self->escapeHTML retain];
  }
  return self;
}

- (void)dealloc {
  [self->numberformat   release];
  [self->dateformat     release];
  [self->formatter      release];
  [self->nilString      release];
  [self->valueWhenEmpty release];
  [self->value          release];
  [self->escapeHTML     release];
  [self->insertBR       release];
  [self->style          release];
  [super dealloc];
}

/* response generation */

- (void)_appendStringLines:(NSString *)_s withSeparator:(NSString *)_br
  contentSelector:(SEL)_sel
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
{
  NSArray *lines;
  unsigned i, count;
  
  lines = [_s componentsSeparatedByString:@"\n"];

  for (i = 0, count = [lines count]; i < count; i++) {
    NSString *line;

    line = [lines objectAtIndex:i];
    if (i != 0) WOResponse_AddString(_response, _br);
    
    [_response performSelector:_sel withObject:line];
  }
}

- (NSFormatter *)_formatterInContext:(WOContext *)_ctx {
  if (self->numberformat) {
    NSNumberFormatter *fmt;

    fmt = [[[NSNumberFormatter alloc] init] autorelease];
    [fmt setFormat:[self->numberformat valueInComponent:[_ctx component]]];
    return fmt;
  }

  if (self->dateformat) {
    NSDateFormatter *fmt;
    NSString *s;
    
    s = [self->dateformat valueInComponent:[_ctx component]];
    fmt = [[NSDateFormatter alloc] initWithDateFormat:s
				   allowNaturalLanguage:NO];
    return [fmt autorelease];
  }
  
  if (self->formatter)
    return [self->formatter valueInComponent:[_ctx component]];
  
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSFormatter *fmt;
  id          obj    = nil;
  SEL         addSel = NULL;
  NSString    *styleName;

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  sComponent = [_ctx component];
  fmt        = [self _formatterInContext:_ctx];

#if DEBUG
  if (fmt!=nil && ![fmt respondsToSelector:@selector(stringForObjectValue:)]) {
    [sComponent errorWithFormat:
                  @"invalid formatter determined by keypath %@: %@",
                  self->formatter, fmt];
  }
#endif
  
  obj    = [self->value valueInContext:_ctx];
  addSel = [self->escapeHTML boolValueInComponent:sComponent]
    ? @selector(appendContentHTMLString:)
    : @selector(appendContentString:);

  if (fmt) {
    NSString *formattedObj;
    
    formattedObj = [fmt stringForObjectValue:obj];
#if 0
    if (formattedObj == nil) {
      [self warnWithFormat:@"formatter %@ returned nil string for object %@",
                           fmt, obj];
    }
#endif
    
    obj = formattedObj;
  }
  
  obj = [obj stringValue];

  styleName = [self->style stringValueInContext:_ctx];

  /* handling of empty and nil values */

  if (self->valueWhenEmpty != nil) {
    if (![obj isNotEmpty]) {
      NSString *s;
      
      s = [self->valueWhenEmpty stringValueInComponent:sComponent];
      
      /* Note: the missing escaping is intentional for WO 4.5 compatibility */
      if (s != nil) {
        if (styleName != nil) {
          [_response appendContentString:@"<span class=\""];
          [_response appendContentHTMLAttributeValue:styleName];
          [_response appendContentString:@"\">"];
        }
        [_response appendContentString:s];
      }
      goto closeSpan;
    }
  }
  else if (self->nilString != nil && obj == nil) {
    NSString *s;

    if (styleName != nil) {
      [_response appendContentString:@"<span class=\""];
      [_response appendContentHTMLAttributeValue:styleName];
      [_response appendContentString:@"\">"];
    }
    s = [self->nilString stringValueInComponent:sComponent];
    [_response performSelector:addSel withObject:s];
    goto closeSpan;
  }
  else if (obj == nil)
    return;

  /* handling of non-empty values */
  
  if (styleName != nil) {
    [_response appendContentString:@"<span class=\""];
    [_response appendContentHTMLAttributeValue:styleName];
    [_response appendContentString:@"\">"];
  }

  if (![self->insertBR boolValueInComponent:sComponent]) {
    [_response performSelector:addSel withObject:obj];
  }
  else {
    [self _appendStringLines:obj 
	  withSeparator:
	    (_ctx->wcFlags.xmlStyleEmptyElements ? @"<br />" : @"<br>")
          contentSelector:addSel toResponse:_response inContext:_ctx];
  }
  
closeSpan:
  if (styleName) {
    [_response appendContentString:@"</span>"];
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:64];
  
  if (self->value)      [str appendFormat:@" value=%@",      self->value];
  if (self->escapeHTML) [str appendFormat:@" escape=%@",     self->escapeHTML];
  if (self->insertBR)   [str appendFormat:@" insertBR=%@",   self->insertBR];
  if (self->formatter)  [str appendFormat:@" formatter=%@",  self->formatter];
  if (self->dateformat) [str appendFormat:@" dateformat=%@", self->dateformat];
  if (self->numberformat)
    [str appendFormat:@" numberformat=%@", self->numberformat];

  if (self->valueWhenEmpty) 
    [str appendFormat:@" valueWhenEmpty=%@", self->valueWhenEmpty];
  if (self->style) 
      [str appendFormat:@" style=%@", self->style];
  
  return str;
}

@end /* _WOComplexString */

@implementation _WOTemporaryString

static Class ComplexStringClass     = Nil;
static Class SimpleStringClass      = Nil;
static Class SimpleASCIIStringClass = Nil;
static Class SimpleDynStringClass   = Nil;

#define ENSURE_CACHE \
  if (ComplexStringClass == Nil)\
    ComplexStringClass = [_WOComplexString class];\
  if (SimpleStringClass == Nil)\
    SimpleStringClass = [_WOSimpleStaticString class];\
  if (SimpleASCIIStringClass == Nil)\
    SimpleASCIIStringClass = [_WOSimpleStaticASCIIString class];\
  if (SimpleDynStringClass == Nil)\
    SimpleDynStringClass = [_WOSimpleDynamicString class];

static inline Class _classForConfig(NSDictionary *_config) {
  Class         sClass = Nil;
  WOAssociation *assoc, *assoc2;
  unsigned      c;
  
  switch ((c = [_config count])) {
    case 0:
      sClass = SimpleStringClass;
      break;
      
    case 1:
      if ((assoc = [_config objectForKey:@"value"])) {
        if ([assoc isValueConstant])
          sClass = SimpleStringClass;
        else
          sClass = SimpleDynStringClass;
        break;
      }
      if ((assoc = [_config objectForKey:@"escapeHTML"])) {
        if ([assoc isValueConstant])
          sClass = SimpleStringClass;
        break;
      }
      break;
      
    case 2:
      if ((assoc = [_config objectForKey:@"value"])) {
        if ((assoc2 = [_config objectForKey:@"escapeHTML"])) {
          if ([assoc isValueConstant] && [assoc2 isValueConstant])
            sClass = SimpleStringClass;

          break;
        }
      }
      break;
      
    default:
      sClass = ComplexStringClass;
      break;
  }
  
  return sClass ? sClass : ComplexStringClass;
}

- (id)initWithName:(NSString *)_n
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  Class stringClass;
  ENSURE_CACHE;

#if DEBUG
  if (_t != nil) {
    NSLog(@"WARNING: WOString '%@' has contents !", _n);
    abort();
  }
#endif

  stringClass = _classForConfig(_config);
  
  return [[stringClass alloc]
                       initWithName:_n associations:_config template:nil];
}
- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  contentElements:(NSArray *)_contents
{
  Class stringClass;
  ENSURE_CACHE;

#if DEBUG
  if ([_contents count] > 0) {
    NSLog(@"WARNING: WOString has contents !");
    abort();
  }
#endif
  
  stringClass = _classForConfig(_associations);
  
  return [[stringClass alloc]
                       initWithName:_name
                       associations:_associations
                       contentElements:nil];
}

- (id)initWithValue:(WOAssociation *)_value escapeHTML:(BOOL)_flag {
  Class stringClass;
  ENSURE_CACHE;
  
  if ((_value == nil) || [_value isValueConstant])
    stringClass = SimpleStringClass;
  else
    stringClass = ComplexStringClass;
    
  return [[stringClass alloc] initWithValue:_value escapeHTML:_flag];
}

- (void)dealloc {
  [self errorWithFormat:@"called dealloc on %@", self];
#if DEBUG
  abort();
#endif
  return;

  /* make Tiger GCC / gcc 4.1 happy */
  if (0) [super dealloc];
}

@end /* _WOTemporaryString */
