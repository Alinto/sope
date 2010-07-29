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

#import "SOPEXBrowserController.h"
#import <WebKit/WebFrame.h>
#import <WebKit/WebBackForwardList.h>
#import <WebKit/WebDocument.h>
#import <WebKit/WebDataSource.h>
#import "SOPEXAppController.h"
#import "SOPEXToolbarController.h"
#import "SOPEXWebConnection.h"
#import "WebView+Ext.h"
#import "SOPEXBrowserWindow.h"
#import "SOPEXDocument.h"
#import "SOPEXWOXDocument.h"
#import "SOPEXWODocument.h"
#import "SOPEXSheetRunner.h"
#include "common.h"

#define DNC [NSNotificationCenter defaultCenter]
#define UD [NSUserDefaults standardUserDefaults]


@interface SOPEXBrowserController (PrivateAPI)
- (void)setStatus:(NSString *)_msg;
- (void)setStatus:(NSString *)_msg isError:(BOOL)isError;
- (void)flushDocument;
- (void)createDocumentFromResponse;
- (void)_selectTabWithIdentifier:(NSString *)identifier;
@end


@implementation SOPEXBrowserController

static unsigned controllersCount = 0;
static NSPoint  cascadeTopLeft   = {0, 0};

NSString *SOPEXApplicationTabIdentifier = @"application";
NSString *SOPEXWOTabIdentifier          = @"wo";
NSString *SOPEXWOXTabIdentifier         = @"wox";
NSString *SOPEXHTMLTabIdentifier        = @"html";
NSString *SOPEXHTTPTabIdentifier        = @"http";

static NGLogger *logger = nil;

+ (void)initialize {
  NGLoggerManager *lm;
  static BOOL     didInit = NO;
  
  if(didInit) return;
  didInit = YES;
  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey:@"SOPEXDebugEnabled"];
}

+ (BOOL)hasActiveControllers {
  return controllersCount != 0;
}

/* init & dealloc */

- (id)init {
  self = [super init];
  if(self) {
    NSString *autosaveName;

    [NSBundle loadNibNamed:@"SOPEXBrowserController" owner:self];
    NSAssert(self->mainWindow != nil,
             @"Problem loading SOPEXBrowserController.nib!");

    autosaveName = [NSString stringWithFormat:@"BrowserWindow%d",
                                              controllersCount];
    [self->mainWindow setFrameAutosaveName:autosaveName];
    controllersCount += 1;
  }
  return self;
}

- (void)release {
#warning !! FIXME
  /* This seems to be triggered by a bug in WebKit by the resource load
     delegate, after a successful load - it might be another problem,
     though.
  */
#if 0
   [self errorWithFormat:@"%s THIS SHOULD NEVER HAPPEN!!", __PRETTY_FUNCTION__];
#endif
}

- (void)dealloc {
  [self->responseHeaderValues release];
  [self->connection release];
  [self->toolbarController release];
  [self->document release];
  [super dealloc];
}


/* setup */

- (void)awakeFromNib {
  NSString *groupName;

  cascadeTopLeft = [self->mainWindow cascadeTopLeftFromPoint:cascadeTopLeft];
  groupName      = [NSString stringWithFormat:@"WebUI%d", controllersCount];
  [self->webView setGroupName:groupName];

  self->responseHeaderValues = [[NSMutableArray alloc] initWithCapacity:20];
  self->toolbarController    = [[SOPEXToolbarController alloc]
    initWithIdentifier:@"SOPEXWebUI"
    target:self];

  [self setStatus:nil];
  [self viewApplication:nil];
}


/* accessors */

- (void)setWebConnection:(SOPEXWebConnection *)_conn {
  ASSIGN(self->connection, _conn);
  if(logger)
    [self debugWithFormat:@"%s connection: %@",
                            __PRETTY_FUNCTION__,
                            self->connection];
}

- (WebView *)webView {
  return self->webView;
}

- (SOPEXWebConnection *)webConnection {
  return self->connection;
}

/* actions */

- (IBAction)orderFront:(id)sender {
  [self->mainWindow makeKeyAndOrderFront:sender];
}

- (IBAction)reload:(id)sender {
  if(sender == nil) {
    NSURLRequest *rq;
    
    rq = [NSURLRequest requestWithURL:[self->connection url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    if(logger)
      [self debugWithFormat:@"%s request: %@", __PRETTY_FUNCTION__, rq];
    [[self->webView mainFrame] loadRequest:rq];
  }
  else {
    [self->webView reload:self];
  }
  [self viewApplication:sender];
}

- (IBAction)back:(id)sender {
  [self->webView goBack];
}

- (IBAction)viewApplication:(id)sender {
  [self _selectTabWithIdentifier:SOPEXApplicationTabIdentifier];
}

- (IBAction)viewSource:(id)sender {
  NSString *componentName;
  
  componentName = [[self->document path] lastPathComponent];
  if([componentName hasSuffix:@"wo"]) {
    [self->woComponentNameField setStringValue:componentName];
    [self _selectTabWithIdentifier:SOPEXWOTabIdentifier];
  }
  else {
    [self->woxNameField setStringValue:componentName];
    [self _selectTabWithIdentifier:SOPEXWOXTabIdentifier];
  }
}

- (IBAction)viewHTML:(id)sender {
  WebDataSource *dataSource;
  id <WebDocumentRepresentation> representation;
  NSString *source;
  
  dataSource = [[self->webView mainFrame] dataSource];
  NSAssert(dataSource != nil, @"dataSource not yet committed?!");
  NSAssert([dataSource isLoading] == NO, @"dataSource not finished loading?!");
  
  representation = [dataSource representation];
  
  if([representation canProvideDocumentSource])
    source = [representation documentSource];
  else
    source = @"";
  
  [self->htmlView setString:source];
  [self _selectTabWithIdentifier:SOPEXHTMLTabIdentifier];
}

- (IBAction)viewHTTP:(id)sender {
  WebDataSource *dataSource;
  NSHTTPURLResponse *response;
  NSDictionary *headerFields;
  NSArray *headers;
  int count, i;
  
  dataSource = [[self->webView mainFrame] dataSource];
  response = (NSHTTPURLResponse *)[dataSource response];
  
  headerFields = [response allHeaderFields];
  headers = [headerFields allKeys];
  count = [headers count];
  
  [self->responseHeaderValues removeAllObjects];
  
  for(i = 0; i < count; i++) {
    NSString *header, *value;
    NSDictionary *headerValueInfo;
    
    header = [headers objectAtIndex:i];
    value = [headerFields objectForKey:header];
    headerValueInfo = [[NSDictionary alloc] initWithObjectsAndKeys:value,
      @"value", header, @"header", nil];
    [self->responseHeaderValues addObject:headerValueInfo];
    [headerValueInfo release];
  }
  
  [self->responseHeaderInfoTableView reloadData];
  [self _selectTabWithIdentifier:SOPEXHTTPTabIdentifier];
}

- (void)_selectTabWithIdentifier:(NSString *)identifier {
  [self->tabView selectTabViewItemWithIdentifier:identifier];
}

- (IBAction)saveDocument:(id)sender {
  if(self->document == nil)
    return;
  if([self->document hasChanges]) {
    if(![self->document performSave]) {
      NSBeep();
      return;
    }
    [self->mainWindow setDocumentEdited:NO];
  }
}

- (IBAction)revertDocumentToSaved:(id)sender {
  [self->document revertChanges];
  [self->mainWindow setDocumentEdited:NO];
}

- (IBAction)toggleToolbar:(id)sender {
  if([self->mainWindow toolbar] == nil)
    [self->toolbarController applyOnWindow:self->mainWindow];
  else
    [self->mainWindow setToolbar:nil];
}

- (IBAction)editInXcode:(id)sender {
  NSString *path;
  
  path = [self->document path];
  [[NSWorkspace sharedWorkspace] openFile:path withApplication:@"Xcode" andDeactivate:YES]; 
}


/* menu & toolbar */

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  return [self validateMenuItem:(id <NSMenuItem>)theItem];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)_item {
  SEL action = [_item action];
  NSString *tabId;

#if 0
  NSLog(@"%s action:%@", __PRETTY_FUNCTION__, NSStringFromSelector(action));
#endif
  if(action == @selector(back:))
    return [self->webView canGoBack];
  else if(action == @selector(saveDocument:) ||
          action == @selector(revertDocumentToSaved:))
  {
    return self->document == nil ? NO : [self->document hasChanges];
  }

  tabId = [[self->tabView selectedTabViewItem] identifier];
  if(action == @selector(viewApplication:)) {
    BOOL isOn = [tabId isEqualToString:SOPEXApplicationTabIdentifier];
    [_item setState:isOn ? NSOnState : NSOffState];
  }
  else if(action == @selector(viewSource:)) {
    BOOL isOn = ([tabId isEqualToString:SOPEXWOXTabIdentifier] ||
                 [tabId isEqualToString:SOPEXWOTabIdentifier]);
    [_item setState:isOn ? NSOnState : NSOffState];

    return self->document != nil ? YES : NO;
  }
  else if(action == @selector(viewHTML:)) {
    BOOL isOn;
    WebDataSource *dataSource;

    isOn = [tabId isEqualToString:SOPEXHTMLTabIdentifier];
    [_item setState:isOn ? NSOnState : NSOffState];
    dataSource = [[self->webView mainFrame] dataSource];
    if(dataSource == nil)
      return NO;
    return [dataSource isLoading] == NO;
  }
  else if(action == @selector(viewHTTP:)) {
    BOOL isOn = [tabId isEqualToString:SOPEXHTTPTabIdentifier];
    [_item setState:isOn ? NSOnState : NSOffState];
  }
  return YES;
}


/* SOPEXDocumentController PROTOCOL */

- (NSTextView *)document:(SOPEXDocument *)_document
  textViewForType:(NSString *)_fileType
{
  if([_document isKindOfClass:[SOPEXWODocument class]]) {
      if([_fileType isEqualToString:@"html"])
          return self->woSourceView;
      return self->woDefinitionView;
  }
  return self->woxSourceView;
}

- (void)document:(SOPEXDocument *)document
  didValidateWithError:(NSError *)error
  forType:(NSString *)fileType
{
  [self viewSource:self];
}


/* private api */

- (void)setStatus:(NSString *)_msg {
  [self setStatus:_msg isError:NO];
}

- (void)setStatus:(NSString *)_msg isError:(BOOL)_isError {
  if(_msg == nil)
      _msg = @"";
  [self->statusBarTextField setStringValue:_msg];
}

- (void)flushDocument {
  [self->document release];
  self->document = nil;
  [self->mainWindow setDocumentEdited:NO];
}

- (void)createDocumentFromResponse {
  WebDataSource     *dataSource;
  NSHTTPURLResponse *response;
  NSDictionary      *headerFields;
  NSString          *templatePath;

  dataSource = [[self->webView mainFrame] dataSource];
  response = (NSHTTPURLResponse *)[dataSource response];
  
  if([response isKindOfClass:[NSHTTPURLResponse class]]) {
    headerFields = [response allHeaderFields];
    // NOTE: WebKit cuddly-capses header keys!
    templatePath = [headerFields objectForKey:@"X-Sope-Template-Path"];
    if(templatePath == nil)
      return;
    
    if([templatePath hasSuffix:@"wo"])
      self->document = [[SOPEXWODocument alloc] initWithPath:templatePath
                                                controller:self];
    else
      self->document = [[SOPEXWOXDocument alloc] initWithPath:templatePath
                                                 controller:self];
  }
}


/* window delegate */


- (BOOL)windowShouldClose:(id)sender {
#if 0
  if(logger)
    [self debugWithFormat:@"%s sender:%@", __PRETTY_FUNCTION__, sender];
#endif
  
  if(sender != self->mainWindow)
    return YES;
  
  if(self->document != nil && [self->document hasChanges]) {
    id panel;
    int rc;
    
    panel = NSGetAlertPanel(
      NSLocalizedString(@"Do you want to save changes to the source code before closing?", "Title of the alert sheet when window should close but changes are still not saved"),
      NSLocalizedString(@"If you don\\u2019t save, your changes will be lost.", "Message of the alert sheet when unsaved changes are about to be lost"),
      NSLocalizedString(@"Save", "Default button text for the alert sheet"),
      NSLocalizedString(@"Don\\u2019t save", "Alternate button text for the alert sheet"),
      NSLocalizedString(@"Cancel", "Other button text for the alert sheet")
      );
    
    rc = SOPEXRunSheetModalForWindow(panel, self->mainWindow);
    NSReleaseAlertPanel(panel);
    
    // NSAlertOtherReturn == Cancel
    // NSAlertAlternateReturn == Don't save
    // NSAlertDefaultReturn == Save
    
    if(rc == NSAlertOtherReturn)
      return NO;
    if(rc == NSAlertDefaultReturn)
      [self saveDocument:self];
    [self flushDocument];
  }
  return YES;
}

- (void)windowWillClose:(NSNotification *)_notif {
  controllersCount -= 1;
  [[SOPEXAppController sharedController] browserControllerDidClose:self];
}

/* tableview datasource */

- (int)numberOfRowsInTableView:(NSTableView *)_tableView {
  return [self->responseHeaderValues count];
}

- (id)tableView:(NSTableView *)_tableView
  objectValueForTableColumn:(NSTableColumn *)_tableColumn
  row:(int)_rowIndex
{
  return [[self->responseHeaderValues objectAtIndex:_rowIndex]
                                      objectForKey:[_tableColumn identifier]];
}


/* WebResourceLoadDelegate */

- (id)webView:(WebView *)_sender 
  identifierForInitialRequest:(NSURLRequest *)_rq 
  fromDataSource:(WebDataSource *)_ds
{
  return [[_rq URL] absoluteString];
}

- (NSURLRequest *)webView:(WebView *)_sender 
  resource:(id)_id
  willSendRequest:(NSURLRequest *)_rq
  redirectResponse:(NSURLResponse *)_redirectResponse 
  fromDataSource:(WebDataSource *)_ds
{
  /* use that to patch resource requests to local files ;-) */
  NSURL    *url, *rurl;
  
  url = [_rq URL];
  if(logger)
    [self debugWithFormat:@"%s: %@ request: %@ url: %@",
                            __PRETTY_FUNCTION__,
                            _id,
                            _rq,
                            url];

  if (![self->connection shouldRewriteRequestURL:url])
    return _rq;
  
  if ((rurl = [self->connection rewriteRequestURL:url]) == nil)
    return _rq;
  if ([rurl isEqual:url])
    return _rq;
  
  return [NSURLRequest requestWithURL:rurl
                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                       timeoutInterval:5.0];
}

- (void)webView:(WebView *)_sender
  resource:(id)_rid 
  didReceiveContentLength:(unsigned)_length 
  fromDataSource:(WebDataSource *)_ds
{
    //NSLog(@"%s: %@ len: %d", __PRETTY_FUNCTION__, _rid, _length);
}

- (void)webView:(WebView *)_sender
  resource:(id)_rid 
  didFinishLoadingFromDataSource:(WebDataSource *)_ds
{
  NSURLResponse *r = [_ds response];
  
  if(logger) {
    [self debugWithFormat:@"%s: %@ ds: %@\n  data-len: %i\n  response: %@\n "
                            @"type: %@\n  enc: %@", 
                            __PRETTY_FUNCTION__, _rid, _ds,
                            [[_ds data] length], r, [r MIMEType],
                            [r textEncodingName]];
  }
  [self->connection processResponse:[_ds response] data:[_ds data]];
}

- (void)webView:(WebView *)_sender
  resource:(id)_rid
  didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)_c 
  fromDataSource:(WebDataSource *)_ds
{
  if(logger)
    [self debugWithFormat:@"%s: %@ ds: %@", __PRETTY_FUNCTION__, _rid, _ds];
}

- (void)webView:(WebView *)_sender 
  resource:(id)_identifier 
  didReceiveResponse:(NSURLResponse *)_response 
  fromDataSource:(WebDataSource *)_ds
{
  if (logger) {
    [self debugWithFormat:@"%s: view: %@\n  resource: %@\n  received: %@\n"
                            @"  datasource: %@\n  data-len: %i%s",
                            __PRETTY_FUNCTION__,
                            _sender, _identifier, _response, _ds, 
                            [[_ds data] length],
                            [_ds isLoading]? " LOADING" : ""];
  }
}


/* WebFrameLoadDelegate */


- (void)webView:(WebView *)sender
  didStartProvisionalLoadForFrame:(WebFrame *)frame
{
  if(self->document != nil && [self->document hasChanges]) {
    id panel;
    int rc;
    
    panel = NSGetAlertPanel(
      NSLocalizedString(@"Do you want to save changes to the source code before proceeding?", "Title of the alert sheet when user wants to proceed but changes are still not saved"),
      NSLocalizedString(@"If you don\\u2019t save, your changes will be lost.", "Message of the alert sheet when unsaved changes are about to be lost"),
      NSLocalizedString(@"Save", "Default button text for the alert sheet"),
      NSLocalizedString(@"Don\\u2019t save", "Alternate button text for the alert sheet"),
      NULL);
    
    rc = SOPEXRunSheetModalForWindow(panel, self->mainWindow);
    NSReleaseAlertPanel(panel);
    
    // NSAlertOtherReturn     == Cancel
    // NSAlertAlternateReturn == Don't save
    // NSAlertDefaultReturn   == Save

    if(rc == NSAlertDefaultReturn)
      [self saveDocument:self];
  }
  [self flushDocument];
  [self->progressIndicator startAnimation:self];
}

- (void)webView:(WebView *)sender
  didReceiveTitle:(NSString *)_title
  forFrame:(WebFrame *)_frame
{
  [self->mainWindow setTitle:_title];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
  [self->progressIndicator stopAnimation:self];
  
#if 0
#warning ** setFavIcon enabled ... doesnt really make sense
  [self->mainWindow setFavIcon:[sender pageIcon]];
#endif
  [self createDocumentFromResponse];
}

- (void)webView:(WebView *)sender
  didFailLoadWithError:(NSError *)error
  forFrame:(WebFrame *)frame
{
  [self->progressIndicator stopAnimation:self];
  [self setStatus:[error localizedDescription] isError:YES];
}

- (void)webView:(WebView *)sender
  didFailProvisionalLoadWithError:(NSError *)error
  forFrame:(WebFrame *)frame
{
  [self webView:sender didFailLoadWithError:error forFrame:frame];
}


/* WebView UI delegate */

- (BOOL)webViewIsStatusBarVisible:(WebView *)sender {
  return YES;
}

- (void)webView:(WebView *)sender
  mouseDidMoveOverElement:(NSDictionary *)_info
  modifierFlags:(unsigned int)_flags
{
  NSURL *url;
  
#if 0
  NSLog(@"%s _info:%@", __PRETTY_FUNCTION__, _info);
#endif
  
  
  url = [_info objectForKey:WebElementImageURLKey];
  if(url != nil) {
    NSString *altString;
    NSRect imageRect;
    NSImage *image;
    NSMutableString *status;
    
    altString = [_info objectForKey:WebElementImageAltStringKey];
    imageRect = [[_info objectForKey:WebElementImageRectKey] rectValue];
    image     = [_info objectForKey:WebElementImageKey];
    
    status = [NSMutableString string];
    
    if(altString == nil)
      altString = [url absoluteString];
    
    url = [_info objectForKey:WebElementLinkURLKey];
    if(url != nil)
      [status appendFormat:@"%@    ", [url absoluteString]];
    
    [status appendFormat:@"[%@]   (w:%.0f h:%.0f)",
                           altString,
                           imageRect.size.width, imageRect.size.height];
    if(NSEqualSizes([image size], imageRect.size) == NO) {
      NSSize size = [image size];
      [status appendFormat:@" -> scaled from (w:%.0f h:%.0f)!", size.width, size.height];
    }
    
    [self setStatus:status];
    return;
  }
  
  url = [_info objectForKey:WebElementLinkURLKey];
  if(url != nil) {
    [self setStatus:[url absoluteString]];
    return;
  }
  
  [self setStatus:nil];
}

- (WebView *)webView:(WebView *)sender
  createWebViewWithRequest:(NSURLRequest *)_rq
{
  SOPEXBrowserController *controller;
  NSURL                  *url;

  controller = [[SOPEXBrowserController alloc] init]; // leak
  url        = [_rq URL];
  if (url) {
    SOPEXWebConnection *conn;
    NSBundle           *bundle;

    bundle = [[self webConnection] localResourceBundle];
    conn   = [[SOPEXWebConnection alloc] initWithURL:url
                                         localResourceBundle:bundle];
    [controller setWebConnection:conn];
  }

  [[[controller webView] mainFrame] loadRequest:_rq];
  return [controller webView];
}

- (void)webViewShow:(WebView *)sender {
#if 0
  NSLog(@"%s sender:%@ webView:%@", __PRETTY_FUNCTION__, sender, self->webView);
#endif
  if (sender == self->webView)
    [self orderFront:self];
}


/* Logging */

- (id)debugLogger {
  return logger;
}

@end
