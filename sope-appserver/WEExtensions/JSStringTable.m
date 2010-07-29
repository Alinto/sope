/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/WODynamicElement.h>

/*
  JSStringTable
  
  Export a string table (usually a .strings file) to JavaScript.
  
  Note: this includes a direct action which makes all languages files
        publically accessible! As far as we could see this has no security
        implications.

  Note: be aware of WOResourceManager handling when using the link instead of
        inplace. The element has some special support for product resource
        managers, but always uses the application resource manager otherwise.
*/

@interface JSStringTable : WODynamicElement
{
  WOAssociation *name;
  WOAssociation *identifier;
  WOAssociation *framework;
  WOAssociation *languages;
  WOAssociation *inplace;
}

@end

#include <SoObjects/SoProductResourceManager.h>
#include <SoObjects/SoProductRegistry.h>
#include <SoObjects/SoProduct.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"
#include <time.h>

@implementation JSStringTable

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->name       = OWGetProperty(_config, @"name");
    self->identifier = OWGetProperty(_config, @"identifier");
    self->framework  = OWGetProperty(_config, @"framework");
    self->languages  = OWGetProperty(_config, @"languages");
    self->inplace    = OWGetProperty(_config, @"inplace");
  }
  return self;
}

- (void)dealloc {
  [self->inplace    release];
  [self->identifier release];
  [self->name       release];
  [self->framework  release];
  [self->languages  release];
  [super dealloc];
}

/* generate response */

+ (void)appendTable:(id)_table withIdentifier:(NSString *)_identifier
  doEscape:(BOOL)_htmlEscape
  toResponse:(WOResponse *)_response
{
  NSEnumerator *keys;
  NSString *key;
  BOOL isFirst;
  
  if (_table == nil) {
    [_response appendContentString:@"<!-- did not find JS string table -->"];
    return;
  }
  if (![_identifier isNotEmpty]) _identifier = @"WELabels";

  [_response appendContentString:@"var "];
  [_response appendContentString:_identifier];
  [_response appendContentString:@" = {\n"];
  
  isFirst = YES;
  keys = [_table keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    NSString *value;
    
    if (isFirst) isFirst = NO;
    else [_response appendContentString:@",\n"];
    
    value = [(NSDictionary *)_table objectForKey:key];
    
    /* escape value */
    value = [value stringByReplacingString:@"\"" withString:@"\\\""];
    
    [_response appendContentString:@"  \""];
    [_response appendContentHTMLString:key];
    [_response appendContentString:@"\": \""];
    [_response appendContentHTMLString:value];
    [_response appendContentString:@"\""];
  }
  [_response appendContentString:@"\n};\n"];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOResourceManager *rm;
  WOComponent       *sComponent;
  NSString          *lidentifier, *lname, *lfw;
  NSArray           *langs;

  if ([_ctx isRenderingDisabled]) return;

  sComponent = [_ctx component];
  lname      = [self->name stringValueInComponent:sComponent];
  if (![lname isNotEmpty]) lname = @"Localizable";

  lfw = [self->framework stringValueInComponent:sComponent];
  
  lidentifier = [self->identifier stringValueInComponent:sComponent];
  if (![lname isNotEmpty])
    lidentifier = [@"WELabels" stringByAppendingString:lname];
  
  if (self->languages != nil) {
    langs = [self->languages valueInComponent:sComponent];
    if ([langs isKindOfClass:[NSString class]])
      langs = [(NSString *)langs componentsSeparatedByString:@","];
  }
  else
    langs = [_ctx resourceLookupLanguages];
  
  if ((rm = [sComponent resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];

  if ([self->inplace boolValueInComponent:sComponent]) {
    /* generate table inline */
    id table;
    
    table = [rm stringTableWithName:lname inFramework:lfw
		languages:langs];

    if (table != nil) {
      [_response appendContentString:@"<script type=\"text/javascript\">\n"];
      [[self class] appendTable:table withIdentifier:lidentifier
		    doEscape:YES /* HTML escape */
		    toResponse:_response];
      [_response appendContentString:@"</script>"];
    }
    else {
      [_response appendContentString:
		   @"<!-- JSStringTable did not find string table: "];
      [_response appendContentHTMLString:lname];
      [_response appendContentString:@" / "];
      [_response appendContentHTMLString:lfw];
      [_response appendContentString:@" / "];
      [_response appendContentHTMLString:
		   [langs componentsJoinedByString:@","]];
      [_response appendContentString:@" -->"];
    }
  }
  else {
    /* generate link to table file */
    NSMutableDictionary *qd;
    NSString *url;
    id product = nil;
    
    if ([rm isKindOfClass:NSClassFromString(@"SoProductResourceManager")])
      product = [[rm valueForKey:@"container"] productName];
    
    qd = [[NSDictionary alloc] initWithObjectsAndKeys:
				 lname ? lname : (NSString *)@"", @"table",
			         lfw   ? lfw   : (NSString *)@"", @"framework",
			         lidentifier ? lidentifier : (NSString *)@"",
			         @"id",
			         product ? product : (id)@"",
			         @"product",
			         [langs componentsJoinedByString:@","],
			         @"languages",
			       nil];
    
    url = [_ctx directActionURLForActionNamed:@"JSStringTableAction/default"
		queryDictionary:qd];
    [qd release]; qd = nil;
    
    /* Note: we MUST use the app-resource manager since we cache info */
    [_response appendContentString:@"<script type=\"text/javascript\" src=\""];
    [_response appendContentString:url];
    [_response appendContentString:@"\"> </script>"];
  }
}

@end /* JSStringTable */

@interface JSStringTableAction : WODirectAction
@end

@implementation JSStringTableAction

static NSString *etag = nil;

- (id<WOActionResults>)defaultAction {
  WOResourceManager *rm = nil;
  WORequest  *rq;
  WOResponse *r;
  id         table;
  NSString   *s, *lname, *lfw, *productName;
  NSArray    *langs;
  
  if (etag == nil) {
    /* 
       Not a strictly correct etag, but should be ok. We assume that the app
       needs to restart for changes to take effect and that changes are global
       for all instances.
    */
    char buf[32];
    sprintf(buf, "\"stamp_%d\"", ((unsigned)time(NULL) - 1121785679));
    etag = [[NSString alloc] initWithCString:buf];
  }
  
  rq = [[self context] request];
  r  = [[self context] response];

  productName = [rq formValueForKey:@"product"];
  if ([productName isNotEmpty]) {
    rm = [[[SoProductRegistry sharedProductRegistry] 
	    productWithName:productName] resourceManager];
  }
  if (rm == nil)
    rm = [[WOApplication application] resourceManager];

  lname = [rq formValueForKey:@"table"];
  lfw   = [rq formValueForKey:@"framework"];
  langs = [[rq formValueForKey:@"languages"] componentsSeparatedByString:@","];
  
  table = [rm stringTableWithName:lname inFramework:lfw languages:langs];
  if (table == nil) {
    [r setStatus:404 /* Not Found */];
    [r appendContentString:@"Found no matching table"];

    [self warnWithFormat:@"RM %@ did not find string table %@ / %@ / %@",
	  rm,
	  lname, lfw, [langs componentsJoinedByString:@","]];
    
    return r;
  }
  
  [r setContentEncoding:NSUTF8StringEncoding];
  [r setHeader:@"application/x-javascript; charset=utf-8"
     forKey:@"content-type"];
  [r setHeader:etag                        forKey:@"etag"];
  
  /* check preconditions */
  
  s = [[[self context] request] headerForKey:@"if-none-match"];
  if (s && [s rangeOfString:etag].length > 0) {
    /* client already has the proper entity */
    [r setStatus:304 /* Not Modified */];
    return r;
  }
  
  /* send script */
  
  [[JSStringTable class] 
    appendTable:table withIdentifier:[rq formValueForKey:@"id"]
    doEscape:NO
    toResponse:r];
  return r;
}

@end /* JSStringTableAction */
