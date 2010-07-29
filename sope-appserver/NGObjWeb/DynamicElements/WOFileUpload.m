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

#include "WOInput.h"

@interface WOFileUpload : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  WOAssociation *filePath; // disposition 'filename'
  WOAssociation *data;     // uploaded data
}

@end /* WOFileUpload */

#include "decommon.h"
#include <NGMime/NGMime.h>
#include <NGHttp/NGHttp.h>

@interface WORequest(UsedPrivates)
- (id)httpRequest;
@end

@implementation WOFileUpload

static NGMimeType *multipartFormData = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (isInitialized) return;
  isInitialized = YES;

  multipartFormData = [[NGMimeType mimeType:@"multipart/form-data"] retain];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{

  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->filePath = OWGetProperty(_config, @"filePath");
    self->data     = OWGetProperty(_config, @"data");
  }
  return self;
}

- (void)dealloc {
  [self->filePath release];
  [self->data     release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NGMimeMultipartBody *body;
  NGMimeType *contentType;
  NSString   *currentId;
  id         formValue  = nil;
  NSArray    *parts;
  unsigned   i, count;
  
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;
  
  currentId = OWFormElementName(self, _ctx);
  
  if ((formValue = [_rq formValueForKey:currentId]) == nil)
    return;

  contentType = [[_rq httpRequest] contentType];
      
  if (![contentType hasSameType:multipartFormData]) {
    [self warnWithFormat:
	    @"Tried to apply file-upload value of eid=%@ from "
	    @"a non multipart-form request (value=%@).",
	    [_ctx elementID], formValue];
    return;
  }
  
#if 0
  NSLog(@"%@: value=%@ ..", [self elementID], formValue);
#endif
  
  if ([self->data isValueSettable])
    [self->data setValue:formValue inComponent:[_ctx component]];
  
  /* the remainder is for locating the file path */
  
  if (![self->filePath isValueSettable])
    return;
  
  body = [[_rq httpRequest] body];
  if (![body isKindOfClass:[NGMimeMultipartBody class]])
    /* TODO: shouldn't we log something? */
    return;
  
  /* search for part of current form element */
  
  parts = [body parts];
  for (i = 0, count = [parts count]; i < count; i++) {
    static Class DispClass = Nil;
    NSString       *formName;
    id             disposition;
    id<NGMimePart> bodyPart;
            
    bodyPart = [parts objectAtIndex:i];
    disposition = [[bodyPart valuesOfHeaderFieldWithName:
			       @"content-disposition"] nextObject];
    
    if (disposition == nil)
      continue;
    
    if (DispClass == Nil)
      DispClass = [NGMimeContentDispositionHeaderField class];
              
    if (![disposition isKindOfClass:DispClass]) {
      disposition =
	[[DispClass alloc] initWithString:[disposition stringValue]];
      disposition = [disposition autorelease];
    }
    
    formName = [(NGMimeContentDispositionHeaderField *)disposition name];
      
    if ([formName isEqualToString:currentId]) {
      [self->filePath setValue:[disposition filename]
	              inComponent:[_ctx component]];
      break;
    }
  }
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *v;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;
  
  v = [self->value stringValueInComponent:[_ctx component]];
      
  WOResponse_AddCString(_response, "<input type=\"file\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddChar(_response, '"');
  if (v != nil) {
    WOResponse_AddCString(_response, " value=\"");
    [_response appendContentHTMLAttributeValue:v];
    WOResponse_AddChar(_response, '"');
  }
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
			 [self->otherTagString stringValueInComponent:
                                [_ctx component]]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:32];
  [str appendString:[super associationDescription]];
  
  if (self->filePath != nil) [str appendFormat:@" path=%@", self->filePath];
  if (self->data     != nil) [str appendFormat:@" data=%@", self->data];
  
  return str;
}

@end /* WOFileUpload */
