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

#ifndef __NGImap4_NGImap4ResponseNormalizer_H__
#define __NGImap4_NGImap4ResponseNormalizer_H__

#import <Foundation/NSObject.h>

@class NSDictionary, NSMutableDictionary;
@class NGHashMap;
@class NGImap4Client;

@interface NGImap4ResponseNormalizer : NSObject
{
  NGImap4Client *client; // non-retained
}

- (id)initWithClient:(NGImap4Client *)_client;

/* primary */

- (NSMutableDictionary *)normalizeResponse:(NGHashMap *)_map;

/* specific */

- (NSDictionary *)normalizeFetchResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeOpenConnectionResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeListResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeSelectResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeStatusResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeSearchResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeSortResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeThreadResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeCapabilityResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeNamespaceResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeQuotaResponse:(NGHashMap *)_map;

/* ACL */

- (NSDictionary *)normalizeGetACLResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeListRightsResponse:(NGHashMap *)_map;
- (NSDictionary *)normalizeMyRightsResponse:(NGHashMap *)_map;

@end

#endif /* __NGImap4_NGImap4ResponseNormalizer_H__ */
