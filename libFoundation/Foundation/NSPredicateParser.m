/* 
   NSPredicateParser.m

   Copyright (C) 2000-2005 SKYRIX Software AG
   All rights reserved.
   
   Author: Helge Hess <helge.hess@opengroupware.org>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <stdio.h>
#include "NSPredicate.h"
#include "NSComparisonPredicate.h"
#include "NSCompoundPredicate.h"
#include "NSExpression.h"
#include "NSValue.h"
#include "NSException.h"
#include "NSDictionary.h"
#include "NSNull.h"
#include "NSCalendarDate.h"
#include "common.h"

//#define USE_DESCRIPTION_FOR_AT 1

static int qDebug = 0;
static NSMutableDictionary *NSPredicateParserTypeMappings = nil;

/* 
   The literals understood by the value parser.
   
   NOTE: Any literal used here can never be used as a key ! So add as little
   as possible.
*/
typedef struct {
  const unsigned char *token;
  id  value;
  int scase;
} NSQPTokEntry;

static NSQPTokEntry toks[] = {
  { (const unsigned char *)"NULL",  nil, 0 },
  { (const unsigned char *)"nil",   nil, 1 },
  { (const unsigned char *)"YES",   nil, 0 },
  { (const unsigned char *)"NO",    nil, 0 },
  { (const unsigned char *)"TRUE",  nil, 0 },
  { (const unsigned char *)"FALSE", nil, 0 },
  { (const unsigned char *)NULL,    nil, 0 }
};

static inline void _setupLiterals(void) {
  static BOOL didSetup = NO;
  if (didSetup) return;
  didSetup = YES;
  toks[0].value = [[NSNull null] retain];
  toks[1].value = toks[0].value;
  toks[2].value = [[NSNumber numberWithBool:YES] retain];
  toks[3].value = [[NSNumber numberWithBool:NO]  retain];
  toks[4].value = toks[2].value;
  toks[5].value = toks[3].value;
}

/* cache */
static Class  StringClass = Nil;
static Class  NumberClass = Nil;
static NSNull *null       = nil;

/* parsing functions */

static NSPredicate *_parseCompoundPredicate(id _ctx, const char *_buf,
                                            unsigned _bufLen, unsigned *_predLen);
static NSPredicate *_testOperator(id _ctx, const char *_buf,
                                  unsigned _bufLen, unsigned *_opLen,
                                  BOOL *_testAnd);
static NSPredicate *_parsePredicates(id _ctx, const char *_buf,
                                     unsigned _bufLen, unsigned *_predLen);
static NSPredicate *_parseParenthesisPredicate(id _ctx,
                                               const char *_buf, unsigned _bufLen,
                                               unsigned *_predLen);
static NSPredicate *_parseNotPredicate(id _ctx, const char *_buf,
                                       unsigned _bufLen, unsigned *_predLen);
static NSPredicate *_parseKeyCompPredicate(id _ctx, const char *_buf,
                                           unsigned _bufLen, unsigned *_predLen);
static NSString *_parseKey(id _ctx, const char *_buf, unsigned _bufLen,
                           unsigned *_keyLen);
static id _parseValue(id _ctx, const char *_buf, unsigned _bufLen,
                      unsigned *_keyLen);
static inline unsigned _countWhiteSpaces(const char *_buf, unsigned _bufLen);
static NSString *_parseOp(const char *_buf, unsigned _bufLen,
                          unsigned *_opLen);

@interface NSPredicateParserContext : NSObject
{
  NSMapTable *predicateCache;
}

- (NSDictionary *)resultForFunction:(NSString *)_fct
  atPos:(unsigned long)_pos;
- (void)setResult:(NSDictionary *)_dict forFunction:(NSString *)_fct
  atPos:(unsigned long)_pos;
- (id)getObjectFromStackFor:(char)_c;

@end

@interface NSPredicateVAParserContext : NSPredicateParserContext
{
  va_list    *va;  
}
+ (id)contextWithVaList:(va_list *)_va;
- (id)initWithVaList:(va_list *)_va;
@end

@interface NSPredicateEnumeratorParserContext : NSPredicateParserContext
{
  NSEnumerator *enumerator;
}
+ (id)contextWithEnumerator:(NSEnumerator *)_enumerator;
- (id)initWithEnumerator:(NSEnumerator  *)_enumerator;
@end

@implementation NSPredicateVAParserContext

+ (id)contextWithVaList:(va_list *)_va {
  return [[[NSPredicateVAParserContext alloc] initWithVaList:_va] autorelease];
}

- (id)initWithVaList:(va_list *)_va {
  if ((self = [super init])) {
    self->va = _va;
  }
  return self;
}

- (id)getObjectFromStackFor:(char)_c {
  id obj = nil;

  if (StringClass == Nil) StringClass = [NSString class];
  if (NumberClass == Nil) NumberClass = [NSNumber class];
  if (null == nil)        null        = [NSNull null];
  
  if (_c == 's') {
    char *str = va_arg(*self->va, char*);
    obj = [StringClass stringWithCString:str];
  }
  else if (_c == 'd') {
    int i= va_arg(*self->va, int);
    obj = [NumberClass numberWithInt:i];
  }
  else if (_c == 'f') {
    double d = va_arg(*self->va, double);
    obj = [NumberClass numberWithDouble:d];
  }
  else if (_c == '@') {
    id o = va_arg(*self->va, id);
#if USE_DESCRIPTION_FOR_AT
    obj = (o == nil) ? (id)null : (id)[o description];
#else
    obj = (o == nil) ? (id)null : (id)o;
#endif
  }
  else {
    [NSException raise:@"NSInvalidArgumentException"
                 format:@"unknown conversation char %c", _c];
  }
  return obj;
}

@end /* NSPredicateVAParserContext */

@implementation NSPredicateEnumeratorParserContext

+ (id)contextWithEnumerator:(NSEnumerator *)_enumerator {
  return [[[NSPredicateEnumeratorParserContext alloc]
                                      initWithEnumerator:_enumerator] autorelease];
}

- (id)initWithEnumerator:(NSEnumerator *)_enumerator {
  if ((self = [super init])) {
    ASSIGN(self->enumerator, _enumerator);
  }
  return self;
}

- (void)dealloc {
  [self->enumerator release];
  [super dealloc];;
}

- (id)getObjectFromStackFor:(char)_c {
  static Class NumberClass = Nil;
  id o;

  if (NumberClass == Nil) NumberClass = [NSNumber class];

  o = [self->enumerator nextObject];
  switch (_c) {
    case '@':
#if USE_DESCRIPTION_FOR_AT
      return [o description];
#else
      return o;
#endif
    
    case 'f':
      return [NumberClass numberWithDouble:[o doubleValue]];
      
    case 'd':
      return [NumberClass numberWithInt:[o intValue]];
      
    case 's':
      // return [NSString stringWithCString:[o cString]];
      return [[o copy] autorelease];
      
    default:
      [NSException raise:@"NSInvalidArgumentException"
                   format:@"unknown or not allowed conversation char %c", _c];
  }
  return nil;
}

@end /* NSPredicateEnumeratorParserContext */

@implementation NSPredicateParserContext

- (id)init {
  if (StringClass == Nil) StringClass = [NSString class];
  
  if ((self = [super init])) {
    self->predicateCache = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            200);
  }
  return self;
}

- (void)dealloc {
  if (self->predicateCache) NSFreeMapTable(self->predicateCache);
  [super dealloc];
}

- (NSDictionary *)resultForFunction:(NSString *)_fct atPos:(unsigned long)_p
{
  NSDictionary *r;
  NSString *k;
  
  k = [[StringClass alloc] initWithFormat:@"%@_%ld", _fct, _p];
  r = NSMapGet(self->predicateCache, k);
  [k release];
  return r;
}

- (void)setResult:(NSDictionary *)_dict forFunction:(NSString *)_fct
  atPos:(unsigned long)_pos
{
  NSString *k;
  
  k = [[StringClass alloc] initWithFormat:@"%@_%ld", _fct, _pos];
  NSMapInsert(self->predicateCache, k, _dict);
  [k release];
}

- (id)getObjectFromStackFor:(char)_c {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

@end /* NSPredicateParserContext */

@implementation NSPredicate(Parsing)

+ (void)registerValueClass:(Class)_valueClass forTypeName:(NSString *)_type {
  if (NSPredicateParserTypeMappings == nil)
    NSPredicateParserTypeMappings = [[NSMutableDictionary alloc] init];
  
  if (_type == nil) {
    NSLog(@"ERROR(%s): got passed no type name!", __PRETTY_FUNCTION__);
    return;
  }
  if (_valueClass == nil) {
    NSLog(@"ERROR(%s): got passed no value-class for type '%@'!",
          __PRETTY_FUNCTION__, _type);
    return;
  }
  
  [NSPredicateParserTypeMappings setObject:_valueClass forKey:_type];
}

+ (NSPredicate *)predicateWithFormat:(NSString *)_format,... {
  va_list     va;
  NSPredicate *qualifier;
  unsigned    length = 0;
  const char  *buf;
  unsigned    bufLen;
  char        *cbuf;

  _setupLiterals();
  if (StringClass == Nil) StringClass = [NSString class];
  
  bufLen = [_format cStringLength];
  cbuf   = malloc(bufLen + 1);
  [_format getCString:cbuf]; cbuf[bufLen] = '\0';
  buf = cbuf;
  
  va_start(va, _format);
  qualifier =
    _parsePredicates([NSPredicateVAParserContext contextWithVaList:&va],
                     buf, bufLen, &length);
  va_end(va);
  
  if (qualifier != nil) { /* check whether the rest of the string is OK */
    if (length < bufLen)
      length += _countWhiteSpaces(buf + length, bufLen - length);
    
    if (length < bufLen) {
      NSLog(@"WARNING(%s): unexpected chars at the end of the "
            @"string(class=%@,len=%i) '%@'",
            __PRETTY_FUNCTION__,
            [_format class],
            [_format length], _format);
      NSLog(@"  buf-length: %i", bufLen);
      NSLog(@"  length:     %i", length);
      NSLog(@"  char[length]: '%c' (%i) '%s'", buf[length], buf[length],
	    (buf+length));
      qualifier = nil;
    }
    else if (length > bufLen) {
      NSLog(@"WARNING(%s): length should never be longer than bufLen ?, "
	    @"internal parsing error !",
	    __PRETTY_FUNCTION__);
    }
  }
  free(cbuf);
  return qualifier;
}

+ (NSPredicate *)predicateWithFormat:(NSString *)_format 
  argumentArray:(NSArray *)_arguments
{
  NSPredicate *qual  = nil;
  unsigned    length = 0;
  const char  *buf   = NULL;
  unsigned    bufLen = 0;
  NSPredicateEnumeratorParserContext *ctx;

  _setupLiterals();
  if (StringClass == Nil) StringClass = [NSString class];
  
  ctx = [NSPredicateEnumeratorParserContext contextWithEnumerator:
					      [_arguments objectEnumerator]];
  
  //NSLog(@"qclass: %@", [_format class]);
  buf    = [_format cString];
  bufLen = [_format cStringLength];
  qual   = _parsePredicates(ctx, buf, bufLen, &length);
  
  if (qual != nil) { /* check whether the rest of the string is OK */
    if (length < bufLen) {
      length += _countWhiteSpaces(buf + length, bufLen - length);
    }
    if (length != bufLen) {
      NSLog(@"WARNING(%s): unexpected chars at the end of the string '%@'",
            __PRETTY_FUNCTION__, _format);
      qual = nil;
    }
  }
  return qual;
}
 
@end /* NSPredicate(Parsing) */

static NSPredicate *_parseSinglePredicate(id _ctx, const char *_buf,
                                            unsigned _bufLen,
                                            unsigned *_predLen)
{
  NSPredicate *res = nil;

  if ((res = _parseParenthesisPredicate(_ctx, _buf, _bufLen, _predLen))  != nil) {
    if (qDebug)
      NSLog(@"_parseSinglePredicate return <%@> for <%s> ", res, _buf);

    return res;
  }
  if ((res = _parseNotPredicate(_ctx, _buf, _bufLen, _predLen)) != nil) {
    if (qDebug)
      NSLog(@"_parseSinglePredicate return <%@> for <%s> ", res, _buf);

    return res;
  }
  if ((res = _parseKeyCompPredicate(_ctx, _buf, _bufLen, _predLen)) != nil) {
    if (qDebug) {
      NSLog(@"_parseSinglePredicate return <%@> for <%s> length %d", 
	    res, _buf, *_predLen);
    }
    return res;
  }
  return nil;
}

static NSPredicate *_parsePredicates(id _ctx, const char *_buf, unsigned _bufLen,
                                     unsigned *_predLen)
{
  NSPredicate *res = nil;


  if ((res = _parseCompoundPredicate(_ctx, _buf, _bufLen, _predLen))) {
    if (qDebug)
      NSLog(@"_parsePredicates return <%@> for <%s> ", res, _buf);
    return res;
  }

  if ((res = _parseSinglePredicate(_ctx, _buf, _bufLen, _predLen))) {
    if (qDebug)
      NSLog(@"_parsePredicates return <%@> for <%s> ", res, _buf);
    return res;
  }
  
  if (qDebug)
    NSLog(@"_parsePredicates return nil for <%s> ", _buf);

  return nil;
}

static NSPredicate *_parseParenthesisPredicate(id _ctx, const char *_buf,
                                               unsigned _bufLen,
                                               unsigned *_predLen)
{
  unsigned    pos     = 0;
  unsigned    qualLen = 0;
  NSPredicate *qual   = nil;

  pos = _countWhiteSpaces(_buf, _bufLen);

  if (_bufLen <= pos + 2) /* at least open and close parenthesis */ {
    if (qDebug)
      NSLog(@"1_parseParenthesisPredicate return nil for <%s> ", _buf);
 
    return nil;
  }
  if (_buf[pos] != '(') {
    if (qDebug)
      NSLog(@"2_parseParenthesisPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  pos++;
  if (!(qual = _parsePredicates(_ctx, _buf + pos, _bufLen - pos,
                                &qualLen))) {
    if (qDebug)
      NSLog(@"3_parseParenthesisPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  
  pos += qualLen;
  if (_bufLen <= pos) {
    if (qDebug)
      NSLog(@"4_parseParenthesisPredicate return nil for <%s> qual[%@] %@ bufLen %d "
            @"pos %d", _buf, [qual class], qual, _bufLen, pos);

    return nil;
  }
  pos += _countWhiteSpaces(_buf + pos, _bufLen - pos);
  if (_buf[pos] != ')') {
    if (qDebug)
      NSLog(@"5_parseParenthesisPredicate return nil for <%s> [%s] ", _buf, _buf+pos);

    return nil;
  }
  if (qDebug)
    NSLog(@"6_parseParenthesisPredicate return <%@> for <%s> ", qual, _buf);
  
  *_predLen = pos + 1; /* one step after the parenthesis */
  return qual;
}

static NSPredicate *_parseNotPredicate(id _ctx, const char *_buf,
                                       unsigned _bufLen, unsigned *_predLen)
{
  unsigned    pos, len   = 0;
  char        c0, c1, c2 = 0;
  NSPredicate *qual      = nil;

  pos = _countWhiteSpaces(_buf, _bufLen);

  if (_bufLen - pos < 4) { /* at least 3 chars for 'NOT' */
    if (qDebug)
      NSLog(@"_parseNotPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  c0 = _buf[pos];
  c1 = _buf[pos + 1];
  c2 = _buf[pos + 2];
  if (!(((c0 == 'n') || (c0 == 'N')) &&
        ((c1 == 'o') || (c1 == 'O')) &&
        ((c2 == 't') || (c2 == 'T')))) {
    if (qDebug)
      NSLog(@"_parseNotPredicate return nil for <%s> ", _buf);
    return nil;
  }
  pos += 3;
  qual = _parseSinglePredicate(_ctx, _buf + pos, _bufLen - pos, &len);
  if (qual == nil) {
    if (qDebug)
      NSLog(@"_parseNotPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  *_predLen = pos +len;
  if (qDebug)
    NSLog(@"_parseNotPredicate return %@ for <%s> ", qual, _buf);
  
  return [NSCompoundPredicate notPredicateWithSubpredicates:
				[NSArray arrayWithObjects:&qual count:1]];
}

static SEL operatorSelectorForString(NSString *_str)
{
  // TODO: fix for NSPredicate
  static NSMapTable *operatorToSelector = NULL; // THREAD
  SEL s;

  if (operatorToSelector == NULL) {
    operatorToSelector = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                          NSIntMapValueCallBacks,
                                          10);
    NSMapInsert(operatorToSelector, @"=",  
		(void *)NSEqualToPredicateOperatorType);
    NSMapInsert(operatorToSelector, @"==", 
		(void *)NSEqualToPredicateOperatorType);
    NSMapInsert(operatorToSelector, @"!=", 
		(void *)NSNotEqualToPredicateOperatorType);
    NSMapInsert(operatorToSelector, @"<>", 
		(void *)NSNotEqualToPredicateOperatorType);
    NSMapInsert(operatorToSelector, @"<",  
		(void *)NSLessThanPredicateOperatorType);
    NSMapInsert(operatorToSelector, @">",  
		(void *)NSGreaterThanPredicateOperatorType);
    
    NSMapInsert(operatorToSelector, @"<=",  
		(void *)NSLessThanOrEqualToPredicateOperatorType);
    NSMapInsert(operatorToSelector, @">=",
                (void *)NSGreaterThanOrEqualToPredicateOperatorType);

    NSMapInsert(operatorToSelector, @"like", 
		(void *)NSLikePredicateOperatorType);
    NSMapInsert(operatorToSelector, @"LIKE", 
		(void *)NSLikePredicateOperatorType);
    
#if 0 // TODO
    // TODO: need to have options here
    NSMapInsert(operatorToSelector, @"caseInsensitiveLike",
                NSLikePredicateOperatorType);
#endif
  }
  
  if ((s = NSMapGet(operatorToSelector, _str)))
    return s;
  
  return NSSelectorFromString(_str);
}

static NSPredicate *_parseKeyCompPredicate(id _ctx, const char *_buf,
                                           unsigned _bufLen, 
					   unsigned *_predLen)
{
  NSExpression *lhs, *rhs;
  NSString     *key       = nil;
  NSString     *op        = nil;
  NSString     *value     = nil;
  NSPredicate  *qual      = nil;
  NSDictionary *dict      = nil;
  SEL          sel        = NULL;
  unsigned     length     = 0;
  unsigned     pos        = 0;
  BOOL         valueIsKey = NO;

  dict = [_ctx resultForFunction:@"parseKeyCompPredicate" 
	       atPos:(unsigned long)_buf];
  if (dict != nil) {
    if (qDebug)
      NSLog(@"_parseKeyCompQual return <%@> [cached] for <%s> ", dict, _buf);
    
    *_predLen = [[dict objectForKey:@"length"] unsignedIntValue];
    return [dict objectForKey:@"object"];
  }
  pos = _countWhiteSpaces(_buf, _bufLen);

  if ((key = _parseKey(_ctx , _buf + pos, _bufLen - pos, &length)) == nil) {
    if (qDebug)
      NSLog(@"_parseKeyCompPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  pos += length;
  pos += _countWhiteSpaces(_buf + pos, _bufLen - pos);

  if (!(op = _parseOp(_buf + pos, _bufLen - pos, &length))) {
    if (qDebug)
      NSLog(@"_parseKeyCompPredicate return nil for <%s> ", _buf);
    return nil;
  }

  sel = operatorSelectorForString(op);
  if (sel == NULL) {
    NSLog(@"WARNING(%s): possible unknown operator <%@>", __PRETTY_FUNCTION__,
          op);
    if (qDebug)
      NSLog(@"_parseKeyCompPredicate return nil for <%s> ", _buf);
    return nil;
  }
  pos       +=length;
  pos       += _countWhiteSpaces(_buf + pos, _bufLen - pos);
  valueIsKey = NO;  
  
  value = _parseValue(_ctx, _buf + pos, _bufLen - pos, &length);
  if (value == nil) {
    value = _parseKey(_ctx, _buf + pos, _bufLen - pos, &length);
    if (value == nil) {
      if (qDebug)
	NSLog(@"_parseKeyCompPredicate return nil for <%s> ", _buf);
      return nil;
    }
    else
      valueIsKey = YES;
  }
  pos      +=length;  
  *_predLen = pos;

  lhs = [NSExpression expressionForKeyPath:key];
  rhs = valueIsKey
    ? [NSExpression expressionForKeyPath:value]
    : [NSExpression expressionForConstantValue:value];
  
  qual = [NSComparisonPredicate predicateWithLeftExpression:lhs
				rightExpression:rhs
				customSelector:sel];
  if (qDebug)
    NSLog(@"_parseKeyCompPredicate return <%@> for <%s> ", qual, _buf);

  if (qual != nil) {
    id keys[2], values[2];
    keys[0] = @"length"; values[0] = [NSNumber numberWithUnsignedInt:pos];
    keys[1] = @"object"; values[1] = qual;
    [_ctx setResult:
            [NSDictionary dictionaryWithObjects:values forKeys:keys count:2]
          forFunction:@"parseKeyCompPredicate"
          atPos:(unsigned long)_buf];
    *_predLen = pos;
  }
  return qual;
}

static NSString *_parseOp(const char *_buf, unsigned _bufLen,
                          unsigned *_opLen)
{
  unsigned pos = 0;
  char     c0  = 0;
  char     c1  = 0;  

  if (_bufLen == 0) {
    if (qDebug)
      NSLog(@"_parseOp _bufLen == 0 --> return nil");
    return nil;
  }
  pos = _countWhiteSpaces(_buf, _bufLen);
  if (_bufLen - pos > 1) {/* at least an operation and a value */
    c0 = _buf[pos];
    c1 = _buf[pos+1];  

    if (((c0 >= '<') && (c0 <= '>')) || (c0 == '!')) {
      NSString *result;
      
      if ((c1 >= '<') && (c1 <= '>')) {
        *_opLen = 2;
        result = [StringClass stringWithCString:_buf + pos length:2];
	if (qDebug)
	  NSLog(@"_parseOp return <%@> for <%s> ", result, _buf);
      }
      else {
        *_opLen = 1;
        result = [StringClass stringWithCString:&c0 length:1];
	if (qDebug)
	  NSLog(@"_parseOp return <%@> for <%s> ", result, _buf);
      }
      return result;
    }
    else { /* string designator operator */
      unsigned opStart = pos;
      while (pos < _bufLen) {
        if (_buf[pos] == ' ')
          break;
        pos++;
      }
      if (pos >= _bufLen) {
        NSLog(@"WARNING(%s): found end of string during operator parsing",
              __PRETTY_FUNCTION__);
      }

      if (qDebug) {
	NSLog(@"%s: _parseOp return <%@> for <%s> ", __PRETTY_FUNCTION__,
	      [StringClass stringWithCString:_buf + opStart
			   length:pos - opStart], _buf);
      }
      
      *_opLen = pos;
      return [StringClass stringWithCString:_buf + opStart length:pos - opStart];
    }
  }
  if (qDebug)
    NSLog(@"_parseOp return nil for <%s> ", _buf);
  return nil;
}

static NSString *_parseKey(id _ctx, const char *_buf, unsigned _bufLen,
                           unsigned *_keyLen)
{ 
  id           result   = nil;
  NSDictionary *dict    = nil;
  unsigned     pos      = 0;
  unsigned     startKey = 0;
  char         c        = 0;

  if (_bufLen == 0) {
    if (qDebug)
      NSLog(@"%s: _bufLen == 0 --> return nil", __PRETTY_FUNCTION__);
    return nil;
  }
  dict = [_ctx resultForFunction:@"parseKey" atPos:(unsigned long)_buf];
  if (dict != nil) {
    if (qDebug) {
      NSLog(@"%s: return <%@> [cached] for <%s> ", __PRETTY_FUNCTION__,
	    dict, _buf);
    }
    *_keyLen = [[dict objectForKey:@"length"] unsignedIntValue];
    return [dict objectForKey:@"object"];
  }
  pos      = _countWhiteSpaces(_buf, _bufLen);
  startKey = pos;
  c        = _buf[pos];

  if (c == '%') {
    if (_bufLen - pos < 2) {
      if (qDebug) {
	NSLog(@"%s: [c==%%,bufLen-pos<2]: _parseValue return nil for <%s> ", 
	      __PRETTY_FUNCTION__, _buf);
      }
      return nil;
    }
    pos++;
    result = [_ctx getObjectFromStackFor:_buf[pos]];
    pos++;
  }
  else {
    /* '{' for namspaces */
    register BOOL isQuotedKey = NO;

    if (c == '"')
      isQuotedKey = YES;
    else if (!(((c >= 'A') && (c <= 'Z')) || ((c >= 'a') && (c <= 'z')) ||
             c == '{')) {
      if (qDebug) {
	NSLog(@"%s: [c!=AZaz{]: _parseKey return nil for <%s> ", 
	      __PRETTY_FUNCTION__, _buf);
      }
      return nil;
    }
    
    pos++;
    while (pos < _bufLen) {
      c = _buf[pos];
      if (isQuotedKey && c == '"')
	break;
      else if
	((c == ' ') || (c == '<') || (c == '>') || (c == '=') || (c == '!') ||
         c == ')' || c == '(')
        break;
      pos++;    
    }
    if (isQuotedKey) {
      pos++; // skip quote
      result = [StringClass stringWithCString:(_buf + startKey + 1) 
			    length:(pos - startKey - 2)];
    }
    else {
      result = [StringClass stringWithCString:(_buf + startKey) 
			    length:(pos - startKey)];
    }
  }
  *_keyLen = pos;  
  if (qDebug)
    NSLog(@"%s: return <%@> for <%s> ", __PRETTY_FUNCTION__, result, _buf);
  
  if (result != nil) {
    id keys[2], values[2];
    
    keys[0] = @"length"; values[0] = [NSNumber numberWithUnsignedInt:pos];
    keys[1] = @"object"; values[1] = result;
    
    [_ctx setResult:
            [NSDictionary dictionaryWithObjects:values forKeys:keys count:2]
          forFunction:@"parseKey"
          atPos:(unsigned long)_buf];
    *_keyLen = pos;
  }
  return result;
}

static id _parseValue(id _ctx, const char *_buf, unsigned _bufLen,
                      unsigned *_keyLen)
{
  NSString     *cast = nil;
  NSDictionary *dict = nil;
  id           obj   = nil;
  unsigned     pos   = 0;
  char         c     = 0;
  
  if (NumberClass == Nil) NumberClass = [NSNumber class];
  if (null == nil) null = [[NSNull null] retain];
  
  if (_bufLen == 0) {
    if (qDebug) NSLog(@"_parseValue _bufLen == 0 --> return nil");
    return nil;
  }
  
  dict = [_ctx resultForFunction:@"parseValue" atPos:(unsigned long)_buf];
  if (dict != nil) {
    if (qDebug) {
      NSLog(@"_parseKeyCompPredicate return <%@> [cached] for <%s> ",
	    dict, _buf);
    }
    *_keyLen = [[dict objectForKey:@"length"] unsignedIntValue];
    return [dict objectForKey:@"object"];
  }
  
  pos = _countWhiteSpaces(_buf, _bufLen);
  c   = _buf[pos];
  
  if (c == '$') { /* found NSPredicateVariable */
    unsigned startVar = 0;
    NSString *varKey;
    
    pos++;
    startVar = pos;
    while (pos < _bufLen) {
      if ((_buf[pos] == ' ') || (_buf[pos] == ')'))
        break;
      pos++;
    }

    varKey = [StringClass stringWithCString:(_buf + startVar)
                          length:pos - startVar];
    obj = [NSExpression expressionForVariable:varKey];
  }
  else {
    /* first, check for CAST */
    BOOL parseComplexCast = NO;
    
    if (c == 'c' && _bufLen > 14) {
      if (strstr(_buf, "cast") == _buf && (isspace(_buf[4]) || _buf[4]=='(')) {
	/* for example: cast("1970-01-01T00:00:00Z" as 'dateTime') [min 15 #]*/
	pos += 4; /* skip 'cast' */
        while (isspace(_buf[pos])) /* skip spaces */
          pos++;
        if (_buf[pos] != '(') {
          NSLog(@"WARNING(%s): got unexpected cast string: '%s'",
                __PRETTY_FUNCTION__, _buf);
        }
        else
          pos++; /* skip opening bracket '(' */
        
	parseComplexCast = YES;
	c = _buf[pos];
      }
    }
    else if (c == '(') { /* starting with a cast */
      /* for example: (NSCalendarDate)"1999-12-12" [min 5 chars] */
      unsigned startCast = 0;
      
      pos++;
      startCast = pos;
      while (pos < _bufLen) {
        if (_buf[pos] == ')')
          break;
        pos++;
      }
      pos++;
      if (pos >= _bufLen) {
        NSLog(@"WARNING(%s): found end of string while reading a cast",
              __PRETTY_FUNCTION__);
        return nil;
      }
      c    = _buf[pos];
      cast = [StringClass stringWithCString:(_buf + startCast)
                          length:(pos - 1 - startCast)];
      if (qDebug)
	NSLog(@"%s: got cast %@", __PRETTY_FUNCTION__, cast);
    }
    
    /* next, check for FORMAT SPECIFIER */
    if (c == '%') {
      if (_bufLen - pos < 2) {
	if (qDebug)
	  NSLog(@"_parseValue return nil for <%s> ", _buf);
	
        return nil;
      }
      pos++;
      obj = [_ctx getObjectFromStackFor:_buf[pos]];
      pos++;
    }
    
    /* next, check for A NUMBER */
    else if (((c >= '0') && (c <= '9')) || (c == '-')) { /* got a number */
      unsigned startNumber;

      startNumber = pos;
      pos++;
      while (pos < _bufLen) {
        c = _buf[pos];
        if (!((c >= '0') && (c <= '9')))
          break;
        pos++;
      }
      obj = [NumberClass numberWithInt:atoi(_buf + startNumber)];
    }

    /* check for some text literals */
    if ((obj == nil) && ((_bufLen - pos) > 1)) {
      unsigned char i;
      
      for (i = 0; i < 20 && (toks[i].token != NULL) && (obj == nil); i++) {
	const unsigned char *tok;
	unsigned char toklen;
	int rc;
	
	tok = toks[i].token;
	toklen = strlen((const char *)tok);
	if ((_bufLen - pos) < toklen)
	  /* remaining string not long enough */
	  continue;
	
	rc = toks[i].scase 
	  ? strncmp(&(_buf[pos]),     (const char *)tok, toklen)
	  : strncasecmp(&(_buf[pos]), (const char *)tok, toklen);
	if (rc != 0)
	  /* does not match */
	  continue;
	if (!(_buf[pos + toklen] == '\0' || isspace(_buf[pos + toklen])))
	  /* not at the string end or folloed by a space */
	  continue;

	/* wow, found the token */
	pos += toklen; /* skip it */
	obj = toks[i].value;
      }
    }
    
    /* next, check for STRING */
    if (obj == nil) {
      if ((c == '\'') || (c == '"')) {
	NSString *res                  = nil;
	char     string[_bufLen - pos];
	unsigned cnt                   = 0;
      
	pos++;
	while (pos < _bufLen) {
	  char ch = _buf[pos];
	  if (ch == c)
	    break;
	  if ((ch == '\\') && (_bufLen > (pos + 1))) {
	    if (_buf[pos + 1] == c) {
	      pos += 1;
	      ch = c;
	    }
	  }
	  string[cnt++] = ch;
	  pos++;
	}
	if (pos >= _bufLen) {
	  NSLog(@"WARNING(%s): found end of string before end of quoted text",
		__PRETTY_FUNCTION__);
	  return nil;
	}
	res = [StringClass stringWithCString:string length:cnt];
	pos++; /* don`t forget quotations */
	if (qDebug) NSLog(@"_parseValue return <%@> for <%s> ", res, _buf);
	obj = res;
      }
    }
    
    /* complete parsing of cast */
    if (parseComplexCast && (pos + 6) < _bufLen) {
      /* now we need " as 'dateTime'" [min 7 #] */
      
      /* skip spaces */
      while (isspace(_buf[pos]) && pos < _bufLen) pos++;
      
      //printf("POS: '%s'\n", &(_buf[pos]));
      /* parse 'as' */
      if (_buf[pos] != 'a' && _buf[pos] != 'A')
	NSLog(@"%s: expecting 'AS' of complex cast ...", __PRETTY_FUNCTION__);
      else if (_buf[pos + 1] != 's' && _buf[pos + 1] != 'S')
	NSLog(@"%s: expecting 'AS' of complex cast ...", __PRETTY_FUNCTION__);
      else {
	/* skip AS */
	pos += 2;
	
	/* skip spaces */
	while (isspace(_buf[pos]) && pos < _bufLen) pos++;
	
	/* read cast type */
	if (_buf[pos] != '\'') {
	  NSLog(@"%s: expected type of complex cast ...", __PRETTY_FUNCTION__);
	}
	else {
	  const unsigned char *cs, *ce;
	  
	  //printf("POS: '%s'\n", &(_buf[pos]));
	  pos++;
	  cs = (const unsigned char *)&(_buf[pos]);
	  ce = (const unsigned char *)index((const char *)cs, '\'');
	  cast = [NSString stringWithCString:(const char*)cs length:(ce - cs)];
	  if (qDebug) {
	    NSLog(@"%s: parsed complex cast: '%@' to '%@'", 
		  __PRETTY_FUNCTION__, obj, cast);
	  }
	  pos += (ce - cs);
	  pos++; // skip '
	  pos++; // skip )
	  //printf("POS: '%s'\n", &(_buf[pos]));
	}
      }
    }
  }
  
  if (cast != nil && obj != nil) {
    Class class = Nil;
    id orig = obj;
    
    if ((class = [NSPredicateParserTypeMappings objectForKey:cast]) == nil) {
      /* no value explicitly mapped to class, try to construct class name... */
      NSString *className;

      className = cast;
      if ((class = NSClassFromString(className)) == Nil) {
        /* check some default cast types ... */
        className = [cast lowercaseString];
        
        if ([className isEqualToString:@"datetime"])
          class = [NSCalendarDate class];
        else if ([className isEqualToString:@"datetime.tz"])
          class = [NSCalendarDate class];
      }
    }
    if (class) {
      obj = [[[class alloc] initWithString:[orig description]] autorelease];
      
      if (obj == nil) {
	NSLog(@"%s: could not init object '%@' of cast class %@(%@) !",
	      __PRETTY_FUNCTION__, orig, class, cast);
	obj = null;
      }
    }
    else {
      NSLog(@"WARNING(%s): could not map cast '%@' to a class "
	    @"(returning null) !", 
	    __PRETTY_FUNCTION__, cast);
      obj = null;
    }
  }
  
  if (qDebug) {
    NSLog(@"%s: return <%@> for <%s> ", __PRETTY_FUNCTION__, 
	  obj != nil ? obj : (id)@"<nil>", _buf);
  }
  
  if (obj != nil) {
    id keys[2], values[2];
    
    keys[0] = @"length"; values[0] = [NSNumber numberWithUnsignedInt:pos];
    keys[1] = @"object"; values[1] = obj;
    
    [_ctx setResult:
            [NSDictionary dictionaryWithObjects:values forKeys:keys count:2]
          forFunction:@"parseValue" atPos:(unsigned long)_buf];
    *_keyLen = pos;
  }
  return obj;
}

static NSPredicate *_testOperator(id _ctx, const char *_buf,
                                  unsigned _bufLen, unsigned *_opLen,
                                  BOOL *isAnd)
{
  NSPredicate *qual       = nil;
  char        c0, c1, c2  = 0;
  unsigned    pos, len    = 0;

  pos = _countWhiteSpaces(_buf, _bufLen);  
  
  if (_bufLen < 4) {/* at least OR or AND and somethink more */   
    if (qDebug)
      NSLog(@"_testOperator return nil for <%s> ", _buf);
    return nil;
  }
  c0 = _buf[pos + 0];
  c1 = _buf[pos + 1];
  c2 = _buf[pos + 2];
  
  if (((c0 == 'a') || (c0  == 'A')) &&
        ((c1 == 'n') || (c1  == 'N')) &&
        ((c2 == 'd') || (c2  == 'D'))) {
      pos    += 3;
      *isAnd  = YES;
  }
  else if (((c0 == 'o') || (c0  == 'O')) && ((c1 == 'r') || (c1  == 'R'))) {
      pos    += 2;
      *isAnd  = NO;
  }
  pos += _countWhiteSpaces(_buf + pos, _bufLen - pos);
  qual = _parseSinglePredicate(_ctx, _buf + pos, _bufLen - pos, &len);
  *_opLen = pos + len;
  if (qDebug)
    NSLog(@"_testOperator return %@ for <%s> ", qual, _buf);
  
  return qual;
}

static NSPredicate *_parseCompoundPredicate(id _ctx, const char *_buf,
                                            unsigned _bufLen, 
					    unsigned *_predLen)
{
  NSPredicate    *q0, *q1 = nil;
  NSMutableArray *array   = nil;
  unsigned       pos, len = 0;
  NSPredicate    *result;
  BOOL           isAnd;

  isAnd = YES;

  if ((q0 = _parseSinglePredicate(_ctx, _buf, _bufLen, &len)) == nil) {
    if (qDebug)
      NSLog(@"_parseAndOrPredicate return nil for <%s> ", _buf);
    
    return nil;
  }
  pos = len;

  if (!(q1 = _testOperator(_ctx, _buf + pos, _bufLen - pos, &len, &isAnd))) {
    if (qDebug)
      NSLog(@"_parseAndOrPredicate return nil for <%s> ", _buf);
    return nil;
  }
  pos  += len;
  array = [NSMutableArray arrayWithObjects:q0, q1, nil];
  
  while (YES) {
    BOOL newIsAnd;

    newIsAnd = YES;
    q0       = _testOperator(_ctx,  _buf + pos, _bufLen - pos, &len, &newIsAnd);

    if (!q0)
      break;
    
    if (newIsAnd != isAnd) {
      NSArray *a;

      a = [[array copy] autorelease];
      
      q1 = (isAnd)
	? [NSCompoundPredicate andPredicateWithSubpredicates:a]
	: [NSCompoundPredicate orPredicateWithSubpredicates:a];
      
      [array removeAllObjects];
      [array addObject:q1];
      isAnd = newIsAnd;
    }
    [array addObject:q0];

    pos += len;
  }

  *_predLen = pos;
  result = (isAnd)
    ? [NSCompoundPredicate andPredicateWithSubpredicates:array]
    : [NSCompoundPredicate orPredicateWithSubpredicates:array];
  
  if (qDebug)
    NSLog(@"_parseAndOrPredicate return <%@> for <%s> ", result, _buf);

  return result;
}

static inline unsigned _countWhiteSpaces(const char *_buf, unsigned _bufLen) {
  unsigned cnt = 0;
  
  if (_bufLen == 0) {
    if (qDebug)
      NSLog(@"_parseString _bufLen == 0 --> return nil");
    return 0;
  }
  
  while (_buf[cnt] == ' ' || _buf[cnt] == '\t' || 
	 _buf[cnt] == '\n' || _buf[cnt] == '\r') {
    cnt++;
    if (cnt == _bufLen)
      break;
  }
  return cnt;
}
