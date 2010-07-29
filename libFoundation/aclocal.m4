AC_SUBST(MAKE)
AC_SUBST(OBJC_RUNTIME)
AC_SUBST(OBJC_RUNTIME_FLAG)
AC_SUBST(BROKEN_COMPILER)
AC_SUBST(BROKEN_BUILTIN_APPLY)
AC_SUBST(NO_NESTED_FUNCTIONS)
AC_SUBST(PCCTS_CFLAGS)
AC_SUBST(HOST)dnl
AC_SUBST(HOST_CPU)dnl
AC_SUBST(HOST_VENDOR)dnl
AC_SUBST(HOST_OS)dnl
AC_SUBST(TARGET)dnl
AC_SUBST(TARGET_CPU)dnl
AC_SUBST(TARGET_VENDOR)dnl
AC_SUBST(TARGET_OS)dnl
AC_SUBST(STRUCT_ALIGNMENT)dnl
dnl
dnl
AC_DEFUN(AC_LANG_OBJECTIVE_C,
[AC_REQUIRE([AC_PROG_CC])dnl
define([AC_LANG], [AC_LANG_OBJECTIVE_C])dnl
OLD_IFS=$IFS
IFS=:
for i in $LD_LIBRARY_PATH
do
  LDFLAGS="-L$i $LDFLAGS"
done
IFS=$OLD_IFS
LIBS="-lobjc $LIBS"
ac_ext=m
# CFLAGS is not in ac_cpp because -g, -O, etc. are not valid cpp options.
ac_cpp='$CPP $OBJC_RUNTIME_FLAG'
ac_compile='${CC-cc} -c $OBJC_RUNTIME_FLAG $CFLAGS conftest.$ac_ext 1>&AC_FD_CC 2>&AC_FD_CC'
ac_link='${CC-cc} -o conftest $OBJC_RUNTIME_FLAG $CFLAGS $LDFLAGS conftest.$ac_ext $LIBS $OBJC_LIBS 1>&AC_FD_CC 2>&AC_FD_CC'
])dnl
dnl
dnl
AC_DEFUN(AC_CHECK_NESTED_FUNCTIONS,
[AC_REQUIRE([AC_PROG_CC])dnl
AC_MSG_CHECKING(whether nested functions work)
AC_CACHE_VAL(ac_cv_nested_functions,
[AC_LANG_SAVE[]dnl
AC_LANG_OBJECTIVE_C[]
AC_TRY_RUN([
#include <stdlib.h>
f(void (*nested)())
{
    (*nested)();
}

main()
{
    int a = 0;
    void nested()
    {
	a = 1;
    }
    f(nested);
    if(a != 1)
	exit(1);
    exit(0);
}
], ac_cv_nested_functions=yes, ac_cv_nested_functions=no,
ac_cv_nested_functions=yes)
AC_LANG_RESTORE[]
])dnl
AC_MSG_RESULT(${ac_cv_nested_functions})
NO_NESTED_FUNCTIONS=no
if test $ac_cv_nested_functions = no; then
    AC_DEFINE(NO_NESTED_FUNCTIONS)
    NO_NESTED_FUNCTIONS=yes
fi
])dnl
dnl
dnl
AC_DEFUN(AC_BROKEN_COMPILER,
[AC_REQUIRE([AC_PROG_CC])dnl
AC_MSG_CHECKING(if the Objective-C compiler crashes with nested functions)
AC_CACHE_VAL(ac_cv_broken_compiler,
[AC_LANG_SAVE[]dnl
AC_LANG_OBJECTIVE_C[]
AC_TRY_RUN([
#include <objc/objc.h>
#include <objc/Object.h>
#include <stdlib.h>

void f()
{
    auto void h(id);

    void h(id exception)
    {
	[Object alloc];
	{
	    void clean(void)
	    {
	    }
	}
    }
}

void g()
{
    auto void h(id);

    void h(id exception)
    {
	[Object alloc];
    }
}

main()
{
    exit(0);
}
], ac_cv_broken_compiler=no,
ac_cv_broken_compiler=yes,
ac_cv_broken_compiler=no)
AC_LANG_RESTORE[]
])dnl
BROKEN_COMPILER=${ac_cv_broken_compiler}
if test ${ac_cv_nested_functions} = no -o ${ac_cv_broken_compiler} = yes; then
  ac_cv_broken_compiler=yes;
  BROKEN_COMPILER=yes;
  AC_DEFINE(BROKEN_COMPILER)
fi
AC_MSG_RESULT(${ac_cv_broken_compiler})
])dnl
dnl
dnl
AC_DEFUN(AC_BROKEN_BUILTIN_APPLY,
[AC_REQUIRE([AC_PROG_CC])dnl
AC_MSG_CHECKING(whether __builtin_apply and __builtin_return are broken)
AC_CACHE_VAL(ac_cv_broken_builtin_apply,
[AC_LANG_SAVE[]dnl
AC_LANG_OBJECTIVE_C[]
AC_TRY_RUN([
#include <objc/Object.h>

float value = 123.456;

@interface MyObject : Object
@end

@implementation MyObject
- (float)floatValue
{
    return value;
}
@end

@interface Forwarder : Object
{
    id object;
}
@end

@implementation Forwarder
- setObject:anObject
{
    object = anObject;
    return self;
}

- (void*)forward:(SEL)selector:(void*)argframe
{
    IMP imp = [object methodFor:@selector(floatValue)];
    void* retframe;
    void* frame = malloc(116);
    *(void**)frame = NULL;
    retframe = __builtin_apply((void(*)(void))imp, frame, 0);
    if(*(long double*)(((char*)retframe) + 8) == (long double)value)
	exit(0);
    exit(1);
}
@end

int main()
{
    id fwd = [[[Forwarder alloc] init] setObject:[MyObject alloc]];
    [fwd floatValue];
    exit(0);
    return 0; // keep compiler happy
}
], ac_cv_broken_builtin_apply=no,
ac_cv_broken_builtin_apply=yes,
ac_cv_broken_builtin_apply=no)
AC_LANG_RESTORE[]
])dnl
AC_MSG_RESULT(${ac_cv_broken_builtin_apply})
BROKEN_BUILTIN_APPLY=${ac_cv_broken_builtin_apply}
if test $BROKEN_BUILTIN_APPLY = yes; then
    AC_DEFINE(BROKEN_BUILTIN_APPLY)
fi
])dnl
dnl
dnl
AC_DEFUN(AC_CHECK_MATH_LIB,
[AC_REQUIRE([AC_PROG_CC])dnl
dnl temporary rename AC_MSG_RESULT to do nothing
define(old_AC_MSG_RESULT, defn([AC_MSG_RESULT]))dnl
define([AC_MSG_RESULT],)dnl
AC_CHECK_FUNC(sqrt, ,
[dnl On linux, to link a program that use math functions we must link with libm.a
LIBS="$LIBS -lm -lc"
ac_cv_func_sqrt=no
AC_TRY_LINK(, [
double sqrt(double);
sqrt(2.0);
], ac_cv_func_sqrt="-lm -lc")
])
define([AC_MSG_RESULT], defn([old_AC_MSG_RESULT]))dnl
undefine([old_AC_MSG_RESULT])dnl
AC_MSG_RESULT($ac_cv_func_sqrt)
])dnl
dnl
dnl
AC_DEFUN(AC_STRUCT_ALIGNMENT,
[AC_REQUIRE([AC_PROG_CC])dnl
AC_MSG_CHECKING(for the C structures alignment)
AC_CACHE_VAL(ac_cv_struct_alignment,
[AC_TRY_RUN([#include <stdio.h>

struct simple {
    double x;
    char y;
} simple1;

int struct_alignment = __alignof__ (simple1);

main()
{
  FILE *f=fopen("conftestval", "w");
  if (!f) exit(1);
  fprintf(f, "%u\n", struct_alignment);
  exit(0);
}
], ac_cv_struct_alignment=`cat conftestval`,
ac_cv_struct_alignment=0,
ifelse([$2], , , ac_cv_struct_alignment=$2))])dnl
AC_MSG_RESULT($ac_cv_struct_alignment)
STRUCT_ALIGNMENT=$ac_cv_struct_alignment
])dnl
dnl
dnl
AC_DEFUN(AC_COMPILE_CHECK_SIZEOF,
[changequote(<<, >>)dnl 
dnl The name to #define. 
define(<<AC_TYPE_NAME>>, translit(sizeof_$1, [a-z *], [A-Z_P]))dnl 
dnl The cache variable name. 
define(<<AC_CV_NAME>>, translit(ac_cv_sizeof_$1, [ *], [_p]))dnl 
changequote([, ])dnl 
AC_MSG_CHECKING(size of $1) 
AC_CACHE_VAL(AC_CV_NAME, 
[for ac_size in 4 8 1 2 16 $2 ; do # List sizes in rough order of prevalence. 
  AC_TRY_COMPILE([#include "confdefs.h" 
#include <sys/types.h> 
$2 
], [switch (0) case 0: case (sizeof ($1) == $ac_size):;], AC_CV_NAME=$ac_size) 
  if test x$AC_CV_NAME != x ; then break; fi 
done 
]) 
if test x$AC_CV_NAME = x ; then 
  echo "cannot determine a size for $1";
  AC_CV_NAME=0; 
fi 
AC_MSG_RESULT($AC_CV_NAME) 
AC_DEFINE_UNQUOTED(AC_TYPE_NAME, $AC_CV_NAME, [The number of bytes in type $1]) 
undefine([AC_TYPE_NAME])dnl 
undefine([AC_CV_NAME])dnl 
]) 
