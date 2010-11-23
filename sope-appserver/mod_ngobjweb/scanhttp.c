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
#include "NGBufferedDescriptor.h"

unsigned char NGScanResponseLine(NGBufferedDescriptor *_in,
                                 unsigned char *_version, int *_status, 
                                 unsigned char *_text) 
{
  if (_in == NULL) return 0;

  if (_version) *_version = '\0';
  if (_text)    *_text    = '\0';
  if (_status)  *_status  = '\0';
  
  {
    int c;
    int i;

    /* scan HTTP Version */
    {
      c = NGBufferedDescriptor_readChar(_in);
      i = 0;
      while ((c > 0) && !apr_isspace(c) && (i < 16)) {
        if (_version) _version[i] = c;
        i++;
        c = NGBufferedDescriptor_readChar(_in);
      }
      if (_version) _version[i] = '\0';
      if (c < 1) return 0; // read error
    }
    
    /* skip spaces */
    while ((c > 0) && apr_isspace(c))
      c = NGBufferedDescriptor_readChar(_in);
    if (c < 1) return 0; // read error

    /* scan code */
    {
      char buf[10];
      i = 0;
      while ((c > 0) && !apr_isspace(c) && (c != '\r') && (c != '\n') && 
             (i < 6)) {
        buf[i] = c;
        i++;
        c = NGBufferedDescriptor_readChar(_in);
      }
      buf[i] = '\0';
      if (_status) *_status = atoi(buf);
    }

    /* skip spaces */
    while ((c > 0) && apr_isspace(c))
      c = NGBufferedDescriptor_readChar(_in);
    if (c < 1) return 0; // read error

    /* check for EOL */
    if (c == '\n') return 1; // response without reason
    if (c == '\r') { // response without reason
      c = NGBufferedDescriptor_readChar(_in); // c=='\n'
      return 1;
    }

    /* scan reason */
    {
      i = 0;
      while ((c > 0) && !apr_isspace(c) && (c != '\r') && (c != '\n') && 
             (i < 6)) {
        if (_text) _text[i] = c;
        i++;
        c = NGBufferedDescriptor_readChar(_in);
      }
      if (_text) _text[i] = '\0';
      if (c < 1) return 0; // read error
    }

    /* scan until line end */
    while ((c > 0) && (c != '\n'))
      c = NGBufferedDescriptor_readChar(_in);

    if (c < 1) return 0; // read error
  }
  return 1;
}

apr_table_t *NGScanHeaders(apr_pool_t *_pool, NGBufferedDescriptor *_in) {
  apr_table_t *headers = NULL;

  if (_in == NULL) return NULL;

  headers = apr_table_make(_pool, 64);
  if (headers) {
    char name[256];
    char value[8000];
    int c;

    while (1) {
      int i, j;
      
      c = NGBufferedDescriptor_readChar(_in);
      if (c <= 0) // error
        break;

      // test for end of HTTP header
      {
        if (c == '\n') // end line '\n'
          break;
        if (c == '\r') { // end line '\r\n'
          c = NGBufferedDescriptor_readChar(_in);
          // c should be '\n'
          break;
        }
      }

      // scan name
      {
        i = 0;
        while ((c > 0) && (c != ':') && (i < 255)) {
          name[i] = c;
          i++;
          c = NGBufferedDescriptor_readChar(_in);
        }
        name[i] = '\0';
        if (i < 1) break; // empty header name ?!
      }
      if (c != ':') break; // missing separator ?

      // skip spaces following separator
      c = NGBufferedDescriptor_readChar(_in);
      while ((c > 0) && (apr_isspace(c)))
        c = NGBufferedDescriptor_readChar(_in);

      // scan value
      {
        j = 0;
        while ((c > 0) && (c != '\r') && (j < 7999)) {
          value[j] = c;
          j++;
          c = NGBufferedDescriptor_readChar(_in);
        }
        value[j] = '\0';
        if (j < 1) break; // empty header value ?!
      }

      if (c == '\n') // '\n' header end
        ;
      else if (c == '\r') { // '\r\n' header end
        c = NGBufferedDescriptor_readChar(_in);
        if (c != '\n') break;
      }
      else // no valid header end
        break;

      // store value
      apr_table_add(headers, name, value);
    }
  }
  return headers;
}
