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

#include <NGObjWeb/WOHTMLDynamicElement.h>
#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

/*
  A QuickTime movie, picture, ...
  
  The HTML tag attributes are described at:
    http://www.apple.com/quicktime/authoring/embed2.html
*/

@interface WOQuickTime : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOElement     *template;
  WOAssociation *filename;
  WOAssociation *framework;
  WOAssociation *src;

  WOAssociation *action;
  WOAssociation *href;
  WOAssociation *pageName;
  WOAssociation *prefixHost;
  
  WOAssociation *width;
  WOAssociation *height;
  WOAssociation *pluginsPage;
  WOAssociation *hotspotList;
  WOAssociation *selection;
  WOAssociation *bgcolor;
  WOAssociation *target;
  WOAssociation *volume;
  WOAssociation *pan;
  WOAssociation *tilt;
  WOAssociation *fov;
  WOAssociation *node;
  WOAssociation *correction;
  WOAssociation *cache;
  WOAssociation *autoplay;
  WOAssociation *hidden;
  WOAssociation *playEveryFrame;
  WOAssociation *controller;
}

@end /* WOQuickTime */

@interface WODynamicElement(UsedPrivates)
- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t;
@end

@implementation WOQuickTime

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super _initWithName:_name associations:_config template:_t])) {
    self->template = [_t retain];
    
    self->filename       = OWGetProperty(_config, @"filename");
    self->framework      = OWGetProperty(_config, @"framework");
    self->src            = OWGetProperty(_config, @"src");

    self->action         = OWGetProperty(_config, @"action");
    self->href           = OWGetProperty(_config, @"href");
    self->pageName       = OWGetProperty(_config, @"pageName");
    self->prefixHost     = OWGetProperty(_config, @"prefixHost");
  
    self->width          = OWGetProperty(_config, @"width");
    self->height         = OWGetProperty(_config, @"height");
    self->pluginsPage    = OWGetProperty(_config, @"pluginsPage");
    self->hotspotList    = OWGetProperty(_config, @"hotspotList");
    self->selection      = OWGetProperty(_config, @"selection");
    self->bgcolor        = OWGetProperty(_config, @"bgcolor");
    self->target         = OWGetProperty(_config, @"target");
    self->volume         = OWGetProperty(_config, @"volume");
    self->pan            = OWGetProperty(_config, @"pan");
    self->tilt           = OWGetProperty(_config, @"tilt");
    self->fov            = OWGetProperty(_config, @"fov");
    self->node           = OWGetProperty(_config, @"node");
    self->correction     = OWGetProperty(_config, @"correction");
    self->cache          = OWGetProperty(_config, @"cache");
    self->autoplay       = OWGetProperty(_config, @"autoplay");
    self->hidden         = OWGetProperty(_config, @"hidden");
    self->playEveryFrame = OWGetProperty(_config, @"playEveryFrame");
    self->controller     = OWGetProperty(_config, @"controller");
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->template);
  RELEASE(self->filename);
  RELEASE(self->framework);
  RELEASE(self->src);
  RELEASE(self->action);
  RELEASE(self->href);
  RELEASE(self->pageName);
  RELEASE(self->prefixHost);
  RELEASE(self->width);
  RELEASE(self->height);
  RELEASE(self->pluginsPage);
  RELEASE(self->hotspotList);
  RELEASE(self->selection);
  RELEASE(self->bgcolor);
  RELEASE(self->target);
  RELEASE(self->volume);
  RELEASE(self->pan);
  RELEASE(self->tilt);
  RELEASE(self->fov);
  RELEASE(self->node);
  RELEASE(self->correction);
  RELEASE(self->cache);
  RELEASE(self->autoplay);
  RELEASE(self->hidden);
  RELEASE(self->playEveryFrame);
  RELEASE(self->controller);
  [super dealloc];
}

/* event handling */

/* HTML generation */

/* description */

@end
