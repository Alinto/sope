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

#ifndef __NGExtensions_NSException_misc_H__
#define __NGExtensions_NSException_misc_H__

#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>

/*
  Miscellaneous method additions to NSException

  the additions make it easier using exceptions in the Java way. In OpenStep
  exceptions are identified by their name, subclasses are mainly used when
  additional information needs to be stored. This works well as long as you do
  not use exceptions very much (as in the Foundation Kit) - if you do you
  soon wish to have a 'hierachy' of exceptions. This can be modelled - like in
  Java - using a subclass for each different kind of exception and then using
  the type of the exception for it's identification. This is supported by
  libFoundation using the TRY and CATCH macros.

  The methods below always use the class name as the exception name if the name
  isn't specified explicitly.
*/

@interface NSException(NGMiscellaneous)

- (id)initWithReason:(NSString *)_reason;
- (id)initWithReason:(NSString *)_reason userInfo:(id)_userInfo;
- (id)initWithFormat:(NSString *)_format,...;

@end

@interface NSObject(NSExceptionNGMiscellaneous)
- (BOOL)isException;
- (BOOL)isExceptionOrNull;
@end


#if COCOA_Foundation_LIBRARY || GNUSTEP_BASE_LIBRARY
@interface NSException (NGLibFoundationCompatibility)
- (void)setReason:(NSString *)_reason;
@end
#endif


/*
  The following macros are for use of locks together with exception handling.
  A synchronized block is properly 'unlocked' even if an exception occures.
  It is used this way:

    SYNCHRONIZED(MyObject) {
      THROW(MyException..);
    }
    END_SYNCHRONIZED;

  Where MyObject must be an object that conforms to the NSObject and NSLocking
  protocol.
  This is much different to

    [MyObject lock];
    {
      THROW(MyException..);
    }
    [MyObject unlock];

  which leaves the lock locked when an exception happens.
*/

#if defined(DEBUG_SYNCHRONIZED)

#define SYNCHRONIZED(__lock__) \
  { \
    id<NSObject,NSLocking> __syncLock__ = [__lock__ retain]; \
    [__syncLock__ lock]; \
    fprintf(stderr, "0x%08X locked in %s.\n", \
            (unsigned)__syncLock__, __PRETTY_FUNCTION__); \
    NS_DURING {

#define END_SYNCHRONIZED \
    } \
    NS_HANDLER { \
      fprintf(stderr, "0x%08X exceptional unlock in %s exception %s.\n", \
              (unsigned)__syncLock__, __PRETTY_FUNCTION__,\
              [[localException description] cString]); \
      [__syncLock__ unlock]; \
      [__syncLock__ release]; __syncLock__ = nil; \
      [localException raise]; \
    } \
    NS_ENDHANDLER; \
    fprintf(stderr, "0x%08X unlock in %s.\n", \
            (unsigned)__syncLock__, __PRETTY_FUNCTION__); \
    [__syncLock__ unlock]; \
    [__syncLock__ release];  __syncLock__ = nil; \
  }

#else

#define SYNCHRONIZED(__lock__) \
  { \
    id<NSObject,NSLocking> __syncLock__ = [__lock__ retain]; \
    [__syncLock__ lock]; \
    NS_DURING {

#define END_SYNCHRONIZED \
    } \
    NS_HANDLER { \
      [__syncLock__ unlock]; \
      [__syncLock__ release]; \
      [localException raise]; \
    } \
    NS_ENDHANDLER; \
    [__syncLock__ unlock]; \
    [__syncLock__ release]; \
  }

#endif

#endif /* __NGExtensions_NSException_misc_H__ */
