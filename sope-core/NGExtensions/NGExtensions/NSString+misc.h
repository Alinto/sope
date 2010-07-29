/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGExtensions_NSString_misc_H__
#define __NGExtensions_NSString_misc_H__

#import <Foundation/NSString.h>

@class NSSet, NSDictionary, NSString;

@interface NSObject(StringBindings)
- (NSString *)valueForStringBinding:(NSString *)_key;
@end

@interface NSString(misc)

/*
  Replaces keys, which enclosed in '$', with values from _bindings. The values
  are retrieved using the '-valueForStringBinding:' method which per default
  use -valueForKey: and -objectForKey: for NSDictionary objects.
  For using of $ escape it with $$.
  
  Example:
    source: @"du da blah $var$ doof"

    dest = [source stringByReplacingVariablesWithBindings:
                     @{ var = @"dummy"; }];
    =>
    dest:   @"du da blah dummy doof"
*/
- (NSString *)stringByReplacingVariablesWithBindings:(id)_bindings;

/*
  If there are variables with no binding, _unkown is used instead.
  If _unkown is nil and there are unknown bindings, an exception will be thrown.
*/
- (NSString *)stringByReplacingVariablesWithBindings:(id)_bindings
  stringForUnknownBindings:(NSString *)_unknown;

/*
  Returns all binding variables. ('aaa $doof$ $bla$' --> (doof, bla) )
*/
- (NSSet *)bindingVariables;

@end

@interface NSString(FilePathVersioningMethods)

/*
  "/PATH/file.txt;1"
*/

- (NSString *)pathVersion;
- (NSString *)stringByDeletingPathVersion;
- (NSString *)stringByAppendingPathVersion:(NSString *)_version;

@end /* NSString(FilePathMethodsVersioning) */

@interface NSString(URLEscaping)

/*
  These functions encode/decode HTTP style URL paths, which can escape
  spaces and special chars.
  Chars are escaped using the '%' hex-notation:

  Encode:
      'Hello World' => 'Hello%20World'
      '& ?' => '%26%20%3F'
*/

- (BOOL)containsURLEscapeCharacters;
- (NSString *)stringByUnescapingURL;
- (NSString *)stringByEscapingURL;

@end

@interface NSString(HTMLEscaping)
- (NSString *)stringByEscapingHTMLString;
- (NSString *)stringByEscapingHTMLAttributeValue;
@end

@interface NSString(XMLEscaping)

- (NSString *)stringByEscapingXMLString;
- (NSString *)stringByEscapingXMLAttributeValue;

/*
  The following methods work in "fully-qualified XML names", in this
  format:
    '{namespace}name'
*/
- (BOOL)xmlIsFQN;
- (NSString *)xmlNamespaceURI;
- (NSString *)xmlLocalName;

@end

@interface NSString(NGScanning)

/* 
   this methods search for a string, while skipping quotes, eg:
   
     [@"abc '++' hello" rangeOfString:@"++" skipQuotes:@"\"'"];
   
   would not return a result !
*/
- (NSRange)rangeOfString:(NSString *)_s 
  skipQuotes:(NSString *)_quotes
  escapedByChar:(unichar)_escape;
- (NSRange)rangeOfString:(NSString *)_s skipQuotes:(NSString *)_quotes;

@end

@interface NSString(MailQuoting)

- (NSString *)stringByApplyingMailQuoting;

@end

#endif /* __NGExtensions_NSString_misc_H__ */
