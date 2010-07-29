/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

  This file is part of OpenGroupware.org.

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

#ifndef	__SOPEX_SOPEXConsole_H_
#define	__SOPEX_SOPEXConsole_H_

#import <AppKit/AppKit.h>

@class NGLogEvent;
@class SOPEXToolbarController;

@interface SOPEXConsole : NSObject
{
  IBOutlet NSWindow *window;
  IBOutlet NSTextView *text;
  
  SOPEXToolbarController *toolbar;
  
  NSDictionary *stdoutAttributes, *stderrAttributes;
}

- (IBAction)orderFront:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)close:(id)sender;

- (BOOL)isVisible;

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem;

- (void)appendLogEvent:(NGLogEvent *)_event;

@end

#endif	/* __SOPEX_SOPEXConsole_H_ */
