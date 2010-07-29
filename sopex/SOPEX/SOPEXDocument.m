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
// $Id: SOPEXDocument.m,v 1.3 2004/04/09 18:53:02 znek Exp $
//  Created by znek on Fri Mar 26 2004.


#import "SOPEXDocument.h"
#import "SOPEXTextView.h"


@implementation SOPEXDocument

#pragma mark -
#pragma mark ### INIT & DEALLOC ###


- (id)init {
    self = [super init];
    if (self) {
        self->typeTextViewLUT = [[NSMutableDictionary alloc] init];
        self->undoManagerLUT = [[NSMutableDictionary alloc] init];
        self->documentEncoding = NSUTF8StringEncoding;
    }
    return self;
}

- (id)initWithPath:(NSString *)_path
        controller:(NSObject<SOPEXDocumentController> *)_controller
{
    if(self) {
        self->controller = _controller;
        [self initWithPath:_path];
        [self revertChanges];
    }
    return self;
}

- (id)initWithPath:(NSString *)_path {
    self = [self init];
    if(self) {
        NSAssert(self->controller != nil, @"controller is not set! This indicates wrong initialization order!");
        self->path = [_path retain];
    }
    return self;
}

- (void)dealloc {
    [self->path release];
    [self->typeTextViewLUT release];
    [self->undoManagerLUT release];
    [super dealloc];
}


#pragma mark -
#pragma mark ### ACCESSORS ###


- (NSString *)path {
    return self->path;
}

- (NSArray *)fileTypes {
    [NSException raise:NSGenericException format:@"%s SUBCLASS RESPONSIBILITY!", __PRETTY_FUNCTION__];
    return nil;
}

- (SOPEXTextView *)textViewForFileType:(NSString *)fileType {
    SOPEXTextView *textView;

    textView = [self->typeTextViewLUT objectForKey:fileType];
    if(textView == nil)
    {
        NSUndoManager *undoManager;

        textView = [self->controller document:self textViewForType:fileType];
        [self->typeTextViewLUT setObject:textView forKey:fileType];

        undoManager = [[NSUndoManager alloc] init];
        [self->undoManagerLUT setObject:undoManager forKey:fileType];
        [undoManager release];
    }
    return textView;
}

- (NSString *)loadRepresentationForFileType:(NSString *)fileType {
    NSData *data;
    
    data = [NSData dataWithContentsOfFile:[self fullPathForFileType:fileType]];
    return [[[NSString alloc] initWithData:data encoding:self->documentEncoding] autorelease];
}

- (NSString *)fullPathForFileType:(NSString *)fileType {
    return self->path;
}

- (NSData *)representationForFileType:(NSString *)fileType {
    NSTextView *textView;
    NSData *representation;
    
    textView = [self textViewForFileType:fileType];
    representation = [[textView string] dataUsingEncoding:self->documentEncoding];
    return representation;
}

- (BOOL)hasChanges {
    NSEnumerator *umEnum;
    NSUndoManager *undoManager;

    umEnum = [self->undoManagerLUT objectEnumerator];
    while((undoManager = [umEnum nextObject]) != nil)
        if([undoManager canUndo])
            return YES;
    return NO;
}

- (BOOL)performSave {
    NSArray *fileTypes;
    unsigned i, count;
    
    fileTypes = [self fileTypes];
    count = [fileTypes count];
    for(i = 0; i < count; i++) {
        NSString *fileType;
        NSData *representation;
        
        fileType = [fileTypes objectAtIndex:i];
        representation = [self representationForFileType:fileType];
        if(![representation writeToFile:[self fullPathForFileType:fileType] atomically:YES])
            return NO;
    }
    
    for(i = 0; i < count; i++) {
        NSString *fileType;
        NSError *status;
        SOPEXTextView *textView;
        
        fileType = [fileTypes objectAtIndex:i];
        textView = [self textViewForFileType:fileType];
        status = [self validateRepresentationForFileType:fileType];
        if(status != nil)
            [self->controller document:self didValidateWithError:status forType:fileType];
        [textView setErrorStatus:status];
#if 1
        [[textView undoManager] removeAllActions];
#endif
    }

    return YES;
}

- (void)revertChanges {
    NSArray *fileTypes;
    unsigned i, count;
    
    fileTypes = [self fileTypes];
    count = [fileTypes count];
    for(i = 0; i < count; i++)
    {
        NSString *fileType, *representation;
        NSTextView *textView;

        fileType = [fileTypes objectAtIndex:i];
        textView = [self textViewForFileType:fileType];
        representation = [self loadRepresentationForFileType:fileType];
        [textView setString:representation];
        [[textView undoManager] removeAllActions];
    }
}

- (NSError *)validateRepresentationForFileType:(NSString *)fileType {
    return nil;
}


#pragma mark -
#pragma mark ### TEXTVIEW DELEGATE ###


- (NSUndoManager *)undoManagerForTextView:(NSTextView *)textView {
    NSString *type;

    type = [[self->typeTextViewLUT allKeysForObject:textView] lastObject];
    return [self->undoManagerLUT objectForKey:type];
}

- (void)textDidChange:(NSNotification *)notification {
    [self performSelector:@selector(_delayedCheckForDocumentEdited:) withObject:[notification object] afterDelay:0.1];
}

- (void)_delayedCheckForDocumentEdited:(SOPEXTextView *)textView {
    [[textView window] setDocumentEdited:[self hasChanges]];
}

#if 0
- (void)textViewWillBecomeFirstResponder:(SOPEXTextView *)textView {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)textViewWillResignFirstResponder:(SOPEXTextView *)textView {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}
#endif

@end
