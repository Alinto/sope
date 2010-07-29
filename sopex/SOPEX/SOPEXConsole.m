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

#include "SOPEXConsole.h"

@class NGLogEvent;

@interface SOPEXConsole (PrivateAPI)
- (NSFont *)stdoutFont;
- (NSFont *)stderrFont;
- (NSColor *)stdoutFontColor;
- (NSColor *)stderrFontColor;

- (void)appendLogEvent:(NGLogEvent *)_event;
@end

#include "SOPEXToolbarController.h"
#include "common.h"

@implementation SOPEXConsole

static NGLogEventFormatter *eventFormatter = nil;

+ (void)initialize {
  static BOOL     didInit = NO;
  
  if(didInit) return;
  didInit = YES;
  eventFormatter = [[NSClassFromString(@"SOPEXConsoleEventFormatter") alloc] init];
}

- (id)init {
  self = [super init];
  if(self) {
    [NSBundle loadNibNamed:@"SOPEXConsole" owner:self];
    NSAssert(self->window != nil, @"Problem loading SOPEXConsole.nib!");
    
    self->toolbar = [[SOPEXToolbarController alloc] initWithIdentifier:@"SOPEXConsole" target:self];
    [self->toolbar applyOnWindow:self->window];
    
    self->stdoutAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[self stdoutFont], NSFontAttributeName, [self stdoutFontColor], NSForegroundColorAttributeName, nil];
    self->stderrAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[self stderrFont], NSFontAttributeName, [self stderrFontColor], NSForegroundColorAttributeName, nil];
  }
  return self;
}

- (void)dealloc {
  [self->window orderOut:self];
  [self->stdoutAttributes release];
  [self->stderrAttributes release];
  [super dealloc];
}


/* console properties */

- (NSFont *)stdoutFont {
  return [NSFont fontWithName:@"Courier" size:12];
}
- (NSFont *)stderrFont {
  return [NSFont fontWithName:@"Courier" size:12];
}
- (NSColor *)stdoutFontColor {
  return [NSColor blackColor];
}
- (NSColor *)stderrFontColor {
  return [NSColor redColor];
}


/* window handling/delegate */

- (IBAction)orderFront:(id)sender {
  [self->window makeKeyAndOrderFront:sender];
}
- (IBAction)close:(id)sender {
  [self->window close];
}
- (void)windowWillClose:(NSNotification *)_notif {
}
- (BOOL)isVisible {
  return [self->window isVisible];
}


/* actions */

- (IBAction)clear:(id)sender {
  NSTextStorage *storage;
  
  storage = [self->text textStorage];
  [storage beginEditing];
  [storage deleteCharactersInRange:NSMakeRange(0, [storage length])];
  [storage endEditing];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)_item {
  return [self validateMenuItem:(id <NSMenuItem>)_item];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
  SEL action = [menuItem action];
  
  if(action == @selector(clear:))
    return [[self->text textStorage] length] > 0;
  return YES;
}

- (void)appendLogEvent:(NGLogEvent *)_event {
  NSTextStorage *storage;
  NSString      *msg;
  unsigned      loc;

  storage = [self->text textStorage];
  msg     = [eventFormatter formattedEvent:_event];

  [storage beginEditing];
  loc = [storage length];
  [storage replaceCharactersInRange:NSMakeRange(loc, 0) withString:msg];
  [storage replaceCharactersInRange:NSMakeRange([storage length], 0)
           withString:@"\n"];
  [storage setAttributes:self->stdoutAttributes
           range:NSMakeRange(loc, [msg length] + 1)];
  
  if([storage length] > 50 * 1024)
    [storage deleteCharactersInRange:NSMakeRange(0, [storage length] - 50 * 1024)];
  [storage endEditing];
  
  // scroll to bottom if verticalScroller is at bottom
  if([[(NSScrollView*)[[self->text superview] superview] verticalScroller] floatValue] == 1.0)
    [self->text scrollRangeToVisible:NSMakeRange([storage length], 1)];
}

@end
