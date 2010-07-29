// $Id: ApacheServer.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheServer_H__
#define __ApacheServer_H__

#include <ApacheAPI/ApacheObject.h>

@interface ApacheServer : ApacheObject
{
}

/* accessors */

- (ApacheServer *)nextServer;

/* description of where the definition came from */

- (NSString *)definitionName;
- (unsigned int)definitionLineNumber;

/* locations of server config info */

- (NSString *)srmConfigName;
- (NSString *)accessConfigName;

- (NSString *)serverAdmin;
- (NSString *)serverHostName;
- (unsigned short)port;

/* log files */

- (NSString *)errorFileName;
- (FILE *)errorLogFile;
- (int)logLevel;

/* module-specific configuration for server, and defaults... */

- (BOOL)isVirtual;

/* transaction handling */

- (NSTimeInterval)timeout;
- (NSTimeInterval)keepAliveTimeout;
- (int)keepAliveMax;
- (BOOL)keepAlive;
- (int)sendBufferSize;

- (id)serverUserId;
- (id)serverGroupId;

- (int)requestLineLimit;
- (int)requestFieldSizeLimit;
- (int)requestFieldCountLimit;

@end

#endif /* __ApacheServer_H__ */
