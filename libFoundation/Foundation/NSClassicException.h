/* 
   NSClassicException.h

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

#ifndef __NSException_h__
#define __NSException_h__

#include <setjmp.h>
#include <stdarg.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>

@interface NSException : NSObject
{
    NSString*	name;
    NSString*	reason;
    NSDictionary* userInfo;
}

/* Class initalization */
+ (void)taskNowMultiThreaded:notification;

/* Creating and Raising Exceptions */
+ (NSException*)exceptionWithName:(NSString*)name
    reason:(NSString*)reason
    userInfo:(NSDictionary*)userInfo;
+ (void)raise:(NSString *)name
    format:(NSString *)format,...;
+ (void)raise:(NSString*)name
    format:(NSString*)format
    arguments:(va_list)argList;

- (id)initWithName:(NSString*)name
    reason:(NSString*)reason
    userInfo:(NSDictionary*)userInfo;
- (void)raise;

/* Querying Exceptions */
- (NSString*)name;
- (NSString*)reason;
- (NSDictionary*)userInfo;

@end /* NSException */


@interface NSException (Extensions)
- (BOOL)exceptionIsKindOfClass:(Class)class;
				/* return [self isKindOfClass:class] */
- (BOOL)exceptionIsIn:(NSArray*)exceptions;
- (NSString*)errorString;
- initWithFormat:(NSString*)format, ...;
- setName:(NSString*)name;
- setReason:(NSString*)reason;
- setUserInfo:(NSDictionary*)userInfo;
@end /* NSException (Extension) */


typedef void NSUncaughtExceptionHandler(NSException *exception);

NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void);
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *handler);

/* Exception names */
LF_EXPORT NSString *NSInconsistentArchiveException;
LF_EXPORT NSString *NSGenericException;
LF_EXPORT NSString *NSInternalInconsistencyException;
LF_EXPORT NSString *NSInvalidArgumentException;
LF_EXPORT NSString *NSMallocException;
LF_EXPORT NSString *NSObjectInaccessibleException;
LF_EXPORT NSString *NSObjectNotAvailableException;
LF_EXPORT NSString *NSDestinationInvalidException;
LF_EXPORT NSString *NSPortTimeoutException;
LF_EXPORT NSString *NSInvalidSendPortException;
LF_EXPORT NSString *NSInvalidReceivePortException;
LF_EXPORT NSString *NSPortSendException;
LF_EXPORT NSString *NSPortReceiveException;
LF_EXPORT NSString *NSOldStyleException;
LF_EXPORT NSString *NSRangeException;


typedef struct _NSHandler
{
    struct _NSHandler*	previousHandler;
    jmp_buf		jmpState;
    NSException*	exception;
} NSHandler;

LF_EXPORT void _NSAddHandler(NSHandler *handler);
LF_EXPORT void _NSRemoveHandler(NSHandler *handler);

/*  OpenStep macros for exception handling. */

#define NS_DURING \
({ \
    __label__ _quit; \
    NSHandler exceptionHandler; \
    if(!setjmp(exceptionHandler.jmpState)) { \
	_NSAddHandler(&exceptionHandler);

#define NS_HANDLER \
	_NSRemoveHandler(&exceptionHandler); \
	goto _quit; /* to remove compiler warning about unused label*/ \
    } \
    else { \
	NSException* localException = exceptionHandler.exception; \
	_NSRemoveHandler(&exceptionHandler); \

#define NS_ENDHANDLER \
	localException = nil; /* Avoid compiler warning */ \
    } \
_quit: 0;\
});

#define NS_VALRETURN(value) \
    ({_NSRemoveHandler(&exceptionHandler); return (value);})

#define NS_VOIDRETURN \
    ({_NSRemoveHandler(&exceptionHandler); return;})


/*
 * The new macros for handling exceptions.
 */

#define TRY \
({ \
    __label__ _quit; \
    NSHandler exceptionHandler; \
    volatile int __setjmp_ret = setjmp(exceptionHandler.jmpState); \
    if(!__setjmp_ret) { \
	_NSAddHandler(&exceptionHandler);

#define END_TRY \
	_NSRemoveHandler(&exceptionHandler); \
	goto _quit; /* to remove compiler warning about unused label */ \
    } \
_quit: \
    { \
	void handler(NSException* localException) \
	{ \
	    BOOL _caught = NO; \
	    if(localException) \
		_NSRemoveHandler(&exceptionHandler); \
	    if(!localException) {

#define CATCH(exception_class) \
	    } else if([localException isKindOfClass:[exception_class class]]) { \
		_caught = YES;

#ifndef PRECOMP
# define MULTICATCH(exception_classes...) \
	    } else if([localException exceptionIsIn: \
		    [NSArray arrayWithObjects:##exception_classes, nil]]) { \
		_caught = YES;
#endif /* PRECOMP */

#define OTHERWISE \
	    } else { \
		_caught = YES;

#define CLEANUP \
	    } \
	    if(localException && !_caught) {

#define FINALLY \
	    } \
	    if(1) {

#define END_CATCH \
	    } \
	    if(!localException) return; \
	    if(!_caught) \
		[localException raise]; \
	    else RELEASE(localException); \
	} \
	handler(__setjmp_ret == 1 ? exceptionHandler.exception : nil); \
    } \
});

    /*  Use BREAK inside a TRY block to get out of it */
#define BREAK	({_NSRemoveHandler(&exceptionHandler); goto _quit;})

#ifndef PRECOMP
    /*  If you want to generate an exception issue a THROW with the exception
	an object derived from the NSException class. */
# define THROW(exception...)	[##exception raise]
#else
# define THROW(exception)		[exception raise]
#endif /* PRECOMP */

    /*  If you want to reraise an exception inside an exception handler
	just say RERAISE. */
#define RERAISE                 THROW(localException)


/*
 * Assertions.
 */

#ifndef __FoundationException_definition__
#define __FoundationException_definition__

@interface FoundationException : NSException
@end

#endif /* __FoundationException_definition__ */

@interface AssertException : FoundationException
@end


@interface NSAssertionHandler : NSObject

/* Getting the Current Handler */
+ (NSAssertionHandler*)currentHandler;

/* Handling Failures */
- (void)handleFailureInFunction:(NSString*)functionName
    file:(NSString*)fileName
    lineNumber:(int)line
    description:(NSString*)format,...;
- (void)handleFailureInMethod:(SEL)selector
    object:(id)object
    file:(NSString*)fileName
    lineNumber:(int)line
    description:(NSString*)format,...;

@end

#ifndef PRECOMP

#define NSAssert(condition, desc, arguments...) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd \
		    object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , ##arguments]; \
    0;})

#define NSCAssert(condition, desc, arguments...) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , ##arguments]; \
    0;})

#define Assert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Assertion failed: "]); \
	THROW([AssertException new]); \
    } \
    0;})

# define NSParameterAssert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Parameter Assertion failed: "]); \
	THROW([AssertException new]); \
    } \
    0;})

# define NSCParameterAssert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Parameter Assertion failed: "]); \
	THROW([AssertException new]); \
    } \
    0;})

#define NSAssert1(args...)	NSAssert(##args)
#define NSAssert2(args...)	NSAssert(##args)
#define NSAssert3(args...)	NSAssert(##args)
#define NSAssert4(args...)	NSAssert(##args)
#define NSAssert5(args...)	NSAssert(##args)

#define NSCAssert1(args...)	NSCAssert(##args)
#define NSCAssert2(args...)	NSCAssert(##args)
#define NSCAssert3(args...)	NSCAssert(##args)
#define NSCAssert4(args...)	NSCAssert(##args)
#define NSCAssert5(args...)	NSCAssert(##args)

#endif /* PRECOMP */


#endif /* __NSException_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
