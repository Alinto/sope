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

#include "NGLdapFileManager.h"
#include "NGLdapConnection.h"
#include "NGLdapEntry.h"
#include "NGLdapAttribute.h"
#include "NGLdapURL.h"
#include "NSString+DN.h"
#import <NGExtensions/NGFileFolderInfoDataSource.h>
#include "common.h"

@implementation NGLdapFileManager

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

static NSString *LDAPObjectClassKey = @"objectclass";
static NSArray  *objectClassAttrs = nil;
static NSArray  *fileInfoAttrs    = nil;

+ (void)_initCache {
  if (objectClassAttrs == nil) {
    objectClassAttrs =
      [[NSArray alloc] initWithObjects:&LDAPObjectClassKey count:1];
  }
  if (fileInfoAttrs == nil) {
    fileInfoAttrs =
      [[NSArray alloc] initWithObjects:
                         @"objectclass",
                         @"createTimestamp",
                         @"modifyTimestamp",
                         @"creatorsName",
                         @"modifiersName",
                         nil];
  }
}

- (id)initWithLdapConnection:(NGLdapConnection *)_con { // designated initializer
  if (_con == nil) {
    [self release];
    return nil;
  }
  
  [[self class] _initCache];
  
  if ((self = [super init])) {
    self->connection = [_con retain];
  }
  return self;
}

- (id)initWithHostName:(NSString *)_host port:(int)_port
  bindDN:(NSString *)_login credentials:(NSString *)_pwd
  rootDN:(NSString *)_rootDN
{
  NGLdapConnection *ldap;
  
  ldap = [[NGLdapConnection alloc] initWithHostName:_host port:_port?_port:389];
  if (ldap == nil) {
    [self release];
    return nil;
  }
  ldap = [ldap autorelease];
  
  if (![ldap bindWithMethod:@"simple" binddn:_login credentials:_pwd]) {
    NSLog(@"couldn't bind as DN '%@' with %@", _login, ldap);
    [self release];
    return nil;
  }
  
  if ((self = [self initWithLdapConnection:ldap])) {
    if (_rootDN == nil) {
      /* check cn=config as available in OpenLDAP */
      NSArray *nctxs;
      
      if ((nctxs = [self->connection namingContexts])) {
        if ([nctxs count] > 1)
          NSLog(@"WARNING: more than one naming context handled by server !");
        if ([nctxs isNotEmpty])
          _rootDN = [[nctxs objectAtIndex:0] lowercaseString];
      }
    }
    
    if (_rootDN) {
      ASSIGNCOPY(self->rootDN,    _rootDN);
      ASSIGNCOPY(self->currentDN, _rootDN);
      self->currentPath = @"/";
    }
  }
  return self;
}

- (id)initWithURLString:(NSString *)_url {
  NGLdapURL *url;

  if ((url = [NGLdapURL ldapURLWithString:_url]) == nil) {
    /* couldn't parse URL */
    [self release];
    return nil;
  }
  
  return [self initWithHostName:[url hostName] port:[url port]
               bindDN:nil credentials:nil
               rootDN:[url baseDN]];
}
- (id)initWithURL:(id)_url {
  return (![_url isKindOfClass:[NSURL class]])
    ? [self initWithURLString:[_url stringValue]]
    : [self initWithURLString:[_url absoluteString]];
}

- (void)dealloc {
  [self->connection  release];
  [self->rootDN      release];
  [self->currentDN   release];
  [self->currentPath release];
  [super dealloc];
}

/* internals */

- (NSString *)_rdnForPathComponent:(NSString *)_pathComponent {
  return _pathComponent;
}
- (NSString *)_pathComponentForRDN:(NSString *)_rdn {
  return _rdn;
}

- (NSString *)pathForDN:(NSString *)_dn {
  NSEnumerator *dnComponents;
  NSString     *path;
  NSString     *rdn;
  
  if (_dn == nil) return nil;
  _dn = [_dn lowercaseString];
  
  if (![_dn hasSuffix:self->rootDN]) {
    /* DN is not rooted in this hierachy */
    return nil;
  }

  /* cut of root */
  _dn = [_dn substringToIndex:([_dn length] - [self->rootDN length])];
  
  path = @"/";
  dnComponents = [[_dn dnComponents] reverseObjectEnumerator];
  while ((rdn = [dnComponents nextObject])) {
    NSString *pathComponent;
    
    pathComponent = [self _pathComponentForRDN:rdn];
    
    path = [path stringByAppendingPathComponent:pathComponent];
  }
  return path;
}

- (NGLdapConnection *)ldapConnection {
  return self->connection;
}
- (NSString *)dnForPath:(NSString *)_path {
  NSString *dn = nil;
  NSArray  *pathComponents;
  unsigned i, count;

  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  if (![_path isNotEmpty]) return nil;
  
  NSAssert1([_path isAbsolutePath],
	    @"path %@ is not an absolute path (after append to cwd) !", _path);
  NSAssert(self->rootDN, @"missing root DN !");
  
  pathComponents = [_path pathComponents];
  for (i = 0, count = [pathComponents count]; i < count; i++) {
    NSString *pathComponent;
    NSString *rdn;
    
    pathComponent = [pathComponents objectAtIndex:i];

    if ([pathComponent isEqualToString:@"."])
      continue;
    if (![pathComponent isNotEmpty])
      continue;

    if ([pathComponent isEqualToString:@"/"]) {
      dn = self->rootDN;
      continue;
    }
    
    if ([pathComponent isEqualToString:@".."]) {
      dn = [dn stringByDeletingLastDNComponent];
      continue;
    }
    
    rdn = [self _rdnForPathComponent:pathComponent];
    dn  = [dn stringByAppendingDNComponent:rdn];
  }
  
  return [dn lowercaseString];
}

/* accessors */

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path {
  NSString *dn;
  NSString *path;

  if (![_path isNotEmpty])
    return NO;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return NO;
  
  if ((path = [self pathForDN:dn]) == nil)
    return NO;
  
  ASSIGNCOPY(self->currentDN,   dn);
  ASSIGNCOPY(self->currentPath, path);
  return YES;
}

- (NSString *)currentDirectoryPath {
  return self->currentPath;
}


- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  NSString       *dn;
  NSEnumerator   *e;
  NSMutableArray *rdns;
  NGLdapEntry    *entry;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return nil;
  
  e = [self->connection flatSearchAtBaseDN:dn
                        qualifier:nil
                        attributes:objectClassAttrs];
  if (e == nil)
    return nil;

  rdns = nil;
  while ((entry = [e nextObject])) {
    if (rdns == nil)
      rdns = [NSMutableArray arrayWithCapacity:128];
    
    [rdns addObject:[entry rdn]];
  }

  return [[rdns copy] autorelease];
}

- (NSArray *)subpathsAtPath:(NSString *)_path {
  NSString       *dn;
  NSEnumerator   *e;
  NSMutableArray *paths;
  NGLdapEntry    *entry;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return nil;
  
  _path = [self pathForDN:dn];
  
  e = [self->connection deepSearchAtBaseDN:dn
                        qualifier:nil
                        attributes:objectClassAttrs];
  if (e == nil)
    return nil;
  
  paths = nil;
  while ((entry = [e nextObject])) {
    NSString *path;
    NSString *sdn;
    
    sdn = [entry dn];
    
    if ((path = [self pathForDN:sdn]) == nil) {
      NSLog(@"got no path for dn '%@' ..", sdn);
      continue;
    }

    if ([path hasPrefix:_path])
      path = [path substringFromIndex:[_path length]];

    if (paths == nil)
      paths = [NSMutableArray arrayWithCapacity:128];
    
    [paths addObject:path];
  }
  
  return [[paths copy] autorelease];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path traverseLink:(BOOL)_fl {
  NSString        *dn;
  NGLdapEntry     *entry;
  NGLdapAttribute *attr;
  id    keys[10];
  id    vals[10];
  short count;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return NO;
  
  entry = [self->connection entryAtDN:dn attributes:fileInfoAttrs];
  if (entry == nil)
    return nil;
  
  count = 0;
  if ((attr = [entry attributeWithName:@"modifytimestamp"])) {
    keys[count] = NSFileModificationDate;
    vals[count] = [[attr stringValueAtIndex:0] ldapTimestamp];
    count++;
  }
  if ((attr = [entry attributeWithName:@"modifiersname"])) {
    keys[count] = NSFileOwnerAccountName;
    vals[count] = [[attr allStringValues] componentsJoinedByString:@","];
    count++;
  }
  if ((attr = [entry attributeWithName:@"creatorsname"])) {
    keys[count] = @"NSFileCreatorAccountName";
    vals[count] = [[attr allStringValues] componentsJoinedByString:@","];
    count++;
  }
  if ((attr = [entry attributeWithName:@"createtimestamp"])) {
    keys[count] = @"NSFileCreationDate";
    vals[count] = [[attr stringValueAtIndex:0] ldapTimestamp];
    count++;
  }
  if ((attr = [entry attributeWithName:@"objectclass"])) {
    keys[count] = @"LDAPObjectClasses";
    vals[count] = [attr allStringValues];
    count++;
  }

  keys[count] = @"NSFileIdentifier";
  if ((vals[count] = [entry dn]))
    count++;
  
  keys[count] = NSFilePath;
  if ((vals[count] = _path))
    count++;
  
  keys[count] = NSFileName;
  if ((vals[count] = [self _pathComponentForRDN:[dn lastDNComponent]]))
    count++;
  
  return [NSDictionary dictionaryWithObjects:vals forKeys:keys count:count];
}

/* determine access */

- (BOOL)fileExistsAtPath:(NSString *)_path {
  return [self fileExistsAtPath:_path isDirectory:NULL];
}
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)_isDir {
  NSString    *dn;
  NGLdapEntry *entry;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return NO;
  
  entry = [self->connection entryAtDN:dn attributes:objectClassAttrs];
  if (entry == nil)
    return NO;

  if (_isDir) {
    NSEnumerator *e;

    /* is-dir based on child-availablitiy */
    e = [self->connection flatSearchAtBaseDN:dn
                          qualifier:nil
                          attributes:objectClassAttrs];
    *_isDir = [e nextObject] ? YES : NO;
  }
  return YES;
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

/* reading contents */

- (BOOL)contentsEqualAtPath:(NSString *)_path1 andPath:(NSString *)_path2 {
  NSString    *dn1, *dn2;
  NGLdapEntry *e1, *e2;

  if ((dn1 = [self dnForPath:_path1]) == nil)
    return NO;
  if ((dn2 = [self dnForPath:_path2]) == nil)
    return NO;
  
  if ([dn1 isEqualToString:dn2])
    /* same DN */
    return YES;

  e1 = [self->connection entryAtDN:dn1 attributes:nil];
  e2 = [self->connection entryAtDN:dn2 attributes:nil];
  
  return [e1 isEqual:e2];
}
- (NSData *)contentsAtPath:(NSString *)_path {
  /* generate LDIF for record */
  NSString        *dn;
  NGLdapEntry     *entry;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return NO;
  
  entry = [self->connection entryAtDN:dn attributes:nil];
  if (entry == nil)
    return nil;
  
  return [[entry ldif] dataUsingEncoding:NSUTF8StringEncoding];
}

/* modifications */

- (NSDictionary *)_errDictForPath:(NSString *)_path toPath:(NSString *)_dest
  dn:(NSString *)_dn reason:(NSString *)_reason
{
  id    keys[6];
  id    values[6];
  short count;

  count = 0;
  
  if (_path) {
    keys[count]   = @"Path";
    values[count] = _path;
    count++;
  }
  if (_dest) {
    keys[count]   = @"ToPath";
    values[count] = _dest;
    count++;
  }
  if (_reason) {
    keys[count]   = @"Error";
    values[count] = _reason;
    count++;
  }
  if (_dn) {
    keys[count]   = @"dn";
    values[count] = _dn;
    count++;
    keys[count]   = @"ldap";
    values[count] = self->connection;
    count++;
  }
  
  return [NSDictionary dictionaryWithObjects:values forKeys:keys count:count];
}

- (BOOL)removeFileAtPath:(NSString *)_path handler:(id)_fhandler {
  NSString *dn;
  
  [_fhandler fileManager:(id)self willProcessPath:_path];
  
  if ((dn = [self dnForPath:_path]) == nil) {
    if (_fhandler) {
      NSDictionary *errDict;
      
      errDict = [self _errDictForPath:_path toPath:nil dn:nil
                      reason:@"couldn't map path to LDAP dn"];
      
      if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
        return YES;
    }
    return NO;
  }
  
  /* should delete sub-entries first ... */
  
  /* delete entry */
  
  if (![self->connection removeEntryWithDN:dn]) {
    if (_fhandler) {
      NSDictionary *errDict;
      
      errDict = [self _errDictForPath:_path toPath:nil dn:dn
                      reason:@"couldn't remove LDAP entry"];
      
      if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
        return YES;
    }
    return NO;
  }
  
  return YES;
}

- (BOOL)copyPath:(NSString *)_path toPath:(NSString *)_destination
  handler:(id)_fhandler
{
  NGLdapEntry *e;
  NSString    *fromDN, *toDN, *toRDN;
  
  [_fhandler fileManager:(id)self willProcessPath:_path];
  
  if ((fromDN = [self dnForPath:_path]) == nil) {
    if (_fhandler) {
      NSDictionary *errDict;
      
      errDict = [self _errDictForPath:_path toPath:_destination dn:nil
                      reason:@"couldn't map source path to LDAP dn"];
      
      if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
        return YES;
    }
    return NO;
  }

  /*
    split destination. 'toDN' is the target 'directory', 'toRDN' the name of
    the target 'file'
  */
  toDN  = [self dnForPath:_destination];
  toRDN = [toDN lastDNComponent];
  toDN  = [toDN stringByDeletingLastDNComponent];
  
  if ((toDN == nil) || (toRDN == nil)) {
    if (_fhandler) {
      NSDictionary *errDict;
      
      errDict = [self _errDictForPath:_path toPath:_destination dn:fromDN
                      reason:@"couldn't map destination path to LDAP dn"];
      
      if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
        return YES;
    }
    return NO;
  }

  /* process record */
  
  if ((e = [self->connection entryAtDN:fromDN attributes:nil]) == nil) {
    if (_fhandler) {
      NSDictionary *errDict;
      
      errDict = [self _errDictForPath:_path toPath:_destination dn:fromDN
                      reason:@"couldn't load source LDAP record"];
      
      if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
        return YES;
    }
    return NO;
  }
  else {
    /* create new record with the attributes of the old one */
    NGLdapEntry *newe;
    NSArray     *attrs;
    
    attrs = [[e attributes] allValues];
    newe  = [[NGLdapEntry alloc] initWithDN:toDN attributes:attrs];
    newe  = [newe autorelease];
    
    /* insert record in target space */
    if (![self->connection addEntry:newe]) {
      /* insert failed */

      if (_fhandler) {
        NSDictionary *errDict;
        
        errDict = [self _errDictForPath:_path toPath:_destination dn:toDN
                        reason:@"couldn't insert LDAP record in target dn"];
        
        if ([_fhandler fileManager:(id)self shouldProceedAfterError:errDict])
          return YES;
      }
      return NO;
    }
  }
  
  /* should process children ? */
  
  return YES;
}

- (BOOL)movePath:(NSString *)_path toPath:(NSString *)_destination 
  handler:(id)_fhandler
{
  /* needs to invoke a modrdn operation */
  [_fhandler fileManager:(id)self willProcessPath:_path];
  
  return NO;
}

- (BOOL)linkPath:(NSString *)_path toPath:(NSString *)_destination 
  handler:(id)_fhandler
{
  /* LDAP doesn't support links .. */
  [_fhandler fileManager:(id)self willProcessPath:_path];
  
  return NO;
}

- (BOOL)createFileAtPath:(NSString *)path
  contents:(NSData *)contents
  attributes:(NSDictionary *)attributes
{
  return NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->rootDN)
    [ms appendFormat:@" root=%@", self->rootDN];
  if (self->currentDN && ![self->currentDN isEqualToString:self->rootDN])
    [ms appendFormat:@" cwd=%@", self->currentDN];
  
  if (self->connection)
    [ms appendFormat:@" ldap=%@", self->connection];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGLdapFileManager */

#include <NGLdap/NGLdapDataSource.h>
#include <NGLdap/NGLdapGlobalID.h>

@implementation NGLdapFileManager(ExtendedFileManager)

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)supportsLockingAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path {
  return YES;
}

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path {
  /* should decode LDIF and store at path .. */
  return NO;
}

/* datasources (work on folders) */

- (EODataSource *)dataSourceAtPath:(NSString *)_path {
  NGLdapDataSource *ds;
  NSString *dn;
  
  if ((dn = [self dnForPath:_path]) == nil)
    /* couldn't get DN for specified path .. */
    return nil;
  
  ds = [[NGLdapDataSource alloc]
                          initWithLdapConnection:self->connection
                          searchBase:dn];
  return [ds autorelease];
}
- (EODataSource *)dataSource {
  return [self dataSourceAtPath:[self currentDirectoryPath]];
}

/* global-IDs */

- (EOGlobalID *)globalIDForPath:(NSString *)_path {
  NSString       *dn;
  NGLdapGlobalID *gid;
  
  if ((dn = [self dnForPath:_path]) == nil)
    return nil;
  
  gid = [[NGLdapGlobalID alloc]
                         initWithHost:[self->connection hostName]
                         port:[self->connection port]
                         dn:dn];
  return [gid autorelease];
}

- (NSString *)pathForGlobalID:(EOGlobalID *)_gid {
  NGLdapGlobalID *gid;
  
  if (![_gid isKindOfClass:[NGLdapGlobalID class]])
    return nil;

  gid = (NGLdapGlobalID *)_gid;
  
  /* check whether host&port is correct */
  if (![[self->connection hostName] isEqualToString:[gid host]])
    return nil;
  if (![self->connection port] == [gid port])
    return nil;
  
  return [self pathForDN:[gid dn]];
}

/* trash */

- (BOOL)supportsTrashFolderAtPath:(NSString *)_path {
  return NO;
}
- (NSString *)trashFolderForPath:(NSString *)_path {
  return nil;
}

@end /* NGLdapFileManager(ExtendedFileManager) */
