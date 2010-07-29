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

#ifndef __libxmlSAXLocator_H__
#define __libxmlSAXLocator_H__

#import <Foundation/NSObject.h>
#import <SaxObjC/SaxLocator.h>

#include <libxml/parser.h>

@interface libxmlSAXLocator : NSObject < SaxLocator >
{
@public
  id            parser;
  void          *ctx;
  const xmlChar *(*getPublicId)(void *ctx);
  const xmlChar *(*getSystemId)(void *ctx);
  int           (*getLineNumber)(void *ctx);
  int           (*getColumnNumber)(void *ctx);
}

- (id)initWithSaxLocator:(xmlSAXLocatorPtr)_loc parser:(id)_parser;
- (void)clear;

/* accessors */

- (int)columnNumber;
- (int)lineNumber;
- (NSString *)publicId;
- (NSString *)systemId;

@end

#endif /* __libxmlSAXLocator_H__ */
