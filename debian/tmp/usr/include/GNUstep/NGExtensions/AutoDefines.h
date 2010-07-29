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

#ifndef __NGExtensions_AutoDefines_H__
#define __NGExtensions_AutoDefines_H__

// TODO: can we remove that?

#if defined(__MINGW32__)
#  define WITH_OPENSTEP 0
#  define GNUSTEP  1

#elif defined(__CYGWIN32__)
#  define WITH_OPENSTEP 0
#  ifndef GNUSTEP
#    define GNUSTEP 1
#  endif

#elif defined(NeXT) || defined(WIN32)
#  define WITH_OPENSTEP 1
#  define GNUSTEP  0
#  ifndef NeXT_RUNTIME
#    define NeXT_RUNTIME 1
#  endif

#elif defined(__APPLE__)
#  ifndef WITH_OPENSTEP
#    define WITH_OPENSTEP 1
#  endif
#  if !GNU_RUNTIME
#    ifndef NeXT_RUNTIME
#      define NeXT_RUNTIME 1
#    endif
#    ifndef APPLE_RUNTIME
#      define APPLE_RUNTIME 1
#    endif
#  endif
#  if !GNUSTEP_BASE_LIBRARY && !LIB_FOUNDATION_LIBRARY
#    ifndef COCOA_Foundation_LIBRARY
#      define COCOA_Foundation_LIBRARY 1
#    endif
#    ifndef NeXT_Foundation_LIBRARY
#      define NeXT_Foundation_LIBRARY 1
#    endif
#    ifndef APPLE_Foundation_LIBRARY
#      define APPLE_Foundation_LIBRARY 1
#    endif
#  endif

#else
#  define WITH_OPENSTEP 0
#  define GNUSTEP  1
#endif

#endif /* __NGExtensions_AutoDefines_H__ */
