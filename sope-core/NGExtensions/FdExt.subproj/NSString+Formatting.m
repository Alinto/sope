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

#include "common.h"
#include "NSString+Formatting.h"
#include "NGMemoryAllocation.h"

#if 0

#if !ISERIES
#  ifndef USE_VA_LIST_PTR
#    define USE_VA_LIST_PTR 1
#  endif
#else
#  define USE_VA_LIST_PTR 0
#endif


// format
//   %|[justification]|[fieldwidth]|[precision]|formatChar
//   %[-]{digit}*[.{digit}*]conv

static const char *formatChars =
  "diouxX" // integers
  "feEgG"  // double
  "c"      // int arg -> uchar
  "s"      // string
  "@"      // object
  "$"      // string object
;
static const char *formatAttrs = "#0- +,";
static const char *formatConv  = "hlLqZ";
static Class StrClass = Nil;

typedef enum {
  DEFAULT_TYPE = 0,
  SHORT_TYPE,
  LONG_TYPE,
  VERY_LONG_TYPE
} NGFormatType;

// implementation

static inline NSString *
wideString(const char *str, int width, char fillChar, BOOL isRightAligned)
{
  unsigned char *tmp;
  register int cnt;
  int len;
  
  if (StrClass == Nil) StrClass = [NSString class];
  
  if (width <= 0)
    return str ? [StrClass stringWithCString:str] : nil;

  if ((len = strlen(str)) >= width)
    return str ? [StrClass stringWithCString:str] : nil;

  tmp = malloc(width + 2);
  if (isRightAligned) { // right aligned
    for (cnt = 0; cnt < (width - len); cnt++)
      tmp[cnt] = fillChar;
    strncpy(tmp + (width - len), str, len);
    tmp[width] = '\0';
  }
  else { // left aligned
    for (cnt = len; cnt < width; cnt++)
      tmp[cnt] = fillChar;
    strncpy(tmp, str, len);
    tmp[cnt] = '\0';
  }
  
  return [[[StrClass alloc]
                     initWithCStringNoCopy:tmp length:strlen(tmp)
                     freeWhenDone:YES] autorelease];
}

static inline NSString *xsSimpleFormatObject(char *fmt, id _value, NSString *_ds) {
  /*
    formats an object value in an simple format
    (this is only the '%{mods}{type}' part of a real
    format string !)
    The method to get the value of the object is
    determined by the {type} of the Format,
    eg: i becomes intValue, @ becomes description ..

    the decimal point in float-strings can be replaced by the _ds
    String. To do this, the result of the Format is scanned for
    '.' and _ds is expanded for this.
  */
  int  fmtLen  = strlen(fmt);
  char fmtChar = fmt[fmtLen - 1];
  NGFormatType typeMode = DEFAULT_TYPE;
  int  width      = -1;
  int  prec       = -1;
  BOOL alignRight = YES;
  char *pos = fmt + 1;
  char *tmp;
  
  if (StrClass == Nil) StrClass = [NSString class];
  
  while (index(formatAttrs, *pos)) {
    if (*pos == '-')
      alignRight = NO;
    pos++;
  }
  
  /* width */
  tmp = pos;
  while (isdigit((int)*pos)) pos++;
  if (tmp != pos) {
    char old = *pos;
    *pos = '\0';
    width = atoi(tmp);
    *pos = old;
  }

  /* prec */
  if (*pos == '.') {
    pos++;
    tmp = pos;
    while (isdigit((int)*pos)) pos++;
    if (tmp != pos) {
      char old = *pos;
      *pos = '\0';
      prec = atoi(tmp);
      *pos = old;
    }
  }

  /* conversion */
  if (index(formatConv, *pos)) {
    switch (*pos) {
      case 'h':
        typeMode = SHORT_TYPE;
        pos++;
        break;
      case 'l':
        typeMode = LONG_TYPE;
        pos++;
        if (*pos == 'l') { // long-long
          typeMode = VERY_LONG_TYPE;
          pos++;
        }
        break;
      case 'L':
      case 'q':
        typeMode = VERY_LONG_TYPE;
        pos++;
        break;
    }
  }

  if (index("diouxX", fmtChar)) {
    char buf[128];
    int  len = -1;

    switch (typeMode) {
      case SHORT_TYPE: {
        unsigned short int i = [(NSNumber *)_value unsignedShortValue];
        len = sprintf(buf, fmt, i);
        break;
      }
      case LONG_TYPE: {
        unsigned long int i = [(NSNumber *)_value unsignedLongValue];
        len = sprintf(buf, fmt, i);
        break;
      }
      case VERY_LONG_TYPE: {
        long long i = [(NSNumber *)_value unsignedLongLongValue];
        len = sprintf(buf, fmt, i);
        break;
      }
      default: {
        unsigned int i = [(NSNumber *)_value unsignedIntValue];
        len = sprintf(buf, fmt, i);
        break;
      }
    }

    return (len >= 0) ? [StrClass stringWithCString:buf length:len] : nil;
  }
  
  if (fmtChar == 'c') {
    char buf[64];
    int  i = [(NSNumber *)_value unsignedCharValue];
    int  len;

    len = sprintf(buf, fmt, (unsigned char)i);

    return (len > 0) ? [StrClass stringWithCString:buf length:len] : nil;
  }
  if (fmtChar == 'C') {
    // TODO: implement correctly
    /* 16bit unichar value */
    char buf[64];
    int  i, len;
    
    /* TODO: evil hack */
    fmt[fmtLen - 1] = 'c';
    i = [(NSNumber *)_value unsignedCharValue];
    len = sprintf(buf, fmt, (unsigned char)i);
    
    return (len > 0) ? [StrClass stringWithCString:buf length:len] : nil;
  }
  
  if (index("feEgG", fmtChar)) {
    unsigned char buf[256];
    unsigned len;

    if (typeMode == VERY_LONG_TYPE) {
      long double i = [(NSNumber *)_value doubleValue];
      len = sprintf(buf, fmt, i);
    }
    else {
      double i = [(NSNumber *)_value doubleValue];
      len = sprintf(buf, fmt, i);
    }

    if (len >= 0) {
      NSMutableString *result;
      unsigned int cnt;
      char         *ptr = buf;
      unsigned int bufCount = 0;
      
      if (_ds == nil)
        return [StrClass stringWithCString:buf length:len];

      result = 
        [NSMutableString stringWithCapacity:len + [_ds cStringLength]];

      for (cnt = 0; cnt < len; cnt++) {
        if (buf[cnt] == '.') {
          if (bufCount > 0) {
            NSString *s;
            
            // TODO: cache selector
            s = [[StrClass alloc] initWithCString:ptr length:bufCount];
            if (s) [result appendString:s];
            [s release];
          }

          if (_ds) [result appendString:_ds];
          
          ptr = &(buf[cnt + 1]);
          bufCount = 0;
        }
        else {
          bufCount++;
        }
        
        if (bufCount > 0) {
          NSString *s;
          
          // TODO: cache selector
          s = [[StrClass alloc] initWithCString:ptr length:bufCount];
          if (s) [result appendString:s];
          [s release];
        }
        return result;
      }
    }
    else 
      return nil;
  }
  else {
    switch (fmtChar) {
      case 's': case 'S': {
        /* TODO: implement 'S', current mech is evil hack */
	unsigned len;
	char *buffer = NULL;
	id result;

	if (_value == nil)
	  return wideString("<null>", width, ' ', alignRight);
	
	len    = [(NSString *)_value cStringLength];
	buffer = malloc(len + 10);
	[_value getCString:buffer];
	buffer[len] = '\0';
	
        result = wideString(buffer, width, ' ', alignRight);
	free(buffer);
	return result;
      }
      
      case '@': {
        id       obj   = _value;
        NSString *dstr = obj ? [obj description] : @"<nil>";
	char     *buffer = NULL;
	unsigned len;

	if (dstr == nil)
	  return wideString("<null>", width, ' ', alignRight);
	
	len    = [dstr cStringLength];
	buffer = malloc(len + 10);
	[dstr getCString:buffer];
	buffer[len] = '\0';
	
	dstr = wideString(buffer, width, ' ', alignRight);
	free(buffer);
	return dstr;
      }
      
      case '$': {
        id       obj   = _value;
        NSString *dstr;
        char     *cstr;

        dstr = obj ? [obj stringValue] : @"<nil>";
        cstr = (char *)[dstr cString];
        if (cstr == NULL) cstr = "<null>";
        
        return wideString(cstr, width, ' ', alignRight);
      }
        
      default:
        fprintf(stderr, "WARNING(%s): unknown printf format used: '%s'\n", 
                __PRETTY_FUNCTION__, fmt);
        break;
    }
  }
  return nil;
}

#if USE_VA_LIST_PTR
static inline NSString *handleFormat(char *fmt, int fmtLen, va_list *_ap) {
#else
static inline NSString *handleFormat(char *fmt, int fmtLen, va_list _ap) {
#endif
  char fmtChar;
  char typeMode   = DEFAULT_TYPE;
  int  width      = -1;
  int  prec       = -1;
  BOOL alignRight = YES;
  char *pos = fmt + 1;
  char *tmp;
  if (StrClass == Nil) StrClass = [NSString class];

  if (fmtLen == 0)
    return @"";

  fmtChar = fmt[fmtLen - 1];
  
  while (index(formatAttrs, *pos)) {
    if (*pos == '-')
      alignRight = NO;
    pos++;
  }
  
  /* width */
  tmp = pos;
  while (isdigit((int)*pos)) pos++;
  if (tmp != pos) {
    char old = *pos;
    *pos = '\0';
    width = atoi(tmp);
    *pos = old;
  }

  /* prec */
  if (*pos == '-') {
    pos++;
    tmp = pos;
    while (isdigit((int)*pos)) pos++;
    if (tmp != pos) {
      char old = *pos;
      *pos = '\0';
      prec = atoi(tmp);
      *pos = old;
    }
  }

  /* conversion */
  if (index(formatConv, *pos)) {
    switch (*pos) {
      case 'h':
        typeMode = SHORT_TYPE;
        pos++;
        break;
      case 'l':
        typeMode = LONG_TYPE;
        pos++;
        if (*pos == 'l') { // long-long
          typeMode = VERY_LONG_TYPE;
          pos++;
        }
        break;
      case 'L':
      case 'q':
        typeMode = VERY_LONG_TYPE;
        pos++;
        break;
    }
  }

#if HEAVY_DEBUG && 0
  printf("  width=%i prec=%i\n", width, prec); fflush(stdout);
#endif
    
  if (index("diouxX", fmtChar)) {
    char buf[128];
    int  len = -1;

    switch (typeMode) {
      case SHORT_TYPE: {
#if USE_VA_LIST_PTR
        unsigned short int i = va_arg(*_ap, int);
#else
        unsigned short int i = va_arg(_ap, int);
#endif
        len = sprintf(buf, fmt, i);
        break;
      }
      case LONG_TYPE: {
#if USE_VA_LIST_PTR        
        unsigned long int i = va_arg(*_ap, unsigned long int);
#else
        unsigned long int i = va_arg(_ap, unsigned long int);
#endif
        len = sprintf(buf, fmt, i);
        break;
      }
      case VERY_LONG_TYPE: {
#if USE_VA_LIST_PTR        
        long long i = va_arg(*_ap, long long);
#else
        long long i = va_arg(_ap, long long);
#endif
        len = sprintf(buf, fmt, i);
        break;
      }
      default: {
#if USE_VA_LIST_PTR        
        unsigned int i = va_arg(*_ap, unsigned int);
#else
        unsigned int i = va_arg(_ap, unsigned int);
#endif
        len = sprintf(buf, fmt, i);
        break;
      }
    }

    return (len >= 0) ? [StrClass stringWithCString:buf length:len] : nil;
  }
  
  if (fmtChar == 'c') {
    char buf[64];
#if USE_VA_LIST_PTR        
    int  i = va_arg(*_ap, int);
#else
    int  i = va_arg(_ap, int);
#endif
    int  len;

    if (i == 0)
      return @"<'\\0'-char>";

    len = sprintf(buf, fmt, (unsigned char)i);

#if HEAVY_DEBUG && 0
    xsprintf("got format %s char %i made %s len %i\n",
             fmt, i, buf, len);
#endif
    
    if (len == 0) return nil;
    return [StrClass stringWithCString:buf length:len];
  }
  if (fmtChar == 'C') {
    /* 16bit unichar */
    char buf[64];
#if USE_VA_LIST_PTR        
    int  i = va_arg(*_ap, int);
#else
    int  i = va_arg(_ap, int);
#endif
    int  len;

    if (i == 0)
      return @"<'\\0'-unichar>";
    
    /* TODO: implement properly, evil hack */
    fmt[fmtLen - 1] = 'c';
    len = sprintf(buf, fmt, (unsigned char)i);

#if HEAVY_DEBUG && 0
    xsprintf("got format %s unichar %i made %s len %i\n",
             fmt, i, buf, len);
#endif
    
    if (len == 0) return nil;
    return [StrClass stringWithCString:buf length:len];
  }
  
  if (index("feEgG", fmtChar)) {
    char buf[256];
    int  len;

    if (typeMode == VERY_LONG_TYPE) {
#if USE_VA_LIST_PTR        
      long double i = va_arg(*_ap, long double);
#else
      long double i = va_arg(_ap, long double);
#endif
      len = sprintf(buf, fmt, i);
    }
    else {
#if USE_VA_LIST_PTR        
      double i = va_arg(*_ap, double);
#else
      double i = va_arg(_ap, double);
#endif
      len = sprintf(buf, fmt, i);
    }

    return (len >= 0) ? [StrClass stringWithCString:buf length:len] : nil;
  }
  
  {
    id result = nil;
    
    switch (fmtChar) {
      case 's':
      case 'S': /* unicode char array */
      case '@':
      case '$': {
        char *cstr = NULL;
	BOOL owned = NO;

        if (fmtChar == 's') {
#if USE_VA_LIST_PTR        
          cstr = va_arg(*_ap, char *);
#else
          cstr = va_arg(_ap, char *);
#endif
        }
        else {
#if USE_VA_LIST_PTR        
          id obj = va_arg(*_ap, id);
#else
          id obj = va_arg(_ap, id);
#endif
          if (obj == nil)
            cstr = "<nil>";
          else {
	    NSString *d;
	    
            if ((d = (fmtChar == '@') ?[obj description]:[obj stringValue])) {
	      unsigned len = [d cStringLength];

	      cstr = NGMalloc(len + 1);
	      [d getCString:cstr];
	      cstr[len] = '\0';
	      owned = YES;
	    }
          }
        }

        if (cstr == NULL) cstr = "<null>";

        result = wideString(cstr, width, ' ', alignRight);
	if (owned) NGFree(cstr);
        break;
      }

      default:
        fprintf(stderr, "WARNING(%s): unknown printf format used: '%s'\n", 
                __PRETTY_FUNCTION__, fmt);
        break;
    }
    return result;
  }
  return nil;
}

static inline NSString *_stringWithCFormat(const char *_format, va_list _ap) {
  const char *firstPercent;
  NSMutableString *result;
  
  if (StrClass == Nil) StrClass = [NSString class];
  firstPercent = index(_format, '%');
#if 0
  fprintf(stderr, "OWN: format='%s'\n", _format);
  fflush(stderr);
#endif
  
  // first check whether there are any '%' in the format ..
  if (firstPercent == NULL) {
    // no formatting contained in _format
    return [StrClass stringWithCString:_format];
  }
  
  result = [NSMutableString stringWithCapacity:256];

  if ((firstPercent - _format) > 0) {
    NSString *s;
    s = [[StrClass alloc] initWithCString:_format 
                          length:(firstPercent - _format)];
    if (s) [result appendString:s];
    [s release];
    _format = firstPercent;
  }

  while (*_format != '\0') { // until end of format string
    if (*_format == '%') { // found formatting character
      _format++; // skip '%'

      if (*_format == '%') { // was a quoted '%'
        [result appendString:@"%"];
        _format++;
      }
      else { // check format
        char extFmt[16];
        char *pos  = extFmt;

        extFmt[0] = '%';
        pos++;
      
        while ((*_format != '\0') &&
                (index(formatChars, *_format) == NULL)) {
          *pos = *_format;
          _format++;
          pos++;
        }
        *pos = *_format;
        _format++;
        pos++;
        *pos = '\0';

        // printf("handling ext format '%s'\n", extFmt); fflush(stdout);
        /* hack for iSeries port, ix86 seems to copy va_list iSeries
            don`t like pointers to va_list
        */
        {
          NSString *s;
#if USE_VA_LIST_PTR
          s = handleFormat(extFmt, strlen(extFmt), &_ap);
#else
          s = handleFormat(extFmt, strlen(extFmt), _ap);
#endif
          if (s) [result appendString:s];
        }
      }
    }
    else { // normal char
      const char *start = _format; // remember start
      NSString *s;
      _format++; // skip found char

      // further increase format until '\0' or '%'
      while ((*_format != '\0') && (*_format != '%'))
        _format++;
      
      s = [[StrClass alloc] initWithCString:start
                            length:(_format - start)];
      if (s) [result appendString:s];
      [s release];
    }
  }
  return result;
}

@implementation NSString(XSFormatting)

+ (id)stringWithCFormat:(const char *)_format arguments:(va_list)_ap {
  return [self stringWithString:_stringWithCFormat(_format, _ap)];
}

+ (id)stringWithFormat:(NSString *)_format arguments:(va_list)_ap {
  unsigned len;
  char     *cfmt;
  id s;

  len = [_format cStringLength] + 1;
  cfmt = malloc(len + 1);
  [_format getCString:cfmt]; cfmt[len] = '\0';
  s = [self stringWithString:_stringWithCFormat(cfmt, _ap)];
  free(cfmt);
  return s;
}

+ (id)stringWithCFormat:(const char *)_format, ... {
  id      result = nil;
  va_list ap;
  
  va_start(ap, _format);
  result = [self stringWithString:_stringWithCFormat(_format, ap)];
  va_end(ap);
  return result;
}

+ (id)stringWithFormat:(NSString *)_format, ... {
  id       result = nil;
  unsigned len;
  char     *cfmt;
  va_list  ap;
  
  len = [_format cStringLength];
  cfmt = malloc(len + 1);
  [_format getCString:cfmt]; cfmt[len] = '\0';
  va_start(ap, _format);
  result = [self stringWithString:_stringWithCFormat(cfmt, ap)];
  va_end(ap);
  free(cfmt);
  return result;
}

- (id)initWithFormat:(NSString *)_format arguments:(va_list)_ap {
  unsigned len;
  char *cfmt;

  len = [_format cStringLength];
  cfmt = malloc(len + 1);
  [_format getCString:cfmt]; cfmt[len] = '\0';
  self = [self initWithString:_stringWithCFormat(cfmt, _ap)];
  free(cfmt);
  return self;
}

@end /* NSString(XSFormatting) */

@implementation NSMutableString(XSFormatting)

- (void)appendFormat:(NSString *)_format arguments:(va_list)_ap {
  unsigned len;
  NSString *s;
  char     *cfmt;
  
  len = [_format cStringLength];
  cfmt = malloc(len + 4);
  
  [_format getCString:cfmt]; cfmt[len] = '\0';
  s = _stringWithCFormat(cfmt, _ap);
  if (cfmt) free(cfmt);
  if (s) [self appendString:s];
}
- (void)appendFormat:(NSString *)_format, ... {
  unsigned len;
  char     *cfmt;
  NSString *s;
  va_list  ap;
  
  len = [_format cStringLength];
  cfmt = malloc(len + 4);
  [_format getCString:cfmt]; cfmt[len] = '\0';
  va_start(ap, _format);
  s = _stringWithCFormat(cfmt, ap);
  va_end(ap);
  if (cfmt) free(cfmt);
  if (s) [self appendString:s];
}

@end /* NSMutableString(XSFormatting) */

#endif

// var args wrappers

int xs_sprintf(char *str, const char *format, ...) {
  va_list ap;
  int result;
  va_start(ap, format);
  result = xs_vsprintf(str, format, ap);
  va_end(ap);
  return result;
}
int xs_snprintf(char *str, size_t size, const char *format, ...) {
  va_list ap;
  int result;
  va_start(ap, format);
  result = xs_vsnprintf(str, size, format, ap);
  va_end(ap);
  return result;
}

/* static linking */

void __link_NSString_Formatting(void) {
  __link_NSString_Formatting();
}
