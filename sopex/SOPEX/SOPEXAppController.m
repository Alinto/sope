/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import "SOPEXAppController.h"
#import <NGStreams/NGStreams.h>
#import <NGStreams/NGNet.h>
#import "SOPEXConsole.h"
#import "SOPEXStatisticsController.h"
#import "SOPEXConstants.h"
#import "SOPEXWebConnection.h"
#import "SOPEXBrowserController.h"
#import <NGObjWeb/NGObjWeb.h>

#define DNC [NSNotificationCenter defaultCenter]
#define UD [NSUserDefaults standardUserDefaults]

@interface WOAdaptor (SOPEXConvenience)
- (NGInternetSocketAddress *)socketAddress;
@end

@interface WOApplication (SOPEXConvenience)
- (NGInternetSocketAddress *)address;
@end

@implementation WOApplication (SOPEXConvenience)
- (NGInternetSocketAddress *)address {
  NSArray   *_adaptors = [self adaptors];
  WOAdaptor *adaptor   = nil;

  NSAssert([_adaptors count] > 0, @"no adaptors registered for application");
  adaptor = [_adaptors objectAtIndex:0];
  
  if (![adaptor respondsToSelector:@selector(socketAddress)])
    return nil;
  return [adaptor socketAddress];
}
@end

@interface SOPEXAppController (PrivateAPI)
- (void)_setup;
- (void)_launchSOPE;
@end

@implementation SOPEXAppController

static NGLogger *logger     = nil;
static BOOL     isInRADMode = YES;

+ (void)initialize {
  NGLoggerManager *lm;
  NSArray         *args;
  static BOOL     didInit = NO;
  
  if(didInit) return;
  didInit = YES;
  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey:@"SOPEXDebugEnabled"];

  // check, if Application has been launched by Finder
  args = [[NSProcessInfo processInfo] arguments];
  if([(NSString *)[args lastObject] hasPrefix:@"-psn_"])
    isInRADMode = NO;
  [logger debugWithFormat:@"Is in RAD mode: %@",
                            isInRADMode ? @"YES" : @"NO"];
}

+ (id)sharedController {
  return [NSApp delegate];
}

- (void)dealloc {
  [DNC removeObserver:self];
  [self->console               release];
  [self->statsController       release];
  [self->mainBrowserController release];
  [super dealloc];
}


/* SETUP */

- (void)awakeFromNib {
  NSString *appName, *s;

  // Fix menu items
  appName = [[NSProcessInfo processInfo] processName];
  s = [NSString stringWithFormat:[self->aboutMenuItem title], appName];
  [self->aboutMenuItem setTitle:s];
  s = [NSString stringWithFormat:[self->hideMenuItem title], appName];
  [self->hideMenuItem setTitle:s];
  s = [NSString stringWithFormat:[self->quitMenuItem title], appName];
  [self->quitMenuItem setTitle:s];
}


- (void)_setup {
  if(![self isInRADMode]) {
    NSMenu *viewMenu;

    // remove RAD menuItems
    [self->mainMenu removeItem:self->debugMenuItem];
    viewMenu = [self->viewSeparatorMenuItem menu];
    [viewMenu removeItem:self->viewSeparatorMenuItem];
    [viewMenu removeItem:self->viewApplicationMenuItem];
    [viewMenu removeItem:self->viewSourceMenuItem];
    [viewMenu removeItem:self->viewHTMLMenuItem];
    [viewMenu removeItem:self->viewHTTPMenuItem];
  }
  
  self->console               = [[SOPEXConsole alloc] init];
  self->mainBrowserController = [[SOPEXBrowserController alloc] init];
  
  [DNC addObserver:self
          selector:@selector(sopeDidFinishLaunching:)
              name:WOApplicationDidFinishLaunchingNotification
            object:nil];
  [DNC addObserver:self
          selector:@selector(sopeDidTerminate:)
              name:WOApplicationDidTerminateNotification
            object:nil];
}

- (void)_launchSOPE {
  [NSThread detachNewThreadSelector:@selector(runSOPE)
            toTarget:self
            withObject:nil];
}

- (void)runSOPE {
  NSAutoreleasePool *p;
  NSUserDefaults    *ud;
  NSString          *appClass;

  p        = [NSAutoreleasePool new];
  ud       = [NSUserDefaults standardUserDefaults];
  appClass = [ud stringForKey:@"SOPEXWOApplicationClass"];
  if (!appClass)
    appClass = @"Application";
  WOApplicationMain(appClass, 0, NULL);
  [p release];
}

- (void)prepareForLaunch {
  NSUserDefaults      *ud;
  NSArray             *appenders;
  NSMutableDictionary *tmp, *fmt;

  ud = [NSUserDefaults standardUserDefaults];

  /* NGLogging */
  
  [ud setObject:@"SOPEXConsoleAppender" forKey:@"NGLogDefaultAppenderClass"];
  [ud setObject:@"SOPEXConsoleEventFormatter"
      forKey:@"NGLogDefaultLogEventFormatterClass"];

  fmt = [[NSMutableDictionary alloc] initWithCapacity:1];
  [fmt setObject:@"SOPEXConsoleEventFormatter" forKey:@"Class"];

  tmp = [[NSMutableDictionary alloc] initWithCapacity:1];
  [tmp setObject:@"SOPEXConsoleAppender" forKey:@"Class"];
  [tmp setObject:fmt                     forKey:@"Formatter"];
  [fmt release];

  appenders = [[NSArray alloc] initWithObjects:tmp, nil];
  [tmp release];

  tmp = [[NSMutableDictionary alloc] initWithCapacity:2];
  [tmp setObject:@"INFO"   forKey:@"LogLevel"];
  [tmp setObject:appenders forKey:@"Appenders"];
  [appenders release];
  [ud setObject:tmp forKey:@"WOHttpTransactionLoggerConfig"];
  [tmp release];

  /* SOPE options */
  
  /* wildcard host and automatic port */
  [ud setObject:@"*:auto" forKey:@"WOPort"];

  if([self isInRADMode]) {
    // the next entry works, because  executable's cwd is the project directory
    // (set in project's launch options)
    [ud setObject:[[NSFileManager defaultManager] currentDirectoryPath]
        forKey:@"WOProjectDirectory"];
    
    // Debugging options
    [ud setBool:NO  forKey:@"WOCachingEnabled"];
    [ud setBool:YES forKey:@"WODebuggingEnabled"];

#if 0
    [ud setBool:YES forKey:@"WODebugComponentLookup"];
    [ud setBool:YES forKey:@"WODebugResourceLookup"];
#endif
#if 0
    [ud setBool:YES forKey:@"WOxComponentElemBuilderDebugEnabled"];
    [ud setBool:YES forKey:@"WOxElemBuilder_LogAssociationMapping"];
    [ud setBool:YES forKey:@"WOxElemBuilder_LogAssociationCreation"];
#endif
#if 0
#warning ** ZNeK: Profiling information
    [ud setBool:YES forKey:@"WOProfileComponents"];
    [ud setBool:YES forKey:@"WOProfileElements"];
    [ud setBool:YES forKey:@"WOProfileHttpAdaptor"];
#endif
  }
  else {
    [ud setBool:YES forKey:@"WOCachingEnabled"];
    [ud setBool:NO  forKey:@"WODebuggingEnabled"];
    [ud removeObjectForKey:@"WOProjectDirectory"];
  }
}


/* ACCESSORS */

- (BOOL)isInRADMode {
  return isInRADMode;
}


/* ACTIONS */

- (IBAction)openConsole:(id)sender {
  [self->console orderFront:sender];
}

- (IBAction)openStatistics:(id)sender {
  [self->statsController orderFront:sender];
}

- (IBAction)clear:(id)sender {
  [self->console clear:sender];
}

- (IBAction)restart:(id)sender {
  [[WOApplication application] terminate];
  [self _launchSOPE];
}


/* Notifications */

- (void)browserControllerDidClose:(SOPEXBrowserController *)_controller {
  if(self->mainBrowserController == _controller) {
    self->mainBrowserController = nil;
  }
  if (![SOPEXBrowserController hasActiveControllers]) {
    if([self->console isVisible])
      [self->console close:self];
    if([self->statsController isVisible])
      [self->statsController close:self];
  }
}

/* VALIDATION */

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
  SEL action = [menuItem action];
  
#if 0
  NSLog(@"%s action:%@", __PRETTY_FUNCTION__, NSStringFromSelector(action));
#endif
  if(action == @selector(openStatistics:))
    return self->statsController != nil;
  if(action == @selector(clear:))
    return [self->console validateMenuItem:menuItem];
  return YES;
}


/* APPLICATION DELEGATE */

- (void)applicationWillFinishLaunching:(NSNotification *)_notif {
}

- (void)applicationDidFinishLaunching:(NSNotification *)_notif {
  [self _setup];
  [self prepareForLaunch];
  [self _launchSOPE];
  if(isInRADMode)
    [self openConsole:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)_a {
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)_a {
#warning !! FIXME!!
#if 0
  if(! [self windowShouldClose:self->mainWindow])
    return NSTerminateLater;
#endif
  [[WOApplication application] terminate];
  return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)_notif {
}


/* WOApplication notifications */

- (void)sopeDidFinishLaunching:(NSNotification *)_notif {
  /* do this in main thread */
  [self performSelectorOnMainThread:@selector(_connectToSOPE)
        withObject:nil
        waitUntilDone:NO];
}

- (void)_connectToSOPE {
  /* create web connection */
  WOApplication      *app;
  SOPEXWebConnection *conn;
  NSString           *url, *path;
  NSBundle           *rsrcBundle;
  
  app = [WOApplication application];
  /* ZNeK: "localhost" might be wrong as WOPort could be an
    NGInternetSocketAddress ... in theory */
  url = [NSString stringWithFormat:@"http://localhost:%d/%@",
                                     [[app address] port],
                                     [app name]];

  // In Rapid Development mode the mainBundle path is the current working
  // directory, which is where the source code is located
  if([self isInRADMode]) {
    path = [[NSFileManager defaultManager] currentDirectoryPath];
  }
  else {
    path = [[NSBundle mainBundle] resourcePath];
  }
  
  // However, SOPE:X applications have a special WebServerResources folder
  path       = [path stringByAppendingPathComponent:@"WebServerResources"];
  rsrcBundle = [[[NSBundle alloc] initWithPath:path] autorelease];
  
  self->statsController =
    [[SOPEXStatisticsController alloc] initWithApplicationURL:url];
  
  conn =
    [(SOPEXWebConnection *)[SOPEXWebConnection alloc]
      initWithURL:url
      localResourceBundle:rsrcBundle];
  
  [self->mainBrowserController setWebConnection:conn];
  [conn release];
  
  if(logger)
    [self debugWithFormat:@"Connecting SOPE at %@", url];
  [self->mainBrowserController reload:nil];
  [self->mainBrowserController orderFront:self];
}

- (void)sopeDidTerminate:(NSNotification *)_notif {
  [self warnWithFormat:@"SOPE did terminate"];
}


/* Logging */

- (SOPEXConsole *)console {
  return self->console;
}

- (id)debugLogger {
  return logger;
}

@end
