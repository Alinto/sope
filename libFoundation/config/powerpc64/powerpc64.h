/* 
   powerpc.h

   Copyright (C) 1998 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@aracnet.com>

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

#ifndef __powerpc_h__
#define __powerpc_h__

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

#define APPLY_ARGS_SIZE	144

/* Define the size of the result block returned by the __builtin_apply. This
   block contains all registers that could be used to return the function
   value. This value is computed by apply_result_size function in expr.c. There
   are also machines where this value is predefined in the machine description
   file, so that machine specific information can be stored. */

#define APPLY_RESULT_SIZE	16

/* Define how to access the arguments' frame in order to set an argument.
   FRAME_DATA is the address in the frame where the argument has to be set.
   ARGUMENT_LOCATION is the address of the argument that has to be set.
   ARG_INFO is an NSArgumentInfo that describes the argument. */

#define FRAME_SET_ARGUMENT(FRAME_DATA, ARGUMENT_LOCATION, ARG_INFO) \
    ({ if ((ARG_INFO).size < sizeof(void*)) \
           memcpy(((char*)(FRAME_DATA)) + sizeof(void*) - (ARG_INFO).size, \
                  (ARGUMENT_LOCATION), \
                  (ARG_INFO).size); \
       else if (*(ARG_INFO).type == _C_FLT) \
           *(double*)(FRAME_DATA) = (double)*(float*)(ARGUMENT_LOCATION); \
       else memcpy((FRAME_DATA), (ARGUMENT_LOCATION), (ARG_INFO).size); \
    })

/* Define how to access the arguments' frame in order to get an argument.
   FRAME_DATA is the address in the frame where the argument has to be get
   from.
   ARGUMENT_LOCATION is the address of the argument where the value has to
   be set.
   ARG_INFO is an NSArgumentInfo that describes the argument. */

#define FRAME_GET_ARGUMENT(FRAME_DATA, ARGUMENT_LOCATION, ARG_INFO) \
     ({ if ((ARG_INFO).size < sizeof(void*)) \
           memcpy((ARGUMENT_LOCATION), \
                  ((char*)(FRAME_DATA)) + sizeof(void*) - (ARG_INFO).size, \
                  (ARG_INFO).size); \
       else if (*(ARG_INFO).type == _C_FLT) \
           *(float*)(ARGUMENT_LOCATION) = (float)*(double*)(FRAME_DATA); \
       else memcpy((ARGUMENT_LOCATION), (FRAME_DATA), (ARG_INFO).size); \
    })


/* Define how to find the value returned by a function. TYPE is a Objective-C
   encoding string describing the type of the returned value. ARGS is the
   arguments frame passed to __builtin_apply. RESULT_FRAME is the address of
   the block returned by __builtin_apply. RETURN_VALUE is an address where
   this macro should put the returned value. */

#define FUNCTION_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({	int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) { \
	    *(float*)(RETURN_VALUE) \
                = (float)*(double*)(((char*)(RESULT_FRAME)) + 8); \
	} \
	else if(*(TYPE) == _C_DBL) { \
	    *(double*)(RETURN_VALUE) \
                = *(double*)(((char*)(RESULT_FRAME)) + 8); \
	} \
	else if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy((RETURN_VALUE), \
		   *(void**)(((char*)(ARGS)) + sizeof(void*)), type_size); \
	else if(type_size <= sizeof(void*)) \
	    memcpy((RETURN_VALUE), \
		   ((char*)(RESULT_FRAME)) + sizeof(void*) - type_size, \
                   type_size); \
         else memcpy((RETURN_VALUE), (RESULT_FRAME), type_size); })


/* Set the value in RETURN_VALUE to be the value returned by a function.
   Assume that the fucntion was previously called and RESULT_FRAME is the
   address of the block returned by __builtin_apply. TYPE is the actual
   type of this value. ARGS is the address of block that was passed
   to __builtin_apply. */

#define FUNCTION_SET_VALUE(TYPE, ARGS, RESULT_FRAME, RETURN_VALUE) \
    ({  int type_size = objc_sizeof_type(TYPE); \
	if(*(TYPE) == _C_FLT) \
	    *(double*)(((char*)(RESULT_FRAME)) + 8) = \
		(double)*(float*)(RETURN_VALUE); \
	else if(*(TYPE) == _C_DBL) \
	    *(double*)(((char*)(RESULT_FRAME)) + 8) = \
		*(double*)(RETURN_VALUE); \
	else if(*(TYPE) == _C_STRUCT_B || *(TYPE) == _C_UNION_B \
		|| *(TYPE) == _C_ARY_B) \
	    memcpy(*(void**)(((char*)(ARGS)) + sizeof(void*)), \
		   (RETURN_VALUE), type_size); \
	else if(type_size <= sizeof(void*)) \
	    memcpy(((char*)(RESULT_FRAME)) + sizeof(void*) - type_size, \
                   (RETURN_VALUE), \
                   type_size); \
	else memcpy((RESULT_FRAME), (RETURN_VALUE), type_size); })


/* If the RETTYPE is a structure and the address of the structure value is
   passed to the called function, then obtain from ARGS its address. In general
   this address is the second pointer into the arguments frame. This macro
   should produce 0 if the RETTYPE doesn't match the conditions above. */

#define GET_STRUCT_VALUE_ADDRESS(ARGS, RETTYPE) \
    ((*(RETTYPE) == _C_STRUCT_B || *(RETTYPE) == _C_UNION_B \
	    || *(RETTYPE) == _C_ARY_B) ? \
	  *(void**)(((char*)(ARGS)) + sizeof(void*)) \
	: 0)

/* Prepare ARGS for calling the function. If the function returns a struct by
   value, it's the caller responsability to pass to the called function the
   address of where to store the structure value. */

#define SET_STRUCT_VALUE_ADDRESS(ARGS, ADDR, RETTYPE) \
    *(void**)(((char*)(ARGS)) + sizeof(void*)) = (ADDR)


/* The following macros are used to determine the encoding of a selector given
   the types of arguments. This macros follows the similar ones defined in the
   target machine description from the compiler sources. */

/* Define a data type for recording info about the arguments list of a method.
   A variable of this type is further used by FUNCTION_ARG_ENCODING to
   determine the encoding of an argument. This type should record all info
   about arguments processed so far. */

/* On RS/6000 the first eight words of non-FP are normally in
   registers and the rest are pushed.  The first 13 FP args are in
   registers. */

typedef struct rs6000_args 
{
    int int_args;       /* Number of integer arguments so far */
    int float_args;     /* Number of float arguments so far */
    int int_regs_position;  /* The current position for integers in
                               the register's frame */
    int stack_position; /* The current position in the stack frame */
} CUMULATIVE_ARGS;


/* Initialize a variable of type CUMULATIVE_ARGS. This macro is called before
   processing the first argument of a method. */

#define INIT_CUMULATIVE_ARGS(CUM) \
    ({ (CUM).int_args = 0; \
       (CUM).float_args = 0; \
       (CUM).int_regs_position = 4; \
       (CUM).stack_position = 0; \
    })

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


#define FUNCTION_ARG_ENCODING(CUM, TYPE, STACK_ARGSIZE) \
({  id encoding; \
    const char* type = [(TYPE) cString]; \
\
    if (*type == _C_FLT || *type == _C_DBL) { \
        if (++(CUM).float_args > 13) { \
            /* Place the argument on stack. Floats are pushed as doubles. */ \
            (CUM).stack_position += ROUND ((CUM).stack_position, \
                                           __alignof__(double)); \
            encoding = [NSString stringWithFormat:@"%s%d", type, \
                         (CUM).stack_position + OBJC_FORWARDING_MIN_OFFSET]; \
            (STACK_ARGSIZE) = ROUND ((CUM).stack_position, sizeof(double)); \
        } \
        else { \
            /* Place the argument on register's frame. Floats are \
               pushed as doubles. The register's frame for floats and \
               doubles starts at index 40. */ \
            int offset = 40 + sizeof (double) * ((CUM).float_args - 1); \
            encoding = [NSString stringWithFormat:@"%s+%d", type, offset]; \
            (CUM).int_regs_position += ROUND (objc_sizeof_type(type), \
                                              objc_alignof_type(type)); \
        } \
    } \
    else { \
        int align, size; \
\
        if (*type == _C_STRUCT_B || *type == _C_UNION_B \
            || *type == _C_ARY_B) { \
            align = __alignof__(type); \
            size = objc_sizeof_type (type); \
        } \
        else { \
            align = __alignof__(int); \
            size = objc_sizeof_type (type); \
        } \
\
        if (++(CUM).int_args > 8) { \
            /* We have a type to place on the stack */ \
            (CUM).stack_position += ROUND ((CUM).stack_position, align); \
            encoding = [NSString stringWithFormat:@"%s%d", type, \
                        (CUM).stack_position + OBJC_FORWARDING_MIN_OFFSET]; \
            (STACK_ARGSIZE) = ROUND ((CUM).stack_position, size); \
        } \
        else { \
            /* We have to place a value on the register's frame. The \
               register's frame for references and integers starts at 4. */ \
            (CUM).int_regs_position = ROUND((CUM).int_regs_position, align); \
            encoding = [NSString stringWithFormat:@"%s+%d", type, \
                                 (CUM).int_regs_position]; \
            (CUM).int_regs_position += ROUND (size, align); \
        } \
    } \
    encoding; })

#endif /* __powerpc_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
