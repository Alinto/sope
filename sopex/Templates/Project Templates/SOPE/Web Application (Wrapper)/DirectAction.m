/*
  DirectAction.m
  Project �PROJECTNAME�
  
  Created by �USERNAME� on �DATE�
*/

#include "DirectAction.h"
#include "common.h"

@implementation DirectAction

- (id<WOActionResults>)defaultAction {
  return [self pageWithName:@"Main"];
}

@end /* DirectAction */
