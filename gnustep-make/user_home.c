/*
   user_home.c
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: February 2002

   This file is part of the GNUstep Makefile Package.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

#include "config.h"

#ifdef __MINGW32__
#ifndef __MINGW__
#define __MINGW__
#endif
#ifndef __WIN32__
#define __WIN32__
#endif
#endif

#include <stdio.h>
#include <ctype.h>

#if defined(__MINGW__)
# include <windows.h>
#endif

#if HAVE_SYS_TYPES_H
# include <sys/types.h>
#endif

#if HAVE_STDLIB_H
# include <stdlib.h>
#endif

#if HAVE_UNISTD_H
# include <unistd.h>
#endif

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_PWD_H
# include <pwd.h>
#endif

#define lowlevelstringify(X) #X
#define stringify(X) lowlevelstringify(X)

#define SEP "/"

/*
 * This tool is intended to produce a definitive form of the
 * user specific root directories for a GNUstep user.  It must
 * remain consistent with the code in the GNUstep base library
 * which provides path information for all GNUstep applications.
 *
 *
 * How to run this tool ...
 *
 * 1. With no arguments ... the tool should print the home directory of
 * the current user to stdout.
 *
 * 2. With a 'user' argument ... the tool should print the
 * GNUSTEP_USER_ROOT directory to stdout.
 *
 * 3. With a 'defaults' argument ... the tool should print the
 * GNUSTEP_DEFAULTS_ROOT directory to stdout.
 *
 * Any other arguments will be ignored.
 * On success the tool will terminate with an exit status of zero
 * On failure, the tool will terminate with an exit status of one
 * and will print an error message to stderr.
 */

/* NOTE FOR DEVELOPERS.
 * If you change the behavior of this method you must also change
 * NSUser.m in the base library package to match.
 */
int main (int argc, char** argv)
{
  char		buf0[1024];
  char		path[2048];
  char		home[2048];
  char		*loginName = 0;
  enum { NONE, DEFS, USER } type = NONE;
#if defined(__MINGW__)
  char		buf1[1024];
  int		len0;
  int		len1;
#else
  struct passwd *pw;
#endif

  if (argc > 1)
    {
      if (strcmp(argv[1], "defaults") == 0)
	{
	  type = DEFS;
	}
      else if (strcmp(argv[1], "user") == 0)
	{
	  type = USER;
	}
    }

  if (loginName == 0)
    {
#if defined(__WIN32__)
      /* The GetUserName function returns the current user name */
      DWORD	n = 1024;

      len0 = GetEnvironmentVariable("LOGNAME", buf0, 1024);
      if (len0 > 0 && len0 < 1024)
	{
	  loginName = buf0;
	  loginName[len0] = '\0';
	}
      else if (GetUserName(buf0, &n))
	{
	  loginName = buf0;
	}
#else
#if HAVE_GETPWUID
#if HAVE_GETEUID
      int uid = geteuid();
#else
      int uid = getuid();
#endif /* HAVE_GETEUID */
      struct passwd *pwent = getpwuid (uid);
      loginName = pwent->pw_name;
#endif /* HAVE_GETPWUID */
#endif
      if (loginName == 0)
	{
	  fprintf(stderr, "Unable to determine current user name.\n");
	  return 1;
	}
    }

#if !defined(__MINGW__)
  pw = getpwnam (loginName);
  if (pw == 0)
    {
      fprintf(stderr, "Unable to locate home directory for '%s'\n", loginName);
      return 1;
    }
  strncpy(home, pw->pw_dir, sizeof(home));
#else
  home[0] = '\0';
  /*
   * The environment variable HOMEPATH holds the home directory
   * for the user on Windows NT; Win95 has no concept of home.
   * For OPENSTEP compatibility (and because USERPROFILE is usually
   * unusable because it contains spaces), we use HOMEPATH in
   * preference to USERPROFILE.
   */
  len0 = GetEnvironmentVariable("HOMEPATH", buf0, 1024);
  if (len0 > 0 && len0 < 1024)
    {
      buf0[len0] = '\0';
      /*
       * Only use HOMEDRIVE is HOMEPATH does not already contain drive.
       */
      if (len0 < 2 || buf0[1] != ':')
	{
	  len1 = GetEnvironmentVariable("HOMEDRIVE", buf1, 128);
	  if (len1 > 0 && len1 < 128)
	    {
	      buf1[len1] = '\0';
	      sprintf(home, "%s%s", buf1, buf0);
	    }
	  else
	    {
	      sprintf(home, "C:%s", buf0);
	    }
	}
      else
	{
	  strcpy(home, buf0);
	}
    }
  else
    {
      /* The environment variable USERPROFILE may hold the home directory
	 for the user on modern versions of windoze. */
      len0 = GetEnvironmentVariable("USERPROFILE", buf0, 1024);
      if (len0 > 0 && len0 < 1024)
	{
	  buf0[len0] = '\0';
	  strcpy(home, buf0);
	}
    }
  if (home[0] != '\0')
    {
      int	i;

      for (i = 0; i < strlen(home); i++)
	{
	  if (isspace((unsigned int)home[i]))
	    {
              /*
               * GNU make doesn't handle spaces in paths.
               * Broken, wrong and totally unfixable.
               */
              fprintf(stderr, "Make cannot handle spaces in paths so the " \
                          "home directory '%s' may cause problems!\n", home);
	      break;
	    }
	}
    }
#endif

  if (type == NONE)
    {
      strcpy(path, home);
    }
  else
    {
      FILE	*fptr;
      char	*user = "";
      char	*defs = "";
      int	forceD = 0;
      int	forceU = 0;

#if defined (__MINGW32__)
      len0 = GetEnvironmentVariable("GNUSTEP_SYSTEM_ROOT", buf0, sizeof(buf0));
      if (len0 > 0)
	{
	  strcpy(path, buf0);
	}
#else 
      {
	const char *gnustep_system_root = (const char*)getenv("GNUSTEP_SYSTEM_ROOT");

	if (gnustep_system_root != 0)
	  {
	    strcpy(path, gnustep_system_root);
	  }
	else
	  {
	    /* On my machine the strcpy was segfaulting when
	     * gnustep_system_root == 0.  */
	    path[0] = '\0';
	  }
      }
#endif
      strcat(path, SEP);
      strcat(path, ".GNUsteprc");
      fptr = fopen(path, "r");
      if (fptr != 0)
	{
	  while (fgets(buf0, sizeof(buf0), fptr) != 0)
	    {
	      char	*pos = strchr(buf0, '=');
	      char	*key = buf0;
	      char	*val;

	      if (pos != 0)
		{
		  val = pos;
		  *val++ = '\0';
		  while (isspace((int)*key))
		    key++;
		  while (strlen(key) > 0 && isspace((int)key[strlen(key)-1]))
		    key[strlen(key)-1] = '\0';
		  while (isspace(*val))
		    val++;
		  while (strlen(val) > 0 && isspace((int)val[strlen(val)-1]))
		    val[strlen(val)-1] = '\0';
		}
	      else
		{
		  while (isspace((int)*key))
		    key++;
		  while (strlen(key) > 0 && isspace((int)key[strlen(key)-1]))
		    key[strlen(key)-1] = '\0';
		  val = "";
		}
		  	
	      if (strcmp(key, "GNUSTEP_USER_ROOT") == 0)
		{
		  if (*val == '~')
		    {
		      user = malloc(strlen(val) + strlen(home));
		      strcpy(user, home);
		      strcat(user, &val[1]);
		    }
		  else
		    {
		      user = malloc(strlen(val) + 1);
		      strcpy(user, val);
		    }
		}
	      else if (strcmp(key, "GNUSTEP_DEFAULTS_ROOT") == 0)
		{
		  if (*val == '~')
		    {
		      defs = malloc(strlen(val) + strlen(home));
		      strcpy(defs, home);
		      strcat(defs, &val[1]);
		    }
		  else
		    {
		      defs = malloc(strlen(val) + 1);
		      strcpy(defs, val);
		    }
		}
	      else if (strcmp(key, "FORCE_USER_ROOT") == 0)
		{
		  forceU = 1;
		}
	      else if (strcmp(key, "FORCE_DEFAULTS_ROOT") == 0)
		{
		  forceD = 1;
		}
	    }
	  fclose(fptr);
	}

      if (*user == '\0' || forceU == 0 || *defs == '\0' || forceD == 0)
	{
	  strcpy(path, home);
	  strcat(path, SEP);
	  strcat(path, ".GNUsteprc");
	  fptr = fopen(path, "r");
	  if (fptr != 0)
	    {
	      while (fgets(buf0, sizeof(buf0), fptr) != 0)
		{
		  char	*pos = strchr(buf0, '=');

		  if (pos != 0)
		    {
		      char	*key = buf0;
		      char	*val = pos;

		      *val++ = '\0';
		      while (isspace((int)*key))
			key++;
		      while (strlen(key) > 0
			&& isspace((int)key[strlen(key)-1]))
			key[strlen(key)-1] = '\0';
		      while (isspace((int)*val))
			val++;
		      while (strlen(val) > 0
			&& isspace((int)val[strlen(val)-1]))
			val[strlen(val)-1] = '\0';

		      if (strcmp(key, "GNUSTEP_USER_ROOT") == 0)
			{
			  if (*user == '\0' || forceU == 0)
			    {
			      if (*val == '~')
				{
				  user = malloc(strlen(val) + strlen(home));
				  strcpy(user, home);
				  strcat(user, &val[1]);
				}
			      else
				{
				  user = malloc(strlen(val) + 1);
				  strcpy(user, val);
				}
			    }
			}
		      else if (strcmp(key, "GNUSTEP_DEFAULTS_ROOT") == 0)
			{
			  if (*defs == '\0' || forceD == 0)
			    {
			      if (*val == '~')
				{
				  defs = malloc(strlen(val) + strlen(home));
				  strcpy(defs, home);
				  strcat(defs, &val[1]);
				}
			      else
				{
				  defs = malloc(strlen(val) + 1);
				  strcpy(defs, val);
				}
			    }
			}
		    }
		}
	      fclose(fptr);
	    }
	}

      if (type == DEFS)
	{
	  strcpy(path, defs);
	  if (*path == '\0')
	    {
	      strcpy(path, user);
	    }
	}
      else
	{
	  strcpy(path, user);
	}

      if (*path == '\0')
	{
	  strcpy(path, home);
	  strcat(path, SEP);
	  strcat(path, "GNUstep");
	}
    }
#if defined(__MINGW__)
  /*
   * We always want to use unix style paths.
   */
  if (strlen(path) > 1 && path[1] == ':')
    {
      char	*ptr = path;

      while (*ptr != '\0')
	{
	  if (*ptr == '\\')
	    {
	      *ptr = '/';
	    }
	  if (*ptr == '/' && ptr > path && ptr[-1] == '/')
	    {
	      memmove(ptr, &ptr[1], strlen(ptr)+1);
	    }
	  else
	    {
	      ptr++;
	    }
	}
      if (path[2] == '/' || path[2] == '\0')
	{
	  path[1] = path[0];
	}
      else
	{
	  memmove(&path[1], path, strlen(path)+1);
	  path[2] = '/';
	}
      path[0] = '/';
    }
#endif
  printf("%s", path);
  return 0;
}

