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
// $Id: SOPEXStatisticsController.m,v 1.2 2004/05/02 16:27:46 znek Exp $
//  Created by znek on Thu Feb 12 2004.

#import "SOPEXStatisticsController.h"


@interface SOPEXStatisticsController (PrivateAPI)
- (void)parseXMLData:(NSData *)xmlData;
- (void)setCurrentPageKey:(NSString *)key;
@end


@implementation SOPEXStatisticsController

#pragma mark -
#pragma mark ### INIT & DEALLOC ###

- (id)initWithApplicationURL:(NSString *)url
{
    NSString *path;
    NSData *data;

    [super init];
    
    [NSBundle loadNibNamed:@"SOPEXStats" owner:self];
    NSAssert(self->window != nil, @"Problem loading SOPEXStats.nib!");

    self->applicationURL = [[NSURL URLWithString:url] retain];
    self->statsURL = [[NSURL URLWithString:[NSString stringWithFormat:@"%@/x/WOStats", url]] retain];

    [self->baseURLTextField setStringValue:[self->applicationURL description]];

    path = [[NSBundle bundleForClass:isa] pathForResource:@"SOPEXStatisticsNatLang" ofType:@"plist"];
    NSAssert(path != nil, @"Couldn't find SOPEXStatisticsNatLang.plist!");
    data = [NSData dataWithContentsOfFile:path];
    NSAssert(data != nil, @"Couldn't load SOPEXStatisticsNatLang.plist!");
    self->natLangDict = [[NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL] retain];

    self->applicationStats = [[NSMutableArray alloc] initWithCapacity:20];
    self->pageNames = [[NSMutableArray alloc] initWithCapacity:20];
    self->statsForPageNameLUT = [[NSMutableDictionary alloc] initWithCapacity:20];
    return self;
}

- (void)dealloc
{
    [self->window orderOut:self];
    [self setCurrentPageKey:nil];
    [self->applicationStats release];
    [self->pageNames release];
    [self->statsForPageNameLUT release];
    [self->natLangDict release];
    [self->applicationURL release];
    [self->statsURL release];
    [super dealloc];
}


#pragma mark -
#pragma mark ### PRIVATE ###


- (void)parseXMLData:(NSData *)xmlData
{
    NSXMLParser *parser;
    
    parser = [[NSXMLParser alloc] initWithData:xmlData];
    [parser setDelegate:self];
    
    [self->applicationStats removeAllObjects];
    [self->pageNames removeAllObjects];
    [self->statsForPageNameLUT removeAllObjects];

    [self setCurrentPageKey:nil];
    self->characterBuffer = [[NSMutableString alloc] init];

    [parser parse];
    if([parser parserError] != nil)
    {
        NSLog(@"%s PARSER ERROR! error:%@", __PRETTY_FUNCTION__, [[parser parserError] localizedDescription]);
    }
    [parser release];

    [self->characterBuffer release];
    self->characterBuffer = nil;

    [self->applicationStatsTableView reloadData];
    [self->pageStatsOutlineView reloadData];
}


#pragma mark -
#pragma mark ### ACTIONS ###


- (IBAction)orderFront:(id)sender {
    [self->window makeKeyAndOrderFront:sender];
    [self performRefresh:self];
}

- (IBAction)close:(id)sender {
  [self->window close];
}

- (IBAction)performRefresh:(id)sender {
    NSURLRequest *request;
    NSData *xmlStats;

    [self->refreshButton setEnabled:NO];
    [self->refreshProgressIndicator startAnimation:self];
    
    // stats = [self->statsURL resourceDataUsingCache:NO];
    // this leads to mayhem, as NSURL's resourceDataUsingCache: method boasts about being
    // able to decompress gzip'ed data, but doesn't do it automatically

    request = [NSURLRequest requestWithURL:self->statsURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    NSLog(@"%s retrieving from URL:%@", __PRETTY_FUNCTION__, self->statsURL);
    xmlStats = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];

    NSLog(@"%s retrieved %d bytes.", __PRETTY_FUNCTION__, [xmlStats length]);
    [self parseXMLData:xmlStats];

    [self->refreshProgressIndicator stopAnimation:self];
    [self->refreshButton setEnabled:YES];
}

- (IBAction)openApplicationInBrowser:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:self->applicationURL];
}


/* Window handling */

- (BOOL)isVisible {
  return [self->window isVisible];
}

#pragma mark -
#pragma mark ### WINDOW DELEGATE ###


- (void)windowWillClose:(NSNotification *)_notif {
}


#pragma mark -
#pragma mark ### NSXMLPARSER DELEGATE ###


- (void)setCurrentPageKey:(NSString *)key
{
    [key retain];
    [self->currentPageKey release];
    self->currentPageKey = key;
    
    if(key != nil)
    {
        [self->pageNames addObject:key];

        self->currentStats = [[NSMutableArray alloc] initWithCapacity:20];
        [self->statsForPageNameLUT setObject:self->currentStats forKey:key];
        [self->currentStats release];
    }
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    if([elementName isEqualToString:@"page"])
    {
        [self setCurrentPageKey:[attributeDict objectForKey:@"name"]];
    }
    else if([elementName isEqualToString:@"application"])
    {
        [self->pidTextField setStringValue:[attributeDict objectForKey:@"pid"]];
        self->currentStats = self->applicationStats;
    }
    else if([elementName isEqualToString:@"pages"])
    {
    }
    [self->characterBuffer deleteCharactersInRange:NSMakeRange(0, [self->characterBuffer length])];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    NSMutableDictionary *currentStatDict;
    NSString *tmp;
    NSString *key;

    if([elementName isEqualToString:@"application"] || [elementName isEqualToString:@"page"] || [elementName isEqualToString:@"pages"])
        return;

    key = [self->natLangDict objectForKey:elementName];
    if(key == nil)
        key = elementName;
    if([key isEqualToString:@""])
        key = nil;

    if(key != nil)
    {
        currentStatDict = [[NSMutableDictionary alloc] initWithCapacity:2];
        [currentStatDict setObject:key forKey:@"property"];
        tmp = [self->characterBuffer copy];
        [currentStatDict setObject:tmp forKey:@"value"];
        [tmp release];
        [self->currentStats addObject:currentStatDict];
    }
    else
    {
        if([elementName isEqualToString:@"statisticsDate"])
        {
            tmp = [self->characterBuffer copy];
            [self->lastRefreshDateTextField setStringValue:tmp];
            [tmp release];
        }
        else
        {
            NSLog(@"%s Suppressing addition of elementName:%@", __PRETTY_FUNCTION__, elementName);
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [self->characterBuffer appendString:string];
}


#pragma mark -
#pragma mark ### NSTABLEVIEW DELEGATE ###


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self->applicationStats count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    return [[self->applicationStats objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}


#pragma mark -
#pragma mark ### NSTABLEVIEW DELEGATE ###


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if(item == nil)
        return [self->pageNames count];
    
    if([item isKindOfClass:[NSString class]])
        return [[self->statsForPageNameLUT objectForKey:item] count];
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(item == nil)
        return YES;
    return [self->pageNames containsObject:item];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    NSArray *statsList;
    
    if(item == nil)
        statsList = self->pageNames;
    else
        statsList = [self->statsForPageNameLUT objectForKey:item];
    return [statsList objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if([item isKindOfClass:[NSString class]]) {
        if([[tableColumn identifier] isEqualToString:@"name"])
            return item;
        else
            return nil;
    }
    return [item objectForKey:[tableColumn identifier]];
}

@end
