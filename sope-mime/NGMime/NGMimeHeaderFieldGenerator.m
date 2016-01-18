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

#include "NGMimeHeaderFieldGenerator.h"
#include "NGMimeHeaderFields.h"
#include "common.h"


/*
   text       :=  ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" /
                  "*" / "+" / "-" / "/" / "^" /  "`" / "{" / "|" /
                  "}" / "~"

  tspecials   :=  "(" / ")" / "<" / ">" / "@" / "," / ";" /
                  ":" / "\" / <"> / "/" / "[" / "]" / "?" /
                  "=" / "_"

  rfc822_text := 1*<any (US-ASCII) CHAR except SPACE, CTLs, or tspecials>
*/
static unsigned char rfc822_text[256] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 0-15 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 16-31 */
    0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, /* 32-47 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, /* 48-63 */
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, /* 64-79 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, /* 80-95 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, /* 96-111 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, /* 112-127 */

    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* >= 128 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};


@implementation NGMimeHeaderFieldGenerator

+ (id)headerFieldGenerator {
  return [[[self alloc] init] autorelease];
}

#define MAX_LENGTH_QP_ENCODED 75
#define QP_ENCODE_PREFIX "=?utf-8?q?"
#define QP_ENCODE_SUFFIX "?="
/*
  Encodes a string into q-printable format (RFC-2047):
     * hello world: =?utf-8?q?hello_world?=
     * hëllö: =?utf-8?q?h=C3=ABll=C3=B6=?=
*/
+ (NSString *)encodeQuotedPrintableWord:(NSString *)word
{
  NSString *prefix = @QP_ENCODE_PREFIX;
  NSString *suffix = @QP_ENCODE_SUFFIX;

  NSUInteger max_length = 3 * [word lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  unsigned char *qencoded = calloc(max_length + 1, sizeof(char));
  if (!qencoded) return nil;

  NSData *word_data = [word dataUsingEncoding: NSUTF8StringEncoding];
  int ret = NGEncodeQuotedPrintableMime ([word_data bytes], [word_data length],
                                         qencoded, max_length);
  if (ret == -1) {
    free(qencoded);
    return nil;
  }

  NSString *result = [NSString stringWithFormat:@"%@%s%@", prefix, qencoded, suffix];
  free(qencoded);

  return result;
}

/*
  According to RFC 2047 an encoded word may not be more than 75 characters
  long, this method split the given string into several chunks that won't be
  longer than 75 characters long after being qp encoded
*/
static NSArray *splitWordIfQPEncodingTooBig(NSString *s)
{
  NSUInteger max_length = MAX_LENGTH_QP_ENCODED - strlen(QP_ENCODE_PREFIX)
                          - strlen(QP_ENCODE_SUFFIX);
  // First, quick way for short words (most of the times)
  if (3 * [s lengthOfBytesUsingEncoding: NSUTF8StringEncoding] < max_length)
    return [NSArray arrayWithObjects: s, nil];

  NSData *data = [s dataUsingEncoding: NSUTF8StringEncoding];
  NSUInteger size = [data length];
  const unsigned char *bytes = [data bytes];
  NSMutableArray *chunks = [NSMutableArray array];
  NSUInteger i, chunk_size = 0, chunk_start = 0;
  for (i = 0; i < size; i++) {
    if (!rfc822_text[bytes[i]])
      chunk_size += 3;
    else
      chunk_size++;
    if (chunk_size > max_length) {
      // This part is tricky because utf8 characters can have 1..4 bytes to
      // encode the full character
      NSData *subdata = [data subdataWithRange: NSMakeRange(chunk_start, i-1-chunk_start)];
      NSString *chunk_string = [[NSString alloc] initWithBytes: [subdata bytes]
                                                        length: [subdata length]
                                                      encoding: NSUTF8StringEncoding];
      if (chunk_string) {
        // Ok, we made the chunk just at the end of a full character
        chunk_start = i-1;
      } else {
        // Let's make the chunk shorted until we can create an ok utf8 string
        // This means we have a partial codepoint not forming a full character
        NSUInteger backtrack;
        for (backtrack = 1; !chunk_string && backtrack <= 3; backtrack++) {
          subdata = [data subdataWithRange: NSMakeRange(chunk_start, i-1-chunk_start-backtrack)];
          chunk_string = [[NSString alloc] initWithBytes: [subdata bytes]
                                                  length: [subdata length]
                                                encoding: NSUTF8StringEncoding];
        }
        chunk_start = i-1-backtrack;
      }
      [chunk_string autorelease];
      [chunks addObject: chunk_string];
      chunk_size = 0;
    }
  }

  // The last chunk should be ok, because we are ending the string so no
  // partial codepoints at the end of the chunk
  NSData *subdata = [data subdataWithRange: NSMakeRange(chunk_start, size-chunk_start)];
  NSString *chunk_string = [[NSString alloc] initWithBytes: [subdata bytes]
                                                    length: [subdata length]
                                                  encoding: NSUTF8StringEncoding];
  [chunk_string autorelease];
  [chunks addObject: chunk_string];

  return chunks;
}

/*
  Encodes given string into q-printable format  (RFC-2047). It takes
  into account that text could be a long string and adds CRLF SPACE
  to split into lines no longer than 75 characters long.
*/
+ (NSString *)encodeQuotedPrintableText:(NSString *)input
{
  NSArray *words = [input componentsSeparatedByString: @" "];
  NSMutableString *text = [@"" mutableCopy], *line = [@"" mutableCopy];
  BOOL encodedLastWord = NO, needsEncode = NO;
  NSUInteger spaces = 0;

  for (NSString *word in words) {
    // Count number of spaces from the previous encoded word
    if ([line length] > 0 || [word length] == 0) spaces++;
    // If word is empty means we had a space (which we've already counted it)
    if ([word length] == 0) continue;

    NSData *data = [word dataUsingEncoding: NSUTF8StringEncoding];
    needsEncode = NGEncodeQuotedPrintableMimeNeeded ([data bytes], [data length]);

    NSArray *parts = splitWordIfQPEncodingTooBig (word);
    for (NSString *part in parts) {
      NSString *encoded = part;
      if (needsEncode) {
        NSMutableString *toEncode = [part mutableCopy];
        if (encodedLastWord) {
          // Add spaces between words. As both words are encoded we need to
          // also encode those spaces, because whitespace between encoded words
          // will be ignored for decoders
          NSUInteger n;
          for (n = 0; n < spaces; n++)
            [toEncode insertString: @" " atIndex: 0];
          spaces = 0;
        }
        encoded = [[self class] encodeQuotedPrintableWord: toEncode];
      }
      // Insert pending spaces from last word. Normally it will be 1 or
      // 0 in case needsEncode && encodedLastWord (becase the spaces are
      // already in `encoded` string)
      NSUInteger n;
      for (n = 0; n < spaces; n++)
        [line appendString: @" "];
      spaces = 0;

      if ([line length] + [encoded length] <= MAX_LENGTH_QP_ENCODED) {
        [line appendString: encoded];
      } else {
        if ([text length] > 0)
          [text appendString: @"\n "];
        [text appendString: line];
        line = [NSMutableString stringWithString: encoded];
      }
    }

    encodedLastWord = needsEncode;
  }
  // Add last line to result. Add \n and spaces if needed
  if ([text length] > 0)
    [text appendString: @"\n "];
  NSUInteger n;
  for (n = 0; n < spaces; n++)
    [line appendString: @" "];
  [text appendString: line];

  return text;
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end /* NGMimeHeaderFieldGenerator */

BOOL NGEncodeQuotedPrintableMimeNeeded(const unsigned char *src, unsigned srcLen)
{
  unsigned i = 0;

  for (i = 0; i < srcLen; i++) {
    if (src[i] != ' ' && !rfc822_text[src[i]]) {
      return YES;
    }
  }

  return NO;
}

int NGEncodeQuotedPrintableMime(const unsigned char *src, unsigned srcLen,
                                unsigned char *dest, unsigned destLen)
{
  unsigned cnt = 0;
  unsigned destCnt = 0;
  unsigned char hexT[16] = {'0', '1', '2', '3', '4', '5', '6', '7',
                            '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

  if (srcLen > destLen)
    return -1;

  for (cnt = 0; cnt < srcLen && destCnt < destLen; cnt++) {
    register unsigned char c = src[cnt];

    if (rfc822_text[c] == 1) {
      // no quoting
      dest[destCnt++] = c;
    } else if (c == ' ') {
      // Special case ' ' => '_'
      dest[destCnt++] = '_';
    } else {
      // need to be quoted
      if (destLen - destCnt <= 2)
        break;

      dest[destCnt++] = '=';
      dest[destCnt++] = hexT[(c >> 4) & 15];
      dest[destCnt++] = hexT[c & 15];
    }
  }

  if (cnt < srcLen)
    return -1;

  return destCnt;
}
