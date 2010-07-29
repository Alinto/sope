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

#include "NGImap4FileManager.h"
#include <NGImap4/NGImap4Folder.h>
#include <NGImap4/NGImap4Context.h>
#include <NGImap4/NGImap4Message.h>
#include <NGExtensions/NGFileFolderInfoDataSource.h>
#include "imCommon.h"
#include <NGImap4/NGImap4DataSource.h>

@interface NGImap4FileManager(Privates)

- (BOOL)loginWithUser:(NSString *)_user
  password:(NSString *)_pwd
  host:(NSString *)_host;

- (id<NGImap4Folder>)_lookupFolderAtPath:(NSArray *)_paths;
- (id<NGImap4Folder>)_lookupFolderAtPathString:(NSString *)_path;

- (EOQualifier *)_qualifierForFileName:(NSString *)_filename;

@end

@implementation NGImap4FileManager

static BOOL debugOn = NO;

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if ((debugOn = [ud boolForKey:@"NGImap4FileManagerDebugEnabled"]))
    NSLog(@"NGImap4FileManager debugging is enabled.");
}

- (id)initWithUser:(NSString *)_user
  password:(NSString *)_pwd
  host:(NSString *)_host
{
  if ((self = [super init])) {
    if (![self loginWithUser:_user password:_pwd host:_host]) {
      [self logWithFormat:@"could not login user '%@' host '%@'.", 
              _user, _host];
      [self release];
      return nil;
    }
  }
  return self;
}
- (id)init {
  return [self initWithUser:nil password:nil host:nil];
}
- (id)initWithURL:(NSURL *)_url {
  if (_url == nil) {
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->imapContext = [NGImap4Context alloc]; /* keep gcc happy */
    if ((self->imapContext = [self->imapContext initWithURL:_url]) == nil){
      [self logWithFormat:@"ERROR: got no IMAP4 context for url %@ ...",_url];
      [self release];
      return nil;
    }
    
    [self->imapContext enterSyncMode];
    
    if (![self->imapContext openConnection]) {
      [self logWithFormat:@"ERROR: could not open IMAP4 connection ..."];
      [self release];
      return nil;
    }
    
    if ((self->rootFolder = [[self->imapContext serverRoot] retain]) == nil) {
      [self logWithFormat:@"ERROR: did not find root folder ..."];
      [self release];
      return nil;
    }
    if ((self->currentFolder=[[self->imapContext inboxFolder] retain])==nil) {
      [self logWithFormat:@"ERROR: did not find inbox folder ..."];
      [self release];
      return nil;
    }
    
    if (![[_url path] isEqualToString:@"/"]) {
      if (![self changeCurrentDirectoryPath:[_url path]]) {
	[self logWithFormat:@"ERROR: couldn't change to URL path: %@", _url];
	[self release];
	return nil;
      }
    }
  }
  return self;
}

- (id)imapContext {
  return self->imapContext;
}

- (void)dealloc {
  [self->currentFolder release];
  [self->imapContext   release];
  [self->rootFolder    release];
  [super dealloc];
}

/* operations */

- (BOOL)loginWithUser:(NSString *)_user
  password:(NSString *)_pwd
  host:(NSString *)_host
{
  NSException  *loginException;
  NSDictionary *conDict;
  
  [self->imapContext   release]; self->imapContext   = nil;
  [self->rootFolder    release]; self->rootFolder    = nil;
  [self->currentFolder release]; self->currentFolder = nil;
  
  conDict = [NSDictionary dictionaryWithObjectsAndKeys:
                            _user ? _user : (NSString *)@"anonymous", @"login",
                            _pwd  ? _pwd  : (NSString *)@"",         @"passwd",
                            _host ? _host : (NSString *)@"localhost", @"host",
                            nil];
  
  loginException = nil;
  
  self->imapContext =
    [[NGImap4Context alloc] initWithConnectionDictionary:conDict];
  [self->imapContext enterSyncMode];
  
  if (![self->imapContext openConnection])
    return NO;
  
  if ((self->rootFolder = [[self->imapContext serverRoot] retain]) == nil)
    return NO;
  if ((self->currentFolder = [[self->imapContext inboxFolder] retain]) == nil)
    return NO;
  
  return YES;
}

/* internals */

- (id<NGImap4Folder>)_lookupFolderAtPath:(NSArray *)_paths {
  id<NGImap4Folder> folder;
  NSEnumerator  *e;
  NSString      *path;

  folder = self->currentFolder;

  e = [_paths objectEnumerator];
  while ((path = [e nextObject]) && (folder != nil)) {
    if ([path isEqualToString:@"."])
      continue;
    if ([path isEqualToString:@""])
      continue;
    if ([path isEqualToString:@".."]) {
      folder = [folder parentFolder];
      continue;
    }
    if ([path isEqualToString:@"/"]) {
      folder = self->rootFolder;
      continue;
    }
    
    folder = [folder subFolderWithName:path caseInsensitive:NO];
  }

  return folder;
}
- (id<NGImap4Folder>)_lookupFolderAtPathString:(NSString *)_path {
  return [self _lookupFolderAtPath:[_path pathComponents]];
}

- (EOQualifier *)_qualifierForFileName:(NSString *)_filename {
  return [EOQualifier qualifierWithQualifierFormat:@"uid=%@", _filename];
}

/* directory ops */

- (BOOL)createDirectoryAtPath:(NSString *)_path
  attributes:(NSDictionary *)_attributes
{
  id<NGImap4Folder> folder;
  NSString *filename;
  
  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  filename = [_path lastPathComponent];
  _path    = [_path stringByDeletingLastPathComponent];
  
  if ((folder = [self _lookupFolderAtPathString:_path]) == nil)
    return NO;
  
  return [folder createSubFolderWithName:filename];
}

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path {
  id<NGImap4Folder> folder;

  if (![_path isNotEmpty])
    return NO;

  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  if ((folder = [self _lookupFolderAtPathString:_path]) == nil)
    return NO;

  ASSIGN(self->currentFolder, folder);

  return YES;
}

- (NSString *)currentDirectoryPath {
  if ([self->currentFolder isEqual:[self->currentFolder parentFolder]] ||
      [self->currentFolder parentFolder] == nil)
    return @"/";
  else return [self->currentFolder absoluteName];
}

- (NGImap4Folder *)currentFolder {
  return self->currentFolder;
}

/* operations */

- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  return [self directoryContentsAtPath:_path directories:YES files:YES];
}

- (NSArray *)directoriesAtPath:(NSString *)_path {
  return [self directoryContentsAtPath:_path directories:YES files:NO];
}

- (NSArray *)filesAtPath:(NSString *)_path {
  return [self directoryContentsAtPath:_path directories:NO files:YES];
}

- (NSArray *)directoryContentsAtPath:(NSString *)_path
  directories:(BOOL)_dirs
  files:(BOOL)_files
{
  id<NGImap4Folder> folder;
  NSMutableArray *results;
  NSEnumerator   *e;
  NGImap4Folder  *tmp;
  NGImap4Message *msg;
  
  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];

  if ((folder = [self _lookupFolderAtPath:[_path pathComponents]]) == nil) {
    /* folder does not exist */
    if (debugOn) [self debugWithFormat:@"did not find folder."];
    return nil;
  }
  
  results = [NSMutableArray arrayWithCapacity:64];
  
  /* add folders */
  if (_dirs) {
    if (debugOn) 
      [self debugWithFormat:@"  add subfolders: %@", [folder subFolders]];
    
    e = [[folder subFolders] objectEnumerator];
    while ((tmp = [e nextObject]) != nil)
      [results addObject:[tmp name]];
  }

  /* add messages */
  if (_files) {
    e = [[folder messages] objectEnumerator];
    while ((msg = [e nextObject]))
      [results addObject:[NSString stringWithFormat:@"%d", [msg uid]]];
  }

  if (debugOn) 
    [self debugWithFormat:@"  dir contents: %@", results];
  return results;
}

- (NGImap4Message *)messageAtPath:(NSString *)_path {
  id<NGImap4Folder> folder;
  NSString       *filename;
  EOQualifier    *q;
  NSArray        *msgs;
  NGImap4Message *msg;

  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  filename = [_path lastPathComponent];
  _path    = [_path stringByDeletingLastPathComponent];

  if ((folder = [self _lookupFolderAtPath:[_path pathComponents]]) == nil)
    return nil;

  q = [self _qualifierForFileName:filename];
  //NSLog(@"qualifier: %@", q);

  msgs = [folder messagesForQualifier:q maxCount:2];
  if (![msgs isNotEmpty]) {
    /* no such message .. */
    return nil;
  }
  if ([msgs count] > 1) {
    NSLog(@"multiple messages for uid %@", filename);
    return nil;
  }
  msg = [msgs objectAtIndex:0];
  return msg;
}

- (NSData *)contentsAtPath:(NSString *)_path {
  return [self contentsAtPath:_path part:@""];
}

- (NSData *)contentsAtPath:(NSString *)_path part:(NSString *)_part {
  id<NGImap4Folder> folder;
  NSString          *fileName;

  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];

  fileName = [_path lastPathComponent];
  _path    = [_path stringByDeletingLastPathComponent];

  if ((folder = [self _lookupFolderAtPath:[_path pathComponents]]) == nil)
    return nil;
  
  if (![folder respondsToSelector:@selector(blobForUid:part:)])
    return nil;
  
  return [(NGImap4Folder *)folder blobForUid:[fileName unsignedIntValue] 
			   part:_part];
}

- (BOOL)fileExistsAtPath:(NSString *)_path {
  BOOL isDir;
  return [self fileExistsAtPath:_path isDirectory:&isDir];
}
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)_isDir {
  id<NGImap4Folder> folder;
  NSArray  *paths;
  NSString *fileName;
  
  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];

  if ([_path isEqualToString:@"/"]) {
    if (_isDir) *_isDir = YES;
    return self->rootFolder != nil ? YES : NO;
  }
  
  fileName = [_path lastPathComponent];
  _path    = [_path stringByDeletingLastPathComponent];
  paths    = [_path pathComponents];
  folder   = [self _lookupFolderAtPath:paths];
  
  if (debugOn) {
    [self debugWithFormat:
	    @"base '%@' file '%@' paths: %@, file %@, folder %@", 
	    _path, fileName, paths, fileName, folder];
  }
  
  if (folder == nil)
    return NO;

  if ([fileName isEqualToString:@"."]) {
    *_isDir = YES;
    return YES;
  }
  if ([fileName isEqualToString:@".."]) {
    *_isDir = YES;
    return YES;
  }
  
  // TODO: what is the caseInsensitive good for?
  if (debugOn) [self debugWithFormat:@"  lookup '%@' in %@", fileName, folder];
  if ([folder subFolderWithName:fileName caseInsensitive:NO] != nil) {
    *_isDir = YES;
    return YES;
  }
  
  *_isDir = NO;

  /* check for message 'file' */
  {
    EOQualifier *q;
    NSArray *msgs;

    q = [self _qualifierForFileName:fileName];
    msgs = [folder messagesForQualifier:q maxCount:2];

    if ([msgs isNotEmpty])
      return YES;
  }
  
  return NO;
}

- (BOOL)isReadableFileAtPath:(NSString *)_path {
  return [self fileExistsAtPath:_path];
}
- (BOOL)isWritableFileAtPath:(NSString *)_path {
  return [self fileExistsAtPath:_path];
}
- (BOOL)isExecutableFileAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)isDeletableFileAtPath:(NSString *)_path {
  return [self fileExistsAtPath:_path];
}

/* attributes */

- (NSDictionary *)_fileAttributesOfFolder:(id<NGImap4Folder>)_folder {
  NSMutableDictionary *attrs;
  id tmp;

  attrs = [NSMutableDictionary dictionaryWithCapacity:12];
  
  if ((tmp = [_folder absoluteName]))
    [attrs setObject:tmp forKey:NSFilePath];
  if ((tmp = [_folder name]))
    [attrs setObject:tmp forKey:NSFileName];
  if ((tmp = [[_folder parentFolder] absoluteName]))
    [attrs setObject:tmp forKey:NSParentPath];
  
  [attrs setObject:[self->imapContext login] forKey:NSFileOwnerAccountName];
  [attrs setObject:NSFileTypeDirectory forKey:NSFileType];
  
  return attrs;
}

- (NSDictionary *)_fileAttributesOfMessage:(NGImap4Message *)_msg
  inFolder:(NGImap4Folder *)_folder
{
  NSMutableDictionary *attrs;
  NSString            *fileName, *filePath;
  NSDictionary        *headers;
  id                  tmp;

  static NGMimeHeaderNames *Fields = NULL;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  
  
  headers = (id)[_msg headers];
  //NSLog(@"headers: %@", headers);
  
  fileName = [NSString stringWithFormat:@"%i", [_msg uid]];
  filePath = [[_folder absoluteName] stringByAppendingPathComponent:fileName];
  attrs    = [NSMutableDictionary dictionaryWithCapacity:12];
  
  if (filePath) [attrs setObject:filePath forKey:NSFilePath];
  if (fileName) [attrs setObject:fileName forKey:NSFileName];
  
  if ((tmp = [_folder absoluteName]))
    [attrs setObject:tmp forKey:NSParentPath];
  
  if ((tmp = [headers objectForKey:@"date"])) {
    /* should parse date ? */
    NSCalendarDate *date;

    if ([tmp isKindOfClass:[NSDate class]])
      date = tmp;
    else {
      NGMimeRFC822DateHeaderFieldParser *parser;
      parser = [[NGMimeRFC822DateHeaderFieldParser alloc] init];
      date = [parser parseValue:
                     [tmp dataUsingEncoding:[NSString defaultCStringEncoding]]
                     ofHeaderField:@"date"];
      [parser release];
    }
    
    if (date == nil)
      NSLog(@"could not parse date: %@", tmp);
    
    [attrs setObject:(date != nil ? date : (NSCalendarDate *)tmp) 
	   forKey:NSFileModificationDate];
  }
  
  if ((tmp = [headers objectForKey:Fields->from]))
    [attrs setObject:tmp forKey:@"NGImapFrom"];
  if ((tmp = [headers objectForKey:Fields->xMailer]))
    [attrs setObject:tmp forKey:@"NGImapMailer"];
  if ((tmp = [headers objectForKey:Fields->organization]))
    [attrs setObject:tmp forKey:@"NGImapOrganization"];
  if ((tmp = [headers objectForKey:Fields->to]))
    [attrs setObject:tmp forKey:@"NGImapReceiver"];
  if ((tmp = [headers objectForKey:Fields->subject]))
    [attrs setObject:tmp forKey:@"NGImapSubject"];
  if ((tmp = [headers objectForKey:Fields->contentType]))
    [attrs setObject:tmp forKey:@"NGImapContentType"];
  
  [attrs setObject:[self->imapContext login] forKey:NSFileOwnerAccountName];
  [attrs setObject:[NSNumber numberWithInt:[_msg size]] forKey:NSFileSize];

  if ((tmp = [headers objectForKey:Fields->messageID]))
    [attrs setObject:tmp forKey:@"NSFileIdentifier"];
  else {
    [attrs setObject:[NSNumber numberWithInt:[_msg uid]]
           forKey:@"NSFileIdentifier"];
  }
  
  [attrs setObject:NSFileTypeRegular forKey:NSFileType];
  
  return attrs;
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path
  traverseLink:(BOOL)flag
{
  NSString      *fileName;
  id<NGImap4Folder> folder, sfolder;
  
  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  fileName = [_path lastPathComponent];
  _path    = [_path stringByDeletingLastPathComponent];
  
  if ((folder = [self _lookupFolderAtPath:[_path pathComponents]]) == nil)
    return nil;
  
  /* check for folder */
  
  if ([fileName isEqualToString:@"."])
    return [self _fileAttributesOfFolder:folder];
  if ([fileName isEqualToString:@".."])
    return [self _fileAttributesOfFolder:[folder parentFolder]];
  
  if ((sfolder = [folder subFolderWithName:fileName caseInsensitive:NO])) 
    return [self _fileAttributesOfFolder:sfolder];
  
  /* check for messages */
  
  if (![folder isKindOfClass:[NGImap4Folder class]])
    return nil;
  
  {
    EOQualifier *q;
    NSArray *msgs;
    
    q = [self _qualifierForFileName:fileName];
    msgs = [folder messagesForQualifier:q maxCount:2];

    if (![msgs isNotEmpty]) {
      /* msg does not exist */
      //NSLog(@"did not find msg for qualifier %@ in folder %@", q, folder);
      return nil;
    }
    
    return [self _fileAttributesOfMessage:[msgs objectAtIndex:0]
                 inFolder:(NGImap4Folder *)folder];
  }
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_path {
  NSMutableDictionary *dict;
  id tmp;

  dict = [NSMutableDictionary dictionaryWithCapacity:12];

  if ((tmp = [self->imapContext host]))
    [dict setObject:tmp forKey:@"host"];
  if ((tmp = [self->imapContext login]))
    [dict setObject:tmp forKey:@"login"];
  if ((tmp = [self->imapContext serverName]))
    [dict setObject:tmp forKey:@"serverName"];
  if ((tmp = [self->imapContext serverKind]))
    [dict setObject:tmp forKey:@"serverKind"];
  if ((tmp = [self->imapContext serverVersion]))
    [dict setObject:tmp forKey:@"serverVersion"];
  if ((tmp = [self->imapContext serverTag]))
    [dict setObject:tmp forKey:@"serverTag"];

  if ((tmp = [[self->imapContext trashFolder] absoluteName]))
    [dict setObject:tmp forKey:@"trashFolderPath"];
  if ((tmp = [[self->imapContext sentFolder] absoluteName]))
    [dict setObject:tmp forKey:@"sentFolderPath"];
  if ((tmp = [[self->imapContext draftsFolder] absoluteName]))
    [dict setObject:tmp forKey:@"draftsFolderPath"];
  if ((tmp = [[self->imapContext inboxFolder] absoluteName]))
    [dict setObject:tmp forKey:@"inboxFolderPath"];
  if ((tmp = [[self->imapContext serverRoot] absoluteName]))
    [dict setObject:tmp forKey:@"rootFolderPath"];
  
  return dict;
}


- (EODataSource *)dataSourceAtPath:(NSString *)_path {
  id<NGImap4Folder> f;
  
  if ((f = [self _lookupFolderAtPath:[_path pathComponents]]) == nil)
    return nil;
  
  // TODO: check whether 'f' is really an NGImap4Folder?
  return [[[NGImap4DataSource alloc] initWithFolder:(NGImap4Folder *)f] 
	   autorelease];
}

- (BOOL)syncMode {
  return [self->imapContext isInSyncMode];
}

- (void)setSyncMode:(BOOL)_bool {
  if (_bool)
    [self->imapContext enterSyncMode];
  else
    [self->imapContext leaveSyncMode];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)ms {
  [ms appendFormat:@" ctx=%@",  self->imapContext];
  [ms appendFormat:@" root=%@", self->rootFolder];
  [ms appendFormat:@" wd=%@",   self->currentFolder];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

@end /* NGImap4FileManager */
