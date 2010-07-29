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
#ifndef __config_h__
#define __config_h__

/* Define if system calls automatically restart after interruption
   by a signal.  */
#undef HAVE_RESTARTABLE_SYSCALLS

/* Define if you have the gethostbyname_r function. */
#undef HAVE_GETHOSTBYNAME_R

/* Define if you have the gethostbyaddr_r function. */
#undef HAVE_GETHOSTBYADDR_R

/* Define if you have the gethostent_r function. */
#undef HAVE_GETHOSTENT_R

/* Define if you have posix mmap function.  */
#define HAVE_MMAP 1

/* Define if you have the getcwd function */
#define HAVE_GETCWD 1

/* Define if you have the getuid function */
#define HAVE_GETUID 1

/* Define if you have the getpwnam function */
#undef HAVE_GETPWNAM

/* Define if you have the getpwuid function */
#undef HAVE_GETPWUID

/* Define if you have the kill function */
#undef HAVE_KILL

/* Define if you have the statvfs function */
#undef HAVE_STATVFS

/* Define if you have the poll function */
//#define HAVE_POLL 1

/* Define if you have the chown function */
#define HAVE_CHOWN 1

/* Define if you have the symlink function */
#define HAVE_SYMLINK 1

/* Define if you have the readlink function */
#define HAVE_READLINK 1

/* Define if you have the fsync function */
#define HAVE_FSYNC 1

/* Define if you have the opendir family of functions */
#undef HAVE_OPENDIR

/* Define if you have the isatty function */
#define HAVE_ISATTY 1

/* Define if you have the ttyname function */
#define HAVE_TTYNAME 1

/* Define if you have the ttyname_r function */
#undef HAVE_TTYNAME_R

/* Define if you have the <string.h> header file.  */
#define HAVE_STRING_H 1

/* Define if you have the <strings.h> header file.  */
#define HAVE_STRINGS_H 1

/* Define if you have the <memory.h> header file */
#define HAVE_MEMORY_H 1

/* Define if you have the <stdlib.h> header file.  */
#define HAVE_STDLIB_H 1

/* Define if you have the <limits.h> header file.  */
#define HAVE_LIMITS_H 1

/* Define if you have the <libc.h> header file.  */
#define HAVE_LIBC_H 1

/* Define if you have the <sys/stat.h> header file */
#define HAVE_SYS_STAT_H 1

/* Define if you have the <sys/fcntl.h> header file */
#define HAVE_SYS_FCNTL_H 1

/* Define if you have the <fcntl.h> header file */
#define HAVE_FCNTL_H 1

/* Define if you have the <sys/vfs.h> header file */
#undef HAVE_SYS_VFS_H

/* Define if you have the <sys/statfs.h> header file */
#undef HAVE_SYS_STATFS_H

/* Define if you have the <sys/statvfs.h> header file */
#undef HAVE_SYS_STATVFS_H

/* Define if you have the <poll.h> header file */
#undef HAVE_POLL_H

/* Define if you have the <sys/poll.h> header file */
#undef HAVE_SYS_POLL_H

/* Define if you have the <sys/socket.h> header file */
#define HAVE_SYS_SOCKET_H 1

/* Define if you have the <unistd.h> header file */
#define HAVE_UNISTD_H 1

/* Define if you have the <sys/ioctl.h> header file */
#define HAVE_SYS_IOCTL_H 1

/* Define if you have the <sys/filio.h> header file */
#define HAVE_SYS_FILIO_H 1

/* Define if you have the <netinet/in.h> header file */
#define HAVE_NETINET_IN_H 1

/* Define if you have the <netdb.h> header file */
#define HAVE_NETDB_H 1

/* Define if you have the <windows.h> header file */
#undef HAVE_WINDOWS_H

/* Define if you have the <winsock.h> header file */
#undef HAVE_WINSOCK_H

/* Define if you have the <Windows32/Sockets.h> header file */
#undef HAVE_WINDOWS32_SOCKETS_H

/* Define if you have the <pwd.h> header file */
#define HAVE_PWD_H 1

/* Define if you have the <process.h> header file */
#undef HAVE_PROCESS_H

/* Define if you have the <grp.h> header file */
#define HAVE_GRP_H 1

/* Define if you have the <sys/file.h> header file */
#define HAVE_SYS_FILE_H 1

/* Define if you have the <sys/select.h> header file */
#define HAVE_SYS_SELECT_H 1

/* Define if you have the <time.h> header file */
#define HAVE_TIME_H 1

/* Define if you have the <sys/time.h> header file */
#define HAVE_SYS_TIME_H 1

/* Define if you have the <sys/types.h> header file */
#define HAVE_SYS_TYPES_H 1

/* Define if you have the <utime.h> header file */
#define HAVE_UTIME_H 1

/* Define if you have the <sys/errno.h> header file */
#define HAVE_SYS_ERRNO_H 1

/* Define if sys/wait.h is POSIX compatible */
#define HAVE_SYS_WAIT_H 1

/* Define this if you have the <vfork.h> header file */
#undef HAVE_VFORK_H

/* Define for vfork in case it's not defined */
#undef vfork

/* Define for pid_t in case it's not defined */
#define HAVE_pid_t 1

/* The following macros deal with directory entries. */
#define HAVE_DIRENT_H 1
#undef HAVE_SYS_NDIR_H
#define HAVE_SYS_DIR_H 1
#undef HAVE_NDIR_H
#undef HAVE_DIR_H

/* The structure alignment as determined by configure */
#define STRUCT_ALIGNMENT @STRUCT_ALIGNMENT@

/* The name of the target platform, obtained by configure */
#define TARGET_PLATFORM		"@host@"

/* define POLL constants */

#if HAVE_POLL_H
#  include <poll.h>
#endif
#if HAVE_SYS_POLL_H
#  include <sys/poll.h>
#endif

#ifndef POLLIN
# ifdef HAVE_POLL
#  warning "manually declared POLLIN=1 .."
# endif
#  define POLLIN     1
#endif
#ifndef POLLOUT
# ifdef HAVE_POLL
#  warning "manually declared POLLOUT=2 .."
# endif
#  define POLLOUT    2
#endif
#ifndef POLLERR
# ifdef HAVE_POLL
#  warning "manually declared POLLERR=4 .."
# endif
#  define POLLERR    4
#endif

#ifndef POLLRDNORM
#  ifdef linux
#    define POLLRDNORM POLLIN
#  else /* !linux */
#    ifdef POLLIN
#     ifdef HAVE_POLL
#      warning "manually declared POLLRDNORM=POLLIN .."
#     endif
#      define POLLRDNORM POLLIN
#    else
#     ifdef HAVE_POLL
#      warning "manually declared POLLRDNORM .."
#     endif
#      define POLLRDNORM 1
#    endif
#  endif /* !linux */
#endif

#ifndef POLLWRNORM
#  ifdef linux
#    define POLLWRNORM POLLOUT
#  else /* !linux */
#    ifdef POLLOUT
#     ifdef HAVE_POLL
#      warning "manually declared POLLWRNORM=POLLOUT .."
#     endif
#      define POLLWRNORM POLLOUT
#    else
#     ifdef HAVE_POLL
#      warning "manually declared POLLWRNORM .."
#     endif
#      define POLLWRNORM 2
#    endif
#  endif /* !linux */
#endif

#endif /* __config_h__ */
