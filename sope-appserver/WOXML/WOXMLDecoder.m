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

#include <WOXML/WOXMLDecoder.h>
#include "WOXMLMappingModel.h"
#include "WOXMLMapDecoder.h"
#include <DOM/DOMDocument.h>
#include "common.h"

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (id)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation WOXMLDecoder

+ (id)xmlDecoderWithMapping:(NSString *)_mapURL {
  WOXMLMappingModel *model;

  if ((model = [WOXMLMappingModel mappingModelByParsingFromURL:_mapURL]) == nil)
    return nil;

  return AUTORELEASE([[WOXMLMapDecoder alloc] initWithModel:model]);
}

/* root object */

- (id)decodeRootObjectFromString:(NSString *)_str {
  return [self subclassResponsibility:_cmd];
}
- (id)decodeRootObjectFromData:(NSData *)_data {
  return [self subclassResponsibility:_cmd];
}

- (id)decodeRootObjectFromFileHandle:(NSFileHandle *)_fh {
  return [self decodeRootObjectFromData:[_fh readDataToEndOfFile]];
}

@end /* WOXMLDecoder */
