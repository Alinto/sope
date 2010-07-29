// $Id: EOAdaptorGlobalID.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOAdaptorGlobalID_H__
#define __EOAdaptorGlobalID_H__

#include <EOControl/EOGlobalID.h>

@class EOKeyGlobalID, NSDictionary;

@interface EOAdaptorGlobalID : EOGlobalID < NSCopying >
{
@protected
  EOGlobalID   *gid;
  NSDictionary *conDict;
}

- (id)initWithGlobalID:(EOGlobalID *)_gid
  connectionDictionary:(NSDictionary *)_conDict;

- (EOGlobalID *)globalID;
- (NSDictionary *)connectionDictionary;

- (BOOL)isEqual:(id)_obj;
- (BOOL)isEqualToEOAdaptorGlobalID:(EOAdaptorGlobalID *)_gid;

@end

#endif /* __EOAdaptorGlobalID_H__ */
