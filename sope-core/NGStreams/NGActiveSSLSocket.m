/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2011 Jeroen Dekkers <jeroen@dekkers.ch>

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

#include <NGStreams/NGActiveSSLSocket.h>
#include "common.h"

#if HAVE_GNUTLS
#  include <gnutls/gnutls.h>
#elif HAVE_OPENSSL
#  define id openssl_id
#  include <openssl/ssl.h>
#  include <openssl/err.h>
#  undef id
#endif

@interface NGActiveSocket(UsedPrivates)
- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address;
@end

@implementation NGActiveSSLSocket

#if HAVE_GNUTLS
- (id)initWithDomain:(id<NGSocketDomain>)_domain {
  if ((self = [super initWithDomain:_domain])) {
    //BIO *bio_err;
    static BOOL didGlobalInit = NO;
    int ret;

    if (!didGlobalInit) {
      /* Global system initialization*/
      if (gnutls_global_init()) {
	[self release];
	return nil;
      }

      didGlobalInit = YES;
    }

    ret = gnutls_certificate_allocate_credentials ((gnutls_certificate_credentials_t *) &self->cred);
    if ( ret)
      {
	NSLog(@"ERROR(%s): couldn't create GnuTLS credentials (%s)",
	      __PRETTY_FUNCTION__, gnutls_strerror(ret));
	[self release];
	return nil;
      }

    self->session = NULL;
  }
  return self;
}

- (void)dealloc {
  if (self->session) {
    gnutls_deinit((gnutls_session_t) self->session);
    self->session = NULL;
  }
  if (self->cred) {
    gnutls_certificate_free_credentials((gnutls_certificate_credentials_t) self->cred);
    self->cred = NULL;
  }
  [super dealloc];
}

/* basic IO, reading and writing bytes */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  ssize_t ret;

  if (self->session == NULL)
    // should throw error
    return NGStreamError;


  ret = gnutls_record_recv((gnutls_session_t) self->session, _buf, _len);
  if (ret < 0)
    return NGStreamError;
  else
    return ret;
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  ssize_t ret;

  if (self->session == NULL)
    // should throw error
    return NGStreamError;

  ret = gnutls_record_send((gnutls_session_t) self->session, _buf, _len);
  if (ret < 0)
    return NGStreamError;
  else
    return ret;
}

/* connection and shutdown */

- (BOOL)markNonblockingAfterConnect {
  return NO;
}

- (BOOL) startTLS
{
  int ret;

  ret = gnutls_init((gnutls_session_t *) &self->session, GNUTLS_CLIENT);
  if (ret) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't create GnuTLS session (%s)",
          __PRETTY_FUNCTION__, gnutls_strerror(ret));
    return NO;
  }

  gnutls_priority_set_direct (session, "NORMAL", NULL);

  ret = gnutls_credentials_set((gnutls_session_t) self->session, GNUTLS_CRD_CERTIFICATE, (gnutls_certificate_credentials_t) self->cred);
  if (ret) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't set GnuTLS credentials (%s)",
          __PRETTY_FUNCTION__, gnutls_strerror(ret));
    return NO;
  }

  gnutls_transport_set_ptr((gnutls_session_t) self->session, (gnutls_transport_ptr_t) self->fd);

  ret = gnutls_handshake((gnutls_session_t) self->session);
  if (ret) {
    NSLog(@"ERROR(%s): couldn't setup SSL connection on socket (%s)",
	  __PRETTY_FUNCTION__, gnutls_strerror(ret));
    if (ret == GNUTLS_E_FATAL_ALERT_RECEIVED) {
      NSLog(@"Alert: %s", gnutls_alert_get_name(gnutls_alert_get(self->session)));
    }
    [self shutdown];
    return NO;
  }

  return YES;
}

- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address {
  if (![super primaryConnectToAddress:_address])
    /* could not connect to Unix socket ... */
    return NO;

  return [self startTLS];
}

- (BOOL)shutdown {
  if (self->session) {
    gnutls_deinit((gnutls_session_t) self->session);
    self->session = NULL;
  }
  if (self->cred) {
    gnutls_certificate_free_credentials((gnutls_certificate_credentials_t) self->cred);
    self->cred = NULL;
  }
  return [super shutdown];
}

#elif HAVE_OPENSSL

#if STREAM_BIO
static int streamBIO_bwrite(BIO *, const char *, int) {
}
static int streamBIO_bread(BIO *, char *, int) {
}
static int streamBIO_bputs(BIO *, const char *) {
}
static int streamBIO_bgets(BIO *, char *, int) {
}
static long streamBIO_ctrl(BIO *, int, long, void *) {
}
static int streamBIO_create(BIO *) {
}
static int streamBIO_destroy(BIO *) {
}
static long streamBIO_callback_ctrl(BIO *, int, bio_info_cb *) {
}

static BIO_METHOD streamBIO = {
  0 /* type */,
  "NGActiveSocket" /* name */,
  streamBIO_bwrite,
  streamBIO_bread,
  streamBIO_bputs,
  streamBIO_bgets,
  streamBIO_ctrl,
  streamBIO_create,
  streamBIO_destroy,
  streamBIO_callback_ctrl
};

// create: BIO_new(&streamBIO);

#endif /* STREAM_BIO */

- (id)initWithDomain:(id<NGSocketDomain>)_domain {
  if ((self = [super initWithDomain:_domain])) {
    //BIO *bio_err;
    static BOOL didGlobalInit = NO;
    
    if (!didGlobalInit) {
      /* Global system initialization*/
      SSL_library_init();
      SSL_load_error_strings();
      didGlobalInit = YES;
    }

    /* An error write context */
    //bio_err = BIO_new_fp(stderr, BIO_NOCLOSE);
    
    /* Create our context*/
    
    if ((self->ctx = SSL_CTX_new(SSLv23_method())) == NULL) {
      NSLog(@"ERROR(%s): couldn't create SSL context for v23 method !",
            __PRETTY_FUNCTION__);
      [self release];
      return nil;
    }

    SSL_CTX_set_verify(self->ctx, SSL_VERIFY_NONE, NULL);
  }
  return self;
}

- (void)dealloc {
  if (self->ctx) {
    SSL_CTX_free(self->ctx);
    self->ctx = NULL;
  }
  [super dealloc];
}

/* basic IO, reading and writing bytes */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  if (self->ssl == NULL)
    // should throw error
    return NGStreamError;
  
  return SSL_read(self->ssl, _buf, _len);
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  return SSL_write(self->ssl, _buf, _len);
}

/* connection and shutdown */

- (BOOL)markNonblockingAfterConnect {
  return NO;
}

- (BOOL) startTLS
{
  int ret;

  if (self->ctx == NULL) {
    NSLog(@"ERROR(%s): ctx isn't setup yet !",
          __PRETTY_FUNCTION__);
    return NO;
  }

  if ((self->ssl = SSL_new(self->ctx)) == NULL) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't create SSL socket structure ...",
          __PRETTY_FUNCTION__);
    return NO;
  }

  if (SSL_set_fd(self->ssl, self->fd) <= 0) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't set FD ...",
          __PRETTY_FUNCTION__);
    return NO;
  }
 
  ret = SSL_connect(self->ssl);
  if (ret <= 0) {
    NSLog(@"ERROR(%s): couldn't setup SSL connection on socket (%s)...",
	  __PRETTY_FUNCTION__, ERR_error_string(SSL_get_error(self->ssl, ret), NULL));
    [self shutdown];
    return NO;
  }
  
  return YES;
}

- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address {
  if (self->ctx == NULL) {
    NSLog(@"ERROR(%s): ctx isn't setup yet !",
          __PRETTY_FUNCTION__);
    return NO;
  }

  if ((self->ssl = SSL_new(self->ctx)) == NULL) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't create SSL socket structure ...",
          __PRETTY_FUNCTION__);
    return NO;
  }
  
  if (![super primaryConnectToAddress:_address])
    /* could not connect to Unix socket ... */
    return NO;
  
  /* probably we should create a BIO for streams !!! */
  if ((self->sbio = BIO_new_socket(self->fd, BIO_NOCLOSE)) == NULL) {
    NSLog(@"ERROR(%s): couldn't create SSL socket IO structure ...",
          __PRETTY_FUNCTION__);
    [self shutdown];
    return NO;
  }
  
  NSAssert(self->ctx,  @"missing SSL context ...");
  NSAssert(self->ssl,  @"missing SSL socket ...");
  NSAssert(self->sbio, @"missing SSL BIO ...");
  
  SSL_set_bio(self->ssl, self->sbio, self->sbio);
  if (SSL_connect(self->ssl) <= 0) {
    NSLog(@"ERROR(%s): couldn't setup SSL connection on socket ...",
          __PRETTY_FUNCTION__);
    [self shutdown];
    return NO;
  }
  
  return YES;
}
- (BOOL)shutdown {
  if (self->ctx) {
    SSL_CTX_free(self->ctx);
    self->ctx = NULL;
  }
  return [super shutdown];
}

#else /* no OpenSSL available */

+ (void)initialize {
  NSLog(@"WARNING: The NGActiveSSLSocket class was accessed, "
        @"but OpenSSL support is turned off.");
}
- (id)initWithDomain:(id<NGSocketDomain>)_domain {
  [self release];
  return nil;
}

#endif

@end /* NGActiveSSLSocket */
