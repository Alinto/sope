/* 
   sparc.h

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

#ifndef __sparc_h__
#define __sparc_h__

#ifndef OBJC_FORWARDING_STACK_OFFSET
#define OBJC_FORWARDING_STACK_OFFSET	0
#endif

#ifndef OBJC_FORWARDING_MIN_OFFSET
#define OBJC_FORWARDING_MIN_OFFSET 0
#endif

/* Define the size of the block returned by __builtin_apply_args. This value is
   computed by the function in expr.c. The block contains in order: a pointer
   to the stack arguments frame, the structure value address unless this is
   passed as an "invisible" first argument and all registers that may be used
   in calling a function. */

#define APPLY_ARGS_SIZE	32

/* Define the size of the result block returned by the __builtin_apply. This
   block contains all registers that could be used to return the function
   value. This value is computed by apply_result_size function in expr.c. There
   are also machines where this value is predefined in the machine description
   file, so that machine specific information can be stored. */

#define APPLY_RESULT_SIZE	16

/* Define how to find the value returned by a function. TYPE is a Objective-C
   encoding string describing the type of the returned value. ARGS is the
   arguments frame passed to __builtin_apply. RESULT is the address of the
   block returned by __builtin_apply. RETURN_VALUE is an address where this
   macro should put the returned value. */

#define FUNCTION_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({	int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy((RETURN_VALUE), *(void**)(RESULT_FRAME), type_size); \
	else if (*(TYPE) == _C_FLT || *(TYPE) == _C_DBL) \
	    memcpy((RETURN_VALUE), (RESULT_FRAME) + 8, type_size); \
	else if (type_size <= sizeof(void*)) \
	    memcpy((RETURN_VALUE), (RESULT_FRAME) + sizeof(void*) - type_size, type_size);  })


/* Set the value in RETURN_VALUE to be the value returned by a function.
   Assume that the fucntion was previously called and RESULT_FRAME is the
   address of the block returned by __builtin_apply. TYPE is the actual
   type of this value. ARGS is the address of block that was passed
   to __builtin_apply. */

#define FUNCTION_SET_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({  int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy(*(void**)(ARGS), (RETURN_VALUE), type_size); \
	else if (*(TYPE) == _C_FLT || *(TYPE) == _C_DBL) \
	    memcpy((RESULT_FRAME) + 8, (RETURN_VALUE), type_size); \
	else if (type_size <= sizeof(void*)) \
	    memcpy((RESULT_FRAME) + sizeof(void*) - type_size, (RETURN_VALUE), type_size); })

/* If the RETTYPE is a structure and the address of the structure value is
   passed to the called function, then obtain from ARGS its address. In general
   this address is the second pointer into the arguments frame. This macro
   should produce 0 if the RETTYPE doesn't match the conditions above. */

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


/* The following macros are used to determine the encoding of a selector given
   the types of arguments. This macros follows the similar ones defined in the
   target machine description from the compiler sources. */

/* Define a data type for recording info about the arguments list of a method.
   A variable of this type is further used by FUNCTION_ARG_ENCODING to
   determine the encoding of an argument. This type should record all info
   about arguments processed so far. */

/* From config/sparc/sparc.h in the GCC sources:

   On SPARC the first six args are normally in registers
   and the rest are pushed.  Any arg that starts within the first 6 words
   is at least partially passed in a register unless its data type forbids.
   For v9, the first 6 int args are passed in regs and the first N
   float args are passed in regs (where N is such that %f0-15 are filled).
   The rest are pushed.  Any arg that starts within the first 6 words
   is at least partially passed in a register unless its data type forbids.

   ...

   The SPARC ABI stipulates passing struct arguments (of any size) and
   (!v9) quad-precision floats by invisible reference.
*/

enum sparc_arg_location { IN_REGS = 0, ON_STACK = 1 };

struct sparc_args {
    int offsets[2];   /* 0 for args in regs, 1 for the rest of args on stack */
    int onStack;
};

#define CUMULATIVE_ARGS struct sparc_args

/* Initialize a variable of type CUMULATIVE_ARGS. This macro is called before
   processing the first argument of a method. */

#define INIT_CUMULATIVE_ARGS(CUM) \
    ({  (CUM).offsets[0] = 8; /* encoding in regs starts from 8 */ \
	(CUM).offsets[1] = 20; /* encoding in regs starts from 20 or 24 */ \
	(CUM).onStack = NO; })


/* This macro determines the encoding of the next argument of a method. It is
   called repetitively, starting with the first argument and continuing to the
   last one. CUM is a variable of type CUMULATIVE_ARGS. TYPE is a NSString
   which represents the type of the argument processed. This macro must
   produce a NSString whose value represents the encoding and position of the
   current argument. STACKSIZE is a variable that counts the number of bytes
   occupied by the arguments on the stack. */

#ifndef ROUND
#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })
#endif

#define GET_SPARC_ARG_LOCATION(CUM, CSTRING_TYPE, TYPESIZE) \
    ((CUM).onStack \
	? ON_STACK \
	: ((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 8 \
	    ? (((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 4 \
		? 0 : ((CUM).offsets[ON_STACK] += 4)),\
	      IN_REGS) \
	    : ((CUM).onStack = YES, ON_STACK)))

#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
    ({  id encoding; \
	const char* type = [(TYPE) cString]; \
	int align = objc_alignof_type(type); \
	int type_size = objc_sizeof_type(type); \
	int arg_location = GET_SPARC_ARG_LOCATION(CUM, type, type_size); \
\
	(CUM).offsets[arg_location] \
		= ROUND((CUM).offsets[arg_location], align); \
	if(type_size < sizeof(int)) \
	    (CUM).offsets[arg_location] += sizeof(int) - ROUND(type_size, align); \
	encoding = [NSString stringWithFormat: \
				(arg_location == IN_REGS ? @"%@+%d" : @"%@%d"), \
				(TYPE), \
				(arg_location == IN_REGS \
				    ? ((CUM).offsets[arg_location] \
					    + OBJC_FORWARDING_STACK_OFFSET) \
				    : (CUM).offsets[arg_location])]; \
	if(arg_location == ON_STACK) { \
	    if((*type == _C_STRUCT_B || *type == _C_UNION_B \
		    || *type == _C_ARY_B)) \
		(STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + ROUND(type_size, align); \
	    else (STACK_ARGSIZE) = (CUM).offsets[ON_STACK] + type_size; \
	} \
	(CUM).offsets[arg_location] += \
	    type_size < sizeof(int) \
		? ROUND(type_size, align) \
		: ROUND(type_size, sizeof(void*)); \
	encoding; })

#endif /* __sparc_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
