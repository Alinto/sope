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

#ifndef __DOMBuilderFactory_H__
#define __DOMBuilderFactory_H__

#import <Foundation/NSObject.h>
#include <DOM/DOMBuilder.h>

/*
  To get a reader for HTML files:
    reader = [factory createDOMBuilderForMimeType:@"text/html"];

  for XML files:
    reader = [factory createDOMBuilderForMimeType:@"text/xml"];
    
  a specific reader:
    reader = [factory createDOMBuilderWithName:@"libxmlSAXDriver"];
*/

@class NSDictionary;
    
@interface DOMBuilderFactory : NSObject
{
}

+ (id)standardDOMBuilderFactory;

- (id<NSObject,DOMBuilder>)createDOMBuilder;
- (id<NSObject,DOMBuilder>)createDOMBuilderWithName:(NSString *)_name;
- (id<NSObject,DOMBuilder>)createDOMBuilderForMimeType:(NSString *)_mtype;

- (NSArray *)availableDOMBuilders;

@end

#endif /* __DOMBuilderFactory_H__ */
