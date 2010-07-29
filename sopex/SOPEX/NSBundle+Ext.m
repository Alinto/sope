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
//  Created by znek on Sun May 02 2004.


#import "NSBundle+Ext.h"


@implementation NSBundle (SOPEXExt)

- (NSString *)pathForResourceWithURLPath:(NSString *)_urlPath
{
    static NSFileManager *fm = nil;
    NSRange r;
    NSString *resourcePath;

    if(fm == nil)
        fm = [[NSFileManager defaultManager] retain];

    // need to strip /Appname/WebServerResources/ first
    r = [_urlPath rangeOfString:@"WebServerResources"];
    if(r.location != NSNotFound)
        _urlPath = [_urlPath substringFromIndex:r.location + r.length];
    else if ([_urlPath hasPrefix:@"/"] && ([_urlPath length] > 1))
      _urlPath = [_urlPath substringFromIndex:1];

    resourcePath = [[self bundlePath] stringByAppendingPathComponent:_urlPath];
    if([fm fileExistsAtPath:resourcePath])
        return resourcePath;

    _urlPath = [_urlPath lastPathComponent];
    return [self pathForResource:[_urlPath stringByDeletingPathExtension]
                          ofType:[_urlPath pathExtension]];
}

@end
