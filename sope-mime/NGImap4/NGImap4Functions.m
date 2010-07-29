/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include <NGImap4/NGImap4Functions.h>
#include <NGImap4/NGImap4Folder.h>
#include <NGImap4/NGImap4Support.h>
#include <NGImap4/NGImap4Context.h>
#include <NGImap4/NGImap4Client.h>
#include "imCommon.h"

@interface NGImap4Context(Private)
- (void)setLastException:(NSException *)_exception;
@end /*NGImap4Context(Private) */

@implementation NGImap4FolderHandler

static int                  LogImapEnabled = -1;
static NGImap4FolderHandler *sharedHandler = nil; // THREAD
static BOOL                 debugFolderLookup = NO;

+ (id)sharedImap4FolderHandler {
  if (sharedHandler == nil)
    sharedHandler = [[self alloc] init];
  return sharedHandler;
}

void _checkDefault() {
  if (LogImapEnabled == -1) {
    LogImapEnabled = [[NSUserDefaults standardUserDefaults]
                                      boolForKey:@"ImapLogEnabled"]?1:0;
  }
}

BOOL _checkResult(NGImap4Context *_ctx, NSDictionary *_dict,
                  const char *_command)
{
  _checkDefault();
  if (![[_dict objectForKey:@"result"] boolValue]) {
    if (![_ctx lastException]) {
      NGImap4ResponseException *exc;

      if (LogImapEnabled) {
        NSLog(@"ERROR[%s]: got error during %s: %@",
            __PRETTY_FUNCTION__, _command, _dict);
      }
      exc = [[NGImap4ResponseException alloc]
                                       initWithFormat:
                                       [_dict objectForKey:@"reason"]];
      [_ctx setLastException:exc];
      [_ctx removeAllFromRefresh];
      [exc release]; exc = nil;
    }
    return NO;
  }
  return YES;
}

- (BOOL)isFolder:(id<NGImap4Folder>)_child 
  aSubfolderOf:(id<NGImap4Folder>)_parent
{
  return _isSubFolder(_parent, _child);
}
BOOL _isSubFolder(id<NGImap4Folder> parentFolder, id<NGImap4Folder>_folder) {
  NSEnumerator  *enumerator;
  NGImap4Folder *folder;
  
  enumerator = [[parentFolder subFolders] objectEnumerator];
  while ((folder = [enumerator nextObject])) {
    if ([_folder isEqual:folder])
      break;
    
    if ([[parentFolder context] lastException])
      return NO;
  }
  return (folder != nil) ? YES : NO;
}

- (NGImap4Folder *)subfolderWithName:(NSString *)_name
  parentFolder:(id<NGImap4Folder>)_parent
  ignoreCase:(BOOL)_caseIns
{
  return _subFolderWithName(_parent, _name, _caseIns);
}
NGImap4Folder *_subFolderWithName
(id<NGImap4Folder> _parent, NSString *_name, BOOL _caseIns) 
{
  NSEnumerator  *enumerator;
  NGImap4Folder *f;

  if (_caseIns)
    _name = [_name lowercaseString];
  
  if (debugFolderLookup)
    NSLog(@"LOOKUP %@ IN %@", _name, [_parent subFolders]);
  
  enumerator = [[_parent subFolders] objectEnumerator];
  while ((f = [enumerator nextObject]) != nil) {
    NSString *n;

    n = [f name];
    if (_caseIns) 
      n = [n lowercaseString];

    if ([n isEqualToString:_name]) {
      if (debugFolderLookup) NSLog(@"  FOUND: %@", f);
      return f;
    }

    if ([[_parent context] lastException] != nil) {
      if (debugFolderLookup) {
	NSLog(@"  FAILED: %@", [[_parent context] lastException]);
      }
      return NO;
    }
  }
  if (debugFolderLookup) NSLog(@"  NOT FOUND.");
  return nil;
}

BOOL _hasNewMessagesInSubFolder(id<NGImap4Folder> _parent, BOOL _fetch) {
  NSEnumerator *enumerator;
  id           obj;
  
  enumerator = [[_parent subFolders] objectEnumerator];
  while ((obj = [enumerator nextObject])) {
    if ([obj hasNewMessagesSearchRecursiv:YES fetchOnDemand:_fetch])
      return YES;

    if ([[_parent context] lastException])
      return NO;
  }
  return NO;
}

BOOL _hasUnseenMessagesInSubFolder(id<NGImap4Folder> self, BOOL _fetch) {
  NSEnumerator *enumerator;
  id           obj;
  
  enumerator = [[self subFolders] objectEnumerator];
  while ((obj = [enumerator nextObject])) {
    if ([obj hasUnseenMessagesSearchRecursiv:YES fetchOnDemand:_fetch])
      return YES;

    if ([[self context] lastException])
      return NO;
  }
  return NO;
}

BOOL _deleteSubFolder(id<NGImap4Folder> self, NGImap4Folder *_folder) {
  /* TODO: jr, why is this a function and not a method ?
     AW: they will be used in 2 different classes ...
         'grep _deleteSubFolder *.m' */
  
  NSEnumerator   *enumerator;
  NGImap4Folder  *folder;
  NGImap4Context *ctx;

  _checkDefault();
    
  ctx = [self context];

  [ctx resetLastException];
  
  if (!_isSubFolder(self, _folder)) {
    if (LogImapEnabled) {
      NSLog(@"ERROR: Couldn`t delete %@ because it`s no subfolder of %@",
            _folder, self);
    }
    return NO;
  }
  enumerator = [[_folder subFolders] objectEnumerator];
  
  while ((folder = [enumerator nextObject])) {
    [_folder deleteSubFolder:folder];

    if ([ctx lastException]) {
      [self resetSubFolders];
      return NO;
    }
  }
  if (![_folder isReadOnly] && ![_folder noselect])  {
    NSDictionary *result;

    if ([self isKindOfClass:[NGImap4Folder class]]) { 
      if (![ctx registerAsSelectedFolder:(NGImap4Folder *)self]) {
        [self resetSubFolders];
        return NO;
      }
    }
    [ctx resetLastException];
    
    result = [[ctx client] delete:[_folder absoluteName]];

    if (!_checkResult(ctx, result, __PRETTY_FUNCTION__)) {
      [self resetSubFolders];
      return NO;
    }
    [self resetSubFolders];
    [ctx removeFromRefresh:_folder];
    return YES;
  }
  return NO;
}

BOOL _copySubFolder(id<NGImap4Folder> self,
                    id<NGImap4Folder> _f, id<NGImap4Folder> _toFolder)
{
  /* TODO: jr, why is this a function and not a method ? 
     AW: they will be used in 2 different classes ...
         'grep _deleteSubFolder *.m' */
  
  NSEnumerator  *enumerator;
  NGImap4Folder *folder, *subFolder;  
  NSString      *folderName;

  _checkDefault();
  
  if (!_isSubFolder(self, _f)) {
    if (LogImapEnabled) {
      NSLog(@"ERROR: Couldn`t copy %@ because it`s no subfolder of %@",
            _f, self);
    }
    return NO;
  }
  if ([[_toFolder absoluteName] hasPrefix:[_f absoluteName]]) {
    if (LogImapEnabled) {
      NSLog(@"ERROR: Couldn`t copy %@ is subFolder from %@",
            _toFolder, _f);
    }
    return NO;
  }
  
  if ([self isEqual:_toFolder])
    return YES;
  
  folderName = [_f name];
  self       = [self retain];
  
  if (![_toFolder createSubFolderWithName:folderName]) {
    return NO;
  }
  [self autorelease];
  enumerator = [[_toFolder subFolders] objectEnumerator];
  while ((folder = [enumerator nextObject])) {
    if ([[folder name] isEqualToString:folderName])
      break;
    
    if ([[self context] lastException])
      return NO;
  }
  if (!folder)
    return NO;

  if (![_f noselect]) {
    
    if (![[self context] registerAsSelectedFolder:(NGImap4Folder *)_f])
      return NO;
    
    if ([_f exists] > 0) {
      NSDictionary *res;
      
      res = [[[self context] client] copyFrom:0 to:[_f exists]
                                     toFolder:[folder absoluteName]];
      if (!_checkResult([self context], res, __PRETTY_FUNCTION__))
        return NO;
    }
  }
  [folder resetFolder];
  enumerator = [[_f subFolders] objectEnumerator];
  while ((subFolder = [enumerator nextObject])) {
    if (![_f copySubFolder:subFolder to:folder])
      break;

    if ([[self context] lastException])
      return NO;
  }
  return (subFolder == nil) ? YES : NO;
}

BOOL _moveSubFolder(id<NGImap4Folder> self, NGImap4Folder *_f,
                    id<NGImap4Folder>_folder) 
{
  if (!_isSubFolder(self, _f))
    return NO;

  if ([[_folder absoluteName] hasSuffix:[_f absoluteName]])
    /* _folder is the same as or a subfolder from _f */
    return NO;

  if ([_folder isEqual:self])
    return YES;

  if (![self copySubFolder:_f to:(NGImap4Folder *)_folder])
    return NO;
  
  return [self deleteSubFolder:_f];
}

BOOL _createSubFolderWithName(id<NGImap4Folder> self, NSString *_name,
                              BOOL _append)
{
  NGImap4Context *ctx;
  NSRange        r;
  NSDictionary   *res;

  if (_name == nil)
    return NO;

  ctx = [self context];
  r   = [_name rangeOfString:[[ctx client] delimiter]];
  if (r.length > 0) {
    NSException *e;
    
    e = [[NGImap4Exception alloc]
	  initWithFormat:@"It`s not allowed to use '%@' in "
	    @"a foldername <%@>", [[ctx client] delimiter],
	    _name];
    [ctx setLastException:e];
    [e release];
    return NO;
  }
  
  [ctx resetLastException];
  if (_append)
    _name = [[self absoluteName] stringByAppendingPathComponent:_name];

  res = [[ctx client] create:_name];
  if (!_checkResult(ctx, res, __PRETTY_FUNCTION__))
    return NO;

  res = [[ctx client] subscribe:_name];

  if (!_checkResult(ctx, res, __PRETTY_FUNCTION__))
    return NO;

  [self resetSubFolders];
  return YES;
}
- (NSException *)createSubfolderWithName:(NSString *)_name
  parentFolder:(id<NGImap4Folder>)_parent
  append:(BOOL)_append
{
  if (_createSubFolderWithName(_parent, _name, _append))
    return nil;
  
  return [[_parent context] lastException];
}

@end /* NGImap4FolderHandler */

NSString *
SaneFolderName(NSString *folderName)
{
  NSString *saneFName;

  saneFName = [[folderName stringByReplacingString: @"\\"
                                        withString: @"\\\\"]
                stringByReplacingString: @"\""
                             withString: @"\\\""];

  return saneFName;
}
