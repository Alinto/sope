// $Id: SOPEXToolbarController.m,v 1.3 2004/05/02 16:27:46 znek Exp $

#import "SOPEXToolbarController.h"
#import <AppKit/AppKit.h>

@implementation SOPEXToolbarController

- (id)initWithIdentifier:(NSString *)_tid target:(id)_target {
    if ((self = [super init])) {
        self->toolbarID = [_tid copy];
        self->target    = _target;
    }
    return self;
}
- (id)init {
    return [self initWithIdentifier:nil target:nil];
}

- (void)dealloc {
    [self->toolbar      release];
    [self->toolbarID    release];
    [self->idToInfo     release];
    [self->cachedItems release];
    [super dealloc];
}

/* accessors */

- (NSToolbar *)toolbar {
    if (self->toolbar == nil) {
        self->toolbar = 
        [[NSToolbar alloc] initWithIdentifier:self->toolbarID];
        [self->toolbar setAllowsUserCustomization:YES];
        [self->toolbar setAutosavesConfiguration:YES];
        [self->toolbar setDisplayMode:NSToolbarDisplayModeDefault];
        [self->toolbar setDelegate:self];
    }
    return self->toolbar;
}

- (NSDictionary *)toolbarDictionary {
    NSString *p;
    
    if (self->idToInfo)
        return self->idToInfo;
    
    p = [[NSBundle bundleForClass:isa] 
          pathForResource:self->toolbarID ofType:@"toolbar"];
    if (p == nil) {
        NSLog(@"did not find %@.toolbar !", self->toolbarID);
        return nil;
    }
    self->idToInfo = [[NSDictionary alloc] initWithContentsOfFile:p];
    if (self->idToInfo == nil)
        NSLog(@"could not load %@.toolbar: %@", self->toolbarID, p);
    self->cachedItems = [[NSMutableDictionary alloc] initWithCapacity:[[self->idToInfo objectForKey:@"allowedItems"] count]];
    return self->idToInfo;
}

- (NSArray *)defaultItemIdentifiers {
    return [[self toolbarDictionary] objectForKey:@"defaultItems"];
}
- (NSArray *)allowedItemIdentifiers {
    return [[self toolbarDictionary] objectForKey:@"allowedItems"];
}
- (NSArray *)selectableItemIdentifiers {
    return [[self toolbarDictionary] objectForKey:@"selectableItems"];
}

- (NSDictionary *)infoForIdentifier:(NSString *)_itemID {
    return [[self toolbarDictionary] objectForKey:_itemID];
}

/* operations */

- (void)applyOnWindow:(NSWindow *)_window {
    [_window setToolbar:[self toolbar]];
}

/* toolbar delegate */

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdent 
 willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
    NSToolbarItem *toolbarItem;
    NSDictionary *itemInfo;
    NSString *s;
    
    if ((itemInfo = [self infoForIdentifier:itemIdent]) == nil)
        return nil;
    
    if ((toolbarItem = [self->cachedItems objectForKey:itemIdent]) != nil)
        return toolbarItem;
    
    toolbarItem = 
        [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];
    
    if ((s = [itemInfo objectForKey:@"initialState"]))
    {
        if ([s isEqualToString:@"disabled"])
            [toolbarItem setEnabled:NO];
    }
    else
    {
        [toolbarItem setEnabled:YES];
    }
    
    if ((s = [itemInfo objectForKey:@"label"]))
        [toolbarItem setLabel:s];
    if ((s = [itemInfo objectForKey:@"paletteLabel"]))
        [toolbarItem setPaletteLabel:s];
    else
        [toolbarItem setPaletteLabel:[toolbarItem label]];
    
    if ((s = [itemInfo objectForKey:@"toolTip"]))
        [toolbarItem setToolTip:s];
    else
        [toolbarItem setToolTip:[toolbarItem paletteLabel]];

    if ((s = [itemInfo objectForKey:@"imageName"]))
    {
        NSString *path = [[NSBundle bundleForClass:isa] pathForResource:[s stringByDeletingPathExtension] ofType:[s pathExtension]];
        if(path != nil)
        {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if(data != nil)
            {
                NSImage *image;
                
                image = [[NSImage alloc] initWithData:data];
                [toolbarItem setImage:image];
                [image release];
            }
            else
            {
                NSLog(@"%s cannot open image file at path:%@", __PRETTY_FUNCTION__, path);
            }
        }
        else
        {
            NSLog(@"%s cannot find image named:%@", __PRETTY_FUNCTION__, s);
        }
    }
    if ((s = [itemInfo objectForKey:@"action"])) {
        [toolbarItem setTarget:self->target];
        [toolbarItem setAction:NSSelectorFromString(s)];
    } 
    
    [self->cachedItems setObject:toolbarItem forKey:itemIdent];
    [toolbarItem release];

    return toolbarItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return [self defaultItemIdentifiers];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self allowedItemIdentifiers];
}
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return [self selectableItemIdentifiers];
}

@end /* SOPEXToolbarController */
