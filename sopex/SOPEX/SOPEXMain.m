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
// $Id: SOPEXMain.m,v 1.3 2004/05/02 16:27:46 znek Exp $
//  Created by znek on Fri Feb 13 2004.


#import <AppKit/AppKit.h>
#import <NGObjWeb/NGObjWeb.h>
#import "SOPEXConstants.h"


int SOPEXMain(NSString *appClassName, int argc, const char *argv[]) {
    NSAutoreleasePool *pool;
    NSUserDefaults    *ud;
    int               status;
    
    pool = [[NSAutoreleasePool alloc] init];
    ud   = [NSUserDefaults standardUserDefaults];
    [ud setObject:@".sopex" forKey:@"WOApplicationSuffix"];
    if(appClassName)
        [ud setObject:appClassName forKey:@"SOPEXWOApplicationClass"];
    status = NSApplicationMain(argc, argv);
    [pool release];
    return status;
}
