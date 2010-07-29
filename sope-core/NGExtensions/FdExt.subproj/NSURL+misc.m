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

#include "NSURL+misc.h"
#include "common.h"

static BOOL debugURLProcessing = NO;

@implementation NSURL(misc)

- (NSString *)pathWithCorrectTrailingSlash {
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  /*
    At least on OSX 10.3 the -path method missing the trailing slash, eg:
      http://localhost:20000/dbd.woa/so/localhost/
    gives:
      /dbd.woa/so/localhost
  */
  NSString *p;
  
  if ((p = [self path]) == nil)
    return nil;
  
  if ([p hasSuffix:@"/"])
    return p;

  if (![[self absoluteString] hasSuffix:@"/"])
    return p;
  
  /* so we are running into the bug ... */
  return [p stringByAppendingString:@"/"];
#else
  return [self path];
#endif
}

- (NSString *)stringByAddingFragmentAndQueryToPath:(NSString *)_path {
  NSString *lFrag, *lQuery;
  
  if ([self isFileURL])
    return _path;
  
  lFrag   = [self fragment];
  lQuery  = [self query];
  
  if ((lFrag != nil) || (lQuery != nil)) {
    NSMutableString *ms;
    
    ms = [NSMutableString stringWithCapacity:([_path length] + 32)];
    
    [ms appendString:_path];
    
    if (lFrag) {
      [ms appendString:@"#"];
      [ms appendString:lFrag];
    }
    if (lQuery) {
      [ms appendString:@"?"];
      [ms appendString:lQuery];
    }
    return ms;
  }
  else
    return _path;
}

- (NSString *)stringValueRelativeToURL:(NSURL *)_base {
  /*
    Sample:
      self: http://localhost:20000/dbd.woa/so/localhost/Databases/A
      base: http://localhost:20000/dbd.woa/so/localhost/
         => Databases/A
    
    Note: on Panther Foundation the -path misses the trailing slash!
  */
  NSString *relPath;
  
  if (_base == self || _base == nil) {
    relPath = [self pathWithCorrectTrailingSlash];
    relPath = [relPath urlPathRelativeToSelf];
    relPath = [self stringByAddingFragmentAndQueryToPath:relPath];
    if (debugURLProcessing) {
      NSLog(@"%s: no base or base is self => '%@'", 
	    __PRETTY_FUNCTION__, relPath);
    }
    return relPath;
  }
  
  /* check whether we are already marked relative to _base .. */
  if ([self baseURL] == _base) {
    NSString *p;
    
    p = [self relativePath];
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
    /* see -pathWithCorrectTrailingSlash for bug description ... */
    if (![p hasSuffix:@"/"]) {
      if ([[self absoluteString] hasSuffix:@"/"])
	p = [p stringByAppendingString:@"/"];
    }
#endif
    p = [self stringByAddingFragmentAndQueryToPath:p];
    if (debugURLProcessing) {
      NSLog(@"%s: url base and _base match => '%@'", 
	    __PRETTY_FUNCTION__, p);
    }
    return p;
  }
  
  /* check whether we are in the same path namespace ... */
  if (![self isInSameNamespaceWithURL:_base]) {
    /* need to return full URL */
    relPath = [self absoluteString];
    if (debugURLProcessing) {
      NSLog(@"%s: url is in different namespace from base => '%@'", 
	    __PRETTY_FUNCTION__, relPath);
    }
    return relPath;
  }
  
  relPath = [[self pathWithCorrectTrailingSlash] 
                   urlPathRelativeToPath:[_base pathWithCorrectTrailingSlash]];
  if (debugURLProcessing) {
    NSLog(@"%s: path '%@', base-path '%@' => rel '%@'", __PRETTY_FUNCTION__,
	  [self path], [_base path], relPath);
  }
  relPath = [self stringByAddingFragmentAndQueryToPath:relPath];
  
  if (debugURLProcessing) {
    NSLog(@"%s: same namespace, but no direct relative (%@, base %@) => '%@'", 
	  __PRETTY_FUNCTION__, 
	  [self absoluteString], [_base absoluteString], relPath);
  }
  return relPath;
}

static BOOL isEqual(id o1, id o2) {
  if (o1 == o2) return YES;
  if (o1 == nil || o2 == nil) return NO;
  return [o1 isEqual:o2];
}

- (BOOL)isInSameNamespaceWithURL:(NSURL *)_url {
  if (_url == nil)  return NO;
  if (_url == self) return YES;
  if ([self isFileURL] && [_url isFileURL]) return YES;
  if ([self baseURL] == _url) return YES;
  if ([_url baseURL] == self) return YES;
  
  if (![[self scheme] isEqualToString:[_url scheme]])
    return NO;
  
  if (!isEqual([self host], [_url host]))
    return NO;
  if (!isEqual([self port], [_url port]))
    return NO;
  if (!isEqual([self user], [_url user]))
    return NO;
  
  return YES;
}

@end /* NSURL */

@implementation NSString(URLPathProcessing)

- (NSString *)urlPathRelativeToSelf {
  /*
    eg:                "/a/b/c.html"
    should resolve to: "c.html"
    
    Directories are a bit more difficult, eg:
      "/a/b/c/"
    is resolved to
      "../c/"
  */
  NSString *p;
  NSString *lp;

  /*
    /SOGo/so/X/Mail/Y/INBOX/withsubdirs/
    ..//SOGo/so/X/Mail/Y/INBOX/withsubdirs//
  */
  
  p  = self;
  lp = [p lastPathComponent];
  if (![p hasSuffix:@"/"])
    return lp;
  
  return [[@"../" stringByAppendingString:lp] stringByAppendingString:@"/"];
}

- (NSString *)urlPathRelativeToRoot {
  NSString *p;
  
  p = self;
  
  if ([p isEqualToString:@"/"])
    /* don't know better ... what is root-relative-to-root ? */
    return @"/";
  
  if ([p length] == 0) {
    NSLog(@"%s: invalid path (length 0), using /: %@",
          __PRETTY_FUNCTION__, self);
    return @"/";
  }
  
  /* this is the same like the absolute path, only without a leading "/" .. */
  return [p characterAtIndex:0] == '/' ? [p substringFromIndex:1] : p;
}

static NSString *calcRelativePathOfChildURL(NSString *self, NSString *_base) {
  /*
      the whole base URI is prefix of our URI:
        case a)
          b: "/a/b/c"
          s: "/a/b/c/d"
          >: "c/d"
        case b)
          b: "/a/b/c/"
          s: "/a/b/c/d"
          >: "d"
        case c)
          b: "/a/b/c"
          s: "/a/b/ccc/d"
          >: "ccc/d"
        
      b=s is already catched above and s is guaranteed to be
      longer than b.
  */
  unsigned blen;
  NSString *result;
    
  if (debugURLProcessing)
      NSLog(@"%s:   has base as prefix ...", __PRETTY_FUNCTION__);
  blen = [_base length];
    
  if ([_base characterAtIndex:(blen - 1)] == '/') {
      /* last char of 'b' is '/' => case b) */
      result = [self substringFromIndex:blen];
  }
  else {
      /*
        last char of 'b' is not a slash (either case a) or case c)),
        both are handled in the same way (search last / ...)
      */
      NSRange  r;
        
      r = [_base rangeOfString:@"/" options:NSBackwardsSearch];
      if (r.length == 0) {
        NSLog(@"%s: invalid base, found no '/': '%@' !",
              __PRETTY_FUNCTION__, _base);
        result = self;
      }
      else {
        /* no we have case b) ... */
        result = [self substringFromIndex:(r.location + 1)];
      }
  }
  return result;
}

- (NSString *)commonDirPathPrefixWithString:(NSString *)_other {
  // TODO: the implementation can probably be optimized a _LOT_
  /* eg "/home/images/" vs "/home/index.html" => "/home/", _not_ "/home/i" ! */
  NSString *s;
  unsigned len;
  NSRange  r;
  
  if (_other == self)
    return self;
  
  s   = [self commonPrefixWithString:_other options:0];
  len = [s length];
  if (len == 0)
    return s;
  if ([s characterAtIndex:(len - 1)] == '/')
    return s;
  
  r = [s rangeOfString:@"/" options:NSBackwardsSearch];
  if (r.length == 0) /* hm, can't happen? */
    return nil;
  
  return [s substringToIndex:(r.location + r.length)];;
}

static 
NSString *calcRelativePathOfNonChildURL(NSString *self, NSString *_base) {
  unsigned numSlashes;
  NSString *result;
  NSString *prefix;
  NSString *suffix;
  unsigned plen;
  
  prefix     = [self commonDirPathPrefixWithString:_base];
  plen       = [prefix length];
  suffix     = [self substringFromIndex:plen];
  numSlashes = 0;
    
  if (debugURLProcessing) {
    NSLog(@"%s:   does not have base as prefix, common '%@'\n"
	  @"  self='%@'\n"
	  @"  base='%@'\n"
	  @"  suffix='%@'",
	  __PRETTY_FUNCTION__, prefix, self, _base, suffix);
  }
    
  if (plen == 0) {
      NSLog(@"%s: invalid strings, no common prefix ...: '%@' and '%@' !",
              __PRETTY_FUNCTION__, self, _base);
      return self;
  }
    
  if (plen == 1) {
      /*
        common prefix is root. That is, nothing in common:
          b: "/a/b"
          s: "/l"
          >: "../l"
          
          b: "/a/b/"
          s: "/l"
          >: "../../l"
	(number of slashes without root * "..", then the trailer?)
      */
      unsigned i, len;
      
      len = [_base length];
      
      if ([prefix characterAtIndex:0] != '/') {
        NSLog(@"%s: invalid strings, common prefix '%@' is not '/': "
              @"'%@' and '%@' !",
              __PRETTY_FUNCTION__, self, _base, prefix);
      }
      
      for (i = 1 /* skip root */; i < len; i++) {
	if ([_base characterAtIndex:i] == '/')
	  numSlashes++;
      }
  }
  else {
      /*
	base: /dev/en/projects/bsd/index.html
	self: /dev/en/macosx/
	=>    ../../macosx/
      */
      NSString *basesuffix;
      unsigned i, len;
      
      basesuffix = [_base substringFromIndex:plen];
      len        = [basesuffix length];
      
      for (i = 0; i < len; i++) {
	if ([basesuffix characterAtIndex:i] == '/')
	  numSlashes++;
      }
  }

  if (debugURLProcessing)
    NSLog(@"%s:   slashes: %d", __PRETTY_FUNCTION__, numSlashes);
    
  /* optimization for some depths */
  switch (numSlashes) {
    case 0: /* no slashes in base: b:/a, s:/images/a => images/a */
      result = suffix;
      break;
    case 1: /* one slash in base: b:/a/, s:/images/a => ../images/a, etc */
      result = [@"../" stringByAppendingString:suffix];
      break;
    case 2: result = [@"../../"         stringByAppendingString:suffix]; break;
    case 3: result = [@"../../../"      stringByAppendingString:suffix]; break;
    case 4: result = [@"../../../../"   stringByAppendingString:suffix]; break;
    case 5: result = [@"../../../../../" stringByAppendingString:suffix];break;
    default: {
      NSMutableString *ms;
      unsigned i;
      
      ms = [NSMutableString stringWithCapacity:(numSlashes * 3)];
      for (i = 0; i < numSlashes; i++)
	[ms appendString:@"../"];
      [ms appendString:suffix];
      result = ms;
      break;
    }
  }
  if (debugURLProcessing)
    NSLog(@"%s:  => '%@'", __PRETTY_FUNCTION__, result);
  return result;
}

- (NSString *)urlPathRelativeToPath:(NSString *)_base {
  /*
    This can be used for URLs in the same namespace. It should
    never return an absolute path (it only does in error conditions).
  */
  // TODO: the implementation can probably be optimized a _LOT_
  
  if (_base == nil || [_base length] == 0) {
    NSLog(@"%s: invalid base (nil or length 0), using absolute path '%@' ...",
          __PRETTY_FUNCTION__, self);
    return self;
  }
  
  if ([_base isEqualToString:@"/"])
    return [self urlPathRelativeToRoot];
  if ([_base isEqualToString:self])
    return [self urlPathRelativeToSelf];
  
  if (debugURLProcessing)
    NSLog(@"%s: %@ relative to %@ ...", __PRETTY_FUNCTION__, self, _base);
  
  if ([self hasPrefix:_base])
    return calcRelativePathOfChildURL(self, _base);
  
  return calcRelativePathOfNonChildURL(self, _base);
}

@end /* NSString(URLPathProcessing) */
