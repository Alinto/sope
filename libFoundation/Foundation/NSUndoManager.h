/* 
   NSUndoManager.h

   Copyright (C) 1999 MDlink GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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

#ifndef __NSUndoManager_h__
#define __NSUndoManager_h__

#include <Foundation/NSObject.h>

@interface NSUndoManager : NSObject

- (BOOL)canUndo;
- (BOOL)canRedo;

- (void)undo;
- (void)redo;

- (void)registerUndoWithTarget:(id)_target
  selector:(SEL)_selector
  object:(id)_object;

- (void)removeAllActions;
- (void)removeAllActionsWithTarget:(id)_target;

@end

#endif /* __NSUndoManager_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
