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

#include "WOHyperlinkInfo.h"
#include "WOElement+private.h"
#include <NGObjWeb/WOHTMLDynamicElement.h>
#include "decommon.h"

@implementation WOHyperlinkInfo

- (id)initWithConfig:(NSMutableDictionary *)_config {
  unsigned count;

  if ((self->initialCount = count = [_config count]) == 0) {
    NSLog(@"%s: missing associations for WOHyperlink !", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  
  self->sidInUrl = YES;
  
  //NSLog(@"CONFIG: %@", _config);
  
  if ((self->action = OWGetProperty(_config, @"action"))) {
    count--;
#if DEBUG
    if (count > 0) {
      if ([_config objectForKey:@"pageName"] ||
          [_config objectForKey:@"href"]     ||
          [_config objectForKey:@"directActionName"] ||
          [_config objectForKey:@"actionClass"]) {
        NSLog(@"WARNING: inconsistent association settings in WOHyperlink !"
              @" (assign only one of pageName, href, "
              @"directActionName or action)");
      }
    }
#endif
    if ([self->action isValueConstant]) {
      /* make a direct-action ... */
      self->directActionName = self->action;
      self->action = nil;

      if (count > 0) {
        if ((self->actionClass = OWGetProperty(_config,@"actionClass")))
          count--;
      }
      if (count > 0) {
        WOAssociation *sidInUrlAssoc;
        
        if ((sidInUrlAssoc = OWGetProperty(_config, @"?wosid"))) {
          self->sidInUrl = [sidInUrlAssoc boolValueInComponent:nil];
          RELEASE(sidInUrlAssoc);
          count--;
        }
        else
          self->sidInUrl = YES;
      }
      else
        self->sidInUrl = YES;
    }
  }
  else if ((self->pageName = OWGetProperty(_config, @"pageName"))) {
    count--;
#if DEBUG
    if (count > 0) {
      if ([_config objectForKey:@"action"] ||
          [_config objectForKey:@"href"]     ||
          [_config objectForKey:@"directActionName"] ||
          [_config objectForKey:@"actionClass"]) {
        NSLog(@"WARNING: inconsistent association settings in WOHyperlink !"
              @" (assign only one of pageName, href, "
              @"directActionName or action)");
      }
    }
#endif
  }
  else if ((self->href = OWGetProperty(_config, @"href"))) {
    count--;
    if (count > 0) {
      WOAssociation *sidInUrlAssoc;
      
      if ((sidInUrlAssoc = OWGetProperty(_config, @"?wosid"))) {
        self->sidInUrl = [sidInUrlAssoc boolValueInComponent:nil];
        RELEASE(sidInUrlAssoc);
        count--;
      }
      else
        self->sidInUrl = NO;
    }
#if DEBUG
    if (count > 0) {
      if ([_config objectForKey:@"action"] ||
          [_config objectForKey:@"pageName"]     ||
          [_config objectForKey:@"directActionName"] ||
          [_config objectForKey:@"actionClass"]) {
        NSLog(@"WARNING: inconsistent association settings in WOHyperlink !"
              @" (assign only one of pageName, href, "
              @"directActionName or action)");
      }
    }
#endif
  }
  else if ((self->directActionName = OWGetProperty(_config,@"directActionName"))) {
    count--;
    if (count > 0) {
      if ((self->actionClass = OWGetProperty(_config,@"actionClass")))
        count--;
    }
    if (count > 0) {
      WOAssociation *sidInUrlAssoc;
      
      if ((sidInUrlAssoc = OWGetProperty(_config, @"?wosid"))) {
        self->sidInUrl = [sidInUrlAssoc boolValueInComponent:nil];
        RELEASE(sidInUrlAssoc);
        count--;
      }
      else
        self->sidInUrl = YES;
    }
    
#if DEBUG
    if (count > 0) {
      if ([_config objectForKey:@"action"] ||
          [_config objectForKey:@"href"]     ||
          [_config objectForKey:@"pageName"]) {
        NSLog(@"WARNING: inconsistent association settings in WOHyperlink !"
              @" (assign only one of pageName, href, "
              @"directActionName or action)");
      }
    }
#endif
  }
  else {
    NSLog(@"%s: missing link-type specified for WOHyperlink (config=%@) !",
          __PRETTY_FUNCTION__, _config);
    RELEASE(self);
    return nil;
  }
  
  if (count > 0) {
    if ((self->string = OWGetProperty(_config, @"string"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->fragmentIdentifier=OWGetProperty(_config, @"fragmentIdentifier"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->target = OWGetProperty(_config, @"target"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->queryDictionary = OWGetProperty(_config, @"queryDictionary"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->queryParameters = OWExtractQueryParameters(_config))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->disabled = OWGetProperty(_config, @"disabled"))) {
      count--;
      assocCount++;
    }
  }

  if (count > 0) {
    if ((self->filename = OWGetProperty(_config, @"filename"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->framework = OWGetProperty(_config, @"framework"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->src = OWGetProperty(_config, @"src"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->disabledFilename = OWGetProperty(_config, @"disabledFilename"))) {
      count--;
      assocCount++;
    }
  }
  if (count > 0) {
    if ((self->isAbsolute = OWGetProperty(_config, @"absolute"))) {
      count--;
      assocCount++;
    }
  }
  
  self->rest = _config;
  
  return self;
}

@end /* WOHyperlinkInfo */
