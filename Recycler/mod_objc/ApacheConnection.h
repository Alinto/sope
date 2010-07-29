// $Id: ApacheConnection.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheConnection_H__
#define __ApacheConnection_H__

#include "ApacheObject.h"

@class NSString;
@class ApacheResourcePool, ApacheServer;

@interface ApacheConnection : ApacheObject

/* accessors */

- (ApacheResourcePool *)connectionPool;
- (ApacheServer *)server;
- (ApacheServer *)baseServer;

/* Information about the connection itself */

- (int)childNumber;

/* Who is the client? */

- (NSString *)remoteIP;
- (NSString *)remoteHost;
- (NSString *)remoteLogName;
- (NSString *)user;
- (NSString *)authorizationType;

- (NSString *)localIP;
- (NSString *)localHost;

- (BOOL)isAborted;

- (BOOL)usesKeepAlive;
- (BOOL)doesNotUseKeepAlive;
- (BOOL)didUseKeepAlive;
- (int)numberOfKeepAlives;

- (BOOL)isValidDoubleReverseDNS;
- (BOOL)isInvalidDoubleReverseDNS;

@end

#endif /* __ApacheConnection_H__ */
