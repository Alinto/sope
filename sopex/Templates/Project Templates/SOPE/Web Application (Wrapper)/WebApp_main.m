//
// �PROJECTNAME�_main.m
// �PROJECTNAME�
//
// Created by �USERNAME� on �DATE�
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
