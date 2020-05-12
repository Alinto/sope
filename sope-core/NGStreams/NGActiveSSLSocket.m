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

#include <NGStreams/NGActiveSSLSocket.h>
#include "common.h"

#if HAVE_GNUTLS
#  include <gnutls/gnutls.h>
#define LOOP_CHECK(rval, cmd) \
  do { \
    rval = cmd; \
  } while(rval == GNUTLS_E_AGAIN || rval == GNUTLS_E_INTERRUPTED);
#elif HAVE_OPENSSL
#  define id openssl_id
#  include <openssl/ssl.h>
#  include <openssl/err.h>
#  include <openssl/x509v3.h>
#  undef id
#endif

@interface NGActiveSocket(UsedPrivates)
- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address;
@end

@implementation NGActiveSSLSocket

- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address {

  if (![super primaryConnectToAddress:_address])
    /* could not connect to Unix socket ... */
    return NO;

  return [self startTLS];
}

+ (id) socketConnectedToAddress: (id<NGSocketAddress>) _address
                  onHostName: (NSString *) _hostName
{
  id sock = [[self alloc] initWithDomain:[_address domain]
                      onHostName: _hostName];
  if (![sock connectToAddress:_address]) {
    NSException *e;
    e = [[sock lastException] retain];
    [self release];
    e = [e autorelease];
    [e raise];
    return nil;
  }
  sock = [sock autorelease];
  return sock;
}

#if HAVE_GNUTLS
- (id)initWithDomain:(id<NGSocketDomain>)_domain
      onHostName: (NSString *)_hostName
{
  hostName = [_hostName copy];
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

    ret = gnutls_certificate_allocate_credentials((gnutls_certificate_credentials_t *) &self->cred);
    if (ret)
      {
        NSLog(@"ERROR(%s): couldn't create GnuTLS credentials (%s)",
              __PRETTY_FUNCTION__, gnutls_strerror(ret));
        [self release];
        return nil;
      }

    ret = gnutls_certificate_set_x509_system_trust(self->cred);
    if (ret)
      {
        NSLog(@"ERROR(%s): could not set GnuTLS system trust (%s)",
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
  [hostName release];
  [super dealloc];
}

/* basic IO, reading and writing bytes */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  ssize_t ret;

  if (self->session == NULL)
    // should throw error
    return NGStreamError;


  LOOP_CHECK(ret, gnutls_record_recv((gnutls_session_t) self->session, _buf, _len));
  if (ret <= 0)
    return NGStreamError;
  else
    return ret;
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  ssize_t ret;

  if (self->session == NULL)
    // should throw error
    return NGStreamError;

  LOOP_CHECK(ret, gnutls_record_send((gnutls_session_t) self->session, _buf, _len));
  if (ret <= 0)
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
  gnutls_session_t sess;

  [self disableNagle: YES];

  ret = gnutls_init((gnutls_session_t *) &self->session, GNUTLS_CLIENT);
  if (ret) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't create GnuTLS session (%s)",
          __PRETTY_FUNCTION__, gnutls_strerror(ret));
    return NO;
  }
  sess = (gnutls_session_t) self->session;

  gnutls_set_default_priority(sess);

  ret = gnutls_credentials_set(sess, GNUTLS_CRD_CERTIFICATE, (gnutls_certificate_credentials_t) self->cred);
  if (ret) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't set GnuTLS credentials (%s)",
          __PRETTY_FUNCTION__, gnutls_strerror(ret));
    return NO;
  }

  // set SNI
  ret = gnutls_server_name_set(sess, GNUTLS_NAME_DNS, [hostName UTF8String], [hostName length]);
  if (ret) {
    // should set exception !
    NSLog(@"ERROR(%s): couldn't set GnuTLS SNI (%s)",
          __PRETTY_FUNCTION__, gnutls_strerror(ret));
    return NO;
  }

  gnutls_session_set_verify_cert(sess, [hostName UTF8String], 0);

#if GNUTLS_VERSION_NUMBER < 0x030109
  gnutls_transport_set_ptr(sess, (gnutls_transport_ptr_t)(long)self->fd);
#else
  gnutls_transport_set_int(sess, self->fd);
#endif /* GNUTLS_VERSION_NUMBER < 0x030109 */

  gnutls_handshake_set_timeout(sess, GNUTLS_DEFAULT_HANDSHAKE_TIMEOUT);
  do {
    ret = gnutls_handshake(sess);
  } while (ret < 0 && gnutls_error_is_fatal(ret) == 0);

  if (ret < 0) {
    NSLog(@"ERROR(%s):GnutTLS handshake failed on socket (%s)",
      __PRETTY_FUNCTION__, gnutls_strerror(ret));
    if (ret == GNUTLS_E_FATAL_ALERT_RECEIVED) {
      NSLog(@"Alert: %s", gnutls_alert_get_name(gnutls_alert_get(sess)));
    }
    [self shutdown];
    return NO;
  }

  return YES;
}

- (BOOL)shutdown {

  if (self->session) {
    int ret;
    LOOP_CHECK(ret, gnutls_bye((gnutls_session_t)self->session, GNUTLS_SHUT_RDWR));
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

- (id)initWithDomain:(id<NGSocketDomain>)_domain
          onHostName: (NSString *)_hostName
{

  hostName = [_hostName copy];
  if ((self = [super initWithDomain:_domain])) {
    //BIO *bio_err;

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    static BOOL didGlobalInit = NO;
    if (!didGlobalInit) {
      /* Global system initialization*/
      SSL_library_init();
      SSL_load_error_strings();
      didGlobalInit = YES;
    }
#endif /* OPENSSL_VERSION_NUMBER */


    /* Create our context*/
    if ((self->ctx = SSL_CTX_new(SSLv23_method())) == NULL) {
      NSLog(@"ERROR(%s): couldn't create SSL context for v23 method !",
            __PRETTY_FUNCTION__);
      [self release];
      return nil;
    }
    // use system default trust store
    SSL_CTX_set_default_verify_paths(self->ctx);

    if ((self->ssl = SSL_new(self->ctx)) == NULL) {
      // should set exception !
      NSLog(@"ERROR(%s): couldn't create SSL socket structure ...",
            __PRETTY_FUNCTION__);
      return nil;
    }
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    X509_VERIFY_PARAM *param = NULL;
    param = SSL_get0_param(self->ssl);
    X509_VERIFY_PARAM_set_hostflags(param, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
    if (!X509_VERIFY_PARAM_set1_host(param, [hostName UTF8String], 0)) {
      return nil;
    }
#else
    SSL_set1_host(self->ssl, [hostName UTF8String]);
#endif /* OPENSSL_VERSION_NUMBER < 0x10100000L */

    // send SNI
    SSL_set_tlsext_host_name(self->ssl, [hostName UTF8String]);
    // verify the peer
    SSL_set_verify(self->ssl, SSL_VERIFY_PEER, NULL);

  }
  return self;
}

- (void)dealloc {
  [self shutdown];
  [hostName release];
  [super dealloc];
}

/* basic IO, reading and writing bytes */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  int ret;

  if (self->ssl == NULL)
    // should throw error
    return NGStreamError;

  ret = SSL_read(self->ssl, _buf, _len);

  if (ret <= 0)
    return NGStreamError;

  return ret;
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

  [self disableNagle: YES];

  if (self->ssl == NULL) {
    NSLog(@"ERROR(%s): SSL structure is not set up!",
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
    NSLog(@"ERROR(%s): couldn't setup SSL connection on host %@ (%s)...",
      __PRETTY_FUNCTION__, hostName, ERR_error_string(SSL_get_error(self->ssl, ret), NULL));
    [self shutdown];
    return NO;
  }

  return YES;
}

- (BOOL)shutdown {
  if (self->ssl) {
    int ret = SSL_shutdown(self->ssl);
    // call shutdown a second time
    if (ret == 0)
      SSL_shutdown(self->ssl);
    SSL_free(self->ssl);
    self->ssl = NULL;
  }
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
