/* 
   NSFuncallException.h

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

@class NSDictionary;

@interface NSException : NSObject
{
    NSString     *name;
    NSString     *reason;
    NSDictionary *userInfo;
}

/* Creating and Raising Exceptions */

+ (NSException *)exceptionWithName:(NSString *)name
  reason:(NSString *)reason
  userInfo:(NSDictionary *)userInfo;
+ (void)raise:(NSString *)name
  format:(NSString *)format,...;
+ (void)raise:(NSString *)name
  format:(NSString *)format
  arguments:(va_list)argList;

- (id)initWithName:(NSString *)name
  reason:(NSString *)reason
  userInfo:(NSDictionary *)userInfo;
- (void)raise;

/* Querying Exceptions */

- (NSString *)name;
- (NSString *)reason;
- (NSDictionary *)userInfo;

@end /* NSException */


@interface NSException (Extensions)
- (BOOL)exceptionIsKindOfClass:(Class)class;
			/* return [self isKindOfClass:class] */
- (BOOL)exceptionIsIn:(NSArray *)exceptions;
- (NSString *)errorString;
- (id)initWithFormat:(NSString *)format, ...;
- (id)initWithFormat:(NSString *)format arguments:(va_list)ap;
- (id)setName:(NSString *)name;
- (id)setReason:(NSString *)reason;
- (id)setUserInfo:(NSDictionary *)userInfo;
@end /* NSException (Extension) */

@interface NSException (Backtrace)
+ (NSString *)backtrace;
+ (void)printBacktrace;
@end /* NSException(Backtrace) */

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

/*  OpenStep macros for exception handling.
    Use the ones defined below instead. */

#define NS_DURING	TRY {

#define NS_HANDLER	} END_TRY OTHERWISE {

#define NS_ENDHANDLER	} END_CATCH

#define NS_VALRETURN(value) \
    ({_NSRemoveHandler(&exceptionHandler); handler(nil); return (value);})

#define NS_VOIDRETURN \
    ({_NSRemoveHandler(&exceptionHandler); handler(nil); return;})

typedef void (*THandlerFunction)(id);

typedef struct _NSHandler
{
    struct _NSHandler *previousHandler;
    jmp_buf	      jmpState;
    THandlerFunction  handler;
} NSHandler;

LF_EXPORT void _NSAddHandler(NSHandler *handler);
LF_EXPORT void _NSRemoveHandler(NSHandler *handler);


/*
 * The new macros for handling exceptions.
 */

#define TRY \
{ \
    auto void handler(); \
    NSHandler exceptionHandler; \
\
    int _dummy = \
    ({ \
	__label__ _quit; \
	if(!setjmp(exceptionHandler.jmpState)) { \
	    exceptionHandler.handler = handler; \
	    _NSAddHandler(&exceptionHandler);

#define END_TRY \
	    _NSRemoveHandler(&exceptionHandler); \
	    handler(nil); \
	    goto _quit; /* to remove compiler warning about unused label*/ \
	}; \
	_quit: 0; \
    }); \
    void handler(NSException *localException) \
    { \
	BOOL _caught = NO; \
        RETAIN(localException);\
	if (localException != nil) \
	    _NSRemoveHandler(&exceptionHandler); \
	if (localException == nil) { _dummy++;

#define CATCH(exception_class) \
	} else if([localException exceptionIsKindOfClass:[exception_class class]]) { \
	    _caught = YES;

#ifndef PRECOMP
# define MULTICATCH(exception_classes...) \
	} else if ([localException exceptionIsIn: \
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
	if (localException==nil) return; \
	if (!_caught) \
	    [localException raise]; \
	else {\
	    RELEASE(localException); \
	    longjmp(exceptionHandler.jmpState, 1); \
	}\
    } \
}


/*  Use BREAK inside a TRY block to get out of it */
#define BREAK	({_NSRemoveHandler(&exceptionHandler); goto _quit;})

#ifndef PRECOMP
/*  If you want to generate an exception issue a THROW with the exception
    an object derived from the NSException class. */
# define THROW(exception...)	[##exception raise]
#else
# define THROW(exception)	[exception raise]
#endif /* PRECOMP */

/*  If you want to reraise an exception inside an exception handler
    just say RERAISE. */
#define RERAISE                 [localException raise]



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
# define NSAssert(condition, desc, arguments...) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd \
		    object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , ##arguments]; \
    0;})

# define NSCAssert(condition, desc, arguments...) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , ##arguments]; \
    0;})

# define Assert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Assertion failed: "]); \
	[[AssertException new] raise]; \
    } \
    0;})

# define NSParameterAssert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Parameter Assertion failed: "]); \
	[[AssertException new] raise]; \
    } \
    0;})

# define NSCParameterAssert(condition) \
    ({if(!(condition)) {\
	NSLog([(@#condition) stringByPrependingString:@"Parameter Assertion failed: "]); \
	[[AssertException new] raise]; \
    } \
    0;})

# define NSAssert1(condition, desc, a1) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1]; \
    0;})
# define NSAssert2(condition, desc, a1, a2) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2]; \
    0;})
# define NSAssert3(condition, desc, a1, a2, a3) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3]; \
    0;})
# define NSAssert4(condition, desc, a1, a2, a3, a4) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3, a4]; \
    0;})
# define NSAssert5(condition, desc, a1, a2, a3, a4, a5) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInMethod:_cmd object:self \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3, a4, a5]; \
    0;})

# define NSCAssert1(condition, desc, a1) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1]; \
    0;})
# define NSCAssert2(condition, desc, a1, a2) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2]; \
    0;})
# define NSCAssert3(condition, desc, a1, a2, a3) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3]; \
    0;})
# define NSCAssert4(condition, desc, a1, a2, a3, a4) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3, a4]; \
    0;})
# define NSCAssert5(condition, desc, a1, a2, a3, a4, a5) \
    ({ if(!(condition)) \
	    [[NSAssertionHandler currentHandler] \
		    handleFailureInFunction: \
			[NSString stringWithCString:__PRETTY_FUNCTION__] \
		    file:[NSString stringWithCString:__FILE__] \
		    lineNumber:__LINE__ \
		    description:(desc) , a1, a2, a3, a4, a5]; \
    0;})

#endif /* PRECOMP */

#endif /* __NSException_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
