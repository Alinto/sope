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

#include "WOHyperlink.h"

@class NSString, NSDictionary;
@class WOElement, WOAssociation;

/*
  Class Hierachy
    [WOHTMLDynamicElement]
      [WOHyperlink]
        _WOCommonStaticDAHyperlink
*/

@interface _WOCommonStaticDAHyperlink : WOHyperlink
{
  NSString      *daName;
  WOElement     *template;
  WOAssociation *string;
  NSDictionary  *queryParameters;  /* associations beginning with ? */
  BOOL          sidInUrl;          /* include session-id in wa URL ? */
}
@end /* _WOCommonStaticDAHyperlink */

#include "WOHyperlinkInfo.h"
#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOAssociation.h>
#include "decommon.h"

@implementation _WOCommonStaticDAHyperlink

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    NSString *dc, *dn;
    
    self->template        = [_t retain];
    self->string          = _info->string;
    self->queryParameters = _info->queryParameters;
    
    dc = [_info->actionClass       stringValueInComponent:nil];
    dn = [ _info->directActionName stringValueInComponent:nil];
    
    if (![dc isEqualToString:@"DirectAction"] && ([dc length] != 0))
      self->daName = [[NSString alloc] initWithFormat:@"%@/%@", dc, dn];
    else
      self->daName = [dn copy];
    
    self->containsForm = NO;
    self->sidInUrl     = _info->sidInUrl;
  }
  return self;
}

- (void)dealloc {
  [self->daName   release];
  [self->template release];
  [self->string   release];
  [self->queryParameters release];
  [super dealloc];
}

/* responder */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSMutableDictionary *qd;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent = [_ctx component];
  WOResponse_AddCString(_response, "<a href=\"");
  
  /* href */
  if (self->queryParameters != nil) {
    NSEnumerator *keys;
    NSString     *key;

    qd = [NSMutableDictionary dictionaryWithCapacity:
                                [self->queryParameters count]];
    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject])) {
      id assoc, value;
      
      assoc = [self->queryParameters objectForKey:key];
      value = [assoc stringValueInComponent:sComponent];
          
      [qd setObject:(value != nil ? value : (id)@"") forKey:key];
    }
  }
  else
    qd = nil;

  /* add session ID */

  if (self->sidInUrl) {
    if ([_ctx hasSession]) {
      WOSession *sn;
      
      if (qd == nil)
        qd = [NSMutableDictionary dictionaryWithCapacity:2];
      
      sn = [_ctx session];
      [qd setObject:[sn sessionID] forKey:WORequestValueSessionID];
      
      if (![sn isDistributionEnabled]) {
        [qd setObject:[[WOApplication application] number]
            forKey:WORequestValueInstance];
      }
    }
  }
  
  WOResponse_AddString(_response,
                       [_ctx directActionURLForActionNamed:self->daName
                             queryDictionary:qd]);
  
  WOResponse_AddCString(_response, "\"");

  [self appendExtraAttributesToResponse:_response inContext:_ctx];
    
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  [_response appendContentCharacter:'>'];

  /* content */
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  if (self->string) {
    [_response appendContentHTMLString:
                 [self->string stringValueInComponent:sComponent]];
  }
  
  /* closing tag */
  WOResponse_AddCString(_response, "</a>");
}

@end /* _WOCommonStaticDAHyperlink */
