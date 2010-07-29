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

#ifndef __NGStreams_NGUrlChars_H__
#define __NGStreams_NGUrlChars_H__

static inline BOOL isUrlAlpha(unsigned char _c) {
  return
    (((_c >= 'a') && (_c <= 'z')) ||
     ((_c >= 'A') && (_c <= 'Z')))
    ? YES : NO;
}
static inline BOOL isUrlDigit(unsigned char _c) {
  return ((_c >= '0') && (_c <= '9')) ? YES : NO;
}
static inline BOOL isUrlSafeChar(unsigned char _c) {
  switch (_c) {
    case '$': case '-': case '_': case '@':
    case '.': case '&': case '+':
      return YES;

    default:
      return NO;
  }
}
static inline BOOL isUrlExtraChar(unsigned char _c) {
  switch (_c) {
    case '!': case '*': case '"': case '\'':
    case '|': case ',':
      return YES;
  }
  return NO;
}
static inline BOOL isUrlEscapeChar(unsigned char _c) {
  return (_c == '%') ? YES : NO;
}
static inline BOOL isUrlReservedChar(unsigned char _c) {
  switch (_c) {
    case '=': case ';': case '/':
    case '#': case '?': case ':':
    case ' ':
      return YES;
  }
  return NO;
}

static inline BOOL isUrlXalpha(unsigned char _c) {
  if (isUrlAlpha(_c))      return YES;
  if (isUrlDigit(_c))      return YES;
  if (isUrlSafeChar(_c))   return YES;
  if (isUrlExtraChar(_c))  return YES;
  if (isUrlEscapeChar(_c)) return YES;
  return NO;
}

static inline BOOL isUrlHexChar(unsigned char _c) {
  if (isUrlDigit(_c))
    return YES;
  if ((_c >= 'a') && (_c <= 'f'))
    return YES;
  if ((_c >= 'A') && (_c <= 'F'))
    return YES;
  return NO;
}

static inline BOOL isUrlAlphaNum(unsigned char _c) {
  return (isUrlAlpha(_c) || isUrlDigit(_c)) ? YES : NO;
}

#endif /* __NGStreams_NGUrlChars_H__ */
