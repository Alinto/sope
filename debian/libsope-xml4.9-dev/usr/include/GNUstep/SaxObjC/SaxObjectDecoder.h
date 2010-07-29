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

#ifndef __SaxObjC_SaxObjectDecoder_H__
#define __SaxObjC_SaxObjectDecoder_H__

#include <SaxObjC/SaxDefaultHandler.h>

/*
  This SAX handler takes a model dictionary and maps the SAX events
  to object construction commands.
  
  [to be done: further description of format and function]
*/

@class SaxObjectModel;

@interface SaxObjectDecoder : SaxDefaultHandler
{
  id<NSObject,SaxLocator> locator;
  id rootObject;
  id mapping;

  NSMutableArray *infoStack;
  NSMutableArray *mappingStack;
  NSMutableArray *objectStack;
}

- (id)initWithMappingModel:(SaxObjectModel *)_model;
- (id)initWithMappingAtPath:(NSString *)_path;
- (id)initWithMappingNamed:(NSString *)_name;

/* parse results */

- (id)rootObject;

/* cleanup */

- (void)reset;

@end

@interface NSObject(SaxObjectCoding)

- (id)initWithSaxDecoder:(SaxObjectDecoder *)_decoder;
- (id)awakeAfterUsingSaxDecoder:(SaxObjectDecoder *)_decoder;

@end

#endif /* __SaxObjC_SaxObjectDecoder_H__ */
