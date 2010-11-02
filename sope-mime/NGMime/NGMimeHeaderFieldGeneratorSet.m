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

#include "NGMimeHeaderFieldGenerator.h"
#include "NGMimeHeaderFields.h"
#include "NGMimePartParser.h"
#include "common.h"

@implementation NGMimeHeaderFieldGeneratorSet

+ (int)version {
  return 2;
}

static NGMimeHeaderFieldGeneratorSet *rfc822Set = nil;

+ (id)headerFieldGenerator {
  return [[[self alloc] init] autorelease];
}

+ (id)headerFieldGeneratorSet {
  return [[[self alloc] init] autorelease];
}

+ (id)defaultRfc822HeaderFieldGeneratorSet {
  static NGMimeHeaderNames *Fields = NULL;
  id gen;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
                    
  if (rfc822Set)
    return rfc822Set;
  
  rfc822Set = [[self alloc] init];

  gen = [NGMimeContentDispositionHeaderFieldGenerator headerFieldGenerator];
  if (gen)
    [rfc822Set setGenerator:gen forField:Fields->contentDisposition];
  
  if ((gen = [NGMimeContentLengthHeaderFieldGenerator headerFieldGenerator]))
    [rfc822Set setGenerator:gen forField:Fields->contentLength];
  if ((gen = [NGMimeContentTypeHeaderFieldGenerator headerFieldGenerator]))
    [rfc822Set setGenerator:gen forField:Fields->contentType];
  if ((gen = [NGMimeRFC822DateHeaderFieldGenerator headerFieldGenerator]))
    [rfc822Set setGenerator:gen forField:Fields->date];
  
  if ((gen = [NGMimeAddressHeaderFieldGenerator headerFieldGenerator])) {
    /* FIXME - following additional fields containing an address may be added here:
     * - sender (RFC 2822, sect. 3.6.2)
     * - resent-sender, resent-cc, resent-bcc (RFC 2822, sect. 3.6.6)
     * Are the values case-insensitive, so "Reply-To" and "reply-to" will both
     * be detected?
     */
    [rfc822Set setGenerator:gen forField:@"resent-from"];
    [rfc822Set setGenerator:gen forField:@"resent-to"];
    [rfc822Set setGenerator:gen forField:Fields->to];
    [rfc822Set setGenerator:gen forField:Fields->cc];
    [rfc822Set setGenerator:gen forField:@"bcc"];
    [rfc822Set setGenerator:gen forField:Fields->from];
    [rfc822Set setGenerator:gen forField:@"reply-to"];
    [rfc822Set setGenerator:gen forField:@"Disposition-Notification-To"];
  }
  
  if ((gen = [NGMimeStringHeaderFieldGenerator headerFieldGenerator]))
    [rfc822Set setDefaultGenerator:gen];
  
  return rfc822Set;
}

- (id)init {
  return [self initWithDefaultGenerator:nil];
}

- (id)initWithDefaultGenerator:(id<NGMimeHeaderFieldGenerator>)_gen {
  if ((self = [super init])) {
    self->fieldNameToGenerate =
      [[NSMutableDictionary allocWithZone:[self zone]]
                            initWithCapacity:16];
    self->defaultGenerator = [_gen retain];
  }
  return self;
}

- (void)dealloc {
  [self->fieldNameToGenerate release];
  [self->defaultGenerator    release];
  [super dealloc];
}

/* accessors */

- (void)setGenerator:(id<NGMimeHeaderFieldGenerator>)_gen
  forField:(NSString *)_name
{
  [self->fieldNameToGenerate setObject:_gen forKey:_name];
}

- (void)setDefaultGenerator:(id<NGMimeHeaderFieldGenerator>)_gen {
  ASSIGN(self->defaultGenerator, _gen);
}

- (id<NGMimeHeaderFieldGenerator>)_gen {
  return self->defaultGenerator;
}

/* operation */

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  NGMimeHeaderFieldGenerator *gen = nil;
  
  if ((gen = [self->fieldNameToGenerate objectForKey:_headerField]) == nil)
    gen = (NGMimeHeaderFieldGenerator *)self->defaultGenerator;
  
  if (gen == nil) {
    NSLog(@"WARNING(%s): no defaultGenerator is set", __PRETTY_FUNCTION__);
    return [NSData data];
  }
  return [gen generateDataForHeaderFieldNamed:_headerField
              value:_value];
}

@end /* NGMimeHeaderFieldGeneratorSet */
