
#ifndef __NGImap4_NGImap4ServerGlobalID_H__
#define __NGImap4_NGImap4ServerGlobalID_H__

#include <EOControl/EOGlobalID.h>

@interface NGImap4ServerGlobalID : EOGlobalID < NSCopying >
{
  NSString *hostName;
  NSString *login;
  int      port;
}

+ (id)imap4ServerGlobalIDForHostname:(NSString *)_host port:(int)_port
  login:(NSString *)_login;
- (id)initWithHostname:(NSString *)_host port:(int)_port
  login:(NSString *)_login;

/* accessors */

- (NSString *)hostName;
- (NSString *)login;
- (int)port;

/* comparison */

- (BOOL)isEqualToImap4ServerGlobalID:(NGImap4ServerGlobalID *)_other;

@end

#endif /* __NGImap4_NGImap4ServerGlobalID_H__ */
