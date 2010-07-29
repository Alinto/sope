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

#ifndef __NGImap4Message_BodyStructure_H__
#define __NGImap4Message_BodyStructure_H__

@interface NSCalendarDate(RFC822Dates)
+ (NSCalendarDate *)calendarDateWithRfc822DateString:(NSString *)_str;
@end /* NSString(RFC822Dates) */

@interface NGImap4Message(BodyStructure)

static id _buildMultipartMessage(id self, NSURL *_baseUrl, NSDictionary *_dict,
                                 id<NGMimePart>_part);
static id _buildMessage(id self, NSURL *_baseUrl, NSDictionary *_dict);
static id _buildPart(id self, NSURL *_baseUrl, NSDictionary *_dict);
static id _buildMimeBodyPart(id self, NSDictionary *_dict);
static id _buildMimeMessageBody(id self, NSURL *_baseUrl, NSDictionary *_dict,
                                id<NGMimePart>_part);
@end  /* NGImap4Message(BodyStructure) */

@implementation NGImap4Message(BodyStructure)
       
static id _buildMultipartMessage(id self, NSURL *_baseUrl, NSDictionary *_dict,
                                 id<NGMimePart>_part) {
  NGMimeMultipartBody *body;
  NSEnumerator        *enumerator;
  NSDictionary        *part;
  int                 cnt;
  
  body = [[NGMimeMultipartBody alloc] initWithPart:_part];
  enumerator = [[_dict objectForKey:@"parts"] objectEnumerator];

  cnt = 1;
  while ((part = [enumerator nextObject])) {
    NSURL *url;

    {
      NSString *baseStr;

      baseStr = [_baseUrl absoluteString];

      if ([baseStr hasSuffix:@"="])
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%d",
                                             baseStr, cnt]];
      else
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@.%d",
                                             baseStr, cnt]];
    }
    [body addBodyPart:_buildPart(self, url, part)];
    cnt++;
  }
  return [body autorelease];
}

static id _buildMessage(id self, NSURL *_baseUrl, NSDictionary *_dict) {
  NGMutableHashMap *map;
  NGMimeMessage    *message;
  NSString         *value;

  static NGMimeHeaderNames *Fields = NULL;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  

  map = [NGMutableHashMap hashMapWithCapacity:4];

  if ([(value = [_dict objectForKey:@"subject"]) isNotNull])
    [map setObject:value forKey:Fields->subject];
  
  if ([(value = [_dict objectForKey:@"messageId"]) isNotNull])
    [map setObject:value forKey:Fields->messageID];
  
  if ([(value = [_dict objectForKey:@"in-reply-to"]) isNotNull])
    [map setObject:value forKey:@"in-reply-to"];
  
  if ([(value = [_dict objectForKey:Fields->contentLength]) isNotNull])
    [map setObject:value forKey:Fields->contentLength];
  
  if ([(value = [_dict objectForKey:@"date"]) isNotNull]) {
    NSCalendarDate *d;

    if ((d = [NSCalendarDate calendarDateWithRfc822DateString:value])) 
      [map setObject:d forKey:Fields->date];
  }
  {
    NSEnumerator   *enumerator;
    id             obj;
    static NSArray *Array = nil;

    if (Array == nil) {
      Array = [[NSArray alloc] initWithObjects:
                               Fields->from,
                               @"sender",
                               Fields->replyTo,
                               Fields->to,
                               Fields->cc,
                               @"bcc", nil];
    }
    enumerator = [Array objectEnumerator];
    while ((obj = [enumerator nextObject])) {
      NSArray *addrs;

      if ((addrs = [_dict objectForKey:obj])) {
        NSEnumerator *addrEnum;
        NSDictionary *addr;
        NSMutableString *str;

        addrEnum = [addrs objectEnumerator];
        str      = nil;
        while ((addr = [addrEnum nextObject]) != nil) {
          NSString *personalName, *mailboxName, *hostName;
	  
          if (str == nil)
            str = [NSMutableString stringWithCapacity:32];
          else
            [str appendString:@", "];
	  
          personalName = [addr objectForKey:@"personalName"];
          mailboxName  = [addr objectForKey:@"mailboxName"];
          hostName     = [addr objectForKey:@"hostName"];

          if ([personalName isNotEmpty]) {
	    [str appendString:@"\""];
	    [str appendString:personalName];
	    [str appendString:@"\" <"];
	    [str appendString:mailboxName];
	    [str appendString:@"@"];
	    [str appendString:hostName];
	    [str appendString:@">"];
          }
          else {
	    [str appendString:mailboxName];
	    [str appendString:@"@"];
	    [str appendString:hostName];
	  }
        }
        if (str != nil)
          [map setObject:str forKey:obj];
      }
    }
  }
  {
    id part, tmp, body;

    part = _buildPart(self, _baseUrl, [_dict objectForKey:@"body"]);

    [map setObject:[part contentType] forKey:Fields->contentType];

    if (![[map valueForKey:Fields->contentTransferEncoding] length]) {
      if ((tmp = [[part valuesOfHeaderFieldWithName:
                        Fields->contentTransferEncoding] nextObject])) {
        [map setObject:tmp forKey:Fields->contentTransferEncoding];
      }
    }
    if (![[map valueForKey:Fields->contentLength] intValue]) {
      if ((tmp = [[part valuesOfHeaderFieldWithName:Fields->contentLength]
                  nextObject])) {
        [map setObject:tmp forKey:Fields->contentLength];
      }
    }
    message = [NGMimeMessage messageWithHeader:map];

    if ([(body = [part body]) isKindOfClass:[NSURL class]]) {
      NSString *baseStr;

      baseStr = [body absoluteString];

      if ([baseStr hasPrefix:@"="]) {
        body = [NSURL URLWithString:[NSString stringWithFormat:@"%@1",
                                              baseStr]];
      }
      else
        body = [NSURL URLWithString:[NSString stringWithFormat:@"%@.1",
                                              baseStr]];
    }
    [message setBody:body];
  }
  return message;
}

static id _buildPart(id self, NSURL *_baseUrl, NSDictionary *_dict) {
  NSString       *type, *subType;
  NGMimeBodyPart *part;
  NSURL          *url;

  url     = _baseUrl;
  type    = [[_dict objectForKey:@"type"] lowercaseString]; 
  subType = [[_dict objectForKey:@"subtype"] lowercaseString];
 
  part = _buildMimeBodyPart(self, _dict);
    
  if ([type isEqualToString:@"multipart"]) {
    [part setBody:_buildMultipartMessage(self, url, _dict, part)];
  }
  else if ([type isEqualToString:@"message"] &&
           [subType isEqualToString:@"rfc822"]) {
    [part setBody:_buildMessage(self, url, _dict)];
  }
  else {
    [part setBody:url];
  }
  return part;
}

static id _buildMimeBodyPart(id self, NSDictionary *_dict)
{
  NGMutableHashMap *dict;
  NSString         *value;
  NGMimeType       *type;
  static NGMimeHeaderNames *Fields = NULL;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  

  dict = [NGMutableHashMap hashMapWithCapacity:8];

  type = [NGMimeType mimeType:[[_dict objectForKey:@"type"] lowercaseString]
                     subType:[[_dict objectForKey:@"subtype"] lowercaseString]
                     parameters:[_dict objectForKey:@"parameterList"]];

  [dict setObject:type forKey:Fields->contentType];

  if ([(value = [_dict objectForKey:@"bodyId"]) isNotEmpty])
    [dict setObject:value forKey:Fields->messageID];
  
  if ([(value = [_dict objectForKey:@"size"]) isNotEmpty])
    [dict setObject:value forKey:Fields->contentLength];
  
  if ([(value = [_dict objectForKey:@"encoding"]) isNotEmpty]) {
    [dict setObject:[value lowercaseString]
          forKey:Fields->contentTransferEncoding];
  }
  return [NGMimeBodyPart bodyPartWithHeader:dict];
}


static id _buildMimeMessageBody(id self, NSURL *_baseUrl, NSDictionary *_dict,
                                id<NGMimePart>_part)
{
  NSString *type, *subType;
  NSURL    *url;
  id       result;

  type    = [[_dict objectForKey:@"type"] lowercaseString];
  subType = [[_dict objectForKey:@"subtype"] lowercaseString];

  url = [NSURL URLWithString:[[_baseUrl absoluteString]
                                        stringByAppendingString:@"?part="]];
  if ([type isEqualToString:@"multipart"]) {
    result = _buildMultipartMessage(self, url, _dict, _part);
  }
  else {
    if ([type isEqualToString:@"message"] &&
        [subType isEqualToString:@"rfc822"]) {
      result = _buildMessage(self, url, _dict);
    }
    else {
      result = [NSURL URLWithString:[[_baseUrl absoluteString]
                                        stringByAppendingString:@"?part=1"]];
    }
  }
  return result;
}

@end /* NGImap4Message(BodyStructure) */

#endif /* __NGImap4Message_BodyStructure_H__ */
