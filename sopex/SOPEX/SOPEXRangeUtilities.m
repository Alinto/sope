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
// $Id: SOPEXRangeUtilities.m,v 1.2 2004/05/02 16:27:46 znek Exp $
//  Created by znek on Tue Mar 23 2004.


#import "SOPEXRangeUtilities.h"


extern BOOL SOPEX_isValidTagNameCharacter(unichar character);

extern NSRange SOPEX_findOpenTagForRangeInString(NSRange range, NSString *string);
extern NSRange SOPEX_findMatchingClosingTagForRangeInString(NSRange range, NSString *string);
extern NSRange SOPEX_findClosingTagForRangeInString(NSRange range, NSString *string);
extern NSRange SOPEX_findMatchingOpenTagForRangeInString(NSRange range, NSString *string);


/* 'valid' is really bound to the SOPE context, here */
BOOL SOPEX_isValidTagNameCharacter(unichar character)
{
    static NSCharacterSet *validTagNameCharacterSet = nil;
    
    if(validTagNameCharacterSet == nil)
    {
        validTagNameCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-:.#?!"];
        [validTagNameCharacterSet retain];
    }
    
    return [validTagNameCharacterSet characterIsMember:character];
}

/* This implementation is pretty naive, it doesn't know SGML rules and doesn't perform any
other sophisticated matching. It works pretty well in real life, though. */
NSRange SOPEX_findMatchingTagForRangeInString(NSRange range, NSString *string)
{
    NSRange matchingRange;
    
    if((matchingRange = SOPEX_findOpenTagForRangeInString(range, string)).location != NSNotFound)
    {
        NSRange closingRange;
        
        closingRange = SOPEX_findMatchingClosingTagForRangeInString(matchingRange, string);
        if(closingRange.location == NSNotFound)
            return NSMakeRange(NSNotFound, 0);
        matchingRange = NSUnionRange(matchingRange, closingRange);
    }
    else if((matchingRange = SOPEX_findClosingTagForRangeInString(range, string)).location != NSNotFound)
    {
        NSRange openRange;
        
        openRange = SOPEX_findMatchingOpenTagForRangeInString(matchingRange, string);
        if(openRange.location == NSNotFound)
            return NSMakeRange(NSNotFound, 0);
        matchingRange = NSUnionRange(matchingRange, openRange);
    }
    return matchingRange;
}

NSRange SOPEX_findOpenTagForRangeInString(NSRange range, NSString *string)
{
    BOOL found;
    int left, right, count;

    if(range.location == NSNotFound)
        return NSMakeRange(NSNotFound, 0);
    
    if((range.length == 2) && ([[string substringWithRange:range] isEqualToString:@"</"]))
        return NSMakeRange(NSNotFound, 0);

    found = NO;
    left = range.location + 1; // offset 1 to right because we might have hit a '<'
    
    while(!found && left >= 0)
    {
        unichar charToLeft;
        
        charToLeft = [string characterAtIndex:--left];
        if (!SOPEX_isValidTagNameCharacter(charToLeft)) {
            if(charToLeft == '<')
                found = YES;
            else
                break;
	}
    }
    if(!found)
        return NSMakeRange(NSNotFound, 0);
    
    right = range.location + range.length;
    count = [string length];

    while(SOPEX_isValidTagNameCharacter([string characterAtIndex:right]) && right <= count)
        right++;

    return NSMakeRange(left, right - left);
}

NSRange SOPEX_findMatchingClosingTagForRangeInString(NSRange range, NSString *string)
{
    unsigned depth, loc, count;
    BOOL isCloseTag;
    unichar current;

    isCloseTag = NO;
    count = [string length];
    loc = range.location + range.length;
    
    current = [string characterAtIndex:range.location + 1];
    if((current == '!') && ([string characterAtIndex:range.location + 2] != '-'))
        depth = 0;
    else
        depth = 1;

    while(loc < count)
    {        
        current = [string characterAtIndex:loc];
        if(current == '<')
        {
            if((loc + 1) < count)
                if([string characterAtIndex:loc + 1] != '/')
                    depth++;
        }
        else if(current == '>')
        {
            if(isCloseTag)
                depth--;
            if(depth == 0)
                return NSUnionRange(range, NSMakeRange(loc, 1));
        }
        else if((current == '/') || (current == '-') || (current == '?'))
        {
            isCloseTag = YES;
        }
        else if(!SOPEX_isValidTagNameCharacter(current))
        {
            isCloseTag = NO;
        }
        loc++;
    }
    return NSMakeRange(NSNotFound, 0);
}

NSRange SOPEX_findClosingTagForRangeInString(NSRange range, NSString *string)
{
    return NSMakeRange(NSNotFound, 0);
}

NSRange SOPEX_findMatchingOpenTagForRangeInString(NSRange range, NSString *string)
{
    return NSMakeRange(NSNotFound, 0);
}

