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

#ifndef	__SOPEX_SOPEXAppController_H_
#define	__SOPEX_SOPEXAppController_H_

#import <AppKit/AppKit.h>

@class SOPEXConsole;
@class SOPEXStatisticsController;
@class SOPEXBrowserController;

@interface SOPEXAppController : NSObject
{
  IBOutlet NSMenu *mainMenu;

  IBOutlet NSMenuItem *debugMenuItem;
  IBOutlet NSMenuItem *viewSeparatorMenuItem;

  IBOutlet NSMenuItem *viewApplicationMenuItem;
  IBOutlet NSMenuItem *viewSourceMenuItem;
  IBOutlet NSMenuItem *viewHTMLMenuItem;
  IBOutlet NSMenuItem *viewHTTPMenuItem;

  IBOutlet NSMenuItem *aboutMenuItem;
  IBOutlet NSMenuItem *hideMenuItem;
  IBOutlet NSMenuItem *quitMenuItem;

  SOPEXConsole              *console;
  SOPEXStatisticsController *statsController;
  SOPEXBrowserController    *mainBrowserController;
}

+ (id)sharedController;

- (BOOL)isInRADMode;

/* hook to provide custom launch defaults. remember to call super! */
- (void)prepareForLaunch;

- (IBAction)openConsole:(id)sender;
- (IBAction)openStatistics:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)restart:(id)sender;

- (SOPEXConsole *)console;

- (void)browserControllerDidClose:(SOPEXBrowserController *)_controller;

@end

#endif	/* __SOPEX_SOPEXAppController_H_ */
