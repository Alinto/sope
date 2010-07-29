/* 
   NSAttributedString.h

   Copyright (C) 2002 Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@skyrix.com>

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

#ifndef __NSAttributedString_h__
#define __NSAttributedString_h__

/* not yet implemented, but required to compile some third party stuff .. */

#include <Foundation/NSObject.h>

@interface NSAttributedString : NSObject
@end

@interface NSMutableAttributedString : NSAttributedString
@end

#endif /* NSAttributedString */
