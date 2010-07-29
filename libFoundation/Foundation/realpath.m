/*
 * realpath.c -- canonicalize pathname by removing symlinks
 * Copyright (C) 1993 Rick Sladkey <jrs@world.std.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Library Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library Public License for more details.
 */

/* Modified function name & some ifdefs to compile under this hierarchy */

#include <config.h>

#include <stdio.h>
#include <errno.h>

#if HAVE_SYS_STAT_H
# include <sys/stat.h>			/* for S_IFLNK */
#endif

#ifdef HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_STRINGS_H
# include <strings.h>
#endif

#ifdef _POSIX_VERSION
#include <limits.h>			/* for PATH_MAX */
#else
# if HAVE_SYS_PARAM_H
# include <sys/param.h>			/* for MAXPATHLEN */
# endif
#endif

#ifndef PATH_MAX
#if defined(_POSIX_VERSION) && defined(_POSIX_PATH_MAX)
#define PATH_MAX _POSIX_PATH_MAX
#else
#ifdef MAXPATHLEN
#define PATH_MAX MAXPATHLEN
#else
#define PATH_MAX 1024
#endif
#endif
#endif

#define MAX_READLINKS 32

/* this is the same as realpath() but renamed to avoid linkink problems */

char *resolve_symlinks_in_path(const char *path, char *resolved_path)
{
	char copy_path[PATH_MAX];
	char *new_path = resolved_path;
	char *max_path;
#ifdef S_IFLNK
	int readlinks = 0;
	int n;
	char link_path[PATH_MAX];
#endif

	/* Make a copy of the source path since we may need to modify it. */
	strcpy(copy_path, path);
	path = copy_path;
	max_path = copy_path + PATH_MAX - 2;
	/* If it's a relative pathname use getwd for starters. */
	if (*path != '/') {
#ifdef HAVE_GETCWD
		getcwd(new_path, PATH_MAX - 1);
#else
		getwd(new_path);
#endif
		new_path += strlen(new_path);
		if (new_path[-1] != '/')
			*new_path++ = '/';
	}
	else {
		*new_path++ = '/';
		path++;
	}
	/* Expand each slash-separated pathname component. */
	while (*path != '\0') {
		/* Ignore stray "/". */
		if (*path == '/') {
			path++;
			continue;
		}
		if (*path == '.') {
			/* Ignore ".". */
			if (path[1] == '\0' || path[1] == '/') {
				path++;
				continue;
			}
			if (path[1] == '.') {
				if (path[2] == '\0' || path[2] == '/') {
					path += 2;
					/* Ignore ".." at root. */
					if (new_path == resolved_path + 1)
						continue;
					/* Handle ".." by backing up. */
					while ((--new_path)[-1] != '/')
						;
					continue;
				}
			}
		}
		/* Safely copy the next pathname component. */
		while (*path != '\0' && *path != '/') {
			if (path > max_path) {
				errno = ENAMETOOLONG;
				return NULL;
			}
			*new_path++ = *path++;
		}
#ifdef S_IFLNK
		/* Protect against infinite loops. */
		if (readlinks++ > MAX_READLINKS) {
			errno = ELOOP;
			return NULL;
		}
		/* See if latest pathname component is a symlink. */
		*new_path = '\0';
		n = readlink(resolved_path, link_path, PATH_MAX - 1);
		if (n < 0) {
			/* EINVAL means the file exists but isn't a symlink. */
			if (errno != EINVAL)
				return NULL;
		}
		else {
			/* Note: readlink doesn't add the null byte. */
			link_path[n] = '\0';
			if (*link_path == '/')
				/* Start over for an absolute symlink. */
				new_path = resolved_path;
			else
				/* Otherwise back up over this component. */
				while (*(--new_path) != '/')
					;
			/* Safe sex check. */
			if (strlen(path) + n >= PATH_MAX) {
				errno = ENAMETOOLONG;
				return NULL;
			}
			/* Insert symlink contents into path. */
			strcat(link_path, path);
			strcpy(copy_path, link_path);
			path = copy_path;
		}
#endif /* S_IFLNK */
		*new_path++ = '/';
	}
	/* Delete trailing slash but don't whomp a lone slash. */
	if (new_path != resolved_path + 1 && new_path[-1] == '/')
		new_path--;
	/* Make sure it's null terminated. */
	*new_path = '\0';
	return resolved_path;
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

