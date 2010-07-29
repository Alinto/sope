/* 
   EOAdaptor.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef __EOAdaptor_h__
#define __EOAdaptor_h__

#import <Foundation/NSObject.h>

@class NSMutableArray, NSArray, NSDictionary, NSString, NSURL;

@class EOModel;
@class EOAttribute;
@class EOAdaptorContext;

/* The EOAdaptor class could be overriden for a concrete database adaptor.
   You have to override only those methods marked in this header with
   `override'.
*/

/* Don't make EOAdaptor* classes garbage collectable because we want to make
   the instances release the database allocated resources immediately when they
   receive the -release message. */

@interface EOAdaptor : NSObject
{
@protected
    EOModel        *model;
    NSString       *name;
    NSDictionary   *connectionDictionary;
    NSDictionary   *pkeyGeneratorDictionary;
    NSMutableArray *contexts;       // values with contexts
    id             delegate;       // not retained

    /* Flags used to check if the delegate responds to several messages */
    BOOL delegateWillReportError:1;
}

/* Creating an EOAdaptor */
+ (id)adaptorWithModel:(EOModel *)aModel;
+ (id)adaptorWithName:(NSString *)aName;
+ (id)adaptorForURL:(id)_url;
+ (NSString *)libraryDriversSubDir;
- (id)initWithName:(NSString *)aName;

/* Getting an adaptor's name */
- (NSString*)name;

/* Get the library subdir name */

/* Setting connection information */
- (void)setConnectionDictionary:(NSDictionary*)aDictionary;
- (NSDictionary*)connectionDictionary;
- (BOOL)hasValidConnectionDictionary;                   // override

/* Setting pkey generation info */
- (void)setPkeyGeneratorDictionary:(NSDictionary*)aDictionary;
- (NSDictionary*)pkeyGeneratorDictionary;

/* Setting the model */
- (void)setModel:(EOModel*)aModel;
- (EOModel*)model;

/* Creating and removing an adaptor context */
- (EOAdaptorContext*)createAdaptorContext;              // override
- (NSArray *)contexts;

/* Checking connection status */
- (BOOL)hasOpenChannels;

/* Getting adaptor-specific information */
- (Class)expressionClass;                               // override
- (Class)adaptorContextClass;                           // override
- (Class)adaptorChannelClass;                           // override
- (BOOL)isValidQualifierType:(NSString*)aTypeName;      // override

/* Formatting SQL */
- (id)formatAttribute:(EOAttribute*)attribute;          // override
- (id)formatValue:value forAttribute:(EOAttribute*)attribute; // override

/* Reporting errors */
- (void)reportError:(NSString*)anError;

/* Setting the delegate */
- (id)delegate;
- (void)setDelegate:(id)aDelegate;

@end /* EOAdaptor */


@interface EOAdaptor(Private)
- (void)contextDidInit:(id)aContext;
- (void)contextWillDealloc:(id)aContext;
@end


@interface NSObject(EOAdaptorDelegate)

- (BOOL)adaptor:(EOAdaptor*)anAdaptor willReportError:(NSString*)anError;

@end /* NSObject(EOAdaptorDelegate) */

@interface EOAdaptor(MDlinkExtensions)
- (NSString *)charConvertExpressionForAttributeNamed:(NSString *)_attrName;
- (NSString *)lowerExpressionForTextAttributeNamed:(NSString *)_attrName;
- (NSString *)expressionForTextValue:(id)_value;
- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)attribute;
@end

@interface EOAdaptor(EOF2Additions)

- (BOOL)canServiceModel:(EOModel *)_model;

@end

#endif /* __EOAdaptor_h__*/
