/*
   which_lib.c
   Copyright (C) 1997, 2001, 2002 Free Software Foundation, Inc.

   Author: Nicola Pero <nicola@brainstorm.co.uk>
   Date: January 2002

   Based on the original which_lib.c by Ovidiu Predescu,
   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: October 1997

   This file is part of the GNUstep Makefile Package.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/*

  Command line arguments are:

  * a list of library search paths in the GCC notation, as in
    -L/usr/lib/opt/hack/
    -L/usr/GNUstep/Local/Library/Libraries/ix86/linux-gnu/gnu-gnu-gnu
    -L/usr/GNUstep/System/Library/Libraries/ix86/linux-gnu/gnu-gnu-gnu
    (order is important, paths are searched in the order they are listed);

  * a list of libraries in the GCC notation, as in
    -lgnustep-base -lgnustep-gui -lobjc

  * flags specifying whether a profile, static/shared library is
    to be preferred, as in profile=yes shared=yes

  The tool outputs the same list of library search paths and the list
  of libraries it received in input, with an important modification:
  each library name is modified to match the available version of the
  library (by appending nothing for a normal or debug library,
  _p for a profile one, _s for a static one, and _ps for both ) -- giving
  preference to libraries matching the specified profile,
  shared library flags.  For example, if a profile=yes
  shared=yes is specified, and libgnustep-base_p.so is in the library
  search path, which_lib will replace -lgnustep-base with
  -lgnustep-base_p in the output.

  Here is exactly how the search is performed:

  The tool first searches into the list of directories for a library
  exactly matching the name and the type required.  If found, it's
  used.

  If none is found, the library looks for an approximate match, as
  detailed in the following list.  Each search in the following list
  is performed on the list of directories, and uses the shared flags
  as specified.

  If none is still found and shared=yes, the tool looks for any
  available shared library with that name (regardless of wheter it's
  profile/nothing).

  If none is still found, the tool looks for any available static
  library with that name (regardless of any profile/shared
  flag).

  If still not found, the tool outputs the unmodified library name (as
  in -lgnustep-base) ... perhaps the library is somewhere else in the
  linker path ... otherwise that will normally result in a linker
  error later on.

*/

#include "config.h"

#include <stdio.h>

#if HAVE_SYS_TYPES_H
# include <sys/types.h>
#endif

#if HAVE_STDLIB_H
# include <stdlib.h>
#endif

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_CTYPE_H
# include <ctype.h>
#endif

#if HAVE_SYS_STAT_H
# include <sys/stat.h>
#endif

#include <fcntl.h>

#if HAVE_DIRENT_H
# include <dirent.h>
#else
# define dirent direct
# if HAVE_SYS_NDIR_H
#  include <sys/ndir.h>
# endif
# if HAVE_SYS_DIR_H
#  include <sys/dir.h>
# endif
# if HAVE_NDIR_H
#  include <ndir.h>
# endif
#endif


/* determine filesystem max path length */

# include <limits.h>			/* for PATH_MAX */

#ifdef _POSIX_VERSION
# include <utime.h>
#else
# if HAVE_SYS_PARAM_H
#  include <sys/param.h>		/* for MAXPATHLEN */
# endif
#endif

#ifndef PATH_MAX
# ifdef _POSIX_VERSION
#  define PATH_MAX _POSIX_PATH_MAX
# else
#  ifdef MAXPATHLEN
#   define PATH_MAX MAXPATHLEN
#  else
#   define PATH_MAX 1024
#  endif
# endif
#endif

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

/* Extension used for shared and non-shared libraries.  */
char* libext = ".a";
char* shared_libext = ".so";

/* If set to 1, all code will print out information about what it
   does.  */
int show_all = 0;

/* Strips off carriage returns, newlines and spaces at the end of the
   string. (this removes some \r\n issues on Windows)  */
static void stripstr (char *s)
{
  unsigned len;

  if (s == NULL)
    {
      return;
    }

  len = strlen ((char *)s);
  while (len > 0)
    {
      len--;
      if (isspace(s[len]))
	{
	  s[len] = '\0';
	}
    }
}

/* Normalize the directory, and checks that it exists on disk and is a
   directory.  Return the normalized path, or NULL if the path does
   not exist on disk, or is not a valid directory.  */
static char *normalize_and_check_dir (char *path)
{
  int length = strlen (path);
  char *normalized_path = NULL;
  struct stat statbuf;

#ifdef __MINGW32__
  if (path[0] == '/'  &&  path[1] == '/')
    {
      /* Convert //server/ to a format Windows functions understand. */
      char *s;

      /* Convert //server/path/to/ --> server/path/to/ */
      normalized_path = malloc (length * sizeof (char));
      strcpy (normalized_path, &(path[2]));

      /* Convert server/path/to/ --> server:/path/to/ */
      s = strchr (normalized_path, '/');
      if (s)
	{
	  /* The index of the '/' after 'server' in the original path.  */
	  int index = 2 + (s - normalized_path);

	  *s = ':';
	  strcpy (s + 1, &(path[index]));
	}
    }
  else
#endif
    {
      normalized_path = malloc ((length + 1) * sizeof (char));
      strcpy (normalized_path, path);
    }

  /* Now check that the path exists and is a directory.  */
  if (stat (normalized_path, &statbuf) < 0)
    /* Error occured or dir doesn't exist */
    {
      if (show_all)
	{
	  fprintf (stderr, "Library path '%s' doesn't exist - ignored\n",
		   normalized_path);
	}
      free (normalized_path);
      return NULL;
    }
  else if ((statbuf.st_mode & S_IFMT) != S_IFDIR)
    /* Not a directory */
    {
      if (show_all)
	{
	  fprintf (stderr, "Library path '%s' isn't a directory - ignored\n",
		   normalized_path);
	}
      free (normalized_path);
      return NULL;
    }

  stripstr ((unsigned char *)normalized_path);
  return normalized_path;
}

/*  Search for a library with library_name, suffix suffix and
    extension ext.

    library_name must not contain the suffix, so library_name should
    be something like 'gnustep-base'.

    suffix is the wanted suffix (valid suffixes are "", _d, _p, _s,
    _ds, _dp, _ps, _dps).  Must not be NULL.

    ext is the wanted extension (normally, either .so or .a).  Must
    not be NULL.

    Return 0 if it doesn't find anything matching.

    Return 1 if a library with the appropriate suffix/extension/type
    matches in 'path' and print to stdout the name of the library. */

static int search_for_lib_with_suffix_and_ext (const char *library_name,
					       char **library_paths,
					       int paths_no,
					       char *suffix,
					       char *ext)
{
  /* Iterate over the library_paths, looking for the library.  */
  int i;

  for (i = 0; i < paths_no; i++)
    {
      char full_filename[PATH_MAX + 1];
      struct stat statbuf;

#ifdef __MINGW32__
      if (strcmp (ext, ".dll.a") == 0)
	{
	  /* Mingw can link against dlls directly, so if we're
	   * currently searching for libxxx.dll.a, make a try first at
	   * xxx.dll.  The standard algorithm will search for
	   * libxxx.dll.a (and failing that libxxx.a) later.
	   */
	  strcpy (full_filename, library_paths[i]);
	  strcat (full_filename, "/");
	  strcat (full_filename, library_name);
	  strcat (full_filename, suffix);
	  strcat (full_filename, ".dll");
	  if (show_all)
	    {
	      fprintf (stderr, " %s\n", full_filename);
	    }
	  
	  if (stat (full_filename, &statbuf) >= 0)
	    {
	      goto library_found;
	    }
	}
#endif

      strcpy (full_filename, library_paths[i]);
      strcat (full_filename, "/lib");
      strcat (full_filename, library_name);
      strcat (full_filename, suffix);
      strcat (full_filename, ext);

      if (show_all)
	{
	  fprintf (stderr, " %s\n", full_filename);
	}

      if (stat (full_filename, &statbuf) < 0)
	/* Error - likely that file doesn't exist.  */
	{
	  continue;
	}

#ifdef __MINGW32__
    library_found:
#endif
      
      if ((statbuf.st_mode & S_IFMT) == S_IFREG)
	/* Found it! */
	{
	  if (show_all)
	    {
	      fprintf (stderr, "  Found!\n");
	    }
	  printf (" -l%s", library_name);
	  if (*suffix)
	    {
	      printf ("%s", suffix);
	    }
	  return 1;
	}
    }

  return 0;
}

/*  Search for a library with library_name, extension ext and any
    valid suffix.

    The same comments as for 'search_for_lib_with_suffix_and_ext' apply,
    except that any valid suffix is accepted (valid suffixes are: "",
    _d, _p, _s, _ds, _dp, _ps, _dps).
*/

static int search_for_lib_with_ext (const char *library_name,
				    int library_name_len,
				    char **library_paths,
				    int paths_no,
				    char *ext)
{
  /* Iterate over the library_paths, looking for the library.  */
  int i;

  for (i = 0; i < paths_no; i++)
    {
      DIR* dir;
      struct dirent* dirbuf;
      int found = 0;

      if (show_all)
	{
	  fprintf (stderr, " %s/lib%s??%s\n", library_paths[i],
		   library_name, ext);
	}

      dir = opendir (library_paths[i]);

      if (dir == NULL)
	{
	  /* For some reasons, we can't read that path.  Perhaps
	     someone removed the directory while we were running :-) */
	  continue;
	}

      while ((dirbuf = readdir (dir)))
	{
	  /* Skip if it doesn't begin with 'lib'.  This implicitly
	     skips "." and ".." in case they are returned.  */
	  if (dirbuf->d_name[0] != 'l')
	    {
	      continue;
	    }
	  if (dirbuf->d_name[1] != 'i')
	    {
	      continue;
	    }
	  if (dirbuf->d_name[2] != 'b')
	    {
	      continue;
	    }

	  /* Skip if it does not match the library name. */
	  if (strncmp (dirbuf->d_name + 3, library_name, library_name_len))
	    {
	      continue;
	    }
	  else
	    {
	      int filelen, extlen;

	      filelen = strlen (dirbuf->d_name);
	      extlen = strlen (ext);

	      if (filelen - extlen <= 0)
		{
		  /* Quite worrying this case.  */
		  continue;
		}

	      if (show_all)
		{
		  fprintf (stderr, "  Considering %s\n",  dirbuf->d_name);
		}

	      /* First check if the extension matches */
	      if (strcmp (dirbuf->d_name + filelen - extlen, ext))
		{
		  /* No luck, skip this file */
		  continue;
		}

	      /* The extension matches.  Check the last remaining bit
		 - that the remaining string we have not checked is
		 one of the allowed suffixes.  The allowed suffixes
		 are: "", _d, _p, _s, _dp, _ds, _ps, _dps.  */
	      {
		char f_suffix[5];
		int j;
		int suffix_len = filelen - (3 /* 'lib' */

					    + library_name_len
					    /* library_name */

					    + extlen /* .so/.a */);

		switch (suffix_len)
		  {
		    /* In the following cases, 'break' means found,
		       'continue' means not found.  */
		  case 0:
		    {
		      /* nothing - it's Ok.  */
		      break;
		    }
		  case 1:
		    {
		      continue;
		    }
		  case 2:
		    {
		      /* Must be one of _d, _p, _s  */
		      char c;

		      if (dirbuf->d_name[3 + library_name_len] != '_')
			{
			  continue;
			}

		      c = dirbuf->d_name[3 + library_name_len + 1];
		      if (c != 'd'  ||  c != 'p'  ||  c != 's')
			{
			  continue;
			}
		      break;
		    }
		  case 3:
		    {
		      /* Must be one of _dp, _ds, _ps  */
		      char c, d;

		      if (dirbuf->d_name[3 + library_name_len] != '_')
			{
			  continue;
			}

		      c = dirbuf->d_name[3 + library_name_len + 1];
		      d = dirbuf->d_name[3 + library_name_len + 2];
		      if ((c == 'd'  &&  (d == 'p'  ||  d == 's'))
			  || (c == 'p'  &&  d == 's'))
			{
			  break;
			}
		      continue;
		    }
		  case 4:
		    {
		      if (dirbuf->d_name[3 + library_name_len] != '_')
			{
			  continue;
			}
		      if (dirbuf->d_name[3 + library_name_len] != 'd')
			{
			  continue;
			}
		      if (dirbuf->d_name[3 + library_name_len] != 'p')
			{
			  continue;
			}
		      if (dirbuf->d_name[3 + library_name_len] != 's')
			{
			  continue;
			}
		      break;
		    }
		  default:
		    {
		      continue;
		    }
		  }

		/* If we're here, it's because it was found!  */
		if (show_all)
		  {
		    fprintf (stderr, "   Found!\n");
		  }

		for (j = 0; j < suffix_len; j++)
		  {
		    f_suffix[j] = dirbuf->d_name[library_name_len + 3 + j];
		  }
		f_suffix[j] = '\0';
		printf (" -l%s%s", library_name, f_suffix);
		found = 1;
		break;
	      }
	    }
	}
      closedir (dir);
      if (found)
	{
	  return 1;
	}
    }

  return 0;
}

/* Search for the library everywhere, and returns the library name.  */
static void output_library_name (const char *library_name,
				 char** library_paths, int paths_no,
				 int profile, int shared,
				 char *libname_suffix)
{
  char *extension = shared ? shared_libext : libext;
  int library_name_len = strlen (library_name);

  if (show_all)
    {
      fprintf (stderr, "\n>>Library %s:\n", library_name);
    }

  /* We first perform the search of a matching library in all dirs.  */
  if (show_all)
    {
      fprintf (stderr, "Scanning all paths for an exact match\n");
    }

  if (search_for_lib_with_suffix_and_ext (library_name,
					  library_paths, paths_no,
					  libname_suffix,
					  extension))
    {
      return;
    }


  /* The library was not found.  Try various approximations first,
     slightly messing the original profile requests, but still
     honouring the shared=yes|no requirement.  */
  if (show_all)
    {
      fprintf (stderr, "Scanning all paths for an approximate match\n");
    }

  /* _p: try nothing.  */
  if (profile)
    {
      if (search_for_lib_with_suffix_and_ext (library_name,
					      library_paths, paths_no,
					      shared ? "" : "_s",
					      extension))
	{
	  return;
	}
    }

  /* The library was still not found.  Try to get whatever library we
     have there. */

  /* If a shared library is needed try to find a shared one first.
     Any shared library is all right.  */
  if (shared)
    {
      if (show_all)
	{
	  fprintf (stderr,
		   "Scanning all paths for any shared lib with that name\n");
	}
      if (search_for_lib_with_ext (library_name, library_name_len,
				   library_paths, paths_no, shared_libext))
	{
	  return;
	}
    }

  /* Last hope - return a static library with name 'library_name'.
     Any static library is all right.  */
  if (show_all)
    {
      fprintf (stderr,
	       "Scanning all paths for any static lib with that name\n");
    }
  if (search_for_lib_with_ext (library_name, library_name_len,
			       library_paths, paths_no, libext))
    {
      return;
    }

  /* We couldn't locate the library.  Output the library name we were
     given, without any modification.  Possibly it's somewhere else on
     the linker path, otherwise (more likely) a linker error will
     occur.  Nothing we can do about it.  */
  if (show_all)
    {
      fprintf (stderr, "Library not found, using unmodified library name\n");
    }
  printf (" -l%s", library_name);
  return;
}

int main (int argc, char** argv)
{
  int i;

  /* Type of libraries we prefer.  */
  int profile = 0;
  int shared = 1;

  /* Suffix of the libraries we prefer - something like "" or 
     "_p" or "_ps" */
  char libname_suffix[5];

  /* Array of strings that are the library paths passed on the command
     line.  If we are on Windows, we convert library paths to a format
     that Windows functions understand before we save the paths in
     library_paths, so that you could pass them to Windows functions
     accessing the filesystem.  We also check that the paths actually
     exist on disk, and are directories, before putting them in the
     array.  */
  int paths_no = 0;
  char** library_paths = NULL;

  /* The list of libraries */
  int libraries_no = 0;
  char** all_libraries = NULL;

  /* Other flags which are printed to the output as they are.  */
  int other_flags_no = 0;
  char** other_flags = NULL;



#ifdef __WIN32__
  setmode(1, O_BINARY);
  setmode(2, O_BINARY);
#endif

  if (argc == 1)
    {
      printf ("usage: %s [-Lpath ...] -llibrary shared=yes|no "
	      "profile=yes|no libext=string shared_libext=string "
	      "[show_all=yes]\n", argv[0]);
      exit (1);
    }

  for (i = 1; i < argc; i++)
    {
      /* First switch basing on the first letter of each argument,
         then compare.  */
      switch (argv[i][0])
	{
	case '-':
	  {
	    if (argv[i][1] == 'l')
	      {
		if (all_libraries)
		  {
		    all_libraries = realloc (all_libraries,
					     (libraries_no + 1)
					     * sizeof (char*));
		  }
		else
		  {
		    all_libraries = malloc ((libraries_no + 1)
					    * sizeof (char*));
		  }
		all_libraries[libraries_no] = malloc (strlen (argv[i]) - 1);
		strcpy (all_libraries[libraries_no], argv[i] + 2);
		stripstr ((unsigned char *)all_libraries[libraries_no]);
		libraries_no++;
		continue;
	      }
	    else if (argv[i][1] == 'L')
	      {
		char *lib_path = normalize_and_check_dir (argv[i] + 2);

		/* Always print out the library search path flag,
                   regardless.  */
		printf (" %s", argv[i]);

		if (lib_path != NULL)
		  {
		    if (library_paths)
		      {
			library_paths = realloc (library_paths,
						 (paths_no + 1)
						 * sizeof (char*));
		      }
		    else
		      {
			library_paths = malloc ((paths_no + 1)
						* sizeof(char*));
		      }
		    library_paths[paths_no] = lib_path;
		    paths_no++;
		  }
		continue;
	      }
	    break;
	  }
	case 'd':
	  {
	    if (!strncmp (argv[i], "debug=", 6))
	      {
		continue;
	      }
	    break;
	  }
	case 'l':
	  {
	    if (!strncmp (argv[i], "libext=", 7))
	      {
		libext = malloc (strlen (argv[i] + 7) + 1);
		strcpy (libext, argv[i] + 7);
		continue;
	      }
	    break;
	  }
	case 'p':
	  {
	    if (!strncmp (argv[i], "profile=", 8))
	      {
		profile = !strncmp (argv[i] + 8, "yes", 3);
		continue;
	      }
	    break;
	  }
	case 's':
	  {
	    if (!strncmp (argv[i], "shared=", 7))
	      {
		shared = !strncmp (argv[i] + 7, "yes", 3);
		continue;
	      }
	    else if (!strncmp (argv[i], "shared_libext=", 14))
	      {
		shared_libext = malloc (strlen (argv[i] + 14) + 1);
		strcpy (shared_libext, argv[i] + 14);
		continue;
	      }
	    else if (!strncmp (argv[i], "show_all=", 9))
	      {
		show_all = !strncmp (argv[i] + 9, "yes", 3);
		continue;
	      }
	    break;
	  }
	default:
	  break;
	}

      /* The flag is something different; keep it in the `other_flags' */
      if (other_flags)
	{
	  other_flags = realloc (other_flags,
				 (other_flags_no + 1) * sizeof (char*));
	}
      else
	{
	  other_flags = malloc ((other_flags_no + 1) * sizeof (char*));
	}
      other_flags[other_flags_no] = malloc (strlen (argv[i]) + 1);
      strcpy (other_flags[other_flags_no], argv[i]);
      other_flags_no++;
    }

  /* Determine the exact libname_suffix of the libraries we are
     looking for.  */
  libname_suffix[0] = '_';
  libname_suffix[1] = '\0';
  libname_suffix[2] = '\0';
  libname_suffix[3] = '\0';
  libname_suffix[4] = '\0';

  i = 1;

  if (profile)
    {
      libname_suffix[i] = 'p';
      i++;
    }

  if (!shared)
    {
      libname_suffix[i] = 's';
      i++;
    }

  if (i == 1)
    {
      libname_suffix[0] = '\0';
    }


  if (show_all)
    {
      fprintf (stderr, ">>Input:\n");
      fprintf (stderr, "shared = %d\n", shared);
      fprintf (stderr, "profile = %d\n", profile);
      fprintf (stderr, "libname_suffix = %s\n", libname_suffix);
      fprintf (stderr, "libext = %s\n", libext);
      fprintf (stderr, "shared_libext = %s\n", shared_libext);

      fprintf (stderr, "library names:\n");
      for (i = 0; i < libraries_no; i++)
	{
	  fprintf (stderr, "    %s\n", all_libraries[i]);
	}

      fprintf (stderr, "library paths:\n");
      for (i = 0; i < paths_no; i++)
	{
	  fprintf (stderr, "    %s\n", library_paths[i]);
	}

      fprintf (stderr, "other flags:\n");
      for (i = 0; i < other_flags_no; i++)
	{
	  fprintf (stderr, "    %s\n", other_flags[i]);
	}
    }

  /* Now output the libraries.  */
  for (i = 0; i < libraries_no; i++)
    {
      /* Search for the library, and print (using -l%s) the library
	 name to standard output.  */
      output_library_name (all_libraries[i], library_paths,
			   paths_no, profile, shared, libname_suffix);
    }

  /* Output the other flags */
  for (i = 0; i < other_flags_no; i++)
    {
      printf (" %s", other_flags[i]);
    }

  printf (" ");

  return 0;
}
