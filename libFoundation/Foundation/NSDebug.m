/* 
   NSDebug.m

   Copyright (C) 2004 Marcus Mueller
   All rights reserved.

   Author: Marcus Mueller <znek@mulle-kybernetik.com>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/


#include "NSString.h"


const char *_NSPrintForDebugger(id _obj)
{
  if(_obj && [_obj respondsToSelector:@selector(description)]) {
    return [[_obj description] cString];
  }
  return NULL;
}

