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
// $Id: SOPEXTextView.m,v 1.2 2004/04/09 18:53:02 znek Exp $
//  Created by znek on Thu Apr 01 2004.


#import "SOPEXTextView.h"


@interface SOPEXTextView (PrivateAPI)
- (void)adjustStatusField;
@end


@implementation SOPEXTextView

- (void)awakeFromNib
{
    [self setErrorStatus:nil];
}

- (void)setErrorStatus:(NSError *)status
{
    if((status != nil) && (self->statusField != nil))
    {
        [self->statusField setStringValue:[status localizedDescription]];
        [self adjustStatusField];
        [self->statusField setHidden:NO];
        [[self window] makeFirstResponder:self->statusField];
    }
    else
    {
        [self->statusField setHidden:YES];
    }
}

- (void)adjustStatusField
{
    NSRect frame, sfFrame;

    frame = [[self superview] frame]; // superview is a clipview
    frame = [self convertRect:frame toView:[self->statusField superview]];
    [self->statusField sizeToFit];
    sfFrame = [self->statusField frame];
    sfFrame.origin.x = NSWidth(frame) - NSWidth(sfFrame) + 1.0;
    sfFrame.origin.y = NSMaxY(frame) - NSHeight(sfFrame) + 1.0;
    [self->statusField setFrame:sfFrame];
}

#if SOPEXTextViewNotifiesAboutResponderState
- (void)setDelegate:(id)delegate
{
    [super setDelegate:delegate];
    delegateFlags.respondsToWillBecomeFirstResponder = [delegate respondsToSelector:@selector(textViewWillBecomeFirstResponder:)];
    delegateFlags.respondsToWillResignFirstResponder = [delegate respondsToSelector:@selector(textViewWillResignFirstResponder:)];
}
#endif

- (BOOL)becomeFirstResponder
{
    BOOL yn;
    
    yn = [super becomeFirstResponder];
#if SOPEXTextViewNotifiesAboutResponderState
    if(yn && delegateFlags.respondsToWillBecomeFirstResponder)
        [[self delegate] textViewWillBecomeFirstResponder:self];
#endif
    [self->statusField setHidden:YES];
    return yn;
}

- (BOOL)resignFirstResponder
{
    BOOL yn;
    
    yn = [super resignFirstResponder];
#if SOPEXTextViewNotifiesAboutResponderState
    if(yn && delegateFlags.respondsToWillResignFirstResponder)
        [[self delegate] textViewWillResignFirstResponder:self];
#endif
    return yn;
}

- (void)mouseDown:(NSEvent *)_event
{
    if([_event modifierFlags] & NSControlKeyMask) {
        if([[self delegate] respondsToSelector:@selector(textView:handleRightClickEvent:)])
            if([[self delegate] textView:self handleRightClickEvent:_event])
                return;
    }
    [super mouseDown:_event];
}

- (void)rightMouseDown:(NSEvent *)_event
{
    if([[self delegate] respondsToSelector:@selector(textView:handleRightClickEvent:)])
        if([[self delegate] textView:self handleRightClickEvent:_event])
            return;
    [super rightMouseDown:_event];
}

@end
