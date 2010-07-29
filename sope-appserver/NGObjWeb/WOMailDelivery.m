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

#include <NGObjWeb/WOMailDelivery.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation WOMailDelivery

+ (int)version {
  return 2;
}

WOMailDelivery *sharedInstance = nil;

+ (id)sharedInstance {
  if (sharedInstance == nil)
    sharedInstance = [[WOMailDelivery alloc] init];
  return sharedInstance;
}

// composing mails

- (id)composeEmailFrom:(NSString *)_senderAddress
  to:(NSArray *)_receiverAddresses
  cc:(NSArray *)_ccAddresses
  subject:(NSString *)_subject
  plainText:(NSString *)_text
  send:(BOOL)_sendFlag
{
  NSMutableDictionary *email = [NSMutableDictionary dictionaryWithCapacity:16];
  NSData *content;

  if (_senderAddress == nil)          return nil;
  if ([_receiverAddresses count] < 1) return nil;
  
  if (_subject == nil)     _subject = @"";
  if (_text == nil)        _text    = @"";
  if (_ccAddresses == nil) _ccAddresses = [NSArray array];
  
  [email setObject:_subject           forKey:@"subject"];
  [email setObject:_receiverAddresses forKey:@"to"];
  [email setObject:_ccAddresses       forKey:@"cc"];
  [email setObject:_senderAddress     forKey:@"from"];
  [email setObject:@"text/plain; charset=us-ascii" forKey:@"content-type"];

  content = [NSData dataWithBytes:[_text cString] length:[_text cStringLength]];
  [email setObject:content forKey:@"body"];
  [email setObject:[NSNumber numberWithInt:[content length]]
         forKey:@"content-length"];

  if (_sendFlag) {
    if (![self sendEmail:email])
      return nil;
  }
  return email;
}

- (id)composeEmailFrom:(NSString *)_senderAddress
  to:(NSArray *)_receiverAddresses
  cc:(NSArray *)_ccAddresses
  subject:(NSString *)_subject
  component:(WOComponent *)_component
  send:(BOOL)_sendFlag
{
  NSMutableDictionary *email = [NSMutableDictionary dictionaryWithCapacity:16];

  if (_senderAddress == nil)          return nil;
  if ([_receiverAddresses count] < 1) return nil;
  if (_subject     == nil) _subject = @"";
  if (_ccAddresses == nil) _ccAddresses = [NSArray array];

  [email setObject:_subject           forKey:@"subject"];
  [email setObject:_receiverAddresses forKey:@"to"];
  [email setObject:_ccAddresses       forKey:@"cc"];
  [email setObject:_senderAddress     forKey:@"from"];

  /* gen response */
  {
    WOResponse *response;
    NSString   *contentType;

    response = [_component generateResponse];
    if ([response status] != 200)
      // could not generate response
      return nil;

    contentType = [response headerForKey:@"content-type"];
    if (contentType == nil) contentType = @"text/html";
    
    [email setObject:contentType forKey:@"content-type"];
    [email setObject:[response content] forKey:@"body"];
    [email setObject:[NSNumber numberWithInt:[[response content] length]]
           forKey:@"content-length"];
  }

  if (_sendFlag) {
    if (![self sendEmail:email])
      return nil;
  }
  return email;
}

// sending mails

- (BOOL)sendEmail:(id)_email {
  NSMutableString *sendmail = [NSMutableString stringWithCapacity:256];
  NSArray *to, *cc;
  FILE *toMail;

  to = [(NSDictionary *)_email objectForKey:@"to"];
  cc = [(NSDictionary *)_email objectForKey:@"cc"];

  [sendmail appendString:[[NSUserDefaults standardUserDefaults]
                                          stringForKey:@"WOSendMail"]];
  [sendmail appendString:@" "];
  [sendmail appendString:[to componentsJoinedByString:@" "]];
  [sendmail appendString:@" "];
  [sendmail appendString:[cc componentsJoinedByString:@" "]];

  if ((toMail = popen([sendmail cString], "w")) != NULL) {
    NSEnumerator *e = nil;
    id entry;
    NSString *tmp;
    
    if ((tmp = [[(NSDictionary *)_email objectForKey:@"from"] stringValue])) {
      if (fprintf(toMail, "Reply-To: %s\r\n", [tmp cString]) < 0)
        goto failed;
      if (fprintf(toMail, "From: %s\r\n", [tmp cString]) < 0)
        goto failed;
    }
    
    e = [to objectEnumerator];
    while ((entry = [e nextObject]) != nil) {
      if (fprintf(toMail, "To:%s\r\n", [[entry stringValue] cString]) < 0)
        goto failed;
    }

    e = [cc objectEnumerator];
    while ((entry = [e nextObject]) != nil) {
      if (fprintf(toMail, "Cc:%s\r\n", [[entry stringValue] cString]) < 0)
        goto failed;
    }
    
    if ((tmp = [[(NSDictionary *)_email objectForKey:@"subject"] stringValue])) {
      if (fprintf(toMail, "Subject:%s\r\n", [tmp cString]) < 0)
        goto failed;
    }

    if ((tmp = [[(NSDictionary *)_email objectForKey:@"content-type"] stringValue])) {
      if (fprintf(toMail, "Content-type:%s\r\n", [tmp cString]) < 0)
        goto failed;
    }
    if ((tmp = [[(NSDictionary *)_email objectForKey:@"content-length"] stringValue])) {
      if (fprintf(toMail, "Content-length:%s\r\n", [tmp cString]) < 0)
        goto failed;
    }
    
    /* end header */
    if (fprintf(toMail, "\r\n") < 0)
      goto failed;

    /* write body */
    {
      NSData *body;
      
      body = [(NSDictionary *)_email objectForKey:@"body"];
      if (fwrite([body bytes], [body length], 1, toMail) < 0)
        goto failed;
    }
    fprintf(toMail, "\r\n");
    pclose(toMail);

    return YES;

  failed:
    pclose(toMail);
    return NO;
  }
  return NO;
}

@end /* WOMailDelivery */
