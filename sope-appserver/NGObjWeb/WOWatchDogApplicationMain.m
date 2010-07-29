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

#import <Foundation/Foundation.h>
#include <NGObjWeb/NGObjWeb.h>

#if defined(__CYGWIN32__) || defined(__MINGW32__)

int WOWatchDogApplicationMain
(NSString *appName, int argc, const char *argv[])
{
  /* no watchdog support on Win* */
  return WOApplicationMain(appName, argc, argv);
}

#else

#include <sys/wait.h>
#include <sys/types.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

static pid_t    child = -1;
static NSString *pidFile = nil;
static time_t   lastFailExit = 0;
static unsigned failExitCount = 0;
static BOOL     killedChild = NO;

static void killChild(void) {
  if (child > 0) {
    int status;
    
    fprintf(stderr, "watchdog[%i]: terminating child %i ..\n", getpid(), child);
    
    if (kill(child, SIGTERM) == 0) {
      waitpid(child, &status, 0);
      killedChild = YES;
      
      fprintf(stderr, "  terminated child %i",  child);
      
      if (WIFEXITED(status))
        fprintf(stderr, " exit=%i", WEXITSTATUS(status));
      if (WIFSIGNALED(status))
        fprintf(stderr, " signal=%i", WTERMSIG(status));
      
      fprintf(stderr, ".\n");
      fflush(stderr);
      
      child = -1;
      return;
    }
    else if (kill(child, SIGKILL)) {
      waitpid(child, &status, 0);
      killedChild = YES;
      
      fprintf(stderr, "  killed child %i",  child);
      
      if (WIFEXITED(status))
        fprintf(stderr, " exit=%i", WEXITSTATUS(status));
      if (WIFSIGNALED(status))
        fprintf(stderr, " signal=%i", WTERMSIG(status));
      
      fprintf(stderr, ".\n");
      fflush(stderr);
      
      child = -1;
      return;
    }
  }
}

static void _writePid(NSString *pidFile) {
  if ([pidFile length] > 0) {
    FILE *pf;
      
    if ((pf = fopen([pidFile cString], "w"))) {
      fprintf(pf, "%i\n", getpid());
      fflush(pf);
      fclose(pf);
    }
  }
}
static void _delPid(void) {
  if ([pidFile length] > 0) {
    if (unlink([pidFile cString]) == 0)
      pidFile = nil;
  }
}

static void exitWatchdog(void) {
  killChild();
  _delPid();
}

static void wsignalHandler(int _signal) {
  switch (_signal) {
  case SIGINT:
    /* Control-C */
    fprintf(stderr, "[%i]: watchdog handling signal ctrl-c ..\n", getpid());
    killChild();
    exit(0);
    /* shouldn't get here */
    abort();

  case SIGSEGV:
    /* Coredump ! */
    fprintf(stderr,
            "[%i]: watchdog handling segmentation fault "
            "(SERIOUS PROBLEM) ..\n",
            getpid());
    killChild();
    exit(123);
    /* shouldn't get here */
    abort();

  case SIGTERM:
    /* TERM signal (kill 'pid') */
    fprintf(stderr, "[%i]: watchdog handling SIGTERM ..\n", getpid());
    killChild();
    exit(0);
    /* shouldn't get here */
    abort();
    
  case SIGHUP:
    /* HUP signal (restart children) */
    fprintf(stderr, "[%i]: watchdog handling SIGHUP ..\n", getpid());
    killChild();
    killedChild = YES;
    signal(_signal, wsignalHandler);
    return;
    
  case SIGCHLD:
    break;
    
  default:
    fprintf(stderr, "[%i]: watchdog handling signal %i ..\n",
            getpid(), _signal);
    break;
  }
  fflush(stderr);
  
  switch (_signal) {
    case SIGTERM:
    case SIGINT:
    case SIGKILL:
    case SIGILL:
      killChild();
      exit(0);
      break;
      
    case SIGHUP:
      killChild();
      break;
      
    case SIGCHLD: {
      int   returnStatus;
      pid_t result;
      
      //      NSLog(@"SIGNAL: SIGCHLD");
      // fetch return state
      
      do {
        result = waitpid(-1, &returnStatus, WNOHANG);
        if (result > 0) {
          fprintf(stderr, "[%i]: process %i exited with code %i",
                  getpid(), (int)result, WEXITSTATUS(returnStatus));

          if (WIFSIGNALED(returnStatus)) {
            fprintf(stderr, " (terminated due to signal %i%s)",
                    WTERMSIG(returnStatus),
                    WCOREDUMP(returnStatus) ? ", coredump" : "");
          }
          if (WIFSTOPPED(returnStatus)) {
            fprintf(stderr, " (stopped due to signal %i)",
                    WSTOPSIG(returnStatus));
          }
          
          fprintf(stderr, "\n");
          fflush(stderr);
        }
      }
      while (result > 0);
      
      break;
    }
    
    default:
      fprintf(stderr, "watchdog[%i]: caught signal %i\n", getpid(), _signal);
      break;
  }
  signal(_signal, wsignalHandler);
}

static void signalHandler(int _signal) {
  fprintf(stderr, "[%i]: handling signal %i ..\n",
          getpid(), _signal);
  fflush(stderr);
  
  switch (_signal) {
    case SIGPIPE:
      fprintf(stderr, "[%i]: caught signal SIGPIPE\n", getpid());
      break;
      
    default:
      fprintf(stderr, "[%i]: caught signal %i\n", getpid(), _signal);
      break;
  }
  signal(_signal, signalHandler);
}

int WOWatchDogApplicationMain
(NSString *appName, int argc, const char *argv[])
{
  NSAutoreleasePool *pool;
  NSUserDefaults *ud;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  {
    extern char **environ;
    [NSProcessInfo initializeWithArguments:(void*)argv count:argc
                   environment:(void*)environ];
  }
#endif
  
  ud = [NSUserDefaults standardUserDefaults];
  
  /* default is to use the watch dog! */
  /* Note: the Defaults.plist is not yet loaded at this stage! */
  if ([ud objectForKey:@"WOUseWatchDog"] != nil) {
    if (![ud boolForKey:@"WOUseWatchDog"])
      return WOApplicationMain(appName, argc, argv);
  }
  
  /* watch dog */
  {
    int      failCount = 0;
    int      forkCount = 0;
    BOOL     repeat    = YES;
    BOOL     isVerbose = NO;  
    
    isVerbose = [[ud objectForKey:@"watchdog_verbose"] boolValue];
    pidFile   = [[[ud objectForKey:@"watchdog_pidfile"] stringValue] copy];
    
    /* write current pid to pidfile */
    _writePid(pidFile);
    
    /* register exit handler */
    atexit(exitWatchdog);
    
    /* register signal handlers of watch dog */
    signal(SIGPIPE, wsignalHandler);
    signal(SIGCHLD, wsignalHandler);
    signal(SIGINT,  wsignalHandler);
    signal(SIGTERM, wsignalHandler);
    signal(SIGKILL, wsignalHandler);
    signal(SIGHUP,  wsignalHandler);
    
    /* loop */
    
    while (repeat) {
      time_t clientStartTime;
      
      clientStartTime = time(NULL);
      killedChild = NO;
      
      if ((child = fork()) == -1) {
        fprintf(stderr, "[%i]: fork failed: %s\n", getpid(), strerror(errno));
        failCount++;
        
        if (failCount > 5) {
          fprintf(stderr, "  fork failed %i times, sleeping 60 seconds ..\n",
                  failCount);
          sleep(60);
        }
        else {
          sleep(1);
        }
      }
      else {
        if (child == 0) {
          /* child process */
          signal(SIGPIPE, SIG_DFL);
          signal(SIGCHLD, SIG_DFL);
          signal(SIGINT,  SIG_DFL);
          signal(SIGTERM, SIG_DFL);
          signal(SIGKILL, SIG_DFL);
          
          if (isVerbose)
            fprintf(stderr, "starting child %i ..\n", getpid());

          pidFile = [pidFile stringByAppendingPathExtension:@"child"];
          _writePid(pidFile);
          
          atexit(_delPid);
          
          exit(WOApplicationMain(appName, argc, argv));
          
          /* shouldn't even get here ! */
          fprintf(stderr, "internal server error !\n");
          abort();
        }
        else {
          /* parent (watch dog) */
          int      status = 0;
          pid_t    result = 0;
          time_t   clientStopTime;
          unsigned uptime;
          
          forkCount++;
          
          if (isVerbose) {
            fprintf(stderr, "forked child process %i (#%i) ..\n",
                    child, forkCount);
          }
          
          failCount = 0;
          status    = 0;
          
          if ((result = waitpid(child, &status, 0)) == -1) {
            if (killedChild) {
              killedChild = NO;
              continue;
            }
            
            fprintf(stderr,
                    "### waiting for child %i (#%i) failed: %s\n",
                    child, forkCount, strerror(errno));
            continue;
          }

          clientStopTime = time(NULL);
          uptime = clientStopTime - clientStartTime;
          
          if (WIFSIGNALED(status)) {
            fprintf(stderr,
                    "### child %i (#%i) was terminated by signal %i "
                    "(uptime=%ds).\n",
                    child, forkCount, WTERMSIG(status), uptime);
            
            lastFailExit  = time(NULL);
            failExitCount++;
          }
          else if (WIFEXITED(status)) {
            unsigned exitCode;
            
            if ((exitCode = WEXITSTATUS(status)) != 0) {
              time_t now;
              
              now = time(NULL);

              if (uptime < 3) {
                if (failExitCount > 0) {
                  unsigned secsSinceLastFail;
                
                  secsSinceLastFail = (now - lastFailExit);
                
                  if (secsSinceLastFail > 120) {
                    /* reset fail count */
                    failExitCount = 0;
                  }
                  else if (failExitCount > 20) {
                    printf("### child %i (#%i) already failed %i times "
                           "in the last %i seconds, stopping watchdog !\n",
                           child, forkCount, failExitCount, secsSinceLastFail);
                    repeat = NO;
                  }
                }
              }              
              failExitCount++;
              lastFailExit  = now;
              
              fprintf(stderr,
                      "### child %i (#%i) exited with status %i "
                      "(#fails=%i, uptime=%ds).\n",
                      child, forkCount, exitCode, failExitCount, uptime);
            }
            else {
              fprintf(stderr,
                      "### child %i (#%i) exited successfully (uptime=%ds).\n",
                      child, forkCount, uptime);
            }
            
            if (exitCode == 123) // ???
              repeat = NO;
          }
          else {
            fprintf(stderr,
                    "### abnormal termination of child %i (#%i) status=%i"
                    "(was not signaled nor exited).",
                    child, forkCount, status);
          }
        }
      }
    }
    return 0;
  }
}
#endif

/* main function which initializes server defaults (usually in /etc) */

@interface NSUserDefaults(ServerDefaults)
+ (id)hackInServerDefaults:(NSUserDefaults *)_ud
  withAppDomainPath:(NSString *)_appDomainPath
  globalDomainPath:(NSString *)_globalDomainPath;
@end

int WOWatchDogApplicationMainWithServerDefaults
(NSString *appName, int argc, const char *argv[],
 NSString *globalDomainPath, NSString *appDomainPath)
{
  NSAutoreleasePool *pool;
  Class defClass;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  {
    extern char **environ;
    [NSProcessInfo initializeWithArguments:(void*)argv count:argc
                   environment:(void*)environ];
  }
#endif
  
  if ((defClass = NSClassFromString(@"WOServerDefaults")) != nil) {
    NSUserDefaults *ud, *sd;
    
    ud = [NSUserDefaults standardUserDefaults];
    sd = [defClass hackInServerDefaults:ud
                   withAppDomainPath:appDomainPath
                   globalDomainPath:globalDomainPath];

#if 0    
    if (((sd == nil) || (sd == ud)) && (appDomainPath != nil)) {
      NSLog(@"Note: not using server defaults: '%@' "
            @"(not supported on this Foundation)", appDomainPath);
    }
#endif
  }
  
  return WOWatchDogApplicationMain(appName, argc, argv);
}
