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

#ifndef __NGJavaScriptShadow_H__
#define __NGJavaScriptShadow_H__

#include <NGJavaScript/NGJavaScriptObject.h>
#include <NGScripting/NGScriptLanguage.h>

/*
  A shadow state object for an ObjC real object. The ObjC object needs to
  forward dynamic state changes to this object, but it's properties and
  methods are exposed under 'this' in the state object (no back-reference
  is required).
  The shadow object forwards it's static property and functions calls to it's
  master using the private.

  A shadow is required to retain the state of the script object since
  a normal ObjC object doesn't keep a reference to a script object ! The
  shadow contains some kind of specialized "extra variables" for the ObjC 
  object.
*/

@interface NGJavaScriptShadow : NGJavaScriptObject < NGScriptShadow >
{
  id masterObject; /* non-retained */
}

- (void)setMasterObject:(id)_master;
- (id)masterObject;

@end

#endif /* __NGJavaScriptShadow_H__ */
