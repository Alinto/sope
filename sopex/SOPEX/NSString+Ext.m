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
// $Id: NSString+Ext.m,v 1.2 2004/05/02 16:27:46 znek Exp $
//  Created by znek on Mon Mar 22 2004.

#import "NSString+Ext.h"

@implementation NSString (SOPEXExt)

- (BOOL)containsString:(NSString *)_other
{
    if(_other == nil)
        return NO;
    return [self rangeOfString:_other].location != NSNotFound;
}

@end
