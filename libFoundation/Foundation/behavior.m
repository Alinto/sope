/*
 * This file implements behaviors, "protocols with implementations",
 * an original idea of Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>.
 *
 * I wrote another implementation that works with both GNU and NeXT runtimes.
 * I kept some of Andrew's original comments and some of his functions.
 *
 */

/* A Behavior can be seen as a "Protocol with an implementation" or a
   "Class without any instance variables".  A key feature of behaviors
   is that they give a degree of multiple inheritance.
   
   xxx not necessarily on the "no instance vars".  The behavior just has 
   to have the same layout as the class.
   
   The following function is a sneaky hack way that provides Behaviors
   without adding any new syntax to the Objective C language.  Simply
   define a class with the methods you want in the behavior, then call
   this function with that class as the BEHAVIOR argument.
   
   This function should be called in CLASS's +initialize method.
  
   If you add several behaviors to a class, be aware that the order of 
   the additions is significant.
  
   */

#include <Foundation/common.h>
#include <extensions/objc-runtime.h>
#include <extensions/NSException.h>
#include <extensions/exceptions/GeneralExceptions.h>
#include "common.h"

static void class_add_methods_if_not_there (Class, Class);
static struct objc_method *search_for_method_in_list (struct objc_method_list*, SEL);
static BOOL class_is_kind_of (Class, Class);

void class_add_behavior (Class class, Class behavior)
{
  Class behavior_super_class;

  if (!CLS_ISCLASS (class) || !CLS_ISCLASS (behavior))
    [[[ObjcRuntimeException alloc] initWithFormat:
	    @"Only classes must be passed to class_add_behavior"] raise];

  class_add_methods_if_not_there (class, behavior);
  class_add_methods_if_not_there (class->class_pointer,
				  behavior->class_pointer);

  behavior_super_class = class_get_super_class (behavior);
  if (!class_is_kind_of (class, behavior_super_class))
    class_add_behavior (class, behavior_super_class);
}

static void class_add_methods_if_not_there (Class class, Class behavior)
{
  static SEL initialize_sel = 0;
  struct objc_method_list *mlist;

  if (!initialize_sel)
    initialize_sel = sel_register_name ("initialize");

  for (mlist = behavior->methods; mlist; mlist = mlist->method_next)
    {
      int i;
      int size = mlist->method_count ? mlist->method_count - 1 : 1;
      struct objc_method_list *new_list
        = objc_malloc (sizeof (struct objc_method_list) + sizeof (struct objc_method) * size);

      new_list->method_next = NULL;
      new_list->method_count = 0;
      for (i = 0; i < mlist->method_count; i++)
	{
	  struct objc_method *behavior_method = &(mlist->method_list[i]);
	  struct objc_method *class_method =
            search_for_method_in_list (class->methods,
                                       behavior_method->method_name);

	  if (!class_method
	      && !SEL_EQ (behavior_method->method_name, initialize_sel))
	    {
	      /* As long as the method isn't defined in the CLASS, put the
                 BEHAVIOR method in there.  Thus, behavior methods override
                 the superclasses' methods. */
	      new_list->method_list[new_list->method_count++] =
		*behavior_method;
	    }
	}
      if (i)
	{
          int new_size
            = new_list->method_count ? new_list->method_count - 1 : 1;
	  new_list = objc_realloc (new_list,
                                   sizeof (struct objc_method_list) + sizeof (struct objc_method) * new_size);
	  class_addMethods (class, new_list);
	}
      else
	objc_free (new_list);
    }
}

/* Given a linked list of method and a method's name.  Search for the named
   method's method structure.  Return a pointer to the method's method
   structure if found.  NULL otherwise. */
static struct objc_method *
search_for_method_in_list (struct objc_method_list *mlist, SEL op)
{
  if (!sel_is_mapped (op))
    return NULL;

  /* If not found then we'll search the list.  */
  for (; mlist; mlist = mlist->method_next)
    {
      int i;

      /* Search the method list.  */
      for (i = 0; i < mlist->method_count; ++i)
	{
	  struct objc_method *method = &mlist->method_list[i];

	  if (method->method_name)
	    if (SEL_EQ (method->method_name, op))
	      return method;
	}
    }

  return NULL;
}

static BOOL class_is_kind_of (Class a, Class b)
{
  for (; a; a = class_get_super_class (a))
    if (a == b)
      return YES;
  return NO;
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
