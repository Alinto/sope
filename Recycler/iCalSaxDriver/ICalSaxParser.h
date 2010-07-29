/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#ifndef __ICal2_ICalSaxParser_H__
#define __ICal2_ICalSaxParser_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include <SaxObjC/SaxXMLReader.h>
#include <SaxObjC/SaxContentHandler.h>
#include <SaxObjC/SaxErrorHandler.h>
#include <SaxObjC/SaxLexicalHandler.h>
#include <SaxObjC/SaxLocator.h>

@class SaxAttributes;

@interface ICalSaxParser : NSObject < SaxXMLReader >
{
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  
  /* transient */
  NSStringEncoding encoding;
  SaxAttributes    *attrs;
}

@end

#endif /* __ICal2_ICalSaxParser_H__ */
