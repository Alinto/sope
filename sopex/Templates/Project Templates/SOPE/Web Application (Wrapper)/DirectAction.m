/*
  DirectAction.m
  Project ÇPROJECTNAMEÈ
  
  Created by ÇUSERNAMEÈ on ÇDATEÈ
*/

#include "DirectAction.h"
#include "common.h"

@implementation DirectAction

- (id<WOActionResults>)defaultAction {
  return [self pageWithName:@"Main"];
}

@end /* DirectAction */
