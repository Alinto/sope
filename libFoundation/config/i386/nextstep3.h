/* 
   nextstep3.h

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

#ifndef __nextstep3_h__
#define __nextstep3_h__

/* From gcc/config/i386/next.h:
  `This accounts for the return pc and saved fp on the i386.' */
#define OBJC_FORWARDING_STACK_OFFSET	8
#define OBJC_FORWARDING_MIN_OFFSET 8

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

#ifdef BROKEN_BUILTIN_APPLY

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
	else if((*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) && type_size > 8)\
	    memcpy((RETURN_VALUE), \
		   *(void**)(((char*)(ARGS)) + sizeof(void*)), type_size); \
	else memcpy((RETURN_VALUE), (RESULT_FRAME), type_size); })

#else /* !BROKEN_BUILTIN_APPLY */

#define FUNCTION_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({	int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) { \
	    *(float*)(RETURN_VALUE) = \
		(float)*(long double*)(((char*)(RESULT_FRAME)) + 8); \
	    printf("float value result = %f\n", *(float*)(RETURN_VALUE)); \
	} \
	else if(*(TYPE) == _C_DBL) { \
	    *(double*)(RETURN_VALUE) = \
		(double)*(long double*)(((char*)(RESULT_FRAME)) + 8); \
	    printf("double value result = %f\n", *(double*)(RETURN_VALUE)); \
	} \
	else if((*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) && type_size > 8) \
	    memcpy((RETURN_VALUE), \
		   *(void**)(((char*)(ARGS)) + sizeof(void*)), type_size); \
	else memcpy((RETURN_VALUE), (RESULT_FRAME), type_size); })

#endif /* !BROKEN_BUILTIN_APPLY */

/* Set the value in RETURN_VALUE to be the value returned by a function.
   Assume that the fucntion was previously called and RESULT_FRAME is the
   address of the block returned by __builtin_apply. TYPE is the actual
   type of this value. ARGS is the address of block that was passed
   to __builtin_apply. */

#ifdef BROKEN_BUILTIN_APPLY

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
	else if((*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) && type_size > 8)\
	    memcpy(*(void**)(((char*)(ARGS)) + sizeof(void*)), \
		   (RETURN_VALUE), type_size); \
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
	else if((*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) && type_size > 8)\
	    memcpy(*(void**)(((char*)(ARGS)) + sizeof(void*)), \
		   (RETURN_VALUE), type_size); \
	else memcpy((RESULT_FRAME), (RETURN_VALUE), type_size); })

#endif /* !BROKEN_BUILTIN_APPLY */

/* If the RETTYPE is a structure and the address of the structure value is
   passed to the called function, then obtain from ARGS its address. In general
   this address is the second pointer into the arguments frame. This macro
   should produce 0 if the RETTYPE doesn't match the conditions above. */

#define GET_STRUCT_VALUE_ADDRESS(ARGS, RETTYPE) \
    (((*(RETTYPE) == _C_STRUCT_B || *(RETTYPE) == _C_UNION_B \
	    || *(RETTYPE) == _C_ARY_B) && objc_sizeof_type(RETTYPE) > 8) ? \
	  *(void**)(((char*)(ARGS)) + sizeof(void*)) \
	: 0)

/* Prepare ARGS for calling the function. If the function returns a struct by
   value, it's the caller responsability to pass to the called function the
   address of where to store the structure value. */

#define SET_STRUCT_VALUE_ADDRESS(ARGS, ADDR, RETTYPE) \
    *(void**)(((char*)(ARGS)) + sizeof(void*)) = (ADDR)


#endif /* __nextstep3_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
