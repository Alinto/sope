/*
 Copyright (C) 2004-2005 Marcus Mueller <znek@mulle-kybernetik.com>

 This file is part of OGo

 OGo is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.

 OGo is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with OGo; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
 */
// $Id: SOPEXContentValidator.m,v 1.1 2004/04/09 18:53:02 znek Exp $
//  Created by znek on Mon Apr 05 2004.


#import "SOPEXContentValidator.h"
#import <NGObjWeb/NGObjWeb.h>
#import <Foundation/NSError.h>


NSString *SOPEXDocumentValidationErrorDomain = @"SOPEXDocumentValidationErrorDomain";


@interface SOPEXContentValidator (PrivateAPI)
+ (NSError *)validateContent:(id)content usingSelector:(SEL)selector;
- (NSError *)validateContent:(id)content ofMIMEType:(NSString *)mimeType;
- (NSError *)validateContent:(id)content withParserClass:(Class)parserClass selector:(SEL)selector;
- (NSString *)formattedErrorString;
@end


@interface NSObject(UsedNGObjWebPrivates)
- (id)initWithHandler:(id)_handler;
@end


@implementation SOPEXContentValidator


#pragma mark -
#pragma mark ### INIT & DEALLOC ###


- (id)init
{
    [super init];
    self->warnings = [[NSMutableArray alloc] init];
    self->errors = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [self->warnings release];
    [self->errors release];
    [super dealloc];
}


#pragma mark -
#pragma mark ### VALIDATION ###


+ (NSError *)validateWOXContent:(id)content
{
    return [self validateContent:content usingSelector:@selector(validateWOXContent:)];
}

+ (NSError *)validateWOHTMLContent:(id)content
{
    return [self validateContent:content usingSelector:@selector(validateWOHTMLContent:)];
}

+ (NSError *)validateWODContent:(id)content
{
    return [self validateContent:content usingSelector:@selector(validateWODContent:)];
}

+ (NSError *)validateContent:(id)content usingSelector:(SEL)selector
{
    SOPEXContentValidator *validator;
    NSError *status;
    
    validator = [[self alloc] init];
    status = [validator performSelector:selector withObject:content];
    [validator release];
    return status;
}

- (NSError *)validateWOXContent:(id)content
{
    return [self validateContent:content ofMIMEType:@"text/xml"];
}

- (NSError *)validateContent:(id)content ofMIMEType:(NSString *)mimeType
{
    id <NSObject, SaxXMLReader> xmlReader;
    
    xmlReader = [[SaxXMLReaderFactory standardXMLReaderFactory] createXMLReaderForMimeType:mimeType];
    [xmlReader setErrorHandler:self];
    [xmlReader parseFromSource:content];
    return [self status];
}

- (NSError *)validateWOHTMLContent:(id)content
{
    return [self validateContent:content
                 withParserClass:NSClassFromString(@"WOHTMLParser")
                        selector:@selector(parseHTMLData:)];
}

- (NSError *)validateWODContent:(id)content
{
    return [self validateContent:content
                 withParserClass:NSClassFromString(@"WODParser")
                        selector:@selector(parseDeclarationData:)];
}

- (NSError *)validateContent:(id)content
             withParserClass:(Class)parserClass
                    selector:(SEL)selector
{
    NSData *data;
    id parser;

    if([content isKindOfClass:[NSString class]])
        data = [content dataUsingEncoding:NSUTF8StringEncoding];
    else
        data = content;
    
    NS_DURING {
      *(&parser) = [[parserClass alloc] initWithHandler:self];
      [parser performSelector:selector withObject:data];
    }
    NS_HANDLER
      [self->errors addObject:[localException reason]];
    NS_ENDHANDLER;
    
    [parser release];
    return [self status];
}


#pragma mark -
#pragma mark ### ACCESSORS ###


- (BOOL)hasWarnings
{
    return [self->warnings count] != 0;
}

- (NSArray *)warnings
{
    return self->warnings;
}

- (BOOL)hasErrors
{
    return [self->errors count] != 0;
}

- (NSArray *)errors
{
    return self->errors;
}

- (NSString *)formattedErrorString
{
    return [[self errors] componentsJoinedByString:@"\n"];
}

- (NSError *)status
{
    NSDictionary *info;

    if([self hasErrors] == NO)
        return nil;

    info = [NSDictionary dictionaryWithObject:[self formattedErrorString] forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:SOPEXDocumentValidationErrorDomain code:0 userInfo:info];
}


#pragma mark -
#pragma mark ### SaxErrorHandler Protocol ###


- (void)warning:(SaxParseException *)_exception
{
    [self->warnings addObject:[_exception reason]];
}

- (void)error:(SaxParseException *)_exception
{
#if 0
    NSLog(@"%s reason:%@ ui:%@ line:%@ column:%@", __PRETTY_FUNCTION__, [_exception reason], [_exception userInfo], [[_exception userInfo] objectForKey:@"line"], [[_exception userInfo] objectForKey:@"column"]);
#endif
    [self->errors addObject:[_exception reason]];
}

- (void)fatalError:(SaxParseException *)_exception
{
    [self error:_exception];
}


#pragma mark -
#pragma mark ### WODParserHandler PROTOCOL ###


- (BOOL)parser:(id)_parser willParseDeclarationData:(NSData *)_data
{
    return YES;
}

- (void)parser:(id)_parser finishedParsingDeclarationData:(NSData *)_data declarations:(NSDictionary *)_decls
{
}

- (void)parser:(id)_parser failedParsingDeclarationData:(NSData *)_data exception:(NSException *)_exception
{
    [_exception raise];
}

- (id)parser:(id)_parser makeAssociationWithValue:(id)_value
{
    return nil;
}

- (id)parser:(id)_parser makeAssociationWithKeyPath:(NSString *)_keyPath
{
    return nil;
}

- (id)parser:(id)_parser makeDefinitionForComponentNamed:(NSString *)_cname associations:(id)_entry elementName:(NSString *)_elemName
{
    return nil;
}


#pragma mark -
#pragma mark ### WOHTMLParserHandler PROTOCOL ###


- (BOOL)parser:(id)_parser willParseHTMLData:(NSData *)_data
{
    return YES;
}

- (void)parser:(id)_parser finishedParsingHTMLData:(NSData *)_data elements:(NSArray *)_elements
{
}

- (void)parser:(id)_parser failedParsingHTMLData:(NSData *)_data exception:(NSException *)_exception
{
#if 0
    NSLog(@"%s reason:%@ ui:%@ line:%@ column:%@", __PRETTY_FUNCTION__, [_exception reason], [_exception userInfo], [[_exception userInfo] objectForKey:@"line"], [[_exception userInfo] objectForKey:@"column"]);
#endif
    [_exception raise];
}

- (WOElement *)dynamicElementWithName:(NSString *)_element attributes:(NSDictionary *)_attributes contentElements:(NSArray *)_subElements
{
    return (WOElement *)[NSNull null];
}


#pragma mark -
#pragma mark ### DEBUGGING ###


- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:0x%x warnings:%d errors:%d>", NSStringFromClass(self->isa), self, [self->warnings count], [self->errors count]];
}

@end
