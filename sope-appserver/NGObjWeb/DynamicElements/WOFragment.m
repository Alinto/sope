/*
  Copyright (C) 2007 OpenGroupware.org.

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

/*
 * WOFragment
 * 
 * This element is used to mark rendering fragments. If SOPE receives a URL
 * which contains the 'wofid' request parameter, it will disable rendering in
 * the WOContext. This element can be used to reenable rendering for a certain
 * template subsection.
 * 
 * Note that request handling is NOT affected by fragments! This is necessary
 * to ensure a proper component state setup. If you wish, you can further
 * reduce processing overhead using WOConditionals in appropriate places (if
                                                                          * you know that those sections do not matter for processing)
 * 
 * Fragments can be nested. WOFragment sections _never_ disable rendering or
 * change template control flow, they only enable rendering when fragment ids
 * match. This way it is ensured that "sub fragments" will get properly
 * accessed.
 * This can be overridden by setting the "onlyOnMatch" binding. If this is set
 * the content will only get accessed in case the fragment matches OR not
 * fragment id is set. 
 * 
 * Sample:
 *   <#WOFragment name="tableview" />
 * 
 * Renders:
 *   This element can render a container tag if the elementName is specified.
 *   
 * Bindings:
 *   name        [in] - string       name of fragment
 *   onlyOnMatch [in] - boolean      enable/disable processing for other frags
 *   elementName [in] - string       optional name of container element
 *   <all other bindings are extra-attrs for elementName>
 */
#include "decommon.h"
#include <NGObjWeb/WODynamicElement.h>
#include "WOElement+private.h"

@interface WOFragment : WODynamicElement
{
  WOElement     *template;
  WOAssociation *name;
  WOAssociation *eid;
  WOAssociation *onlyOnMatch;
  WOAssociation *elementName;
}

- (BOOL)isFragmentActiveInContext:(WOContext *)_ctx;

@end /* WOFragment */

@implementation WOFragment

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_assocs
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_assocs template:_c])) {
    self->template    = RETAIN(_c);
    self->name        = OWGetProperty(_assocs, @"name");
    self->eid         = OWGetProperty(_assocs, @"id");
    self->onlyOnMatch = OWGetProperty(_assocs, @"onlyOnMatch");
    self->elementName = OWGetProperty(_assocs, @"elementName");
  }
  return self;
}
- (void)dealloc {
  [self->template    release];
  [self->name        release];
  [self->eid         release];
  [self->onlyOnMatch release];
  [self->elementName release];
  [super dealloc];
}

/* support */

- (BOOL)isFragmentActiveInContext:(WOContext *)_ctx {
  NSString *fragName;
  NSString *fragID = [_ctx fragmentID];

  if (fragID == nil) /* yes, active, no fragment is set */
    return YES;
  
   fragName = self->name == nil
     ? [_ctx elementID]
     : [self->name stringValueInComponent:[_ctx cursor]];
  if (fragName == nil) /* we have no fragid in the current state */
    return YES;
  
  return [fragID isEqualToString:fragName];
}

/* request handling */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->template == nil) return;

  if (self->onlyOnMatch == nil)
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
  else if (![self->onlyOnMatch boolValueInComponent:[_ctx cursor]])
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
  else if ([self isFragmentActiveInContext:_ctx])
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *fragID;

  if (self->template == nil)
    return nil;
  
  fragID = [_ctx fragmentID];
  
  if (self->onlyOnMatch == nil || fragID == nil)
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  if (![self->onlyOnMatch boolValueInComponent:[_ctx cursor]])
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  if ([self isFragmentActiveInContext:_ctx])
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  /* onlyOnMatch is on and fragment is not active, do not call template */
  return nil;
}

/* rendering */

- (void)appendToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  id       cursor       = [_ctx cursor];
  BOOL     wasDisabled  = [_ctx isRenderingDisabled];
  BOOL     isFragActive = [self isFragmentActiveInContext:_ctx];
  BOOL     doRender     = YES;     
  NSString *en          = nil;

  if (!isFragActive) {
    /* we are not active (no match) */
    if (self->onlyOnMatch != nil)
      doRender = ![self->onlyOnMatch boolValueInComponent:cursor];
  }
  
  /* enable rendering if we are active */
  
  if (isFragActive)
    [_ctx enableRendering];
  
  /* start container element if we have no frag */
  
  if (!wasDisabled && self->elementName != nil)
    en = [self->elementName stringValueInComponent:cursor];
  
  if (en != nil) {
    NSString *leid;
    
    WOResponse_AppendBeginTag(_r, en);
    
    /* add id of fragment element */
    
    if (self->eid != nil)
      leid = [self->eid stringValueInComponent:cursor];
    else if (self->name != nil)
      leid = [self->name stringValueInComponent:cursor];
    else
      leid = [_ctx elementID];
    if (leid != nil)
      WOResponse_AppendAttribute(_r, @"id", leid);

    /* additional bindings not specifically tracked by the element*/
    [self appendExtraAttributesToResponse:_r inContext:_ctx];
    
    WOResponse_AppendBeginTagEnd(_r);
  }
  
  /* do content */
  
  if (doRender && self->template != nil)
    [self->template appendToResponse:_r inContext:_ctx];
  
  /* close tag if we have one */
  
  if (en != nil)
    WOResponse_AppendEndTag(_r, en);
  
  /* reestablish old rendering state */
  
  if (isFragActive && wasDisabled)
    [_ctx disableRendering];
}

@end /* WOFragment */
