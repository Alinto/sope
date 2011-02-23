/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "NGSendMail.h"
#include "NGMimeMessageGenerator.h"
#include "NGMailAddressParser.h"
#include "NGMailAddress.h"
#include "common.h"

// TODO: this class is derived from the LSMailDeliverCommand in OGo Logic,
//       it still needs a lot of cleanup

@implementation NGSendMail

+ (id)sharedSendMail {
  static NGSendMail *sendmail = nil; // THREAD
  if (sendmail == nil)
    sendmail = [[self alloc] init];
  return sendmail;
}

- (id)initWithExecutablePath:(NSString *)_path {
  if ((self = [super init])) {
    NSUserDefaults *ud;
    
    ud = [NSUserDefaults standardUserDefaults];
    
    self->isLoggingEnabled = 
      [ud boolForKey:@"ImapDebugEnabled"];
    self->shouldOnlyUseMailboxName =
      [ud boolForKey:@"UseOnlyMailboxNameForSendmail"];
    
    if ([_path isNotNull])
      self->executablePath = [_path copy];
    else {
#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
      self->executablePath = @"/usr/sbin/sendmail";
#else
      self->executablePath = @"/usr/lib/sendmail";
#endif
    }
  }
  return self;
}
- (id)init {
  NSString *p;
  
  p = [[NSUserDefaults standardUserDefaults] stringForKey:@"SendmailPath"];
  return [self initWithExecutablePath:p];
}

- (void)dealloc {
  [self->executablePath release];
  [super dealloc];
}

/* accessors */

- (NSString *)executablePath {
  return self->executablePath;
}

- (BOOL)isSendLoggingEnabled {
  return self->isLoggingEnabled;
}
- (BOOL)shouldOnlyUseMailboxName {
  return self->shouldOnlyUseMailboxName;
}

/* operations */

- (BOOL)isSendMailAvailable {
  NSFileManager *fm;
  
  fm = [NSFileManager defaultManager];
  return [fm isExecutableFileAtPath:[self executablePath]];
}

/* errors */

- (NSException *)missingMailToSendError {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:@"missing mail content to send"
		      userInfo:nil];
}
- (NSException *)cannotWriteTemporaryFileError {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:@"failed to write temporary mail file"
		      userInfo:nil];
}
- (NSException *)failedToStartSendMailError:(int)_errorCode {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:@"failed to start sendmail tool"
		      userInfo:nil];
}
- (NSException *)failedToSendFileToSendMail:(NSString *)_path {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:@"failed to send message file to sendmail tool"
		      userInfo:nil];
}
- (NSException *)failedToSendDataToSendMail:(NSData *)_data {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:@"failed to send message data to sendmail tool"
		      userInfo:nil];
}

- (NSException *)_errorExceptionWithReason:(NSString *)_reason {
  return [NSException exceptionWithName:@"NGSendMailException"
		      reason:_reason
		      userInfo:nil];
#if 0 // TODO: in LSMailDeliverCommand, check whether someone depends on it
  return [LSDBObjectCommandException exceptionWithStatus:NO
				     object:self
				     reason:_reason userInfo:nil];
#endif
}

- (NSException *)_handleSendMailErrorCode:(int)_ec sendmail:(NSString *)_cmdl {
  if (_ec == 32512) {
    NSString *str;
    
    str = [@"NoExecutableSendmailBinary " stringByAppendingString:
	      [self executablePath]];
    [self logWithFormat:@"%@ is no executable file", [self executablePath]];
    return [self _errorExceptionWithReason:str];
  }
  if (_ec == 17664) {
    [self logWithFormat:@"sendmail: message file too big!"];
    return [self _errorExceptionWithReason:@"MessageFileTooBig"];
  }
  
  [self logWithFormat:@"[1] Could not write mail to sendmail! <%d>",_ec];
  return [self _errorExceptionWithReason:@"FailedToSendMail"];
}

/* temporary file */

- (void)_removeMailTmpFile:(NSString *)_path {
  if ([_path length] < 2)
    return;
  
  [[NSFileManager defaultManager] removeFileAtPath:_path handler:nil];
}

- (NSString *)_generateTemporaryFileForPart:(id<NGMimePart>)_part {
  NGMimeMessageGenerator *gen;
  NSString *p;
  
  gen = [[NGMimeMessageGenerator alloc] init];
  p = [[gen generateMimeFromPartToFile:_part] copy];
  [gen release]; gen = nil;

  return [p autorelease];
}

/* parsing mail addresses */

- (NSString *)mailAddrForStr:(NSString *)_str {
  NGMailAddressParser *parser;
  NGMailAddress       *addr;
  
  if (![self shouldOnlyUseMailboxName])
    return _str;
  
  parser = nil;
  addr   = nil;
  
  // TODO: make NGMailAddressParser not throw exceptions,
  //       then remove the handler
  NS_DURING {
    parser = [NGMailAddressParser mailAddressParserWithString:_str];
    addr   = [[parser parseAddressList] lastObject];
  }
  NS_HANDLER {
    fprintf(stderr,"ERROR: get exception during parsing address %s\n",
            [[localException description] cString]);
    parser = nil;
    addr   = nil;
  }
  NS_ENDHANDLER;

  return (addr) ? [addr address] : _str;
}

/* logging */

- (void)_logMailSend:(NSString *)sendmail ofPath:(NSString *)_p {
  fprintf(stderr, "%s \n", [sendmail cString]);
  fprintf(stderr, "read data from %s\n", [_p cString]);
}

- (void)_logMailSend:(NSString *)sendmail ofData:(NSData *)_data {
  fprintf(stderr, "%s \n", [sendmail cString]);
  
  if ([_data length] > 5000) {
    NSData *data;
    
    data = [_data subdataWithRange:NSMakeRange(0,5000)];
    fprintf(stderr, "%s...\n", (unsigned char *)[data bytes]);
  }
  else
    fprintf(stderr, "%s\n", (char *)[_data bytes]);
}

/* sending the mail */

- (FILE *)openStreamToSendMail:(NSString *)_cmdline {
  return [_cmdline isNotNull] ? popen([_cmdline cString], "w") : NULL;
}
- (int)closeStreamToSendMail:(FILE *)_mail {
  if (_mail == NULL) 
    return 0;
  return pclose(_mail);
}

- (NSMutableString *)buildSendMailCommandLineWithSender:(NSString *)_sender {
  NSMutableString *sendmail;
  
  if (![[self executablePath] isNotEmpty])
    return nil;
  
  sendmail = [NSMutableString stringWithCapacity:256];
  [sendmail setString:[self executablePath]];
  
  /* don't treat a line with just "." as EOF */
  [sendmail appendString:@" -i "];
  
  /* add sender when available */
  if (_sender != nil) {
    NSString *f;
    
    f = [[_sender componentsSeparatedByString:@","]
	          componentsJoinedByString:@" "];
    [sendmail appendString:@"-f "];
    [sendmail appendString:f];
    [sendmail appendString:@" "];
  }
  return sendmail;
}

- (NSException *)_handleAppendMessageException:(NSException *)_exception {
  [self logWithFormat:@"catched exception: %@", _exception];
  return nil;
}

- (BOOL)_appendMessageFile:(NSString *)_p to:(FILE *)_fd {
  NGFileStream *fs;
  int  fileLen;
  BOOL result;

  if (_p == nil) {
    NSLog(@"ERROR: call %s without self->messageTmpFile",
          __PRETTY_FUNCTION__);
    return NO;
  }
  fileLen = [[[[NSFileManager defaultManager]
                              fileAttributesAtPath:_p
                              traverseLink:NO]
                              objectForKey:NSFileSize] intValue];
  
  if (fileLen == 0) {
    NSLog(@"ERROR[%s] missing file at path %@", __PRETTY_FUNCTION__,
          _p);
    return NO;
  }
  
  fs = [(NGFileStream *)[NGFileStream alloc] initWithPath:_p];

  if (![fs openInMode:@"r"]) {
    NSLog(@"ERROR[%s]: could not open file stream for temp-file for "
          @"reading: %@", __PRETTY_FUNCTION__, _p);
    [fs release]; fs = nil;
    return NO;
  }
  
  result = YES;
  NS_DURING {
    int  read;
    int  alreadyRead;
    int  bufCnt = 8192;
    char buffer[bufCnt+1];

    alreadyRead = 0;
    
    read = (bufCnt > (fileLen - alreadyRead))
           ? fileLen - alreadyRead : bufCnt;
    
    while ((read = [fs readBytes:buffer count:read]) != 0) {
      int rc;
      
      alreadyRead += read;
      
      rc = fwrite(buffer, read, 1, _fd);
      if (rc == 0) {
          fprintf(stderr, "%s: Failed to write %i bytes to process\n",
                  __PRETTY_FUNCTION__, alreadyRead);
          break;
      }
      if (alreadyRead == fileLen)
	break;
    }
  }
  NS_HANDLER {
    [[self _handleAppendMessageException:localException] raise];
    result = NO;
  }
  NS_ENDHANDLER;
  
  [fs release]; fs = nil;
  return result;
}

- (BOOL)_appendData:(NSData *)_data to:(FILE *)_fd {
  int written;
  
  if (![_data isNotEmpty])
    return YES;
  
  written = fwrite((char *)[_data bytes], [_data length],
		   1, _fd);
  if (written > 0) {
    [self logWithFormat:@"wrote %d, length %d", written, [_data length]];
    return YES;
  }
  
  [self logWithFormat:@"[2] Could not write mail to sendmail <%d>", errno];
  
  if ([_data length] > 5000)
    [self logWithFormat:@"[2] message: [size: %d]", [_data length]];
  else
    [self logWithFormat:@"[2] message: <%s>", (char *)[_data bytes]];
  
  return NO;
}

- (void)addRecipients:(NSArray *)_recipients 
  toCmdLine:(NSMutableString *)_cmdline
{
  NSEnumerator *enumerator;
  NSString     *str;
  
  enumerator = [_recipients objectEnumerator];
  while ((str = [enumerator nextObject]) != nil) {
    NSEnumerator *e;
    NSString     *s;
    
    if ([str rangeOfString:@","].length == 0) {
      [_cmdline appendFormat:@"'%@' ", [self mailAddrForStr:str]];
      continue;
    }
    
    e = [[str componentsSeparatedByString:@","] objectEnumerator];
    while ((s = [e nextObject])) {
      s = [[s componentsSeparatedByString:@"'"] componentsJoinedByString:@""];
      s = [[s componentsSeparatedByString:@","] componentsJoinedByString:@""];
      
      [_cmdline appendFormat:@"'%@'", [self mailAddrForStr:s]];
    }
    [_cmdline appendString:@" "];
  }
}

/* main entry methods */

- (NSException *)sendMailAtPath:(NSString *)_path toRecipients:(NSArray *)_to
  sender:(NSString *)_sender
{
  NSMutableString *sendmail;
  FILE            *toMail       = NULL;
  NSException     *error;
  int  errorCode;
  BOOL ok;
  
  if (_path == nil)
    return [self missingMailToSendError];
  
  sendmail = [self buildSendMailCommandLineWithSender:_sender];
  [self addRecipients:_to toCmdLine:sendmail];
  
  if ((toMail = [self openStreamToSendMail:sendmail]) == NULL)
    return [self failedToStartSendMailError:errno];
  
  if ([self isSendLoggingEnabled]) [self _logMailSend:sendmail ofPath:_path];
  
  ok = [self _appendMessageFile:_path to:toMail];
  
  error = nil;
  if ((errorCode = [self closeStreamToSendMail:toMail]) != 0) {
    if (ok) {
      error = [self _handleSendMailErrorCode:errorCode sendmail:sendmail];
    }
  }
  if (!ok) error = [self failedToSendFileToSendMail:_path];
  return error; /* nil means 'everything is awesome' */
}

- (NSException *)sendMailData:(NSData *)_data toRecipients:(NSArray *)_to
  sender:(NSString *)_sender
{
  NSMutableData *cleaned_data;
  NSMutableString *sendmail;
  FILE            *toMail       = NULL;
  NSException     *error;
  int  errorCode, len, mlen, i;
  const char *bytes;
  char *mbytes;
  BOOL ok;
  
  if (_data == nil)
    return [self missingMailToSendError];
  
  sendmail = [self buildSendMailCommandLineWithSender:_sender];
  [self addRecipients:_to toCmdLine:sendmail];
  
  if ((toMail = [self openStreamToSendMail:sendmail]) == NULL)
    return [self failedToStartSendMailError:errno];
  
  if ([self isSendLoggingEnabled]) [self _logMailSend:sendmail ofData:_data];
  
  //
  // SOPE sucks in many ways and that is one of them. The headers are actually
  // correctly encoded (trailing \r\n is inserted) but not the base64 encoded
  // data since it uses SOPE's dataByEncodingBase64 function which says:
  //
  // NGBase64Coding.h:- (NSData *)dataByEncodingBase64; /* Note: inserts '\n' every 72 chars */
  //
  len = [_data length];
  i = mlen = 0;
  
  cleaned_data = [NSMutableData dataWithLength: len];
  
  bytes = [_data bytes];
  mbytes = [cleaned_data mutableBytes];
  
  while (i < len)
    {
      if (*bytes == '\r' && (i+1 < len) && *(bytes+1) == '\n')
	{
	  bytes++;
	  i++;
	}
  
      *mbytes = *bytes;
      mbytes++; bytes++;
      i++;
      mlen++;
    }
  
  [cleaned_data setLength: mlen];
 
  ok = [self _appendData:cleaned_data to:toMail];
  
  error = nil;
  if ((errorCode = [self closeStreamToSendMail:toMail]) != 0) {
    if (ok) {
      error = [self _handleSendMailErrorCode:errorCode sendmail:sendmail];
    }
  }
  if (!ok) error = [self failedToSendDataToSendMail:_data];
  return error; /* nil means 'everything is awesome' */
}

- (NSException *)sendMimePart:(id<NGMimePart>)_pt toRecipients:(NSArray *)_to
  sender:(NSString *)_sender
{
  NSException *error;
  NSString *tmpfile;
  
  if (_pt == nil)
    return [self missingMailToSendError];

  /* generate file for part */
  
  if ((tmpfile = [self _generateTemporaryFileForPart:_pt]) == nil)
    return [self cannotWriteTemporaryFileError];

  /* send file */
  
  error = [self sendMailAtPath:tmpfile toRecipients:_to sender:_sender];
  
  /* delete temporary file */
  
  [self _removeMailTmpFile:tmpfile];
  
  return error;
}

@end /* NGSendMail */
