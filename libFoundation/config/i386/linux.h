/* 
   linux.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#ifndef __linux_h__
#define __linux_h__

#include "i386.h"

#undef FUNCTION_VALUE
#undef FUNCTION_SET_VALUE
#undef GET_STRUCT_VALUE_ADDRESS
#undef SET_STRUCT_VALUE_ADDRESS

/* Define how to find the value returned by a function. TYPE is a Objective-C
   encoding string describing the type of the returned value. ARGS is the
   arguments frame passed to __builtin_apply. RESULT_FRAME is the address of
   the block returned by __builtin_apply. RETURN_VALUE is an address where
   this macro should put the returned value. */

#if 0 && defined(BROKEN_BUILTIN_APPLY)

#define FUNCTION_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({	int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) { \
	    float aFloat; \
	    asm("fsts %0" : "=f2" (aFloat) :); \
	    *(float*)(RETURN_VALUE) = aFloat; \
	} \
	else if(*(TYPE) == _C_DBL) { \
	    double aDouble; \
	    asm("fstl %0" : "=f2" (aDouble)); \
	    *(double*)(RETURN_VALUE) = aDouble; \
	} \
	else if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy((RETURN_VALUE), *(void**)(RESULT_FRAME), type_size); \
	else memcpy((RETURN_VALUE), (RESULT_FRAME), type_size); })

#else /* !BROKEN_BUILTIN_APPLY */

#define FUNCTION_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({	int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) { \
	    *(float*)(RETURN_VALUE) = \
		(float)*(long double*)(((char*)(RESULT_FRAME)) + 8); \
	} \
	else if(*(TYPE) == _C_DBL) { \
	    *(double*)(RETURN_VALUE) = \
		(double)*(long double*)(((char*)(RESULT_FRAME)) + 8); \
	} \
	else if(*(TYPE) != _C_STRUCT_B && *(TYPE) != _C_UNION_B \
		&& *(TYPE) != _C_ARY_B) \
	    memcpy((RETURN_VALUE), (RESULT_FRAME), type_size); })

#endif /* !BROKEN_BUILTIN_APPLY */

/* Set the value in RETURN_VALUE to be the value returned by a function.
   Assume that the fucntion was previously called and RESULT_FRAME is the
   address of the block returned by __builtin_apply. TYPE is the actual
   type of this value. ARGS is the address of block that was passed
   to __builtin_apply. */

#if 0 && defined(BROKEN_BUILTIN_APPLY)

#define FUNCTION_SET_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({  int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) { \
	    float aFloat = *(float*)(RETURN_VALUE); \
	    asm("fld %0" : : "f" (aFloat)); \
	} \
	else if(*(TYPE) == _C_DBL) { \
	    double aDouble = *(double*)(RETURN_VALUE); \
	    asm("fldl %0" : : "f" (aDouble)); \
	} \
	else if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy(*(void**)(ARGS), (RETURN_VALUE), type_size); \
	else memcpy((RESULT_FRAME), (RETURN_VALUE), type_size); })

#else /* !BROKEN_BUILTIN_APPLY */

#define FUNCTION_SET_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({  int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) \
	    *(long double*)(((char*)(RESULT_FRAME)) + 8) = \
		(long double)*(float*)(RETURN_VALUE); \
	else if(*(TYPE) == _C_DBL) \
	    *(long double*)(((char*)(RESULT_FRAME)) + 8) = \
		(long double)*(double*)(RETURN_VALUE); \
	else if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy(*(void**)(ARGS), (RETURN_VALUE), type_size); \
	else memcpy((RESULT_FRAME), (RETURN_VALUE), type_size); })

#endif /* !BROKEN_BUILTIN_APPLY */

/* If the RETTYPE is a structure and the address of the structure value is
   passed to the called function, then obtain from ARGS its address. In general
   this address is the second pointer into the arguments frame. However on
   linux this address is passed as the first argument to the called function.
   This macro should produce 0 if the RETTYPE doesn't match the conditions
   above. */

#define GET_STRUCT_VALUE_ADDRESS(ARGS, RETTYPE) \
    ((*(RETTYPE) == _C_STRUCT_B || *(RETTYPE) == _C_UNION_B \
	    || *(RETTYPE) == _C_ARY_B) ? \
	  **(void***)(ARGS) \
	: 0)

/* Prepare ARGS for calling the function. If the function returns a struct by
   value, it's the caller responsability to pass to the called function the
   address of where to store the structure value. */

#define SET_STRUCT_VALUE_ADDRESS(ARGS, ADDR, RETTYPE) \
    if(*(RETTYPE) == _C_STRUCT_B || *(RETTYPE) == _C_UNION_B \
	    || *(RETTYPE) == _C_ARY_B) \
	**(void***)(ARGS) = (ADDR);

#endif /* __linux_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
