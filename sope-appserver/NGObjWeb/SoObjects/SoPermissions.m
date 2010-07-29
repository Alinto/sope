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

#include "SoPermissions.h"
#include "common.h"

/* roles */

NSString *SoRole_Manager       = @"Manager";
NSString *SoRole_Anonymous     = @"Anonymous";
NSString *SoRole_Authenticated = @"Authenticated";
NSString *SoRole_Owner         = @"Owner";

/* permissions */

NSString *SoPerm_AccessContentsInformation    = @"Access Contents Information";
NSString *SoPerm_AddDatabaseMethods           = @"Add Database Methods";
NSString *SoPerm_AddDocumentsImagesAndFiles   = @"Add Documents, Images, and Files";
NSString *SoPerm_AddExternalMethods           = @"Add External Methods";
NSString *SoPerm_AddFolders                   = @"Add Folders";
NSString *SoPerm_AddMailHostObjects           = @"Add MailHost Objects";
NSString *SoPerm_AddPythonScripts             = @"Add Python Scripts";
NSString *SoPerm_AddSiteRoots                 = @"Add Site Roots";
NSString *SoPerm_AddUserFolders               = @"Add User Folders";
NSString *SoPerm_AddVersions                  = @"Add Versions";
NSString *SoPerm_AddVocabularies              = @"Add Vocabularies";
NSString *SoPerm_ChangeDatabaseConnections    = @"Change Database Connections";
NSString *SoPerm_ChangeExternalMethods        = @"Change External Methods";
NSString *SoPerm_ChangeImagesAndFiles         = @"Change Images and Files";
NSString *SoPerm_ChangePythonScripts          = @"Change Python Scripts";
NSString *SoPerm_ChangeVersions               = @"Change Versions";
NSString *SoPerm_ChangeBindings               = @"Change Bindings";
NSString *SoPerm_ChangeConfiguration          = @"Change Configuration";
NSString *SoPerm_ChangePermissions            = @"Change Permissions";
NSString *SoPerm_ChangeProxyRoles             = @"Change Proxy Roles";
NSString *SoPerm_DeleteObjects                = @"Delete Objects";
NSString *SoPerm_ManageAccessRules            = @"Manage Access Rules";
NSString *SoPerm_ManageVocabulary             = @"Manage Vocabulary";
NSString *SoPerm_ManageProperties             = @"Manage Properties";
NSString *SoPerm_ManageUsers                  = @"Manage Users";
NSString *SoPerm_OpenCloseDatabaseConnections = @"Open/Close Database Connections";
NSString *SoPerm_QueryVocabulary           = @"Query Vocabulary";
NSString *SoPerm_SaveDiscardVersionChanges = @"Save/Discard Version Changes";
NSString *SoPerm_TakeOwnership             = @"Take Ownership";
NSString *SoPerm_TestDatabaseConnections   = @"Test Database Connections";
NSString *SoPerm_UndoChanges               = @"Undo Changes";
NSString *SoPerm_UseDatabaseMethods        = @"Use Database Methods";
NSString *SoPerm_UseMailHostServices       = @"Use MailHost Services";
NSString *SoPerm_View                      = @"View";
NSString *SoPerm_ViewHistory               = @"View History";
NSString *SoPerm_ViewManagementScreens     = @"View Management Screens";
NSString *SoPerm_WebDAVAccess              = @"WebDAV Access";
NSString *SoPerm_WebDAVLockItems           = @"WebDAV Lock Items";
NSString *SoPerm_WebDAVUnlockItems         = @"WebDAV Unlock Items";
