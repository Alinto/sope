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
// $Id: SOPEXWODocument.m,v 1.3 2004/04/09 18:53:02 znek Exp $
//  Created by znek on Fri Mar 26 2004.


#import "SOPEXWODocument.h"
#import "SOPEXRangeUtilities.h"
#import "SOPEXTextView.h"
#import "SOPEXContentValidator.h"


@implementation SOPEXWODocument

- (id)initWithPath:(NSString *)_path
{
    [super initWithPath:_path];
    self->componentName = [[[_path lastPathComponent] stringByDeletingPathExtension] retain];
    return self;
}

- (void)dealloc
{
    [self->componentName release];
    [super dealloc];
}

- (NSArray *)fileTypes
{
    return [NSArray arrayWithObjects:@"html", @"wod", nil];
}

- (NSString *)fullPathForFileType:(NSString *)fileType
{
    return [NSString stringWithFormat:@"%@/%@.%@", self->path, self->componentName, fileType];
}


#pragma mark -
#pragma mark ### VALIDATION ###


- (NSError *)validateRepresentationForFileType:(NSString *)fileType
{
    id content;
    NSError *status;

    content = [[self textViewForFileType:fileType] string];
    if([fileType isEqualToString:@"html"])
        status = [SOPEXContentValidator validateWOHTMLContent:content];
    else
        status = [SOPEXContentValidator validateWODContent:content];
    return status;
}

@end
