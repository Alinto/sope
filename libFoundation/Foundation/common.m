/* 
   common.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Florin Mihaila <phil@pathcom.com>
	   Bogdan Baliuc <stark@protv.ro>

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSException.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPathUtilities.h>

#include "PrivateThreadData.h"
#include "NSCalendarDateScanf.h"

#include <Foundation/exceptions/GeneralExceptions.h>
#include <extensions/PrintfFormatScanner.h>
#include <extensions/PrintfScannerHandler.h>

#include "config.h"

#if HAVE_WINDOWS_H
#  include <windows.h>
#endif

#ifndef O_BINARY
#  if HAVE_WINDOWS_H
#    warning defined O_BINARY
#  endif
#  define O_BINARY 0
#endif

#include <errno.h>

/* Windows Support */

#if defined(__MINGW32__)

NSString *NSWindowsWideStringToString(LPWSTR _wstr)
{
  unsigned char cstr[256];
  int           result;

  result = WideCharToMultiByte(CP_ACP,
                               0,
                               _wstr,        /* the wide string */
                               -1,           /* determine length of _wstr */
                               cstr,         /* destination */
                               sizeof(cstr), /* buffer size */
                               NULL, /* insert char if char could not be conv */
                               NULL  /* pointer to flag: couldNotBeConverted */);
  return [NSString stringWithCString:cstr];
}

LPWSTR NSStringToWindowsWideString(NSString *_str)
{
  LPWSTR wstr    = NULL;
  int    wstrlen = 0;
  int    result  = 0;
  LPCSTR cstr;
  int    cstrlen = [_str cStringLength];

  cstr = malloc(cstrlen + 1);
  [_str getCString:cstr]; cstr[cstrlen] = '\0';
  
  // first determine required buffer size
  wstrlen = MultiByteToWideChar(CP_ACP,      /* ANSI Code Conversion */
                                0,           /* conversion flags     */
                                cstr,        /* ANSI string          */
                                cstrlen + 1, /* ANSI string length + zero byte */
                                wstr,        /* destination          */
                                0);          /* Shall determine required size */

  // allocate buffer
  wstr = NSZoneMalloc(NULL, sizeof(WCHAR) * (wstrlen + 1));
  
  result = MultiByteToWideChar(CP_ACP,      /* ANSI Code Conversion */
                               0,           /* conversion flags     */
                               cstr,        /* ANSI string          */
                               cstrlen + 1, /* ANSI string length + zero byte */
                               wstr,        /* destination          */
                               wstrlen);    /* destination buffer size */
  free(cstr);
#if !LIB_FOUNDATION_BOEHM_GC
  [NSAutoreleasedPointer autoreleasePointer:wstr];
#endif
  return wstr;
}

#endif

/* File reading */

void *NSReadContentsOfFile(NSString *_path, unsigned _extraCapacity,
                           unsigned *len)
{
    unsigned char *bytes = NULL;
#if defined(__MINGW32__)
    HANDLE fh;
    DWORD  sizeLow, sizeHigh;
    DWORD  got;

    if (len) *len = 0;
    
    fh = CreateFile([_path fileSystemRepresentation],
                    GENERIC_READ,          /* assume read access  */
                    FILE_SHARE_READ,       /* multiple read lock  */
                    NULL,                  /* security attributes */
                    OPEN_EXISTING,         /* fail if file does not exist */
                    FILE_ATTRIBUTE_NORMAL, /* access normal file  */
                    NULL);                 /* template file (not used)    */
    if (fh == INVALID_HANDLE_VALUE)
        // could not open file
        return NULL;

    sizeLow = GetFileSize(fh, &sizeHigh);
    if ((sizeLow == 0xFFFFFFFF) && (GetLastError() != NO_ERROR)) {
        // could not stat file
        CloseHandle(fh);
        return NULL;
    }
    NSCAssert(sizeHigh == 0, @"cannot handle 64bit filesizes yet");

    bytes = NSZoneMallocAtomic(NULL, sizeLow + _extraCapacity);
    if (!ReadFile(fh, bytes, sizeLow, &got, NULL)) {
        if (bytes) {
            lfFree(bytes);
            bytes = NULL;
        }
    }
    CloseHandle(fh);

    if (len) *len = bytes ? sizeLow : 0;
#else /* !mingw32 */
    int         fd;
    struct stat fstat_buf;
    int         got;
    unsigned    plen;
    char        *path;
    
    if (len) *len = 0;
    plen = [_path cStringLength];
    path = malloc(plen + 1);
    [_path getCString:path]; path[plen] = '\0';
    
    if ((fd = open(path, O_RDONLY|O_BINARY, 0)) == -1) {
	//fprintf(stderr, "couldn't open file '%s'\n", path ? path : "<NULL>");
        if (path) free(path);
        return NULL;
    }
    
    if (path) free(path);
    
    if (fstat(fd, &fstat_buf) == -1) {
	// NSLog(@"couldn't stat fd %i file '%@'", fd, _path ? _path : nil);
        close(fd);
	return NULL;
    }

    bytes = NSZoneMallocAtomic(NULL, fstat_buf.st_size + _extraCapacity);
    if (bytes) {
	if ((got = read(fd, bytes, fstat_buf.st_size)) != fstat_buf.st_size) {
	    if (bytes) {
		lfFree(bytes);
		bytes = NULL;
	    }
	}
    }
    close(fd);
    
    if (len) *len = bytes ? fstat_buf.st_size : 0;
#endif
    return bytes;
}

/* Non OpenStep useful things */

void vaRelease(id obj, ...)
{
    va_list args;
    id next_obj;
	
    va_start(args, obj);
    next_obj = obj;
    while (next_obj) {
	RELEASE(next_obj);
	next_obj = va_arg(args, id);
    }
    va_end(args);
}

BOOL writeToFile(NSString *path, NSData *data, BOOL atomically)
{
    const void    *bytes    = [data bytes];
    int           len       = [data length];
    volatile BOOL result    = YES;
    NSString      *filename = nil;
    
#if defined(__MINGW32__)
    HANDLE fh;
    DWORD  wroteBytes;

    filename = atomically ? [path stringByAppendingString:@".tmp"] : path;
    
    fh = CreateFile([filename fileSystemRepresentation],
                    GENERIC_WRITE,         /* assume write access  */
                    0,                     /* exclusive lock       */
                    NULL,                  /* security attributes  */
                    CREATE_ALWAYS,         /* create a new file    */
                    FILE_ATTRIBUTE_NORMAL, /* access normal file   */
                    NULL);                 /* template file (not used) */
    if (fh == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Could not create file for writing %s: %s\n",
                [filename fileSystemRepresentation], strerror(errno));
        return NO;
    }

    if (!WriteFile(fh, bytes, len, &wroteBytes, NULL)) {
        fprintf(stderr,
		"Failed to write %i bytes to %s, only wrote %li bytes\n",
                len, [filename fileSystemRepresentation], wroteBytes);
        CloseHandle(fh);
        return NO;
    }
    CloseHandle(fh);
#else
    int fd;
    
    filename = atomically ? [path stringByAppendingString:@"~"] : path;
    
    fd = open([filename fileSystemRepresentation],
              O_WRONLY | O_CREAT | O_TRUNC | O_BINARY, 0666);
    if (fd == -1) {
        fprintf(stderr, "Could not open file for writing %s: %s\n",
                [filename fileSystemRepresentation], strerror(errno));
        return NO;
    }

    if (write(fd, bytes, len) != len) {
        fprintf(stderr, "Failed to write %i bytes to %s: %s\n",
                len, [filename fileSystemRepresentation], strerror(errno));
        close(fd);
        return NO;
    }
    close(fd);
#endif
        
    if (atomically) {
        NSFileManager *fileManager = nil;
        
	fileManager = [NSFileManager defaultManager];

        NS_DURING {
            [fileManager removeFileAtPath:path handler:nil];
            result = [fileManager movePath:filename toPath:path handler:nil];
        }
        NS_HANDLER {
            fprintf(stderr, "Could not move file %s to file %s\n",
                    [filename fileSystemRepresentation],
                    [path fileSystemRepresentation]);
            result = NO;
        }
        NS_ENDHANDLER;
    }
    return result;
}

char *Ltoa(long nr, char *str, int base)
{
    char buff[34], rest, is_negative;
    int ptr;

    ptr = 32;
    buff[33] = '\0';
    if(nr < 0) {
	is_negative = 1;
	nr = -nr;
    }
    else
	is_negative = 0;

    while(nr != 0) {
	rest = nr % base;
	if(rest > 9)
	    rest += 'A' - 10;
	else
	    rest += '0';
	buff[ptr--] = rest;
	nr /= base;
    }
    if(ptr == 32)
	buff[ptr--] = '0';
    if(is_negative)
	buff[ptr--] = '-';

    Strcpy(str, &buff[ptr+1]);

    return(str);
}

unsigned hashjb(const char* name, int len)
{
  register unsigned long hash = 0, i = 0;
  register unsigned char ch;

  for (; (ch = *name++); i ^= 1) {
    if (i)
      hash *= ch;
    else
      hash += ch;
  }
  hash += ((hash & 0xffff0000) >> 16);
  hash += ((hash & 0x0000ff00) >> 8);
  return hash & (len - 1);
}

NSString* Asprintf(NSString* format, ...)
{
    id string;
    va_list ap;

    va_start(ap, format);
    string = Avsprintf(format, ap);
    va_end(ap);
    return string;
}

NSString* Avsprintf(NSString* format, va_list args)
{
    // THREADING
    static id ofmt = nil;
    id objectFormat, formatScanner, string;

    if (ofmt) {
        objectFormat = ofmt;
        ofmt = nil;
    }
    else
        objectFormat = [[FSObjectFormat alloc] init];
    
    formatScanner = [[PrintfFormatScanner alloc] init];

    [formatScanner setFormatScannerHandler:objectFormat];
    string = [formatScanner stringWithFormat:format arguments:args];

    if (ofmt == nil) ofmt = objectFormat;
    else RELEASE(objectFormat);
    RELEASE(formatScanner);

    return string;
}

/* Moved the THROW here from common.h to avoid recursion in the definition of
   memoryExhaustedException. */
void __raiseMemoryException (void* pointer, int size)
{
    [[memoryExhaustedException setPointer:&pointer memorySize:size] raise];
}


/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
