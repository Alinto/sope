#
#   messages.make
#
#   Prepare messages
#
#   Copyright (C) 2002 Free Software Foundation, Inc.
#
#   Author:  Nicola Pero <n.pero@mi.flashnet.it>
#
#   This file is part of the GNUstep Makefile Package.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#   
#   You should have received a copy of the GNU General Public
#   License along with this library; see the file COPYING.LIB.
#   If not, write to the Free Software Foundation,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Helpful messages which are always printed

# Instance/Shared/strings.make
ALWAYS_ECHO_NO_FILES = @(echo " No files specified ... nothing done.")
ALWAYS_ECHO_NO_LANGUAGES = @(echo " No LANGUAGES specified ... nothing done.")

# Eventual translation of the ALWAYS_ECHO_XXX messages should be done
# here ...

ifneq ($(messages),yes)

  # General messages
  ECHO_PREPROCESSING = @(echo " Preprocessing file $< ...";
  ECHO_COMPILING = @(echo " Compiling file $< ...";
  ECHO_LINKING   = @(echo " Linking $(GNUSTEP_TYPE) $(GNUSTEP_INSTANCE) ...";
  ECHO_JAVAHING  = @(echo " Running javah on $< ...";
  ECHO_INSTALLING = @(echo " Installing $(GNUSTEP_TYPE) $(GNUSTEP_INSTANCE)...";
  ECHO_UNINSTALLING = @(echo " Uninstalling $(GNUSTEP_TYPE) $(GNUSTEP_INSTANCE)...";
  ECHO_COPYING_INTO_DIR = @(echo " Copying $(GNUSTEP_TYPE) $(GNUSTEP_INSTANCE) into $(COPY_INTO_DIR)...";
  ECHO_CREATING = @(echo " Creating $@...";
  ECHO_CHOWNING = @(echo " Fixing ownership of installed file(s)...";
  ECHO_STRIPPING = @(echo " Stripping object file...";

  # ECHO_NOTHING is still better than hardcoding @(, because ECHO_NOTHING
  # prints nothing if messages=no, but it prints all messages when
  # messages=yes, while hardcoding @( never prints anything.
  ECHO_NOTHING = @(

  # Instance/Shared/bundle.make
  ECHO_COPYING_RESOURCES = @(echo " Copying resources into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_COPYING_LOC_RESOURCES = @(echo " Copying localized resources into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_CREATING_LOC_RESOURCE_DIRS = @(echo " Creating localized resource dirs into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_COPYING_RESOURCES_FROM_SUBPROJS = @(echo " Copying resources from subprojects into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_COPYING_WEBSERVER_RESOURCES = @(echo " Copying webserver resources into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_COPYING_WEBSERVER_LOC_RESOURCES = @(echo " Copying localized webserver resources into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_CREATING_WEBSERVER_LOC_RESOURCE_DIRS = @(echo " Creating localized webserver resource dirs into the $(GNUSTEP_TYPE) wrapper...";
  ECHO_INSTALLING_BUNDLE = @(echo " Installing bundle directory...";
  ECHO_COPYING_BUNDLE_INTO_DIR = @(echo " Copying bundle directory into $(COPY_INTO_DIR)...";

  # Instance/Shared/headers.make
  ECHO_INSTALLING_HEADERS = @(echo " Installing headers...";

  # Instance/Shared/java.make
  ECHO_INSTALLING_CLASS_FILES = @(echo " Installing class files...";
  ECHO_INSTALLING_ADD_CLASS_FILES = @(echo " Installing nested class files...";
  ECHO_INSTALLING_PROPERTIES_FILES = @(echo " Installing property files...";

  # Instance/Shared/strings.make
  ECHO_MAKING_STRINGS = @(echo " Making/updating strings files...";

  # Instance/Documentation/autogsdoc.make
  ECHO_AUTOGSDOC = @(echo " Generating reference documentation...";

  END_ECHO = )

#
# Translation of messages:
#
# In case a translation is appropriate (FIXME - decide how to
# determine if this is the case), here we will determine which
# translated messages.make file to use, and include it here; this file
# can override any of the ECHO_XXX variables providing new definitions
# which print out the translated messages.  (if it fails to provide a
# translation of any variable, the original untranslated message would
# then be automatically print out).
#

else

  ECHO_PREPROCESSING =
  ECHO_COMPILING = 
  ECHO_LINKING = 
  ECHO_JAVAHING = 
  ECHO_INSTALLING =
  ECHO_UNINSTALLING =
  ECHO_COPYING_INTO_DIR = 
  ECHO_CREATING =
  ECHO_NOTHING =
  ECHO_CHOWNING =
  ECHO_STRIPPING =

  ECHO_COPYING_RESOURCES = 
  ECHO_COPYING_LOC_RESOURCES =
  ECHO_CREATING_LOC_RESOURCE_DIRS =
  ECHO_COPYING_RESOURCES_FROM_SUBPROJS =
  ECHO_COPYING_WEBSERVER_RESOURCES =
  ECHO_COPYING_WEBSERVER_LOC_RESOURCES = 
  ECHO_CREATING_WEBSERVER_LOC_RESOURCE_DIRS =
  ECHO_INSTALLING_BUNDLE = 
  ECHO_COPYING_BUNDLE_INTO_DIR = 

  ECHO_INSTALLING_HEADERS =

  ECHO_INSTALLING_CLASS_FILES = 
  ECHO_INSTALLING_ADD_CLASS_FILES = 
  ECHO_INSTALLING_PROPERTIES_FILES = 

  ECHO_MAKING_STRINGS = 
  ECHO_AUTOGSDOC = 

  END_ECHO = 

endif

