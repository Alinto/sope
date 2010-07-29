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

#include "ODRDynamicXHTMLTag.h"

/*
  Usage:

  Additions:

    dateformat   - NSDateFormatter spec
    numberformat - NSNumberFormatter spec

    filepath     - NSString              -- filename      (for file upload)
    data         - NSData                -- uploaded data (for file upload)

    selection    - selected radio-button value
  
  HTML 4.01:
   <!ENTITY % InputType
     "(TEXT | PASSWORD | CHECKBOX |
       RADIO | SUBMIT | RESET |
       FILE | HIDDEN | IMAGE | BUTTON)"
      >
   
   <!-- attribute name required for all but submit and reset -->
   <!ELEMENT INPUT - O EMPTY              -- form control -->
   <!ATTLIST INPUT
     %attrs;                              -- %coreattrs, %i18n, %events --
     type        %InputType;    TEXT      -- what kind of widget is needed --
     name        CDATA          #IMPLIED  -- submit as part of form --
     value       CDATA          #IMPLIED  -- Specify for radio buttons and
                                             checkboxes --
     checked     (checked)      #IMPLIED  -- for radio buttons and check boxes --
     disabled    (disabled)     #IMPLIED  -- unavailable in this context --
     readonly    (readonly)     #IMPLIED  -- for text and passwd --
     size        CDATA          #IMPLIED  -- specific to each type of field --
     maxlength   NUMBER         #IMPLIED  -- max chars for text fields --
     src         %URI;          #IMPLIED  -- for fields with images --
     alt         CDATA          #IMPLIED  -- short description --
     usemap      %URI;          #IMPLIED  -- use client-side image map --
     ismap       (ismap)        #IMPLIED  -- use server-side image map --
     tabindex    NUMBER         #IMPLIED  -- position in tabbing order --
     accesskey   %Character;    #IMPLIED  -- accessibility key character --
     onfocus     %Script;       #IMPLIED  -- the element got the focus --
     onblur      %Script;       #IMPLIED  -- the element lost the focus --
     onselect    %Script;       #IMPLIED  -- some text was selected --
     onchange    %Script;       #IMPLIED  -- the element value was changed --
     accept      %ContentTypes; #IMPLIED  -- list of MIME types for file upload--
     >
*/

@interface ODR_XHTML_input : ODRDynamicXHTMLTag
@end

#include "common.h"
#import <NGMime/NGMime.h>
#import <NGHttp/NGHttp.h>

@interface WOContext(Privates)
- (void)addActiveFormElement:(id)_element;
@end

@interface WORequest(HttpRequest)
- (id)httpRequest;
@end

@implementation ODR_XHTML_input

static NGMimeType *multipartFormData = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    multipartFormData = [NGMimeType mimeType:@"multipart/form-data"];
    multipartFormData = RETAIN(multipartFormData);
  }
}

- (BOOL)requiresFormForNode:(id)_node inContext:(WOContext *)_ctx {
  return YES;
}

- (NSFormatter *)_formatterForNode:(id)_node inContext:(WOContext *)_ctx {
  NSFormatter *formatter;
  NSString    *fmt;
  
  if ((fmt = [self stringFor:@"dateformat" node:_node ctx:_ctx])) {
    formatter = [[NSDateFormatter alloc]
                                  initWithDateFormat:fmt
                                  allowNaturalLanguage:NO];
    AUTORELEASE(formatter);
  }
  else if ((fmt = [self stringFor:@"numberformat" node:_node ctx:_ctx])) {
    formatter = [[NSNumberFormatter alloc] init];
    AUTORELEASE(formatter);
    [(NSNumberFormatter *)formatter setFormat:fmt];
  }
  else
    formatter = nil;

  return formatter;
}

- (void)_setStringValue:(NSString *)_value
  onNode:(id)_node
  inContext:(WOContext *)_ctx
{
  if ([self isSettable:@"value" node:_node ctx:_ctx]) {
    NSFormatter *formatter;

    if ((formatter = [self _formatterForNode:_node inContext:_ctx])) {
      id       v;
      NSString *err;
      
      if ([formatter getObjectValue:&v forString:_value errorDescription:&err]){
        [self setValue:v for:@"value" node:_node ctx:_ctx];
        
        if ([self isSettable:@"formattingError" node:_node ctx:_ctx])
          [self setValue:nil for:@"formattingError" node:_node ctx:_ctx];
      }
      else {
        [self setValue:_value for:@"value" node:_node ctx:_ctx];
        
        if ([self isSettable:@"formattingError" node:_node ctx:_ctx])
          [self setValue:err ? err : @"failed"
                for:@"formattingError" node:_node ctx:_ctx];
      }
    }
    else
      [self setString:_value for:@"value" node:_node ctx:_ctx];
  }
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *itype;
  NSString *ename;
  id formValue;
  
#if DEBUG
  if (![_ctx isInForm])
    NSLog(@"WARNING(%s): not in form !", __PRETTY_FUNCTION__);
#endif

  if ([self boolFor:@"disabled" node:_node ctx:_ctx]) {
    return;
  }
  
  itype     = [self stringFor:@"type" node:_node ctx:_ctx];
  ename     = [self _selectNameOfNode:_node inContext:_ctx];
  formValue = [_req formValueForKey:ename];
  
  if ([itype isEqualToString:@"radio"]) {
    BOOL isActiveRadio;
    
    isActiveRadio = [formValue isEqual:[_ctx elementID]];
    
    if ([self isSettable:@"checked" node:_node ctx:_ctx]) {
      [self forceSetBool:isActiveRadio for:@"checked" node:_node ctx:_ctx];
    }
    if (isActiveRadio) {
      if ([self isSettable:@"selection" node:_node ctx:_ctx])
        [self setValue:formValue for:@"selection" node:_node ctx:_ctx];
    }
  }
  else if ([itype isEqualToString:@"image"]) {
    /* does not take values yet .. ('value' isn't transmitted) */
  }
  else if ([itype isEqualToString:@"file"]) {
    if (formValue) {
      NGMimeType *contentType = [[_req httpRequest] contentType];
      
      if (![contentType hasSameType:multipartFormData]) {
        NSLog(@"WARNING: tried to apply file-upload value of %@ from "
              @"a non multipart-form request (value=%@) !",
              [_ctx elementID], formValue);
        return;
      }

      if ([self isSettable:@"data" node:_node ctx:_ctx])
        [self setValue:formValue for:@"data" node:_node ctx:_ctx];

      if ([self isSettable:@"filepath" node:_node ctx:_ctx]) {
        NGMimeMultipartBody *body = [[_req httpRequest] body];

        if ([body isKindOfClass:[NGMimeMultipartBody class]]) {
          NSArray  *parts   = [body parts];
          unsigned i, count = [parts count];

          // search for part of current form element
          
          for (i = 0; i < count; i++) {
            id disposition;
            id<NGMimePart> bodyPart;
            
            bodyPart = [parts objectAtIndex:i];
            disposition =
              [[bodyPart valuesOfHeaderFieldWithName:@"content-disposition"]
                         nextObject];
            
            if (disposition) {
              static Class DispClass = Nil;
              NSString *formName;
              
              if (DispClass == Nil)
                DispClass = [NGMimeContentDispositionHeaderField class];
              
              if (![disposition isKindOfClass:DispClass]) {
                disposition =
                  [[DispClass alloc] initWithString:[disposition stringValue]];
                [disposition autorelease];
              }
              
              formName = [(NGMimeContentDispositionHeaderField *)disposition
								 name];
              
              if ([formName isEqualToString:ename]) {
                [self setValue:[disposition filename]
                      for:@"filepath" node:_node ctx:_ctx];
                break;
              }
            }
          }
        }
      }
    }
  }
  else {
    [self _setStringValue:formValue onNode:_node inContext:_ctx];
    
    if ([self hasAttribute:@"checked" node:_node ctx:_ctx]) {
      if ([self isSettable:@"checked" node:_node ctx:_ctx]) {
        if ([itype isEqualToString:@"checkbox"]) {
          [self setBool:(formValue ? YES : NO) for:@"checked"
                node:_node ctx:_ctx];
        }
        else {
          NSLog(@"WARNING(%s): cannot handle 'checked' attribute of node %@",
                __PRETTY_FUNCTION__, _node);
        }
      }
    }
  }
  
  /* 'active' elements */
  
  if ([itype isEqualToString:@"submit"] || [itype isEqualToString:@"button"]) {
    /* check action */
    if (formValue)
      /* yep, we are the active element (submit-button) */
      [_ctx addActiveFormElement:_node];
  }
  else if ([itype isEqualToString:@"image"]) {
    /* 'image' forms transmit two values: key.x and x.y containing the position*/
    NSString *xId;
    NSString *xValue;
    
    xId = [ename stringByAppendingString:@".x"];
    
    if ((xValue = [_req formValueForKey:xId]))
      /* yep, we are the active element (image-button) */
      [_ctx addActiveFormElement:_node];
  }
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  /* check whether this is the active form element (determined in take-values) */

  if ([self boolFor:@"disabled" node:_node ctx:_ctx]) {
    return nil;
  }

  if ([[_ctx elementID] isEqualToString:[_ctx senderID]]) {
    id onClickNode;
    id<DOMNamedNodeMap> attrs;
    
    if ((attrs = [_node attributes]) == nil)
      return nil;
    
    if ((onClickNode = [_node attributeNode:@"onclick" namespaceURI:@"*"])) {
      return [self invokeValueForAttributeNode:onClickNode inContext:_ctx];
    }
    else {
      NSLog(@"%s: did not find 'onclick' attribute in input node %@ !",
            __PRETTY_FUNCTION__, _node);
      return nil;
    }
  }
  else {
    NSLog(@"input is not active (%@ vs %@) !",
          [_ctx elementID], [_ctx senderID]);
    return nil;
  }
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (![_ctx isInForm]) {
    id value;
    
    value = [self valueFor:@"value" node:_node ctx:_ctx];
    
    [[_ctx component]
           logWithFormat:@"WARNING: input-tag is not in a form !"];
    [_response appendContentHTMLString:[value stringValue]];
    return;
  }
  
  if ([self boolFor:@"disabled" node:_node ctx:_ctx]) {
    id value;
    
    value = [self valueFor:@"value" node:_node ctx:_ctx];
    
    [_response appendContentHTMLString:[value stringValue]];
    return;
  }
  
  /* ok, we are in a form and we are not disabled ... */
  
  {
    NSString    *itype;
    NSString    *ename;
    NSFormatter *formatter;
    int size, maxlen;
    id  value;
    
    ename  = [self _selectNameOfNode:_node inContext:_ctx];
    itype  = [self stringFor:@"type"   node:_node ctx:_ctx];
    size   = [self intFor:@"size"      node:_node ctx:_ctx];
    maxlen = [self intFor:@"maxlength" node:_node ctx:_ctx];
    
    value  = [self valueFor:@"value"  node:_node ctx:_ctx];
    
    formatter = [self _formatterForNode:_node inContext:_ctx];
    
    if (formatter) {
#if DEBUG && 0
      NSLog(@"%s: formatting '%@'<%@> ..",
            __PRETTY_FUNCTION__, value, [value class]);
#endif
      value = [formatter editingStringForObjectValue:value];
#if DEBUG && 0
      NSLog(@"%s: formatted value: '%@'<%@> ..",
            __PRETTY_FUNCTION__, value, [value class]);
#endif
    }
    else
      value = [value stringValue];
    
    [_response appendContentString:@"<input type=\""];
    [_response appendContentHTMLAttributeValue:itype];
    [_response appendContentString:@"\""];
    
    if (ename) {
      [_response appendContentString:@" name=\""];
      [_response appendContentHTMLAttributeValue:ename];
      [_response appendContentString:@"\""];
    }
    
    if (size > 0) {
      [_response appendContentString:@" size=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", size]];
      [_response appendContentCharacter:'"'];
    }
    if (maxlen > 0) {
      [_response appendContentString:@" maxlength=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", size]];
      [_response appendContentCharacter:'"'];
    }
    
    if ([self hasAttribute:@"checked" node:_node ctx:_ctx]) {
      if ([self boolFor:@"checked" node:_node ctx:_ctx])
        /* XHTML !!! */
        [_response appendContentString:@" checked"];
    }
    else {
      if ([itype isEqualToString:@"radio"]) {
        [_response appendContentString:@" value=\""];
        [_response appendContentHTMLAttributeValue:[_ctx elementID]];
        [_response appendContentString:@"\""];
      }
      else if (value) {
        [_response appendContentString:@" value=\""];
        [_response appendContentHTMLAttributeValue:value];
        [_response appendContentString:@"\""];
      }
    }

    /* image specialties */
    
    if ([itype isEqualToString:@"image"]) {
      id       srcNode;
      NSString *src;
      NSString *tmp;
      
      if ((srcNode = [_node attributeNode:@"src" namespaceURI:@"*"]))
        src = [[self valueForAttributeNode:srcNode inContext:_ctx] stringValue];
      else
        src = nil;

      if ([src length] > 0) {
        [_response appendContentString:@" src=\""];
        [_response appendContentString:src];
        [_response appendContentString:@"\""];
      }
      
      if ((tmp = [self stringFor:@"alt" node:_node ctx:_ctx])) {
        [_response appendContentString:@" alt=\""];
        [_response appendContentHTMLAttributeValue:tmp];
        [_response appendContentCharacter:'"'];
      }
    }
    
    [_response appendContentString:@" />"];
  }
}

@end /* ODR_XHTML_input */
