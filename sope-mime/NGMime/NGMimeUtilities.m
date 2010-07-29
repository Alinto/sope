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

#include <NGMime/NGMimeType.h>
#include <NGMime/NGMimeUtilities.h>
#include <string.h>

typedef struct {
  NSString *charset;
  NSString *q;
  NSString *boundary;
  NSString *name;
  NSString *fileName;
  NSString *reportType;
} NGMimeParameterConstants;

static NGMimeParameterConstants *MimeParameterConstants = NULL;
static Class                    NSStringClass           = Nil;
static int                      MimeLogEnabled          = -1;

static NSString *_stringForParameterName(char *_type, int _len) {
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];

  if (MimeLogEnabled == -1) {
    MimeLogEnabled = [[NSUserDefaults standardUserDefaults]
                                      boolForKey:@"MimeLogEnabled"]?1:0;
  }

  if (MimeParameterConstants == NULL) {
    MimeParameterConstants = malloc(sizeof(NGMimeParameterConstants));

    MimeParameterConstants->charset    = NGMimeParameterTextCharset;
    MimeParameterConstants->q          = @"q";
    MimeParameterConstants->name       = @"name";
    MimeParameterConstants->boundary   = @"boundary";
    MimeParameterConstants->fileName   = @"filename";
    MimeParameterConstants->reportType = @"report-type";
  }
  switch (_len) {
    case 0:
      return @"";
    case 1:
      if (_type[0] == 'q')
        return MimeParameterConstants->q;
      break;
    case 4:
      if (strncmp(_type, "name", 4) == 0) 
        return MimeParameterConstants->name;
      break;
    case 7:
      if (strncmp(_type, "charset", 7) == 0) 
        return MimeParameterConstants->charset;
      break;
    case 8:
      if (strncmp(_type, "boundary", 8) == 0) 
          return MimeParameterConstants->boundary;
      if (strncmp(_type, "filename", 8) == 0) 
          return MimeParameterConstants->fileName;
      break;
    case 11:
      if (strncmp(_type, "report-type", 11) == 0) 
          return MimeParameterConstants->reportType;
      break;
  }
  return [NSStringClass stringWithCString:_type length:_len];
}

NSDictionary *parseParameters(id self, NSString *_str, unichar *cstr) {
  if (*cstr != '\0') {
    NSMutableDictionary *paras;

    paras = [[NSMutableDictionary alloc] initWithCapacity:8];
    do {
      unsigned len;
      unichar  *tmp;
      NSString *attrName, *attrValue;

      attrValue = nil;
      attrName  = nil;

      // consume end of previous entry (spaces and ';')
      while ((*cstr == ';') || isRfc822_LWSP(*cstr))
        cstr++;

      // parse attribute
      tmp = cstr;
      len = 0;
      while ((*cstr != '\0') && (isMime_ValidTypeAttributeChar(*cstr))) {
        cstr++;
        len++;
      }
      if (len == 0)
        break;
      {
        unsigned char     buf[len + 1];
        register unsigned i;

        buf[len] = '\0';
        for (i = 0; i < len; i++) buf[i] = tolower(tmp[i]);

        attrName = _stringForParameterName((char *)buf, len);
      }
      // skip spaces
      while ((*cstr != '\0') && (isRfc822_LWSP(*cstr))) {
        cstr++;
      }
      // no value was given for attribute
      if (*cstr == '\0') {
        if (MimeLogEnabled)
          [self logWithFormat:@"WARNING(%s): attribute '%@' has no value in "
                @"MimeType '%@'", __PRETTY_FUNCTION__, attrName, _str];
        break; // exit loop
      }

      // expect '='
      if (*cstr != '=') {
        if (MimeLogEnabled) 
          [self logWithFormat:@"WARNING(%s): attribute '%@', missing '=' "
                @"in MimeType '%@'", __PRETTY_FUNCTION__, attrName, _str];
        break; // exit loop
      }
      cstr++;

      // skip spaces
      while ((*cstr != '\0') && (isRfc822_LWSP(*cstr)))
        cstr++;
      
      /* no value was given for parameter */
      if (*cstr == '\0') {
        if (MimeLogEnabled) 
          [self logWithFormat:@"WARNING(%s): attribute '%@' has no value "
                @"in MimeType '%@'", __PRETTY_FUNCTION__, attrName, _str];
        break; // exit loop
      }
      
      /* now parameter read value */
      if (isRfc822_QUOTE(*cstr)) { // quoted value
        cstr++;
        tmp = cstr;
        len = 0;
        while (!isRfc822_QUOTE(*cstr) && (*cstr != '\0')) {
          cstr++;
          len++;
        }
        attrValue = [[[NSString alloc] initWithCharacters:tmp length:len]
                                autorelease];
          
        if (*cstr == '\0') { // quote was not closed
          if (MimeLogEnabled)  
            [self logWithFormat:@"WARNING(%s): value-quotes in attribute "
                  @"'%@' were not closed in MimeType '%@'",
                  __PRETTY_FUNCTION__, attrName, _str];
          break; // exit loop
        }
        cstr++; // skip closing quote
      }
      else { /* value without quotes */
        tmp = cstr;
        len = 0;

        while (*cstr != '\0') {
          if (isRfc822_SPACE(*cstr)) break;
          if (isRfc822_CTL(*cstr))   break;
            
          if (*cstr == ';') break; /* parameter separator */
            
          cstr++;
          len++;
        }
        attrValue = [[[NSString alloc] initWithCharacters:tmp length:len]
                                autorelease];
      }
      /* store attr/value pair in dictionary */
      [paras setObject:attrValue forKey:attrName];
      attrName  = nil;
      attrValue = nil;

      /* skip spaces */
      while ((*cstr != '\0') && (isRfc822_LWSP(*cstr)))
        cstr++;

      if (*cstr == ';') // skip ';' (attribute separator)
        cstr++;
      else if (*cstr == '\0') /* parsing is finished, exit loop */
        break; // exit loop
      else {
        if (MimeLogEnabled) 
          [self logWithFormat:@"WARNING(%s): expected end of string or ';', "
                @"got '%c'%i (str='%@')", __PRETTY_FUNCTION__, *cstr,
                *cstr, _str];
        break; // exit loop
      }
      /* skip spaces */
      while ((*cstr != '\0') && (isRfc822_LWSP(*cstr)))
        cstr++;
    }
    while (YES);
    return [paras autorelease];
  }
  return nil;
}

  
