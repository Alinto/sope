/* 
   NSAccount.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#ifndef __NSAccount_h__
#define __NSAccount_h__

#include <Foundation/NSObject.h>

@class NSString;
@class NSArray;

@interface NSAccount : NSObject

// Creating an account
+ (id)currentAccount;
+ (id)accountWithName:(NSString*)name;
+ (id)accountWithNumber:(unsigned int)number;

// Getting account information
- (NSString*)accountName;
- (unsigned)accountNumber;

@end /* NSAccount */

@interface NSUserAccount : NSAccount
{
    NSString     *name;
    unsigned int userNumber;
    NSString     *fullName;
    NSString     *homeDirectory;
}

- (NSString*)fullName;
- (NSString*)homeDirectory;

@end /* NSUserAccount */

@interface NSGroupAccount : NSAccount
{
    NSString     *name;
    unsigned int groupNumber;
    NSArray      *members;
}

- (NSArray*)members;

@end /* NSGroupAccount */

#endif /* __NSAccount_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
