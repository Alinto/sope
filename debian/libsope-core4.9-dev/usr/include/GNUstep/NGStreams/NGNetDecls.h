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

#ifndef __NGNet_NGNetDecls_H__
#define __NGNet_NGNetDecls_H__

#if BUILD_libNGStreams_DLL
#  define NGNet_EXPORT  __declspec(dllexport)
#  define NGNet_DECLARE __declspec(dllexport)
#elif libNGStreams_ISDLL
#  define NGNet_EXPORT  extern __declspec(dllimport)
#  define NGNet_DECLARE extern __declspec(dllimport)
#else
#  define NGNet_EXPORT  extern
#  define NGNet_DECLARE 
#endif

#endif /* __NGNet_NGNetDecls_H__ */
