// $Id: ApacheWO.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __ApacheWOMod_H__
#define __ApacheWOMod_H__

#include <ApacheAPI/ApacheModule.h>

@class NSString, NSMutableArray;
@class WOApplication;
@class ApacheWOTransaction;

@interface ApacheWO : ApacheModule
{
  NSMutableArray *woTxStack;
}

/* WO transactions */

- (ApacheWOTransaction *)currentWOTransaction;

/* application management */

+ (WOApplication *)applicationForKey:(NSString *)_key
  className:(NSString *)_className;

@end

#include "ApacheWOTransaction.h"

#endif /* __ApacheWOMod_H__ */
