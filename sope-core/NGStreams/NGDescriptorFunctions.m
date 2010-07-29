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

#if !defined(WIN32) || defined(__CYGWIN32__)

// similiar functions for Windows can be found in NGSocket.[hm]

#include "NGDescriptorFunctions.h"
#include "NGStreamExceptions.h"
#include "common.h"
#include "config.h"

#ifdef HAVE_POLL
#  ifdef HAVE_POLL_H
#    include <poll.h>
#  endif
#  ifdef HAVE_SYS_POLL_H
#    include <sys/poll.h>
#  endif
#  ifndef POLLRDNORM
#    define POLLRDNORM POLLIN /* needed on Linux */
#  endif
#else
#  ifdef HAVE_SELECT_H
#    include <select.h>
#  endif
#endif

#if defined(HAVE_SYS_SOCKET_H) || defined(__APPLE__)
#  include <sys/socket.h>
#endif

#ifdef HAVE_SYS_FCNTL_H
#  include <sys/fcntl.h>
#endif
#if defined(HAVE_FCNTL_H) || defined(__APPLE__)
#  include <fcntl.h>
#endif

#if HAVE_UNISTD_H || defined(__APPLE__)
#  include <unistd.h>
#endif
#if HAVE_LIMITS_H
#  include <limits.h>
#endif
#if HAVE_SYS_TIME_H || defined(__APPLE__)
#  include <sys/time.h>
#endif
#if HAVE_SYS_TYPES_H || defined(__APPLE__)
#  include <sys/types.h>
#endif

#if !HAVE_TTYNAME_R
#  if LIB_FOUNDATION_LIBRARY
extern NSRecursiveLock *libFoundationLock = nil;
#    define systemLock libFoundationLock
#  else
#    ifndef __APPLE__
#      warning "No locking support for ttyname on this platform"
#    endif
#    define systemLock (id)nil
#  endif
#endif

// ******************** Poll *********************

int NGPollDescriptor(int _fd, short _events, int _timeout) {
#ifdef HAVE_POLL
  struct pollfd pfd;
  int           result;

  pfd.fd      = _fd;
  pfd.events  = _events;
  pfd.revents = 0;

  do {
    result = poll(&pfd, 1, _timeout);

    if (result < 0) { // error
      int e = errno;

      if (e == 0) {
        NSLog(@"%s: errno is 0, but return value of poll is <0 (%i) (retry) ?!",
              __PRETTY_FUNCTION__, result);
        continue;
      }

      if ((e != EAGAIN) && (e != EINTR)) 
        // only retry of interrupted or repeatable
        break;
    }
  }
  while (result < 0);

  /* revents: POLLERR POLLHUP POLLNVAL */

  return (result < 0) ? -1 : result;
#else
  struct timeval timeout;
  fd_set rSet;
  fd_set wSet;
  fd_set eSet;
  int    result;
  FD_ZERO(&rSet);
  FD_ZERO(&wSet);
  FD_ZERO(&eSet);

  if (_events & POLLIN)  FD_SET(_fd, &rSet);
  if (_events & POLLOUT) FD_SET(_fd, &wSet);
  if (_events & POLLERR) FD_SET(_fd, &eSet);

  timeout.tv_sec  = _timeout / 1000;
  timeout.tv_usec = _timeout * 1000 - timeout.tv_sec * 1000000;

  do {
    result = select(FD_SETSIZE, &rSet, &wSet, &eSet, &timeout);
    if (result == -1) { // error
      int e = errno;
      if ((e != EAGAIN) && (e != EINTR)) 
        // only retry of interrupted or repeatable
        break;
    }
  }
  while (result == -1);

  return (result < 0) ? -1 : result;
#endif
}

// ******************** Flags ********************

int NGGetDescriptorFlags(int _fd) {
  int val;

  val = fcntl(_fd, F_GETFL, 0);
  if (val < 0)
    [NGIOException raiseWithReason:@"could not get descriptor flags"];
  return val;
}
void NGSetDescriptorFlags(int _fd, int _flags) {
  if (fcntl(_fd, F_SETFL, _flags) == -1)
    [NGIOException raiseWithReason:@"could not set descriptor flags"];
}

void NGAddDescriptorFlag(int _fd, int _flag) {
  int val = NGGetDescriptorFlags(_fd);
  NGSetDescriptorFlags(_fd, val | _flag);
}

// ******************** NonBlocking IO ************

static int enableDescLogging = -1;

int NGDescriptorRecv(int _fd, char *_buf, int _len, int _flags, int _timeout /* in ms */) {
  int errorCode;
  int result;

  if (enableDescLogging == -1) {
    enableDescLogging = 
      [[[NSUserDefaults standardUserDefaults] 
	 objectForKey:@"NGLogDescriptorRecv"] boolValue] ? YES : NO;
  }
  
  if (enableDescLogging) {
    NSLog(@"%s(fd=%i,buf=0x%p,len=%i,flags=%i,timeout=%i)", 
	  __PRETTY_FUNCTION__, _fd,_buf,_len,_flags,_timeout);
  }
  
  if (_timeout == -1)
    _timeout = 1000 * 60 * 60; /* default timeout: 1 hour */
  
  result = recv(_fd, _buf, _len, _flags);
  errorCode = errno;
  if (result == 0) return 0; // EOF
  
  if (enableDescLogging) {
    if ((result < 0) && (errorCode == EINVAL)) {
      NSLog(@"%s: invalid argument in recv(%i, 0x%p, %i, %i)",
	    __PRETTY_FUNCTION__, _fd, _buf, _len, _flags);
    }
  }
  
  if (enableDescLogging) {
    NSLog(@"result=%i, error=%i(%s)", result, errorCode, strerror(errorCode));
  }
  
  if ((result == -1) && (errorCode == EWOULDBLOCK)) { // retry
#if HAVE_POLL
    struct pollfd pfd;
    pfd.fd      = _fd;
    pfd.events  = POLLRDNORM;
    pfd.revents = 0;
    
    do {
      if (enableDescLogging) NSLog(@"starting poll, loop (to=%i)", _timeout);
      
      if ((result = poll(&pfd, 1, _timeout)) < 0) {
        errorCode = errno;
        
	if (enableDescLogging) {
	  if (errno == EINVAL)
	    NSLog(@"%s: invalid argument to poll(...)", __PRETTY_FUNCTION__);
	}
        
        if (errorCode == 0) {
          NSLog(@"%s: errno is 0, but return value of poll is <0 (%i) (retry) ?!",
                __PRETTY_FUNCTION__, result);
          continue;
        }
        
        // retry if interrupted
        if ((errorCode != EINTR) && (errorCode != EAGAIN)) 
          break;
      }
    }
    while (result < 0);
#else
    struct timeval timeout;
    fd_set rSet;
    fd_set wSet;
    fd_set eSet;
    FD_ZERO(&rSet);
    FD_ZERO(&wSet);
    FD_ZERO(&eSet);

    FD_SET(_fd, &rSet);
    
    timeout.tv_sec  = _timeout / 1000;
    timeout.tv_usec = _timeout * 1000 - timeout.tv_sec * 1000000;
    
    do {
      result = select(FD_SETSIZE, &rSet, &wSet, &eSet, &timeout);
      if (enableDescLogging) {
	if ((result < 0) && (errno == EINVAL))
	  NSLog(@"%s: invalid argument in select(...)", __PRETTY_FUNCTION__);
      }
      
      if (result == -1) { // error
        int e = errno;
        if ((e != EAGAIN) && (e != EINTR)) 
          // only retry of interrupted or repeatable
          break;
      }
    }
    while (result == -1);
#endif
    
    if (result == 1) { // data waiting, try to read
      if (enableDescLogging) NSLog(@"receiving data ...");
      
      result = recv(_fd, _buf, _len, _flags);
      if (result == 0)
        return 0; // EOF
      else if (result == -1) {
        errorCode = errno;

        if (errorCode == EWOULDBLOCK)
          NSLog(@"WARNING: would block although descriptor was polled ..");
      }
    }
    else if (result == 0) {
      if (enableDescLogging) {
	NSLog(@"nonblock: recv on %i timed out after %i milliseconds ..",
	      _fd, _timeout);
      }
      result = -2;
    }
    else
      result = -1;
  }

  return result;
}

int NGDescriptorSend
(int _fd, const char *_buf, int _len, int _flags, int _timeout) 
{
  int errorCode;
  int result;

  result = send(_fd, _buf, _len, _flags);
  if (result == 0) return 0; // EOF

  errorCode = errno;

  if ((result == -1) && (errorCode == EWOULDBLOCK)) { // retry
#if HAVE_POLL
    struct pollfd pfd;
    pfd.fd      = _fd;
    pfd.events  = POLLWRNORM;
    pfd.revents = 0;
    
    do {
      if ((result = poll(&pfd, 1, _timeout)) < 0) {
        errorCode = errno;

        if (errorCode == 0) {
          NSLog(@"%s: errno is 0, but return value of poll is <0 (%i) (retry) ?!",
                __PRETTY_FUNCTION__, result);
          continue;
        }
        
        if (errorCode != EINTR) // retry only if interrupted
          break;
      }
    }
    while (result < 0);
#else
    struct timeval timeout;
    fd_set rSet;
    fd_set wSet;
    fd_set eSet;
    FD_ZERO(&rSet);
    FD_ZERO(&wSet);
    FD_ZERO(&eSet);

    FD_SET(_fd, &wSet);
    
    timeout.tv_sec  = _timeout / 1000;
    timeout.tv_usec = _timeout * 1000 - timeout.tv_sec * 1000000;

    do {
      result = select(FD_SETSIZE, &rSet, &wSet, &eSet, &timeout);
      if (result == -1) { // error
        int e = errno;
        if ((e != EAGAIN) && (e != EINTR)) 
          // only retry of interrupted or repeatable
          break;
      }
    }
    while (result == -1);
#endif

    if (result == 1) { // data waiting, try to read
      result = send(_fd, _buf, _len, _flags);
      if (result == 0) return 0; // EOF
    }
    else if (result == 0) {
      NSLog(@"nonblock: send on %i timed out after %i milliseconds ..",
             _fd, _timeout);
      result = -2;
    }
    else
      result = -1;
  }

  return result;
}

// ******************** TTY *********************

/*
  Check whether the descriptor is associated to a terminal device.
  Get the name of the associated terminal device.
*/

BOOL NGDescriptorIsAtty(int _fd) {
#if HAVE_ISATTY
  return isatty(_fd) == 1 ? YES : NO;
#else
  return NO;
#endif
}

NSString *NGDescriptorGetTtyName(int _fd) {
#if HAVE_ISATTY
  if (isatty(_fd) != 1) // not connected to a terminal device ?
    return nil;
#endif
  {
#if HAVE_TTYNAME_R
#  ifndef sparc
   extern int ttyname_r(int, char*, size_t);
#  endif
#  ifdef _POSIX_PATH_MAX
    char namebuffer[_POSIX_PATH_MAX + 128];
#  else
    char namebuffer[4096];
#  endif

    if (ttyname_r(_fd, namebuffer, sizeof(namebuffer)))
      return [NSString stringWithCString:namebuffer];
    
#elif HAVE_TTYNAME
    char     *result = NULL;
    NSString *str    = nil;
    int      errCode = 0;

    [systemLock lock];
    {
      result  = ttyname(_fd);
      errCode = errno;
      if (result) str = [NSString stringWithCString:result];
    }
    [systemLock unlock];
    
    if (str) return str;
#endif
  }
  return nil;
}

#endif // WIN32
