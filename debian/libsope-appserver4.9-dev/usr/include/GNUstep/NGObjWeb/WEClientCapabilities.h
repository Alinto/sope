/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#ifndef __WEExtensions_WEClientCapabilities_H__
#define __WEExtensions_WEClientCapabilities_H__

#import <Foundation/NSObject.h>

@class NSString;

@interface WEClientCapabilities : NSObject
{
  NSString *userAgent;
  
  unsigned short browser;
  unsigned short os;
  unsigned short cpu;
  unsigned char  browserMajorVersion;
  unsigned char  browserMinorVersion;
  
  struct {
    int acceptUTF8:1;
    int reserved:31;
  } flags;
}

/* accessors */

- (NSString *)userAgent;
- (NSString *)userAgentType;
- (NSString *)os;
- (NSString *)cpu;
- (unsigned char)majorVersion;
- (unsigned char)minorVersion;

/* browser capabilities */

- (BOOL)isJavaScriptBrowser;
- (BOOL)isVBScriptBrowser;
- (BOOL)isFastTableBrowser;
- (BOOL)isCSS1Browser;
- (BOOL)isCSS2Browser;
- (BOOL)ignoresCSSOnFormElements;
- (BOOL)isTextModeBrowser;
- (BOOL)isIFrameBrowser;
- (BOOL)isXULBrowser;
- (BOOL)isRobot;
- (BOOL)isDAVClient;
- (BOOL)isXmlRpcClient;
- (BOOL)isBLogClient;
- (BOOL)isRSSClient;

- (BOOL)doesSupportCSSOverflow;
- (BOOL)doesSupportDHTMLDragAndDrop;
- (BOOL)doesSupportXMLDataIslands;
- (BOOL)doesSupportUTF8Encoding;

/* user-agent (it's better to use ^capabilities !) */

- (BOOL)isInternetExplorer;
- (BOOL)isInternetExplorer5;
- (BOOL)isNetscape;
- (BOOL)isNetscape6;
- (BOOL)isLynx;
- (BOOL)isOpera;
- (BOOL)isAmaya;
- (BOOL)isEmacs;
- (BOOL)isWget;
- (BOOL)isWebFolder;
- (BOOL)isMozilla;
- (BOOL)isOmniWeb;
- (BOOL)isICab;
- (BOOL)isKonqueror;

/* OS */

- (BOOL)isWindowsBrowser;
- (BOOL)isLinuxBrowser;
- (BOOL)isMacBrowser;
- (BOOL)isSunOSBrowser;
- (BOOL)isUnixBrowser;
- (BOOL)isX11Browser;

@end

#include <NGObjWeb/WORequest.h>

@interface WORequest(ClientCapabilities)

/* the object is cached in the WORequest's userInfo */
- (WEClientCapabilities *)clientCapabilities;

@end

#include <NGObjWeb/WODynamicElement.h>

/*
  The following element uses JavaScript to find out even more about the client
  browser.
*/

@interface JSClientCapabilityDetector : WODynamicElement
{
  WOAssociation *formName;
  WOAssociation *clientCaps;
}
@end

#endif /* __WEExtensions_WEClientCapabilities_H__ */
