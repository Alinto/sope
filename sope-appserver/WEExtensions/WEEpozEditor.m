/*
  Copyright (C) 2003-2004 SKYRIX Software AG

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

/*
  Note: Its very important that the URLs generated properly match the
        appname! Otherwise you will get security exceptions in JavaScript
        on the client side (probably depends on the browser).
        This also implies, that WOResourcePrefix cannot be used in conjunction
        with Epoz.
*/

#include <NGObjWeb/WODynamicElement.h>

@interface WEEpozEditor : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *name;
  WOAssociation *value;
  WOAssociation *disabled;
  WOAssociation *rows;
  WOAssociation *cols;
  WOAssociation *epozCharset; /* def: iso-8859-1 */
  WOAssociation *epozButtonStyle;
  WOAssociation *epozStyle;
}

@end

#include <NGObjWeb/WEClientCapabilities.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@implementation WEEpozEditor

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_root {

  if ((self = [super initWithName:_name associations:_config template:_root])) {
    self->containsForm = YES;
    self->name     = OWGetProperty(_config, @"name");
    self->value    = OWGetProperty(_config, @"value");
    self->disabled = OWGetProperty(_config, @"disabled");
    self->rows     = OWGetProperty(_config, @"rows");
    self->cols     = OWGetProperty(_config, @"cols");
    
    self->epozCharset     = OWGetProperty(_config, @"charset");
    self->epozStyle       = OWGetProperty(_config, @"style");
    self->epozButtonStyle = OWGetProperty(_config, @"buttonstyle");
  }
  return self;
}

- (void)dealloc {
  [self->epozCharset     release];
  [self->epozButtonStyle release];
  [self->epozStyle       release];
  [self->rows     release];
  [self->cols     release];
  [self->name     release];
  [self->value    release];
  [self->disabled release];
  [super dealloc];
}

/* form support */

static NSString *OWFormElementName(WEEpozEditor *self, WOContext *_ctx) {
  NSString *name;
  
  if (self->name == nil) 
    return [_ctx elementID];
  
  if ((name = [self->name stringValueInComponent:[_ctx component]]))
    return name;

  [[_ctx component]
             logWithFormat:
               @"WARNING: in element %@, 'name' attribute configured (%@),"
               @"but no name assigned (using elementID as name) !",
               self, self->name];
  return [_ctx elementID];
}

// ******************** responder ********************

- (id)parseFormValue:(id)_value inContext:(WOContext *)_ctx {
  return _value;
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *formName;
  id formValue = nil;
  
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;
  
  formName = OWFormElementName(self, _ctx);
  
  if ((formValue = [_req formValueForKey:formName])) {
#if DEBUG && 0
    NSLog(@"%s(%@): form=%@ ctx=%@ value=%@ ..", __PRETTY_FUNCTION__,
	  [_ctx elementID], formName, [_ctx contextID], formValue);
#endif
    
    if ([self->value isValueSettable]) {
      formValue = [self parseFormValue:formValue inContext:_ctx];
      [self->value setStringValue:formValue inComponent:[_ctx component]];
    }
#if DEBUG
    else {
      NSLog(@"%s: form value is not settable: %@", __PRETTY_FUNCTION__,
            self->value);
    }
#endif
  }
}

- (BOOL)isDebuggingEnabled {
  return NO;
}

- (BOOL)isEpozBrowserInContext:(WOContext *)_ctx {
  WEClientCapabilities *cc;
  
  if ((cc = [[_ctx request] clientCapabilities]) == nil) {
    [self debugWithFormat:@"WARNING: missing client capabilities object!"];
    return YES;
  }
  
  if ([cc isInternetExplorer]) {
    if ([cc majorVersion] <= 4) {
      [self debugWithFormat:@"disable Epoz with IE <5"];
      return NO;
    }
    if ([cc majorVersion] == 5 && [cc minorVersion] <= 5) {
      [self debugWithFormat:@"disable Epoz with IE <5.5"];
      return NO;
    }
    [self debugWithFormat:@"enable Epoz with IE >=5.5"];
    return YES;
  }
  
  if ([cc isMozilla] || [cc isNetscape]) {
    [self debugWithFormat:@"enable Epoz with Mozilla: %@", cc];
    return YES;
  }
  
  [self debugWithFormat:@"does not use Epoz with this browser: %@", cc];
  return NO;
}

- (NSString *)stringValueInContext:(WOContext *)_ctx {
  BOOL     removeCR = NO;
  NSString *ua;
  NSString *v;
  
  v = [[self->value valueInComponent:[_ctx component]] stringValue];
  if (![v isNotEmpty])
    return v;
    
  ua = [[_ctx request] headerForKey:@"user-agent"];
  if ([ua rangeOfString:@"Opera"].length > 0)
    removeCR = YES;
    
  if (removeCR)
    v = [v stringByReplacingString:@"\r" withString:@""];
  
  return v;
}

- (void)appendTextAreaToResponse:(WOResponse *)_response 
  inContext:(WOContext *)_ctx 
{
  WOComponent *sComponent;
  NSString *v;
  NSString *r, *c;
  
  sComponent = [_ctx component];
  v = [self stringValueInContext:_ctx];
  r = [self->rows  stringValueInComponent:sComponent];
  c = [self->cols  stringValueInComponent:sComponent];
  
  [_response appendContentString:@"<textarea name=\""];
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  [_response appendContentString:@"\""];
  if (r > 0) {
    [_response appendContentString:@" rows=\""];
    [_response appendContentString:r];
    [_response appendContentString:@"\""];
  }
  if (c > 0) {
    [_response appendContentString:@" cols=\""];
    [_response appendContentString:c];
    [_response appendContentString:@"\""];
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    [_response appendContentCharacter:' '];
    [_response appendContentString:
      [self->otherTagString stringValueInComponent:sComponent]];
  }
  [_response appendContentString:@">"];
  
  if ([v isNotEmpty])
    [_response appendContentHTMLString:v];
  
  [_response appendContentString:@"</textarea>"];
}

- (WOResourceManager *)resourceManagerInContext:(WOContext *)_ctx {
  WOResourceManager *rm;
  
  if ((rm = [[_ctx component] resourceManager]) == nil)
    rm = [[_ctx application] resourceManager];
  return rm;
}
- (NSString *)urlForEpozResourceNamed:(NSString *)_name 
  inContext:(WOContext *)_ctx
{
  WOResourceManager *rm;
  NSArray  *languages;
  
  rm = [self resourceManagerInContext:_ctx];
  languages = [_ctx hasSession] ? [[_ctx session] languages] : (NSArray *)nil;
  
  return [rm urlForResourceNamed:_name inFramework:nil
             languages:languages request:[_ctx request]];
}

- (void)appendEpozScript:(NSString *)_scriptName
  toResponse:(WOResponse *)_response 
  inContext:(WOContext *)_ctx 
{
  NSString *src;
  
  src = [self urlForEpozResourceNamed:_scriptName inContext:_ctx];
  [_response appendContentString:@"<script language=\"JavaScript\""];
  [_response appendContentString:@" type=\"text/javascript\""];
  [_response appendContentString:@" src=\""];
  [_response appendContentHTMLAttributeValue:src];
  [_response appendContentString:@"\"></script>\n"];
}

- (NSString *)epozImageURLInContext:(WOContext *)_ctx {
  /*
    Note: Epoz takes the directory where the resources are located, not
          individual pointers. This also means that you need to have all
          Epoz resources in the directory which contains the 
          "epoz_button_bold.gif" (which is used as the "reference" point
          to the active buttons).
   */
  NSString *src;
  NSRange  r;
  
  src = [self urlForEpozResourceNamed:@"epoz_button_bold.gif" inContext:_ctx];
  r = [src rangeOfString:@"/" options:(NSBackwardsSearch | NSLiteralSearch)];
  if (r.length > 0)
    src = [src substringToIndex:(r.location + r.length)];
  
  return src;
}
- (NSString *)epozToolboxURLInContext:(WOContext *)_ctx {
  /* TODO: replace */
  // return @"/epoz/WebServerResources/toolbox";
  return [self urlForEpozResourceNamed:@"epoz_toolbox.html" inContext:_ctx];
}
- (NSString *)epozCSSURLInContext:(WOContext *)_ctx {
  return [self urlForEpozResourceNamed:@"epoz.css" inContext:_ctx];
}

- (void)appendEpozToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString *v, *tmp;
  
  sComponent = [_ctx component];
  v = [self stringValueInContext:_ctx];
  
  /* first, the background iframe */
  [_r appendContentString:@"<iframe id=\"EpozIFrame\""];
  [_r appendContentString:@" style=\""];
  [_r appendContentString:@"position: absolute;"];
  [_r appendContentString:@" visibility: hidden;"];
  [_r appendContentString:@" width: 0px; height: 0px;"];
  [_r appendContentString:@"\"></iframe>\n"];
  
  /* the language mappings */
  [self appendEpozScript:@"epoz_lang_en.js" 
        toResponse:_r inContext:_ctx];
  
  /* the processing JavaScripts */
  [self appendEpozScript:@"epoz_script_widget.js"
        toResponse:_r inContext:_ctx];
  [self appendEpozScript:@"epoz_script_detect.js" 
        toResponse:_r inContext:_ctx];
  [self appendEpozScript:@"epoz_script_main.js" 
        toResponse:_r inContext:_ctx];
  
  /* 
     Start Epoz
    """ Create an Epoz-Wysiwyg-Editor.
    
        name : the name of the form-element which submits the data
        data : the data to edit
        toolbox : a link to a HTML-Page which delivers additional tools
        lang: a code for the language-file (en,de,...)
        path : path to Epoz-Javascript. Needed mainly for Plone (portal_url).
        widget: You can specify a path to an alternative JavaScript for
                epoz_script_widget.js
        style : style-definition for the editor-area
        button : style-definiton for buttons
        
        If Epoz can't create a Rich-Text-Editor, a simple textarea is created.
    """
  */
  
  [_r appendContentString:
        @"<script language=\"JavaScript\" type=\"text/javascript\"><!--\n"];
  [_r appendContentString:@"InitEpoz("];

  /* name */
  [_r appendContentString:@"'"];
  [_r appendContentString:OWFormElementName(self, _ctx)];
  [_r appendContentString:@"',"];
  
  /* value */
  [_r appendContentString:@"'"];
  {
    /* TODO: escape value, is that enough? */
    NSString *jsv;
    
    jsv = v;
    jsv = [jsv stringByReplacingString:@"'"  withString:@"\\'"];
    jsv = [jsv stringByReplacingString:@"\n" withString:@"\\n"];
    jsv = [jsv stringByReplacingString:@"\r" withString:@""];
    [_r appendContentString:jsv];
  }
  [_r appendContentString:@"',"];
  
  /* image path */
  [_r appendContentString:@"'"];
  [_r appendContentString:[self epozImageURLInContext:_ctx]];
  [_r appendContentString:@"',"];
  
  /* toolbox path */
  [_r appendContentString:@"'"];
  [_r appendContentString:[self epozToolboxURLInContext:_ctx]];
  [_r appendContentString:@"',"];

  if ((tmp = [self->epozStyle stringValueInComponent:sComponent]) == nil)
    tmp = @"width: 590px; height: 250px; border: 1px solid #000000;";
  [_r appendContentString:@"'"];
  [_r appendContentString:tmp];
  [_r appendContentString:@"',"];

  if ((tmp=[self->epozButtonStyle stringValueInComponent:sComponent])==nil) {
    tmp = 
      @"background-color: #EFEFEF; border: 1px solid #A0A0A0; "
      @"cursor: pointer; margin-right: 1px; margin-bottom: 1px;";
  }
  [_r appendContentString:@"'"];
  [_r appendContentString:tmp];
  [_r appendContentString:@"',"];
  
  /* CSS path */
  [_r appendContentString:@"'"];
  [_r appendContentString:[self epozCSSURLInContext:_ctx]];
  [_r appendContentString:@"',"];
  
  /* charset */
  if ((tmp = [self->epozCharset stringValueInComponent:sComponent]) == nil)
    tmp = @"iso-8859-1";
  [_r appendContentString:@"'"];
  [_r appendContentString:tmp];
  [_r appendContentString:@"'"];
  
  [_r appendContentString:@");\n"];
  [_r appendContentString:@"//-->\n</script>"];
  
  /* fallback if scripting is disabled */
  [_r appendContentString:@"<noscript>"];
  [self appendTextAreaToResponse:_r inContext:_ctx];
  [_r appendContentString:@"</noscript>"];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) return;

  if ([self isEpozBrowserInContext:_ctx])
    [self appendEpozToResponse:_response inContext:_ctx];
  else
    [self appendTextAreaToResponse:_response inContext:_ctx];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:64];
  
  if (self->value)    [str appendFormat:@" value=%@",    self->value];
  if (self->name)     [str appendFormat:@" name=%@",     self->name];
  if (self->disabled) [str appendFormat:@" disabled=%@", self->disabled];
  
  if (self->rows) [str appendFormat:@" rows=%@", self->rows];
  if (self->cols) [str appendFormat:@" cols=%@", self->cols];
  
  return str;
}

@end /* WEEpozEditor */
