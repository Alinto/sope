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

#ifndef __WOXMLMappingProperty_H__
#define __WOXMLMappingProperty_H__

#import <Foundation/NSObject.h>

@class NSString;
@class WOXMLMappingEntity;

@interface WOXMLMappingProperty : NSObject
{
  WOXMLMappingEntity *entity;
  NSString *name;
  NSString *xmlTag;
  BOOL     attribute;         /* used during encoding */
  BOOL     forceList;         /* decoding only        */
  NSString *codeBasedOn;
  BOOL     reportEmptyValues; /* decoding only        */
  NSString *outputTags;       /* encoding only ?      */
}

- (id)initWithEntity:(WOXMLMappingEntity *)_entity;

/* validity */

- (BOOL)isValid;

/* attributes */

- (void)setName:(NSString *)_name;
- (NSString *)name;
- (void)setXmlTag:(NSString *)_xmlTag;
- (NSString *)xmlTag;
- (void)setCodeBasedOn:(NSString *)_codeBasedOn;
- (NSString *)codeBasedOn;
- (void)setOutputTags:(NSString *)_tags;
- (NSString *)outputTags;
- (void)setAttribute:(BOOL)_flag;
- (BOOL)attribute;
- (void)setForceList:(BOOL)_flag;
- (BOOL)forceList;
- (void)setReportEmptyValues:(BOOL)_flag;
- (BOOL)reportEmptyValues;

@end

#endif /* __WOXMLMappingProperty_H__ */
