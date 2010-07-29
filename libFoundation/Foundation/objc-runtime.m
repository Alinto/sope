/* 
   objc-runtime.m

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

#include <Foundation/NSString.h>

#include "common.h"
#include <extensions/NSException.h>
#include <extensions/objc-runtime.h>

#if GNU_RUNTIME
#include <objc/sarray.h>


LF_EXPORT void class_add_methods(Class class, struct objc_method_list* mlist)
{
#if libobjc_ISDLL
    extern __declspec(dllimport) void *__objc_uninstalled_dtable;
#else
    extern void *__objc_uninstalled_dtable;
#endif
    int i;
    
    NSCAssert(mlist->method_next == NULL, @"mlist must not be linked");
    /* Insert the new method list in the methods linked list. */
    mlist->method_next = class->methods;
    class->methods = mlist;

    if(class->dtable != __objc_uninstalled_dtable) {
	/* Insert each method imp in the class dtable. */
	for(i = 0; i < mlist->method_count; i++) {
	    struct objc_method* method = &(mlist->method_list[i]);
	    sarray_at_put_safe (class->dtable,
				(sidx)method->method_name->sel_id,
				method->method_imp);
	}
    }
}

#endif /* GNU_RUNTIME */


#if NeXT_RUNTIME

id nil_method(id receiver, SEL op, ...)
{
    return receiver;
}

id next_objc_msg_sendv(id object, SEL op, void* frame)
{
  arglist_t  argFrame = __builtin_apply_args();
  Method     *m       = class_get_instance_method(object->class_pointer, op);
  const char *type;
  void       *result;

  argFrame->arg_ptr = frame;
  *((id*)method_get_first_argument (m, argFrame, &type)) = object;
  *((SEL*)method_get_next_argument (argFrame, &type)) = op;
  result = __builtin_apply((apply_t)m->method_imp, 
			   argFrame,
			   method_get_sizeof_arguments (m));

#if !defined(BROKEN_BUILTIN_APPLY) && defined(i386)
    /* Special hack to avoid pushing the poped float value back to the fp
       stack on i386 machines. This happens with NeXT runtime and 2.7.2
       compiler. If the result value is floating point don't call
       __builtin_return anymore. */
    if(*m->method_types == _C_FLT || *m->method_types == _C_DBL) {
	long double value = *(long double*)(((char*)result) + 8);
	asm("fld %0" : : "f" (value));
    }
    else
#endif
  __builtin_return(result);
}

/* Returns YES iff t1 and t2 have same method types, but we ignore
   the argframe layout */
BOOL
sel_types_match (const char* t1, const char* t2)
{
  if (!t1 || !t2)
    return NO;
  while (*t1 && *t2)
    {
      if (*t1 == '+') t1++;
      if (*t2 == '+') t2++;
      while (isdigit(*t1)) t1++;
      while (isdigit(*t2)) t2++;
      /* xxx Remove these next two lines when qualifiers are put in
	 all selectors, not just Protocol selectors. */
      t1 = objc_skip_type_qualifiers(t1);
      t2 = objc_skip_type_qualifiers(t2);
      if (!*t1 && !*t2)
	return YES;
      if (*t1 != *t2)
	return NO;
      t1++;
      t2++;
    }
  return NO;
}

#endif /* NeXT_RUNTIME */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

