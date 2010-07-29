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

#ifndef __SoObjects_SoPermissions_H__
#define __SoObjects_SoPermissions_H__

#import <Foundation/NSString.h>

/*
  Constants for Permission Names and Roles
  
  Reuse predefined permissions ! Added constants for most permissions found
  in Zope to make this more convenient.
*/

extern NSString *SoRole_Manager;
extern NSString *SoRole_Anonymous;
extern NSString *SoRole_Authenticated;
extern NSString *SoRole_Owner;

extern NSString *SoPerm_AccessContentsInformation;
extern NSString *SoPerm_AddDatabaseMethods;
extern NSString *SoPerm_AddDocumentsImagesAndFiles;
extern NSString *SoPerm_AddExternalMethods;
extern NSString *SoPerm_AddFolders;
extern NSString *SoPerm_AddMailHostObjects;
extern NSString *SoPerm_AddPythonScripts;
extern NSString *SoPerm_AddSiteRoots;
extern NSString *SoPerm_AddUserFolders;
extern NSString *SoPerm_AddVersions;
extern NSString *SoPerm_AddVocabularies;
extern NSString *SoPerm_ChangeDatabaseConnections;
extern NSString *SoPerm_ChangeExternalMethods;
extern NSString *SoPerm_ChangeImagesAndFiles;
extern NSString *SoPerm_ChangePythonScripts;
extern NSString *SoPerm_ChangeVersions;
extern NSString *SoPerm_ChangeBindings;
extern NSString *SoPerm_ChangeConfiguration;
extern NSString *SoPerm_ChangePermissions;
extern NSString *SoPerm_ChangeProxyRoles;
extern NSString *SoPerm_DeleteObjects;
extern NSString *SoPerm_ManageAccessRules;
extern NSString *SoPerm_ManageVocabulary;
extern NSString *SoPerm_ManageProperties;
extern NSString *SoPerm_ManageUsers;
extern NSString *SoPerm_OpenCloseDatabaseConnections;
extern NSString *SoPerm_QueryVocabulary;
extern NSString *SoPerm_SaveDiscardVersionChanges;
extern NSString *SoPerm_TakeOwnership;
extern NSString *SoPerm_TestDatabaseConnections;
extern NSString *SoPerm_UndoChanges;
extern NSString *SoPerm_UseDatabaseMethods;
extern NSString *SoPerm_UseMailHostServices;
extern NSString *SoPerm_View;
extern NSString *SoPerm_ViewHistory;
extern NSString *SoPerm_ViewManagementScreens;
extern NSString *SoPerm_WebDAVAccess;
extern NSString *SoPerm_WebDAVLockItems;
extern NSString *SoPerm_WebDAVUnlockItems;

#endif /* __SoObjects_SoPermissions_H__ */
