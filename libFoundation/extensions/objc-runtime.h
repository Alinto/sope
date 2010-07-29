/* 
   objc-runtime.h

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

#ifndef __objc_runtime_h__
#define __objc_runtime_h__

#include <objc/objc.h>
#include <objc/objc-api.h>
#include <objc/Protocol.h>


/* If neither GNU nor NeXT runtimes are defined,
   make GNU the default runtime
 */
#if !(GNU_RUNTIME || NeXT_RUNTIME)
# define GNU_RUNTIME 1
#endif


#if defined(NX_CURRENT_COMPILER_RELEASE) || defined(__APPLE_CC__)

/* From objc/objc.h */
typedef void* retval_t;		/* return value */
typedef void(*apply_t)(void);	/* function pointer */
typedef union {
  char *arg_ptr;
  char arg_regs[sizeof (char*)];
} *arglist_t;			/* argument frame */

# define class_pointer isa

#  if defined(__APPLE_CC__)
#    define _C_ATOM '%'
#  else
#    define _C_ATOM _C_STR
#  endif

#  if defined(__APPLE_CC__)
extern void objc_error(id object, int code, const char* fmt, ...);
extern void objc_verror(id object, int code, const char* fmt, va_list ap);
typedef BOOL (*objc_error_handler)(id, int code, const char *fmt, va_list ap);

/*
** Error codes
** These are used by the runtime library, and your
** error handling may use them to determine if the error is
** hard or soft thus whether execution can continue or abort.
*/
#define OBJC_ERR_UNKNOWN 0             /* Generic error */

#define OBJC_ERR_OBJC_VERSION 1        /* Incorrect runtime version */
#define OBJC_ERR_GCC_VERSION 2         /* Incorrect compiler version */
#define OBJC_ERR_MODULE_SIZE 3         /* Bad module size */
#define OBJC_ERR_PROTOCOL_VERSION 4    /* Incorrect protocol version */

#define OBJC_ERR_MEMORY 10             /* Out of memory */

#define OBJC_ERR_RECURSE_ROOT 20       /* Attempt to archive the root
					  object more than once. */
#define OBJC_ERR_BAD_DATA 21           /* Didn't read expected data */
#define OBJC_ERR_BAD_KEY 22            /* Bad key for object */
#define OBJC_ERR_BAD_CLASS 23          /* Unknown class */
#define OBJC_ERR_BAD_TYPE 24           /* Bad type specification */
#define OBJC_ERR_NO_READ 25            /* Cannot read stream */
#define OBJC_ERR_NO_WRITE 26           /* Cannot write stream */
#define OBJC_ERR_STREAM_VERSION 27     /* Incorrect stream version */
#define OBJC_ERR_BAD_OPCODE 28         /* Bad opcode */

#define OBJC_ERR_UNIMPLEMENTED 30      /* Method is not implemented */

#define OBJC_ERR_BAD_STATE 40          /* Bad thread state */
#  endif

# include <extensions/encoding.h>
#else
# include <objc/encoding.h>
#endif /* !NX_CURRENT_COMPILER_RELEASE */

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

extern BOOL sel_types_match(const char*, const char*);

#if GNU_RUNTIME

#define class_addMethods	class_add_methods
#define SEL_EQ(sel1, sel2)	sel_eq(sel1, sel2)

#define class_getClassMethod		class_get_class_method
#define class_getInstanceMethod		class_get_instance_method
#define class_poseAs			class_pose_as
#define objc_getClass			objc_get_class
#define objc_lookUpClass		objc_lookup_class
#define sel_getName			sel_get_name
#define sel_getUid			sel_get_uid
#define sel_registerName		sel_register_name
#define sel_isMapped			sel_is_mapped

#define class_setVersion		class_set_version
#define class_getVersion		class_get_version
#define object_getClassName		object_get_class_name
#define objc_msgLookup			objc_msg_lookup
#define next_objc_msg_sendv		objc_msg_sendv

#endif


#if NeXT_RUNTIME

#define SEL_EQ(sel1, sel2)	(sel1 == sel2)

extern BOOL sel_isMapped(SEL sel);
extern const char *sel_getName(SEL sel);
extern SEL sel_getUid(const char *str);
extern SEL sel_registerName(const char *str);
extern const char *object_getClassName(id obj);

extern id class_createInstance(Class, unsigned idxIvars);

extern void class_setVersion(Class, int);
extern int class_getVersion(Class);

extern struct objc_method* class_getInstanceMethod(Class, SEL);
extern struct objc_method* class_getClassMethod(Class, SEL);

extern Class class_poseAs(Class imposter, Class original);
extern id objc_lookUpClass(const char *name);

#define class_get_class_method		class_getClassMethod
#define class_get_instance_method	class_getInstanceMethod
#define class_pose_as			class_poseAs
#define objc_get_class			objc_getClass
#define objc_lookup_class		objc_lookUpClass
#define sel_get_name			sel_getName
#define sel_get_uid			sel_getUid
#define sel_get_any_uid			sel_getUid
#define sel_register_name		sel_registerName
#define sel_is_mapped			sel_isMapped
#define class_create_instance(CLASS) \
	class_createInstance(CLASS, 0)
#define class_set_version		class_setVersion
#define class_get_version		class_getVersion
#define object_get_class_name		object_getClassName

#define objc_msg_lookup			objc_msgLookup
#define objc_msg_sendv			next_objc_msg_sendv

extern id objc_msgSend(id self, SEL op, ...);
extern id objc_msgSendSuper(struct objc_super *super, SEL op, ...);

/* forwarding operations */
#if !defined(__APPLE_CC__)
typedef void* marg_list;
#endif

#if defined(__APPLE_CC__)
#define __CLS_INFO(cls)         ((cls)->info)
#define __CLS_ISINFO(cls, mask) ((__CLS_INFO(cls) & mask) == mask)
#define CLS_ISCLASS(cls) ((cls) && __CLS_ISINFO(cls, CLS_CLASS))
#endif

extern id next_objc_msg_sendv(id self, SEL op, void* arg_frame);

static inline IMP
objc_msgLookup(id object, SEL sel) __attribute__((unused));


static inline IMP
objc_msgLookup(id object, SEL sel)
{
    if(!object || !sel) return NULL;
    else {
	Class class = object->class_pointer;
	struct objc_method* mth =
	    (CLS_ISCLASS(class) ?
		  class_get_instance_method(class, sel)
		: class_get_class_method(class, sel));
	return mth ? mth->method_imp : (IMP)0;
    }
}

#endif /* NeXT_RUNTIME */


extern void class_addMethods(Class, struct objc_method_list*);
void class_add_behavior(Class class, Class behavior);

#endif /* __objc_runtime_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
