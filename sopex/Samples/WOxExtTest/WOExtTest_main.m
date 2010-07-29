//
//  WOExtTest_main.m
//  WOExtTest
//
//  Created by Helge Hess on Mon Feb 16 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#ifdef WITHOUT_SOPEX
#include <NGObjWeb/NGObjWeb.h>
#define SOPEXMain WOApplicationMain
#else
#include <SOPEX/SOPEX.h>
#endif /* WITHOUT_SOPEX */

int main(int argc, const char *argv[]) {
    return SOPEXMain(@"Application", argc, argv);
}
