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
// $Id: SOPEXBrowserWindow.h,v 1.2 2004/03/26 19:05:23 znek Exp $
//  Created by znek on Mon Mar 22 2004.

#ifndef	__SOPEX_SOPEXBrowserWindow_H_
#define	__SOPEX_SOPEXBrowserWindow_H_

#import <AppKit/AppKit.h>


@interface SOPEXBrowserWindow : NSWindow
{
    NSImageView *favIconView;
}

- (void)setFavIcon:(NSImage *)_favIcon;

@end

#endif	/* __SOPEX_SOPEXBrowserWindow_H_ */
