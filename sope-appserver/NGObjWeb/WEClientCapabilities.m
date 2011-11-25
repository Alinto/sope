/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2006-2008 Helge Hess

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

#include <NGObjWeb/WEClientCapabilities.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOResponse.h>
#include <string.h>
#include "common.h"

#define WEUA_UNKNOWN            0
#define WEUA_IE                 1
#define WEUA_Netscape           2
#define WEUA_Lynx               3
#define WEUA_Opera              4
#define WEUA_Amaya              5
#define WEUA_Emacs              6
#define WEUA_Wget               7
#define WEUA_WebFolder          8
#define WEUA_Mozilla            9
#define WEUA_OmniWeb           10
#define WEUA_iCab              11
#define WEUA_Konqueror         12
#define WEUA_Links             13
#define WEUA_DAVFS             14
#define WEUA_CADAVER           15
#define WEUA_GOLIVE            16
#define WEUA_MACOSX_DAVFS      17
#define WEUA_Dillo             18
#define WEUA_JavaSDK           19
#define WEUA_PythonURLLIB      20
#define WEUA_AppleDAVAccess    21
#define WEUA_MSWebPublisher    22
#define WEUA_CURL              23
#define WEUA_Evolution         24
#define WEUA_MSOutlook         25
#define WEUA_MSOutlookExpress  26
#define WEUA_GNOMEVFS          27
#define WEUA_ZideLook          28
#define WEUA_Safari            29
#define WEUA_SOUP              30
#define WEUA_Entourage         31
#define WEUA_NetNewsWire       32
#define WEUA_xmlrpclib_py      33
#define WEUA_Morgul            34
#define WEUA_CFNetwork         35
#define WEUA_KungLog           36
#define WEUA_SOPE              37
#define WEUA_Ecto              38
#define WEUA_NewsFire          39
#define WEUA_Goliath           40
#define WEUA_PerlHTTPDAV       41
#define WEUA_Google            42
#define WEUA_WebDrive          43
#define WEUA_Sunbird           44
#define WEUA_PEAR_XMLRPC       45
#define WEUA_Cook_XMLRPCdotNET 46
#define WEUA_WDFS              47
#define WEUA_ZideOne_Outlook   48

#define WEOS_UNKNOWN   0
#define WEOS_WINDOWS   1
#define WEOS_LINUX     2
#define WEOS_MACOS     3
#define WEOS_SUNOS     4

#define WECPU_UNKNOWN  0
#define WECPU_IX86     1
#define WECPU_SPARC    2
#define WECPU_PPC      3

@interface WEClientCapabilities(Privates)
- (id)initWithRequest:(WORequest *)_request;
@end

@implementation WEClientCapabilities

- (id)initWithRequest:(WORequest *)_request {
  NSString *ac;
  const char *ua;
  const char *tmp;
  int defaultOS  = WEOS_UNKNOWN;
  int defaultCPU = WECPU_UNKNOWN;
  
  /* check charset */
  
  if ((ac = [_request headerForKey:@"accept-charset"])) {
    /* not really correct ..., eg could have quality "0" ! */
    ac = [ac lowercaseString];
    if ([ac rangeOfString:@"utf-8"].length > 0)
      self->flags.acceptUTF8 = 1;
  }
  
  /* process user-agent */
  
  self->userAgent = [[_request headerForKey:@"user-agent"] copy];
#if LIB_FOUNDATION_LIBRARY
  ua = [self->userAgent cString];
#else
  ua = [self->userAgent UTF8String];
#endif
  if (ua == NULL) {
    /* no user-agent, eg telnet */
    ua = "";
  }
  
  /* detect browser */
  
  if ((tmp = strstr(ua, "Opera"))) {
    /* Opera (can fake to be MSIE or Netscape) */
    self->browser = WEUA_Opera;

    /* go to next space */
    while (!isspace(*tmp) && (*tmp != '\0')) tmp++;
    /* skip spaces */
    while (isspace(*tmp) && (*tmp != '\0')) tmp++;
    
    self->browserMajorVersion = atoi(tmp);
    if ((tmp = index(tmp, '.'))) {
      tmp++;
      self->browserMinorVersion = atoi(tmp);
    }
  }
  else if (strstr(ua, "NeonConnection") != NULL || 
           strstr(ua, "ZIDEStore") != NULL ||
           strstr(ua, "ZideLook-Codeon") != NULL) {
    self->browser = WEUA_ZideLook;
    self->browserMinorVersion = 0;
    self->browserMajorVersion = 0;
  }
  else if (strstr(ua, "ZideOne/") != NULL) {
    self->browser = WEUA_ZideOne_Outlook;
    self->browserMinorVersion = 0;
    self->browserMajorVersion = 0;
  }
  else if ((tmp = strstr(ua, "Safari/"))) {
    /* Hm, Safari says it is a Mozilla/5.0 ? */
    int combinedVersion;
    self->browser = WEUA_Safari;
    tmp += 7; /* skip "Safari/" */
    combinedVersion = atoi(tmp);
    /* well, don't know how this is supposed to work? 100=v1.1 */
    if (combinedVersion == 100 /* 100 is v1.1 */) {
      self->browserMajorVersion = 1;
      self->browserMinorVersion = 1;
    }
    else {
      /* watch for upcoming versions ... */
      self->browserMajorVersion = combinedVersion / 100;
    }
  }
  else if ((tmp = strstr(ua, "Sunbird/"))) {
    /* Sunbird says it is a Mozilla */
    self->browser = WEUA_Sunbird;
    tmp += 8; /* skip "Sunbird/" */
    
    self->browserMajorVersion = atoi(tmp);
    if ((tmp = index(tmp, '.'))) {
      tmp++;
      self->browserMinorVersion = atoi(tmp);
    }
  }
  else if (strstr(ua, "Outlook-Express/")) {
    /* Outlook Express 5.5 mailbox access via http */
    self->browser = WEUA_MSOutlookExpress;
  }
  else if (strstr(ua, "Outlook Express/")) {
    /* Outlook Express 5.0 mailbox access via http */
    self->browser = WEUA_MSOutlookExpress;
  }
  else if (strstr(ua, "Microsoft-Outlook/")) {
    /* Outlook 2002 mailbox access via http */
    self->browser = WEUA_MSOutlook;
  }
  else if (strstr(ua, "Microsoft HTTP Post")) {
    /* Outlook 2000 with WebPublishing Assistent */
    self->browser = WEUA_MSWebPublisher;
  }
  else if (strstr(ua, "Entourage/10")) {
    /* Entourage MacOSX 10.1.4 */
    self->browser = WEUA_Entourage;
  }
  else if (strstr(ua, "Microsoft-WebDAV-MiniRedir/5")) {
    /* WebFolders Win XP SP 2 */
    self->browser = WEUA_WebFolder;
  }
  else if ((tmp = strstr(ua, "MSIE"))) {
    /* Internet Explorer */
    self->browser = WEUA_IE;
    
    /* go to next space */
    while (!isspace(*tmp) && (*tmp != '\0')) tmp++;
    /* skip spaces */
    while (isspace(*tmp) && (*tmp != '\0')) tmp++;
    
    self->browserMajorVersion = atoi(tmp);
    if ((tmp = index(tmp, '.'))) {
      tmp++;
      self->browserMinorVersion = atoi(tmp);
    }
  }
  else if ((tmp = strstr(ua, "Konqueror"))) {
    /* Konqueror (KDE2 FileManager) */
    self->browser = WEUA_Konqueror;
    
    if ((tmp = index(tmp, '/'))) {
      tmp++;
      self->browserMajorVersion = atoi(tmp);
      if ((tmp = index(tmp, '.'))) {
        tmp++;
        self->browserMinorVersion = atoi(tmp);
      }
    }
  }
  else if ((tmp = strstr(ua, "Netscape6"))) {
    /* Netscape 6 */
    self->browser = WEUA_Netscape;
    
    if ((tmp = index(tmp, '/'))) {
      tmp++;
      self->browserMajorVersion = atoi(tmp);
      if ((tmp = index(tmp, '.'))) {
        tmp++;
        self->browserMinorVersion = atoi(tmp);
      }
    }
  }
  else if (strstr(ua, "Lynx")) {
    /* Lynx */
    self->browser = WEUA_Lynx;
  }
  else if (strstr(ua, "Links")) {
    /* Links */
    self->browser = WEUA_Links;
  }
  else if (strstr(ua, "gnome-vfs")) {
    /* Links */
    self->browser = WEUA_GNOMEVFS;
  }
  else if (strstr(ua, "cadaver")) {
    /* Cadaver DAV browser */
    self->browser = WEUA_CADAVER;
  }
  else if (strstr(ua, "GoLive")) {
    /* Adobe GoLive */
    self->browser = WEUA_GOLIVE;
  }
  else if (strstr(ua, "DAV.pm")) {
    /* Perl HTTP::DAV */
    self->browser = WEUA_PerlHTTPDAV;
  }
  else if (strstr(ua, "Darwin") != NULL && strstr(ua, "fetch/") != NULL) {
    /* MacOSX 10.0 DAV FileSystem */
    self->browser = WEUA_MACOSX_DAVFS;
  }
  else if (strstr(ua, "Darwin") != NULL && strstr(ua, "WebDAVFS/") != NULL) {
    /* MacOSX DAV FileSystem */
    self->browser = WEUA_MACOSX_DAVFS;
  }
  else if (strstr(ua, "OmniWeb")) {
    /* OmniWeb */
    self->browser = WEUA_OmniWeb;
  }
  else if (strstr(ua, "Evolution")) {
    /* Evolution */
    self->browser = WEUA_Evolution;
  }
  else if (strstr(ua, "wdfs/")) {
    /* WDFS */
    self->browser = WEUA_WDFS;
  }
  else if (strstr(ua, "Soup/")) {
    /* SOUP (GNOME WebDAV library) */
    self->browser = WEUA_SOUP;
  }
  else if (strstr(ua, "amaya")) {
    /* W3C Amaya */
    self->browser = WEUA_Amaya;
  }
  else if (strstr(ua, "NetNewsWire/")) {
    /* NetNewsWire */
    self->browser = WEUA_NetNewsWire;
  }
  else if (strstr(ua, "Dillo")) {
    /* Dillo */
    self->browser = WEUA_Dillo;
  }
  else if (strstr(ua, "Java")) {
    /* Java SDK */
    self->browser = WEUA_JavaSDK;
  }
  else if (strstr(ua, "Python-urllib")) {
    /* Python URL module */
    self->browser = WEUA_PythonURLLIB;
  }
  else if (strstr(ua, "xmlrpclib.py/")) {
    /* Python XML-RPC module */
    self->browser = WEUA_xmlrpclib_py;
  }
  else if (strstr(ua, "Emacs")) {
    /* Emacs */
    self->browser = WEUA_Emacs;
  }
  else if (strstr(ua, "iCab")) {
    /* iCab ?? */
    self->browser = WEUA_iCab;
  }
  else if (strstr(ua, "Wget")) {
    /* Wget */
    self->browser = WEUA_Wget;
  }
  else if (strstr(ua, "DAVAccess") || strstr(ua, "CardDAVPlugin")
           || strstr(ua, "CalendarStore") || strstr(ua, "CoreDAV/")) {
    /* Apple MacOSX 10.2.1 / iCal 1.0 DAV Access Framework */
    self->browser = WEUA_AppleDAVAccess;
  }
  else if (strstr(ua, "DAVKit/")) {
    /* some iCal 1.x DAV Access Framework, report as Apple DAV access */
    self->browser = WEUA_AppleDAVAccess;
  }
  else if (strstr(ua, "dataaccessd/")) {
    /* iOS 5.x (iPhone/iPad) DAV Access Framework, report as Apple DAV access */
    self->browser = WEUA_AppleDAVAccess;
  }
  else if (strstr(ua, "Microsoft Data Access Internet Publishing Provider")) {
    /* WebFolder */
    self->browser = WEUA_WebFolder;
  }
  else if (strstr(ua, "Microsoft Office Protocol Discovery")) {
    /* Word 2003, treat as WebFolder */
    self->browser = WEUA_WebFolder;
  }
  else if (strstr(ua, "curl")) {
    /* curl program */
    self->browser = WEUA_CURL;
  }
  else if (strstr(ua, "Mozilla")) {
    /* other Netscape browser */
    if (strstr(ua, "Mozilla/5")) {
      self->browser = WEUA_Mozilla;
      self->browserMajorVersion = 5;
    }
    else if (strstr(ua, "Mozilla/4")) {
      self->browser = WEUA_Netscape;
      self->browserMajorVersion = 4;
    }
    else {
      NSLog(@"%s: Unknown Mozilla Browser: user-agent='%@'",
            __PRETTY_FUNCTION__, self->userAgent);
    }
  }
  else if (strstr(ua, "Morgul")) {
    self->browser = WEUA_Morgul;
  }
  else if (strstr(ua, "WebDrive")) {
    self->browser = WEUA_WebDrive;
  }
  else if (strstr(ua, "CFNetwork/1.1")) {
    self->browser = WEUA_CFNetwork;
  }
  else if (strstr(ua, "Kung-Log/")) {
    self->browser = WEUA_KungLog;
  }
  else if (strstr(ua, "ecto")) {
    self->browser = WEUA_Ecto;
  }
  else if (strstr(ua, "NewsFire")) {
    self->browser = WEUA_NewsFire;
  }
  else if (strstr(ua, "Goliath")) {
    self->browser = WEUA_Goliath;
  }
  else if (strstr(ua, "SOPE/")) {
    self->browser = WEUA_SOPE;
  }
  else if (strstr(ua, "Mediapartners-Google/")) {
    self->browser = WEUA_Google;
  }
  else if (strstr(ua, "PEAR XML_RPC")) {
    self->browser = WEUA_PEAR_XMLRPC;
  }
  else if (strstr(ua, "XML-RPC.NET")) {
    self->browser = WEUA_Cook_XMLRPCdotNET;
  }
  else {
    /* unknown browser */
    self->browser = WEUA_UNKNOWN;
    
    if (self->userAgent) {
      NSLog(@"%s: Unknown WebClient: user-agent='%@'",
            __PRETTY_FUNCTION__, self->userAgent);
    }
  }
  
  /* detect OS */

  if (strstr(ua, "Windows") != NULL || strstr(ua, "WinNT") != NULL)
    self->os = WEOS_WINDOWS;
  else if (strstr(ua, "Linux"))
    self->os = WEOS_LINUX;
  else if (strstr(ua, "Mac"))
    self->os = WEOS_MACOS;
  else if (strstr(ua, "SunOS"))
    self->os = WEOS_SUNOS;
  else
    self->os = defaultOS;

  /* detect CPU */

  if (strstr(ua, "sun4u"))
    self->cpu = WECPU_SPARC;
  else if (strstr(ua, "i686") || strstr(ua, "i586"))
    self->cpu = WECPU_IX86;
  else if (strstr(ua, "PowerPC") || strstr(ua, "ppc") || strstr(ua, "PPC"))
    self->cpu = WECPU_PPC;
  else if (self->os == WEOS_WINDOWS)
    /* assume ix86 if OS is Windows .. */
    self->cpu = WECPU_IX86;
  else 
    self->cpu = defaultCPU;
  
  return self;
}

- (void)dealloc {
  [self->userAgent release];
  [super dealloc];
}

/* accessors */

- (NSString *)userAgent {
  return self->userAgent;
}

- (NSString *)userAgentType {
  switch (self->browser) {
    case WEUA_IE:                return @"IE";
    case WEUA_Netscape:          return @"Netscape";
    case WEUA_Lynx:              return @"Lynx";
    case WEUA_Links:             return @"Links";
    case WEUA_Opera:             return @"Opera";
    case WEUA_Amaya:             return @"Amaya";
    case WEUA_Emacs:             return @"Emacs";
    case WEUA_Wget:              return @"Wget";
    case WEUA_WebFolder:         return @"WebFolder";
    case WEUA_DAVFS:             return @"DAVFS";
    case WEUA_MACOSX_DAVFS:      return @"MacOSXDAVFS";
    case WEUA_CADAVER:           return @"Cadaver";
    case WEUA_GOLIVE:            return @"GoLive";
    case WEUA_Mozilla:           return @"Mozilla";
    case WEUA_OmniWeb:           return @"OmniWeb";
    case WEUA_iCab:              return @"iCab";
    case WEUA_Konqueror:         return @"Konqueror";
    case WEUA_Dillo:             return @"Dillo";
    case WEUA_JavaSDK:           return @"Java";
    case WEUA_PythonURLLIB:      return @"Python-urllib";
    case WEUA_AppleDAVAccess:    return @"AppleDAVAccess";
    case WEUA_MSWebPublisher:    return @"MSWebPublisher";
    case WEUA_CURL:              return @"CURL";
    case WEUA_Evolution:         return @"Evolution";
    case WEUA_SOUP:              return @"SOUP";
    case WEUA_MSOutlook:         return @"MSOutlook";
    case WEUA_MSOutlookExpress:  return @"MSOutlookExpress";
    case WEUA_GNOMEVFS:          return @"GNOME-VFS";
    case WEUA_ZideLook:          return @"ZideLook";
    case WEUA_Safari:            return @"Safari";
    case WEUA_Entourage:         return @"Entourage";
    case WEUA_NetNewsWire:       return @"NetNewsWire";
    case WEUA_xmlrpclib_py:      return @"xmlrpclib.py";
    case WEUA_Morgul:            return @"Morgul";
    case WEUA_KungLog:           return @"KungLog";
    case WEUA_Ecto:              return @"Ecto";
    case WEUA_NewsFire:          return @"NewsFire";
    case WEUA_Goliath:           return @"Goliath";
    case WEUA_PerlHTTPDAV:       return @"PerlHTTPDAV";
    case WEUA_Google:            return @"Google";
    case WEUA_WebDrive:          return @"WebDrive";
    case WEUA_Sunbird:           return @"Sunbird";
    case WEUA_PEAR_XMLRPC:       return @"PHP PEAR XMLRPC";
    case WEUA_Cook_XMLRPCdotNET: return @"PHP PEAR XMLRPC";
    case WEUA_WDFS:              return @"WDFS";
    case WEUA_ZideOne_Outlook:   return @"ZideOne";
    default:                     return @"unknown";
  }
}
- (NSString *)os {
  switch (self->os) {
    case WEOS_WINDOWS: return @"Windows";
    case WEOS_LINUX:   return @"Linux";
    case WEOS_MACOS:   return @"MacOS";
    case WEOS_SUNOS:   return @"SunOS";
    default:           return @"unknown";
  }
}
- (NSString *)cpu {
  switch (self->cpu) {
    case WECPU_IX86:  return @"ix86";
    case WECPU_SPARC: return @"sparc";
    case WECPU_PPC:   return @"ppc";
    default:          return @"unknown";
  }
}

- (unsigned char)majorVersion {
  return self->browserMajorVersion;
}
- (unsigned char)minorVersion {
  return self->browserMinorVersion;
}

/* browser capabilities */

- (BOOL)isJavaScriptBrowser {
  switch (self->browser) {
    case WEUA_Mozilla:
    case WEUA_IE:
    case WEUA_Opera:
    case WEUA_Netscape:
    case WEUA_OmniWeb:
    case WEUA_Konqueror:
    case WEUA_Safari:
      return YES;
      
    default:
      return NO;
  }
}
- (BOOL)isVBScriptBrowser {
  switch (self->browser) {
    case WEUA_IE:
      return YES;
    
    default:
      return NO;
  }
}

- (BOOL)isFastTableBrowser {
  switch (self->browser) {
    case WEUA_Mozilla:
    case WEUA_IE:
    case WEUA_Opera:
      return YES;

    case WEUA_Safari:
    case WEUA_Konqueror:
      /* to be tried */
      return YES;
      
    case WEUA_Netscape:
      return (self->browserMajorVersion >= 6)
        ? YES : NO;
      
    default:
      return NO;
  }
}

- (BOOL)isCSS2Browser {
  switch (self->browser) {
    case WEUA_IE:        return (self->browserMajorVersion >= 5) ? YES : NO;
    case WEUA_Netscape:  return (self->browserMajorVersion >= 6) ? YES : NO;
    case WEUA_Opera:     return (self->browserMajorVersion >= 4) ? YES : NO;
    case WEUA_Mozilla:   return YES;
    case WEUA_Safari:    return YES;
    case WEUA_Konqueror: return NO;
    default:             return NO;
  }
}

- (BOOL)isCSS1Browser {
  switch (self->browser) {
    case WEUA_IE:        return (self->browserMajorVersion >= 4) ? YES : NO;
    case WEUA_Netscape:  return (self->browserMajorVersion >= 4) ? YES : NO;
    case WEUA_Opera:     return (self->browserMajorVersion >= 4) ? YES : NO;
    case WEUA_Safari:    return YES;
    case WEUA_Konqueror: return NO;
    default:             return NO;
  }
}

- (BOOL)ignoresCSSOnFormElements {
  if (self->browser == WEUA_Safari) /* Safari always displays Aqua buttons */
    return YES;
  
  return [self isCSS1Browser] ? NO : YES;
}

- (BOOL)isXULBrowser {
  if (self->browser == WEUA_Safari) // TODO: Safari supports some XUL stuff
    return NO;
  if ((self->browser == WEUA_Netscape) && (self->browserMajorVersion >= 6))
    return YES;
  if (self->browser == WEUA_Mozilla)
    return YES;
  return NO;
}

- (BOOL)isTextModeBrowser {
  if (self->browser == WEUA_Lynx)  return YES;
  if (self->browser == WEUA_Links) return YES;
  if (self->browser == WEUA_Emacs) return YES;
  return NO;
}

- (BOOL)isIFrameBrowser {
  if ((self->browser == WEUA_IE) && (self->browserMajorVersion >= 5))
    return YES;
  
  /* as suggested in OGo bug #634 */
  if ((self->browser == WEUA_Mozilla) && (self->browserMajorVersion >= 5))
    return YES;
  
  return NO;
}

- (BOOL)isRobot {
  if (self->browser == WEUA_Wget)         return YES;
  if (self->browser == WEUA_JavaSDK)      return YES;
  if (self->browser == WEUA_PythonURLLIB) return YES;
  if (self->browser == WEUA_Google)       return YES;
  return NO;
}
- (BOOL)isDAVClient {
  if (self->browser == WEUA_WebFolder)        return YES;
  if (self->browser == WEUA_DAVFS)            return YES;
  if (self->browser == WEUA_MACOSX_DAVFS)     return YES;
  if (self->browser == WEUA_CADAVER)          return YES;
  if (self->browser == WEUA_GOLIVE)           return YES;
  if (self->browser == WEUA_AppleDAVAccess)   return YES;
  if (self->browser == WEUA_Evolution)        return YES;
  if (self->browser == WEUA_SOUP)             return YES;
  if (self->browser == WEUA_MSOutlook)        return YES;
  if (self->browser == WEUA_MSOutlookExpress) return YES;
  if (self->browser == WEUA_GNOMEVFS)         return YES;
  if (self->browser == WEUA_ZideLook)         return YES;
  if (self->browser == WEUA_Entourage)        return YES;
  if (self->browser == WEUA_Morgul)           return YES;
  if (self->browser == WEUA_Goliath)          return YES;
  if (self->browser == WEUA_PerlHTTPDAV)      return YES;
  if (self->browser == WEUA_WebDrive)         return YES;
  if (self->browser == WEUA_Sunbird)          return YES;
  if (self->browser == WEUA_WDFS)             return YES;
  if (self->browser == WEUA_ZideOne_Outlook)  return YES;
  return NO;
}

- (BOOL)isXmlRpcClient {
  if (self->browser == WEUA_xmlrpclib_py) return YES;
  if (self->browser == WEUA_KungLog)      return YES;
  if (self->browser == WEUA_Ecto)         return YES;
  if (self->browser == WEUA_PEAR_XMLRPC)  return YES;
  if (self->browser == WEUA_Cook_XMLRPCdotNET) return YES;
  return NO;
}
- (BOOL)isBLogClient {
  if (self->browser == WEUA_KungLog) return YES;
  if (self->browser == WEUA_Ecto)    return YES;
  return NO;
}
- (BOOL)isRSSClient {
  if (self->browser == WEUA_NetNewsWire) return YES;
  if (self->browser == WEUA_NewsFire)    return YES;
  return NO;
}

- (BOOL)doesSupportCSSOverflow {
  if (![self isCSS1Browser])
    return NO;
  if ((self->browser == WEUA_IE) && (self->browserMajorVersion >= 5))
    return YES;

  return NO;
}

- (BOOL)doesSupportDHTMLDragAndDrop {
  if (![self isJavaScriptBrowser])
    return NO;
  if (self->os != WEOS_WINDOWS)
    return NO;
  if ((self->browser == WEUA_IE) && (self->browserMajorVersion >= 5))
    return YES;
  return NO;
}

- (BOOL)doesSupportXMLDataIslands {
  if ((self->browser == WEUA_IE) && (self->browserMajorVersion >= 5))
    return YES;
  return NO;
}

- (BOOL)doesSupportUTF8Encoding {
  if (self->flags.acceptUTF8)
    /* explicit UTF-8 support signaled in HTTP header */
    return YES;
  
  switch (self->browser) {
  case WEUA_Mozilla:
  case WEUA_Safari:
  case WEUA_ZideLook:
  case WEUA_Evolution:
  case WEUA_SOUP:
  case WEUA_Morgul:
  case WEUA_Sunbird:
  case WEUA_ZideOne_Outlook:
    /* browser so new, that they always supported UTF-8 ... */
    return YES;
  case WEUA_IE:
    if (self->browserMajorVersion >= 5)
      return YES;
    return NO; // TODO: find out, whether IE 4 gurantees UTF-8 support
  default:
    return NO;
  }
}

/* user-agent */

- (BOOL)isInternetExplorer {
  return self->browser == WEUA_IE ? YES : NO;
}
- (BOOL)isInternetExplorer5 {
  return (self->browser == WEUA_IE) && (self->browserMajorVersion == 5)
    ? YES : NO;
}

- (BOOL)isNetscape {
  return self->browser == WEUA_Netscape ? YES : NO;
}
- (BOOL)isNetscape6 {
  return (self->browser == WEUA_Netscape) && (self->browserMajorVersion == 6)
    ? YES : NO;
}

- (BOOL)isLynx {
  return self->browser == WEUA_Lynx ? YES : NO;
}
- (BOOL)isOpera {
  return self->browser == WEUA_Opera ? YES : NO;
}
- (BOOL)isAmaya {
  return self->browser == WEUA_Amaya ? YES : NO;
}
- (BOOL)isEmacs {
  return self->browser == WEUA_Emacs ? YES : NO;
}
- (BOOL)isWget {
  return self->browser == WEUA_Wget ? YES : NO;
}
- (BOOL)isWebFolder {
  return self->browser == WEUA_WebFolder ? YES : NO;
}
- (BOOL)isMozilla {
  return self->browser == WEUA_Mozilla ? YES : NO;
}
- (BOOL)isOmniWeb {
  return self->browser == WEUA_OmniWeb ? YES : NO;
}
- (BOOL)isICab {
  return self->browser == WEUA_iCab ? YES : NO;
}
- (BOOL)isKonqueror {
  return self->browser == WEUA_Konqueror ? YES : NO;
}
- (BOOL)isPHP {
  return self->browser == WEUA_PEAR_XMLRPC ? YES : NO;
}

/* OS */

- (BOOL)isWindowsBrowser {
  return self->os == WEOS_WINDOWS ? YES : NO;
}
- (BOOL)isLinuxBrowser {
  return self->os == WEOS_LINUX ? YES : NO;
}
- (BOOL)isMacBrowser {
  return self->os == WEOS_MACOS ? YES : NO;
}
- (BOOL)isSunOSBrowser {
  return self->os == WEOS_SUNOS ? YES : NO;
}
- (BOOL)isUnixBrowser {
  switch (self->os) {
    case WEOS_SUNOS:
    case WEOS_LINUX:
      return YES;
    default: return NO;
  }
}
- (BOOL)isX11Browser {
  if ([self isTextModeBrowser])
    return NO;
  if (![self isUnixBrowser])
    return NO;
  return YES;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *s;

  s = [NSMutableString stringWithFormat:@"<%@[0x%p]:",
                         NSStringFromClass([self class]), self];
  
  //[s appendFormat:@" ua='%@'", self->userAgent];
  [s appendFormat:@" type=%@ v%i.%i",
       [self userAgentType],
       self->browserMajorVersion, self->browserMinorVersion];
  [s appendFormat:@" os=%@",   [self os]];
  [s appendFormat:@" cpu=%@",  [self cpu]];
  
  if ([self isFastTableBrowser])  [s appendString:@" fast-tbl"];
  if ([self isCSS1Browser])       [s appendString:@" css1"];
  if ([self isCSS2Browser])       [s appendString:@" css2"];
  if ([self isXULBrowser])        [s appendString:@" xul"];
  if ([self isTextModeBrowser])   [s appendString:@" text"];
  if ([self isRobot])             [s appendString:@" robot"];
  if ([self isJavaScriptBrowser]) [s appendString:@" js"];
  if ([self isVBScriptBrowser])   [s appendString:@" vb"];
  
  [s appendString:@">"];
  return s;
}

@end /* WEClientCapabilities */

static NSString *ClientCapsCacheKey = @"WEClientCapabilities";

@implementation WORequest(ClientCapabilities)

- (WEClientCapabilities *)clientCapabilities {
  NSDictionary         *ua;
  WEClientCapabilities *ccaps;
  NSMutableDictionary  *md;

  if ((ua = [self userInfo]) == nil) {
    ccaps = [WEClientCapabilities alloc];
    if ((ccaps = [ccaps initWithRequest:self]) == nil)
      return nil;
    ccaps = [ccaps autorelease];
    
    ua = [[NSDictionary alloc] initWithObjects:&ccaps
                               forKeys:&ClientCapsCacheKey
                               count:1];
    [self setUserInfo:ua];
    [ua release];
    return ccaps;
  }
  
  if ((ccaps = [ua objectForKey:ClientCapsCacheKey]))
    return ccaps;
  
  ccaps = [WEClientCapabilities alloc];
  if ((ccaps = [ccaps initWithRequest:self]) == nil)
    return nil;
  ccaps = [ccaps autorelease];
    
  md = [ua mutableCopy];
  [md setObject:ccaps forKey:ClientCapsCacheKey];
  ua = [md copy];
  [md release];
  [self setUserInfo:ua];
  [ua release];
  return ccaps;
}

@end /* WORequest(ClientCapabilities) */

static NSString *WEClientDetectorFormName = @"WEClientDetect";

@implementation JSClientCapabilityDetector

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->formName   = OWGetProperty(_config, @"formName");
    self->clientCaps = OWGetProperty(_config, @"clientCaps");
  }
  return self;
}

- (void)dealloc {
  [self->formName   release];
  [self->clientCaps release];
  [super dealloc];
}

- (NSString *)_formNameInContext:(WOContext *)_ctx {
  if (self->formName)
    return [self->formName stringValueInComponent:[_ctx component]];
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (![_ctx isInForm]) {
    [[_ctx component]
           warnWithFormat:@"you must use %@ inside a form !",
             NSStringFromClass([self class])];
    return;
  }

  if ([_ctx isRenderingDisabled]) return;

  if (![[[_ctx request] clientCapabilities] isJavaScriptBrowser])
    /* only works on JavaScript browsers ... */
    return;

  [_response appendContentString:@"<input type='hidden' name='"];
  [_response appendContentString:WEClientDetectorFormName];
  [_response appendContentString:@"' value='browserConfig' />"];
  
  [_response appendContentString:@"<script language='JavaScript'>\n"];
  [_response appendContentString:@"<!-- hide\n"];
  
  [_response appendContentString:@"// -->\n"];
  [_response appendContentString:@"</script>"];
}

@end /* JSClientCapabilityDetector */

/*
  Netscape 4.76, Windows NT 4
    'Mozilla/4.76 [en] (WinNT; U)'
  
  Netscape 6, Windows NT 4
    'Mozilla/5.0 (Windows; U; WinNT4.0; en-US; m18) Gecko/20001108 Netscape6/6.0'
  
  Netscape Navigator 3.01[de], MacOS 8.1
    'Mozilla/3.01 [de]-C-MACOS8 (Macintosh; I; PPC)'

  Netscape Communicator 4.51, SuSE Linux 6.1
    'Mozilla/4.51 [en] (X11; I; Linux 2.2.13 i686)'
  
  Mozilla M17, Windows NT 4
    'Mozilla/5.0 (Windows; U; WinNT4.0; en-US; m17) Gecko/20000807'
  
  Internet Explorer 5.5, Windows NT 4
    'Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0)'
  
  Internet Explorer 3.0.1, MacOS 8.1
    'Mozilla/3.0 (compatible; MSIE 3.0.1; Mac_PowerPC; Mac OS8)'
    
  Internet Explorer 5.0, MacOS 8.1
    'Mozilla/4.0 (compatible; MSIE 5.0; Mac_PowerPC)'

  Internet Explorer 5.0, SPARC Solaris 2.6 (trex)
    'Mozilla/4.0 (compatible; MSIE 5.0; SunOS 5.6 sun4u; X11)'
  
  Konqueror/2.0, SuSE Linux 7.0
    'Mozilla/5.0 (compatible; Konqueror/2.0; X11); Supports MD5-Digest; Supports gzip encoding'
  
  Lynx, SuSE Linux 6.1 (marvin)
    'Lynx/2.8rel.2 libwww-FM/2.14'

  Lynx, SPARC Solaris 2.6 (trex)
    'Lynx/2.7 libwww-FM/2.14'
  
  Opera 4.02, Windows NT 4
    'Mozilla/4.73 (Windows NT 4.0; U) Opera 4.02  [en]'
  
  Opera 5.0, Windows NT 4
    'Mozilla/4.0 (compatible; MSIE 5.0; Windows NT 4.0) Opera 5.0  [en]'
  
  Amaya 4.0, Windows NT 4
    'amaya/V4.0 libwww/5.3.1'
  
  XEmacs, SuSE Linux 6.1
    'Emacs-W3/4.0pre.39 URL/p4.0pre.39 (i686-pc-linux; X11)'

  XEmacs, SuSE Linux 7.2
    'Emacs-W3/4.0pre.46 URL/p4.0pre.46 (i386-suse-linux; X11)'
  
  wget, SuSE Linux 6.1
    'Wget/1.5.3'
  
  Windows 'WebFolder' NT4
    'Microsoft Data Access Internet Publishing Provider Cache Manager'
    'Mozilla/2.0 (compatible; MS FrontPage 4.0)'
    'MSFrontPage/4.0'

  Windows 98 IE 5 WebFolders
    'Microsoft Data Access Internet Publishing Provider DAV'

  OmniWeb
    'OmniWeb/3.0.2 OWF/1999C'

  Links, SuSE Linux 6.1 (marvin)
    'Links (0.95; Linux 2.2.13 i686)'

  Linux DAVFS
    'DAV-FS/0.0.1'

  MacOSX 10.0 DAVFS
    fetch/1.0 Darwin/1.3.7 (Power Macintosh)

  MacOSX 10.1.1 DAV FS
    WebDAVFS/1.0 Darwin/5.1 (Power Macintosh)
  
  MacOSX 10.2.1 DAV FS
    WebDAVFS/1.2.1 (01218000) Darwin/6.1 (Power Macintosh)

  MacOSX 10.4.2 DAV FS
    WebDAVFS/1.4.1 (01418000) Darwin/8.6.0 (Power Macintosh)
  
  Cadaver 0.17.0
    'cadaver/0.17.0 neon/0.12.0-dev'
  
  Adobe GoLive 5
    'GoLive/5. 0 [] (Windows 98; RATBERT)'

  Dillo 0.6.2
    - (very) small X11 web browser
    'Dillo/0.6.1'
  
  Java SDK 1.3
    'Java1.3.0'

  Python 2.0
    'Python-urllib/1.13'
  
  Apple MacOSX 10.2.1 / iCal 1.0 DAV Access Framework
    'DAVAccess/1.0'
  
  Outlook 2000 on W2K with M$ Web Publishing Assistent
    'Microsoft HTTP Post (RFC1867)'
  
  CURL program (libcurl)
    'curl/7.9.8 (i686-suse-linux) libcurl 7.9.8 (OpenSSL 0.9.6g) (ipv6 enabled)'

  Evolution 1.0.8 with Exchange Connector (WebDAV)
    'Evolution/1.0.8'
  
  Outlook 2002 on W2K (HotMail HTTP access)
    'Microsoft-Outlook/10.0 (TmstmpExt)'
  
  Outlook Express 5.5 on W2K (HotMail HTTP access)
    'Outlook-Express/5.5 (MSIE 5.5; Windows NT 5.0; Q312461; T312461; TmstmpExt)'
  
  Outlook Express 6.0 on W2K (HotMail HTTP access)
    'Outlook-Express/6.0 (MSIE 6.0; Windows NT 5.0; Q312461; T312461; TmstmpExt)'

  Nautilus (GNOME Virtual Filesystem)
    'gnome-vfs/1.0.5'
  
  Konqueror 3.0.3 (SuSE 8.1)
    - does not send a user-agent in webdav:// mode !

  ZideLook 0.0
    'neon/0.23.5 NeonConnection 0.0'

  Safari v74 (MacOSX 10.2)
    'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/74 (KHTML, like Gecko) Safari/74'
    - why does it say Mozilla/5.0 ??

  Evolution 1.4.0 with Exchange Connector 1.4.0 (SuSE 8.2)
    'Evolution/1.4.0'
    
  Mozilla Firebird 0.6 (MacOSX 10.2)
    'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6'

  SOUP (Evo OGo Connector by Anders)
    'Soup/1.99.24'

  Entourage/X (Entourage WebDAV 10.1.4, MacOSX)
    'Entourage/10.0 (Mac_PowerPC; DigExt; TmstmpExt)'
  
  Some unknown iCal.app
    'DAVKit/0.1'

  NetNewsWire full version: 
    'NetNewsWire/1.0.5 (Mac OS X; http://ranchero.com/netnewswire/)'
  
  NetNewsWire lite version: 
    'NetNewsWire/1.0.3 (Mac OS X; Lite; http://ranchero.com/netnewswire/)'

  Python xmlrpclib:
    'xmlrpclib.py/1.0.0 (by www.pythonware.com)'

  Windows 2000 IE 6 WebFolders
    'Microsoft Data Access Internet Publishing Provider DAV 1.1'

  Morgul, Windows WebDAV client
    'Morgul'

  Apple iSync v122 / CoreFoundation Network
    'CFNetwork/1.1'

  Kung-Log (WebServicesCore)
    'Kung-Log/1.3 (Macintosh; U; PPC Mac OS X) WebServicesCore'

  Ecto (WebServicesCore)
    'ecto (Macintosh; U; PPC Mac OS X) WebServicesCore'

  NewsFire
    'NewsFire/0.23'
  
  Goliath
    'Goliath/1.0.1 (Macintosh-Carbon; PPC)'

  PERL HTTP::DAV
    'DAV.pm/v0.31'
  
  Google Ads
    'Mediapartners-Google/2.1'

  WebFolders Win XP SP2
    'Microsoft-WebDAV-MiniRedir/5.1.2600'
  
  Word 2003
    'Microsoft Office Protocol Discovery'

  WebDrive
    'WebDrive 7.10.1475 DAV'

  Nokia N80, Opera 8 (352x416, 24b)
    'User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Symbian OS; Series 60/; 7439) Opera 8.60 [de]'
    'X-OS-Prefs: fw:352; fh:416; cd:24c; pl:3; pj:0; pa:1;pi:0;ps:0;'

  Nokia N80, Safari
    'User-Agent: Mozilla/5.0 (SymbianOS/9.1; U; en-us) AppleWebKit/413 (KHTML, like Gecko) Safari/413'

  Nokia N80, WAP Browser
    'User-Agent: NokiaN80-1/3.0 (3.0611.0.8) Series60/3.0  Profile/MIDP-2.0 Configuration/CLDC-1.1'
    'x-wap-profile: "http://nds1.nds.nokia.com/uaprof/NN80-1r100.xml"'

  Sony/Ericsson T610 (128x160, 16b)
    'user-agent: SonyEricssonT610/R301 Profile/MIDP-1.0 Configuration/CLDC-1.0 UP.Link/6.3.0.0.0'
    'x-up-devcap-charset: US-ASCII,ISO-8859-1,UTF-8,ISO-10646-UCS-2'
    'x-up-devcap-iscolor: 1'
    'x-up-devcap-max-pdu: 10000'
    'x-up-devcap-screendepth: 16'
    'x-up-devcap-screenpixels: 128,160'
    'x-up-forwarded-for: 10.233.155.62'
    'x-up-subno: 981574289-60174629'
    'x-up-wtls-info: off'
    'x-wap-profile: "http://wap.sonyericsson.com/UAprof/T610R301.xml"'

  WDFS
    'wdfs/1.4.2 neon/0.26.4'
*/
