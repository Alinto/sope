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

#ifndef __NGObjWeb_WOResponse_private_H__
#define __NGObjWeb_WOResponse_private_H__

#include <NGObjWeb/WOResponse.h>

// fast inline functions (non-WO)

#define WOResponse_AddChar(__R__,__C__) \
  if (__R__) {__R__->addChar(__R__, @selector(appendContentCharacter:), \
			     __C__);}

#define WOResponse_AddString(__R__,__C__) \
  if (__R__) {__R__->addStr(__R__, @selector(appendContentString:), __C__);}
#define WOResponse_AddCString(__R__,__C__) \
  if (__R__) {__R__->addCStr(__R__, @selector(appendContentCString:), \
			     (const unsigned char *)__C__);}

#define WOResponse_AddHtmlString(__R__,__C__) \
  if (__R__) {__R__->addHStr(__R__, @selector(appendContentHTMLString:), \
			     __C__);}

#define WOResponse_AppendBeginTag(__R__,__C__) \
if (__R__) { \
  __R__->addChar(__R__, @selector(appendContentCharacter:), '<'); \
  __R__->addStr(__R__, @selector(appendContentString:), __C__); \
}
#define WOResponse_AppendBeginTagEnd(__R__) \
if (__R__) {__R__->addChar(__R__, @selector(appendContentCharacter:), '>');}

#define WOResponse_AppendEndTag(__R__,__C__) \
if (__R__) { \
  __R__->addCStr(__R__, @selector(appendContentCString:), \
                 (const unsigned char *)"</"); \
  __R__->addStr(__R__, @selector(appendContentString:), __C__); \
  __R__->addChar(__R__, @selector(appendContentCharacter:), '>'); \
}

#define WOResponse_AppendAttribute(__R__,__K__,__V__) \
if (__R__) { \
  __R__->addChar(__R__, @selector(appendContentCharacter:), ' '); \
  __R__->addStr(__R__, @selector(appendContentString:), __K__); \
  __R__->addCStr(__R__, @selector(appendContentCString:), \
                 (const unsigned char *)"=\""); \
  __R__->addHStr(__R__, @selector(appendContentHTMLString:), __V__); \
  __R__->addChar(__R__, @selector(appendContentCharacter:), '\"'); \
}

// TODO: performance ! - use static buffer and appendContentCString !

#define WOResponse_AddUInt(__R__,__C__) \
  if (__R__) {\
    switch(__C__) {\
      case 0: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"0");break; \
      case 1: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"1");break; \
      case 2: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"2");break; \
      case 3: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"3");break; \
      case 4: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"4");break; \
      default: {\
        unsigned char buf[12]; \
	sprintf((char *)buf,"%d", __C__);			\
        __R__->addCStr(__R__, @selector(appendContentCString:), buf);}\
    }\
  }

#define WOResponse_AddInt(__R__,__C__) \
  if (__R__) {\
    switch(__C__) {\
      case 0: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"0");break; \
      case 1: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"1");break; \
      case 2: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"2");break; \
      case 3: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"3");break; \
      case 4: __R__->addCStr(__R__, @selector(appendContentCString:),\
			     (const unsigned char *)"4");break; \
      default: {\
        unsigned char buf[12]; \
	sprintf((char *)buf,"%d", __C__);			\
        __R__->addCStr(__R__, @selector(appendContentCString:), buf);}\
    }\
  }

#endif /* __NGObjWeb_WOResponse_private_H__ */
