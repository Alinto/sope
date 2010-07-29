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

#ifndef	__SOPEX_SOPEXBrowserController_H_
#define	__SOPEX_SOPEXBrowserController_H_

#import <AppKit/AppKit.h>
#include <SOPEX/SOPEXDocument.h> /* SOPEXDocumentController */

@class SOPEXBrowserWindow;
@class WebView;
@class SOPEXToolbarController;
@class SOPEXWebConnection;

@interface SOPEXBrowserController : NSObject <SOPEXDocumentController>
{
  IBOutlet SOPEXBrowserWindow *mainWindow;
  IBOutlet NSTabView *tabView;
  
  IBOutlet NSProgressIndicator *progressIndicator;
  IBOutlet NSTextField *statusBarTextField;

  IBOutlet WebView  *webView;

  IBOutlet NSTextField *woxNameField;
  IBOutlet NSTextView *woxSourceView;
  IBOutlet NSTextField *woComponentNameField;
  IBOutlet NSTextView *woSourceView;
  IBOutlet NSTextView *woDefinitionView;
  
  IBOutlet NSTextView *htmlView;
  
  IBOutlet NSTableView *responseHeaderInfoTableView;
  NSMutableArray *responseHeaderValues;

  SOPEXWebConnection *connection;
  SOPEXToolbarController *toolbarController;

  SOPEXDocument *document;
}

+ (BOOL)hasActiveControllers;

- (NSTextView *)document:(SOPEXDocument *)document textViewForType:(NSString *)fileType;

- (void)setWebConnection:(SOPEXWebConnection *)_conn;

- (IBAction)orderFront:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)viewApplication:(id)sender;
- (IBAction)viewSource:(id)sender;
- (IBAction)viewHTML:(id)sender;
- (IBAction)viewHTTP:(id)sender;

- (IBAction)editInXcode:(id)sender;

    /* debugging */
- (IBAction)toggleToolbar:(id)sender;

@end

#endif	/* __SOPEX_SOPEXBrowserController_H_ */
