// $Id: ApacheCmdParms.h,v 1.1 2004/06/08 11:15:58 helge Exp $

#ifndef __ApacheCmdParms_H__
#define __ApacheCmdParms_H__

#include <ApacheAPI/ApacheObject.h>

@class ApacheResourcePool, ApacheServer;

@interface ApacheCmdParms : ApacheObject
{
}

/* accessors */

- (void *)userInfo;

/* Pool to allocate new storage in */
- (ApacheResourcePool *)pool;

/*
  Pool for scratch memory; persists during
  configuration, but wiped before the first
  request is served...
*/
- (ApacheResourcePool *)temporaryPool;

/* Server_rec being configured for */
- (ApacheServer *)server;

@end

#endif /* __ApacheCmdParms_H__ */
