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

#include "XmlRpcClientTool.h"
#include "common.h"

@implementation NSObject(Printing)

- (void)printWithTool:(XmlRpcClientTool *)_tool {
  printf("%s\n", [[self description] cString]);
}

@end /* NSObject(Printing) */

@implementation NSData(Printing)

- (void)printWithTool:(XmlRpcClientTool *)_tool {
  fwrite([self bytes], [self length], 1, stdout);
}

@end /* NSData(Printing) */

@implementation NSDictionary(Printing)

- (void)printWithTool:(XmlRpcClientTool *)_tool {
  [_tool printDictionary:self];
}

@end /* NSDictionary(Printing) */

@implementation NSArray(Printing)

- (void)printWithTool:(XmlRpcClientTool *)_tool {
  [_tool printArray:self];
}

@end /* NSArray(Printing) */

@implementation NSException(Printing)

- (void)printWithTool:(XmlRpcClientTool *)_tool {
  printf("Exception caught\nName  : %s\nReason: %s\n",
         [[self name] cString], [[self reason] cString]);
}

@end /* NSException(Printing) */
