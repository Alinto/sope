/*
 Copyright (C) 2004-2005 Marcus Mueller <znek@mulle-kybernetik.com>

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
//  Created by znek on Mon Mar 29 2004.


#import "SOPEXSheetRunner.h"
#import <AppKit/AppKit.h>

@interface SOPEXSheetRunner (PrivateAPI)
+ (id)defaultRunner;
- (int)runSheet:(NSWindow *)sheet modalForWindow:(NSWindow *)docWindow;
@end


@implementation SOPEXSheetRunner

+ (id)defaultRunner
{
    static id defaultRunner = nil;

    if(defaultRunner == nil)
        defaultRunner = [[self alloc] init];
    return defaultRunner;
}

+ (int)runSheet:(NSWindow *)sheet modalForWindow:(NSWindow *)docWindow
{
    return [[self defaultRunner] runSheet:sheet modalForWindow:docWindow];
}

- (int)runSheet:(NSWindow *)sheet modalForWindow:(NSWindow *)docWindow
{
    int rc;

    [NSApp beginSheet:sheet modalForWindow:docWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    rc = [NSApp runModalForWindow:sheet];
    [sheet orderOut:self];
    return rc;
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)context
{
    [NSApp stopModalWithCode:returnCode];
}

@end

int SOPEXRunSheetModalForWindow(NSWindow *sheet, NSWindow *window)
{
    return [[SOPEXSheetRunner defaultRunner] runSheet:sheet modalForWindow:window];
}
