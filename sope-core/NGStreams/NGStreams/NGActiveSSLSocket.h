/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2011 Jeroen Dekkers <jeroen@dekkers.ch>
  Copyright (C) 2020 Nicolas Höft

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
#ifndef __NGNet_NGActiveSSLSocket_H__
#define __NGNet_NGActiveSSLSocket_H__

#import <NGStreams/NGSocketProtocols.h>
#include <NGStreams/NGActiveSocket.h>
#include "../config.h"

@interface NGActiveSSLSocket : NGActiveSocket
{
@protected
#ifdef HAVE_GNUTLS
  void *cred; /* real type: gnutls_certificate_credentials_t */
  void *session; /* real type: gnutls_session_t */
#else
  void *ctx;   /* real type: SSL_CTX */
  void *ssl;   /* real type: SSL */
#endif
  NSString *hostName;
}
+ (id) socketConnectedToAddress: (id<NGSocketAddress>) _address
                  onHostName: (NSString *) hostName;

- (id)initWithDomain:(id<NGSocketDomain>)_domain
      onHostName: (NSString *)_hostName;

- (BOOL) startTLS;
@end

#endif /* __NGNet_NGActiveSSLSocket_H__ */
