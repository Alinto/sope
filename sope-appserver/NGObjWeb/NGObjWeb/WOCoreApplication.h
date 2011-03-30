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

#ifndef __NGObjWeb_WOCoreApplication_H__
#define __NGObjWeb_WOCoreApplication_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSDate.h>
#include <NGObjWeb/NGObjWebDecls.h>

@class NSArray, NSNumber, NSDictionary, NSRunLoop;
@class WOAdaptor, WORequest, WOResponse, WORequestHandler;
@class NSBundle;

@class NGActiveSocket, NGPassiveSocket;

NGObjWeb_EXPORT NSString *WOApplicationWillFinishLaunchingNotification;
NGObjWeb_EXPORT NSString *WOApplicationDidFinishLaunchingNotification;
NGObjWeb_EXPORT NSString *WOApplicationWillTerminateNotification;
NGObjWeb_EXPORT NSString *WOApplicationDidTerminateNotification;

@interface WOCoreApplication : NSObject < NSLocking >
{
  NSRecursiveLock *lock;
  NSLock          *requestLock;

  NGActiveSocket *controlSocket;
  NGPassiveSocket *listeningSocket;

  struct {
    BOOL isTerminating:1;
  } cappFlags;
  
@protected
  NSArray         *adaptors;
}

/* active application */

+ (id)application;
- (void)activateApplication;
- (void)deactivateApplication;

/* Watchdog helpers */

- (void)setControlSocket: (NGActiveSocket *) newSocket;
- (NGActiveSocket *)controlSocket;

- (void)setListeningSocket: (NGPassiveSocket *) newSocket;
- (NGPassiveSocket *)listeningSocket;

/* adaptors */

- (NSArray *)adaptors;
- (WOAdaptor *)adaptorWithName:(NSString *)_name
  arguments:(NSDictionary *)_args;
- (BOOL)allowsConcurrentRequestHandling;
- (BOOL)adaptorsDispatchRequestsConcurrently;

/* multithreading */

- (void)lockRequestHandling;
- (void)unlockRequestHandling;
- (void)lock;
- (void)unlock;
- (BOOL)tryLock;

/* request recording */

- (NSString *)recordingPath;

/* runloop */

- (void)run;
- (NSRunLoop *)mainThreadRunLoop;

- (void)terminate;
- (void)terminateAfterTimeInterval:(NSTimeInterval)_interval;
- (BOOL)isTerminating;

/* dispatching requests */

- (WORequestHandler *)handlerForRequest:(WORequest *)_request;

- (WOResponse *)dispatchRequest:(WORequest *)_request;
- (WOResponse *)dispatchRequest:(WORequest *)_request
  usingHandler:(WORequestHandler *)_handler;;

- (void)setPrintsHTMLParserDiagnostics:(BOOL)_flag;
- (BOOL)printsHTMLParserDiagnostics;

@end

int WOApplicationMain(NSString *_appClassName, int argc, const char *argv[]);
int WOWatchDogApplicationMain
  (NSString *_appClassName, int argc, const char *argv[]);
int WOWatchDogApplicationMainWithServerDefaults
  (NSString *_appClassName, int argc, const char *argv[],
   NSString *globalDomainPath, NSString *appDomainPath);

@interface WOCoreApplication(DeprecatedMethodsInWO4)

- (NSRunLoop *)runLoop;
- (WOResponse *)handleRequest:(WORequest *)_request;

@end

@interface WOCoreApplication(Defaults)

/* A hook to override/plugin into the registration of user defaults.
   NOTE: this is called by -init (as the first thing), so be extra cautious
*/
- (void)registerUserDefaults;

/* WOAdaptor */
+ (void)setAdaptor:(NSString *)_key;
+ (NSString *)adaptor;

/* WOAdditionalAdaptors */
+ (void)setAdditionalAdaptors:(NSArray *)_names;
+ (NSArray *)additionalAdaptors;

/* WOPort */
+ (void)setPort:(NSNumber *)_port;
+ (NSNumber *)port;

/* WOWorkerThreadCount */
+ (NSNumber *)workerThreadCount;

/* WOListenQueueSize */
+ (NSNumber *)listenQueueSize;

@end

@interface WOCoreApplication(Logging)
/* implemented in NGExtensions */
- (void)logWithFormat:(NSString *)_fmt, ...;
- (void)debugWithFormat:(NSString *)_fmt, ...;
@end

@interface WOCoreApplication(Bundle)

/* application bundles (run bundles in the WOApp container ...) */

+ (BOOL)didLoadDaemonBundle:(NSBundle *)_bundle;
+ (int)runApplicationBundle:(NSString *)_bundleName
  domainPath:(NSString *)_p
  arguments:(void *)_argv count:(int)_argc;
+ (int)runApplicationBundle:(NSString *)_bundleName
  arguments:(void *)_argv count:(int)_argc;
+ (int)loadApplicationBundle:(NSString *)_bundleName
  domainPath:(NSString *)_domain;

@end

@interface WOCoreApplication(ExtraHelpers)

+ (void) applicationWillStart;

@end

#endif /* __NGObjWeb_WOCoreApplication_H__ */
