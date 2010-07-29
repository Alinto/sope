/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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
// $Id$

#ifndef __SxComponent_Exception_H__
#define __SxComponent_Exception_H__

#import <Foundation/NSException.h>

@class SxComponentInvocation;

@interface NSException(SxComponentExceptionTyping)
- (BOOL)isCredentialsRequiredException;
@end

@interface SxComponentException : NSException
@end

@interface SxAuthException : SxComponentException
{
  id credentials;
  SxComponentInvocation *invocation;
}

/* accessors */

- (void)setCredentials:(id)_credentials;
- (id)credentials;

- (void)setInvocation:(SxComponentInvocation *)_invocation;
- (SxComponentInvocation *)invocation;

@end

@interface SxMissingCredentialsException : SxAuthException
@end

@interface SxInvalidCredentialsException : SxAuthException
@end

#endif /* __SxComponent_Exception_H__ */
