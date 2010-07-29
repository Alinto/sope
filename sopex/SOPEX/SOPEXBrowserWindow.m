/*
 Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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
// $Id: SOPEXBrowserWindow.m,v 1.3 2004/05/02 16:27:46 znek Exp $
//  Created by znek on Mon Mar 22 2004.


#import "SOPEXBrowserWindow.h"


#define USE_NSTheme_PRIVATE_API 0


#if USE_NSTheme_PRIVATE_API
@interface NSView (NSTheme_PrivateAPI_We_Know_Exists)
- (void)addFileButton:(id)fp8;
- (id)newFileButton;
@end


@implementation NSImageView (HACQUE_alert)
- (NSString *)representedFilename
{
    return nil;
}
@end
#endif


@interface SOPEXBrowserWindow (PrivateAPI)
- (NSView *)borderView;
- (NSRect)favIconFrameForTitle:(NSString *)_title;
@end


@implementation SOPEXBrowserWindow

#if 0
- (void)dealloc
{
    [self->favIconView release];
    [super dealloc];
}
#endif

- (NSView *)borderView
{
    return self->_borderView;
}

#if !USE_NSTheme_PRIVATE_API
- (NSRect)favIconFrameForTitle:(NSString *)_title
{
    NSDictionary *attrs;
    NSRect frame, bvFrame;
    float textWidth;
    
    attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName, nil];
    textWidth = [_title sizeWithAttributes:attrs].width;
    bvFrame = [[self borderView] frame];
    frame = NSMakeRect((NSMidX(bvFrame) - (textWidth / 2.0)) - 24, NSHeight(bvFrame) - 19, 16, 16);
    return frame;
}
#endif

- (void)setFavIcon:(NSImage *)_favIcon
{
#if 0
    if(self->favIconView == nil)
    {
#if !USE_NSTheme_PRIVATE_API
        self->favIconView = [[NSImageView alloc] initWithFrame:[self favIconFrameForTitle:[self title]]];
        [self->favIconView setAutoresizingMask:(NSViewMinYMargin | NSViewMinXMargin | NSViewMaxXMargin)];
#else
        self->favIconView = [[self borderView] newFileButton];
        [self->favIconView retain];
#endif

#if !USE_NSTheme_PRIVATE_API
        [[self borderView] addSubview:self->favIconView];
#else
        [[self borderView] addFileButton:self->favIconView];
#endif
        [self->favIconView release];
    }
    [self->favIconView setImage:_favIcon];
#endif
}

#if !USE_NSTheme_PRIVATE_API
- (void)setTitle:(NSString *)_title
{
    if(self->favIconView != nil)
    {
        [self->favIconView setFrame:[self favIconFrameForTitle:_title]];
        [[self borderView] setNeedsDisplay:YES];
    }
    [super setTitle:_title];
}
#endif

@end
