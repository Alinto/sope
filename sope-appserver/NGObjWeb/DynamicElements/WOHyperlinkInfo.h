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

#ifndef __WOHyperlinkInfo_H__
#define __WOHyperlinkInfo_H__

#import <Foundation/NSObject.h>

@class NSMutableDictionary, NSDictionary;
@class WOAssociation, WOElement;

/* a temporary object to store all associations relevant for WOHyperlink */

@interface WOHyperlinkInfo : NSObject
{
@public
  NSMutableDictionary *rest;
  unsigned char initialCount;
  unsigned char assocCount;   /* count of ivar associations which are set */
  
  WOAssociation *action;
  WOAssociation *href;
  WOAssociation *pageName;
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  WOAssociation *isAbsolute;

  BOOL          sidInUrl;

  /* 'ivar' associations */
  WOAssociation *string;
  WOAssociation *fragmentIdentifier;
  WOAssociation *target;
  WOAssociation *disabled;
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;
  WOAssociation *filename;
  WOAssociation *framework;
  WOAssociation *src;
  WOAssociation *disabledFilename;
}

- (id)initWithConfig:(NSMutableDictionary *)_config;

@end

#endif /* __WOHyperlinkInfo_H__ */
