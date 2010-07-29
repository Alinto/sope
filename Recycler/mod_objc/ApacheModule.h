// $Id: ApacheModule.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheModule_H__
#define __ApacheModule_H__

#import <Foundation/NSObject.h>

@class NSString;
@class ApacheCmdParms, ApacheResourcePool, ApacheServer;

@interface ApacheModule : NSObject

/* return the usage string for config commands */
- (NSString *)usageForConfigSelector:(SEL)_selector;

/* logging */

- (void)logWithFormat:(NSString *)_format, ...;
- (void)debugWithFormat:(NSString *)_format, ...;

@end

@class ApacheRequest;

/*
  Note: Modules should not rely on the order in which create_server_config
  and create_dir_config are called.
*/

@interface ApacheModule(ConfigOperations)

- (id)createPerDirectoryConfigInPool:(ApacheResourcePool *)_pool;
- (id)mergePerDirectoryBaseConfig:(id)_base withNewConfig:(id)_new
  inPool:(ApacheResourcePool *)_pool;

- (id)createPerServerConfig:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool;
- (id)mergePerServerBaseConfig:(id)_base withNewConfig:(id)_new
  inPool:(ApacheResourcePool *)_pool;

/*
  -initializeModuleForServer:inPool: occurs after config parsing, but
  before any children are forked.
*/
- (void)initializeModuleForServer:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool;

@end

/* Hooks for getting into the middle of server ops ... */

extern int ApacheDeclineRequest;
extern int ApacheHandledRequest;

@interface ApacheModule(ServerOperations)

/* translate_handler --- translate URI to filename */
- (int)handleTranslationForRequest:(ApacheRequest *)_req;

/*
  access_checker --- check access by host address, etc.   All of these
                     run; if all decline, that's still OK.
*/
- (int)checkAccessForRequest:(ApacheRequest *)_req;

/* check_user_id --- get and validate user id from the HTTP request */
- (int)checkUserIdFromRequest:(ApacheRequest *)_req;

/*
  auth_checker --- see if the user (from check_user_id) is OK *here*.
                   If all of *these* decline, the request is rejected
                   (as a SERVER_ERROR, since the module which was
                   supposed to handle this was configured wrong).
*/
- (int)checkAuthForRequest:(ApacheRequest *)_req;

/*
  type_checker --- Determine MIME type of the requested entity;
                   sets content_type, _encoding and _language fields.
*/
- (int)checkTypeForRequest:(ApacheRequest *)_req;

/* logger --- log a transaction. */
- (int)logRequest:(ApacheRequest *)_req;

- (int)fixupRequest:(ApacheRequest *)_req;
- (int)parseHeadersOfRequest:(ApacheRequest *)_req;

/*
  post_read_request --- run right after read_request or internal_redirect,
                        and not run during any subrequests.
*/
- (int)postProcessRequest:(ApacheRequest *)_req;

@end

/* Regardless of the model the server uses for managing "units of
 * execution", i.e. multi-process, multi-threaded, hybrids of those,
 * there is the concept of a "heavy weight process".  That is, a
 * process with its own memory space, file spaces, etc.  This method,
 * child_init, is called once for each heavy-weight process before
 * any requests are served.  Note that no provision is made yet for
 * initialization per light-weight process (i.e. thread).  The
 * parameters passed here are the same as those passed to the global
 * init method above.
 */
@interface ApacheModule(ForkOperations)

- (void)initializeChildProcessWithServer:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool;
- (void)exitChildProcessWithServer:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool;

@end

#endif /* __ApacheModule_H__ */
