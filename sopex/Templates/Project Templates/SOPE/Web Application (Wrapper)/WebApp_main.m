//
// ÇPROJECTNAMEÈ_main.m
// ÇPROJECTNAMEÈ
//
// Created by ÇUSERNAMEÈ on ÇDATEÈ
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
