/* 
   load.m

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

#include <config.h>
#include <stdio.h>
#include <objc/objc-api.h>
#include "lfmemory.h" /* necessary when used with GC */

#if defined(NeXT) && defined(NeXT_RUNTIME)
#  include <streams/streams.h>
#elif defined(__ELF__) || defined (__svr4__)
#  include <dlfcn.h>
#elif defined(LOADHP)
#  include <dl.h>
#elif defined(__WIN32__)
#  include <windows.h>
#endif

int objc_load_module(char* name, void (*callback)(Class, Category*))
{

#if defined(NeXT) && defined(NeXT_RUNTIME)

    /*
     * NeXT NeXTStep 3.3 with next objc-runtime
     */
    
    int ok;
    NXStream* stream;
    char* files[] = {name, NULL};
    int objc_loadModules(
	char**, NXStream*, void (*callback)(Class, Category*), void*, void*);
    
    stream = NXOpenFile(fileno(stderr), NX_WRITEONLY);

    ok = objc_loadModules(files, stream, callback, NULL, NULL);

    NXClose(stream);
    
    return !ok;

#elif defined(__ELF__) || defined (__svr4__)

    /*
     * ELF system
     */

    void* handle;
    void (*old_objc_load_callback)(Class, Category*);
    
    
    old_objc_load_callback = _objc_load_callback;
    _objc_load_callback = callback;

#if defined(__OpenBSD__)
    handle = dlopen(name, DL_LAZY);
#else
    handle = dlopen(name, RTLD_NOW | RTLD_GLOBAL);
#endif

    _objc_load_callback = old_objc_load_callback;

    if (!handle) {
	fprintf(stderr, "dynamic load (dlopen) error:\n%s\n", dlerror());
	return 0;
    }

    return 1;

#elif defined(LOADHP)

    /*
     * HP SHL LOAD system
     */

    shl_t handle;
    int* ctorlist;

    void (*old_objc_load_callback)(Class, Category*);
    
    
    old_objc_load_callback = _objc_load_callback;
    _objc_load_callback = callback;

    handle = shl_load(name, BIND_IMMEDIATE | BIND_VERBOSE, 0);

    if (!handle) {
	fprintf(stderr, "dynamic load (shl_load) error:\n");
	return 0;
    }

    if (!shl_findsym(&handle, "__CTOR_LIST__", TYPE_UNDEFINED, &ctorlist)) {
	void (**ctor)(void) = (void*)ctorlist;
	int ccount;

	ccount = (int)(**ctor);
	ctor++;
	while (ccount--) {
	    (**ctor)();
	    ctor++;
	}
    }
    else {
	fprintf(stderr, "cannot find modules' ctor list\n");
	return 0;
    }

    _objc_load_callback = old_objc_load_callback;
    return 1;

#elif defined(__WIN32__) || defined(WIN32) || defined(__CYGWIN32__)

    /*
     * WIN32 system
     */

    HINSTANCE handle;
    void (*old_objc_load_callback)(Class, Category*);
    
    
    old_objc_load_callback = _objc_load_callback;
    _objc_load_callback = callback;

    handle = LoadLibraryEx(name, 0, 0);

    _objc_load_callback = old_objc_load_callback;

    if (!handle) {
	fprintf(stderr, "dynamic load (LoadLibraryEx) error on '%s':\n%ld\n",
		name, GetLastError());
	return 0;
    }

    return 1;

#else

    /*
     * Non NeXT, Non ELF system
     */

#warning Dynamic loading not supported!

    fprintf(stderr, "dynamic code loading is not supported\n");
    return 0;

#endif
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
