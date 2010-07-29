// $Id: FBBlobHandle.m 1 2004-08-20 10:38:46Z znek $

#include "FBBlobHandle.h"
#include "FBValues.h"
#include "common.h"

@implementation FBBlobHandle

- (id)initWithBlobID:(NSString *)_bid {
  self->bid = [_bid copyWithZone:[self zone]];
  return self;
}

- (void)dealloc {
  RELEASE(self->bid);
  [super dealloc];
}

/* accessors */

- (NSString *)blobID {
  return self->bid;
}

/* data */

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  NSLog(@"called %@ on BLOB handle %@", NSStringFromSelector(_cmd), self);
  return nil;
}

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  NSLog(@"called %@ on BLOB handle %@", NSStringFromSelector(_cmd), self);
  return nil;
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  switch (_type) {
    case FB_Character:
    case FB_VCharacter:
    case FB_CLOB:
    case FB_BLOB:
      return self->bid;
      //return [NSString stringWithFormat:@"@'%s'", [self->bid cString]];
  }
  return nil;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: id=%@>",
                     NSStringFromClass([self class]), self,
                     [self blobID]];
}

@end /* FBBlobHandle */
