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

#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include "common.h"

@interface WOApplication(MemoryStatistics)

- (NSDictionary *)memoryStatistics;

@end

@implementation WOApplication(MemoryStatistics)

- (NSDictionary *)memoryStatistics {
#ifdef __linux__
  FILE     *f;
  char     buf[4096];
  char     fname[256];
  unsigned len;

  sprintf(fname, "/proc/%d/status", getpid());
  if ((f = fopen(fname, "r"))) {
    id           d = nil;
    NSString     *s;
    NSEnumerator *lines;
    
    len = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[len] = '\0';

    s = [NSString stringWithCString:buf];
    lines = [[s componentsSeparatedByString:@"\n"] objectEnumerator];
    while ((s = [lines nextObject])) {
      NSString *key;
      NSRange rng;

      rng = [s rangeOfString:@":"];
      if (rng.length <= 0)
        continue;

      key = [s substringToIndex:rng.location];

      if ([key hasPrefix:@"Vm"]) {
        const char *cstr;
        id value;
        
        cstr = [s cString];
        while (*cstr != '\0' && *cstr != ':') cstr++;
        if (*cstr == '\0') continue;
        cstr++;
        while (*cstr != '\0' && isspace(*cstr)) cstr++;
        value = [NSString stringWithCString:cstr];
        
        if ([value hasSuffix:@" kB"]) {
          value = [value substringToIndex:[value length] - 3];
          value = [NSNumber numberWithInt:[value intValue] * 1024];
        }
        
        if (d == nil) 
	  d = [NSMutableDictionary dictionaryWithCapacity:16];
        [(NSMutableDictionary *)d setObject:value forKey:key];
      }
    }
    return d;
  }
#endif
  return nil;
}

@end /* WOApplication(MemoryStatistics) */

@implementation WODirectAction(WOStats)

- (id<WOActionResults>)WOStatsAction {
  WOApplication *app;
  WOResponse   *response;
  NSDictionary *stats;
  NSString     *xslPath;
  NSArray      *languages;
  static NSDictionary *keyToDataType = nil;
  
  if (keyToDataType == nil) {
    keyToDataType =
      [[NSDictionary alloc] initWithObjectsAndKeys:
                                  @"number", @"averageDuration",
                                  @"number", @"maximumDuration",
                                  @"number", @"minimumDuration",
                                  @"number", @"totalDuration",
                                  @"number", @"instanceUptime",
                                  @"number", @"instanceUptimeInHours",
                                  @"number", @"instanceLoad",
                                  @"number", @"pageResponseCount",
                                  @"number", @"numberOfZippedResponses",
                                  @"number", @"totalResponseCount",
                                  @"number", @"pageFrequency",
                                  @"number", @"pageDeliveryVolumne",
                                  @"number", @"responseFrequency",
                                  @"number", @"relativeTimeConsumption",
                                  @"number", @"averageResponseSize",
                                  @"number", @"totalResponseSize",
                                  @"number", @"totalZippedSize",
                                  @"number", @"smallestResponseSize",
                                  @"number", @"largestResponseSize",
                                  @"number", @"VmData",
                                  @"number", @"VmExe",
                                  @"number", @"VmRSS",
                                  @"number", @"VmLib",
                                  @"number", @"VmStk",
                                  @"number", @"VmSize",
                                  @"number", @"VmLck",
                                  nil];
  }
  
  app = [WOApplication application];

  xslPath = [[NSUserDefaults standardUserDefaults]
                             stringForKey:@"WOStatsStylesheetName"];
  languages = [[self context] resourceLookupLanguages];
  xslPath   = [[app resourceManager] urlForResourceNamed:xslPath
                                     inFramework:nil
                                     languages:languages
                                     request:[self request]];
  if ([xslPath hasPrefix:@"/missingresource"])
    xslPath = nil;
  
  response = [WOResponse responseWithRequest:[self request]];
  [response setContentEncoding:NSUTF8StringEncoding];
  [response setHeader:@"text/xml; charset=utf-8" forKey:@"content-type"];
  
  stats = [[app statisticsStore] statistics];
  
  [response appendContentString:@"<?xml version='1.0'?>\n"];
  if ([xslPath length] > 0) {
    [response appendContentString:@"<?xml-stylesheet type='text/xsl' href='"];
    [response appendContentString:xslPath];
    [response appendContentString:@"'?>"];
  }

  [response appendContentString:@"<application name='"];
  [response appendContentString:[app name]];
  [response appendContentString:@"'"];
  [response appendContentString:
              [NSString stringWithFormat:@" pid='%d'", getpid()]];
  [response appendContentString:
              @" xmlns:dt='urn:schemas-microsoft-com:datatypes'>\n"];
  
  {
    NSEnumerator *e;
    NSString *key;
    NSDictionary *pageStatistics;
    
    /* application statistics */
    
    e = [stats keyEnumerator];
    while ((key = [e nextObject])) {
      id value;
      NSString *dt;
      
      if ([key isEqualToString:@"pageStatistics"])
        continue;

      value = [stats objectForKey:key];
      
      [response appendContentString:@"  <"];
      [response appendContentString:key];
        
      if ((dt = [keyToDataType objectForKey:key])) {
        [response appendContentString:@" dt:dt='"];
        [response appendContentString:dt];
        [response appendContentString:@"'"];
      }
      
      [response appendContentString:@">"];
      
      [response appendContentHTMLString:[value stringValue]];
      
      [response appendContentString:@"</"];
      [response appendContentString:key];
      [response appendContentString:@">\n"];
    }

    /* memory statistics */

    {
      NSDictionary *mem;
      
      mem = [app memoryStatistics];

      if ([mem count] > 0) {
        [response appendContentString:@"  <memory>\n"];
        
        e = [mem keyEnumerator];
        while ((key = [e nextObject])) {
          id       value;
          NSString *dt;

          value = [mem objectForKey:key];
          
          [response appendContentString:@"  <"];
          [response appendContentString:key];
        
          if ((dt = [keyToDataType objectForKey:key])) {
            [response appendContentString:@" dt:dt='"];
            [response appendContentString:dt];
            [response appendContentString:@"'"];
          }
      
          [response appendContentString:@">"];
      
          [response appendContentHTMLString:[value stringValue]];
      
          [response appendContentString:@"</"];
          [response appendContentString:key];
          [response appendContentString:@">\n"];
        }

        [response appendContentString:@"  </memory>\n"];
      }
    }

    /* page statistics */
    
    pageStatistics = [stats objectForKey:@"pageStatistics"];

    [response appendContentString:@"  <pages>\n"];
    
    e = [pageStatistics keyEnumerator];
    while ((key = [e nextObject])) {
      NSDictionary *stats;
      NSEnumerator *e2;
      NSString     *key2;
      
      stats = [pageStatistics objectForKey:key];
      e2    = [stats keyEnumerator];
      
      [response appendContentString:@"    <page name='"];
      [response appendContentString:key];
      [response appendContentString:@"'>\n"];
      
      while ((key2 = [e2 nextObject])) {
        id value;
        NSString *dt;

        value = [stats objectForKey:key2];
        
        [response appendContentString:@"      <"];
        [response appendContentString:key2];
        
        if ((dt = [keyToDataType objectForKey:key2])) {
          [response appendContentString:@" dt:dt='"];
          [response appendContentString:dt];
          [response appendContentString:@"'"];
        }
        
        [response appendContentString:@">"];
        
        [response appendContentHTMLString:[value stringValue]];
        
        [response appendContentString:@"</"];
        [response appendContentString:key2];
        [response appendContentString:@">\n"];
      }
      [response appendContentString:@"    </page>\n"];
    }
    
    [response appendContentString:@"  </pages>\n"];
  }
  
  [response appendContentString:@"</application>\n"];
  
  return response;
}

@end /* WODirectAction(WOStats) */
