// $Id: ApacheResourcePool.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheResourcePool.h"
#include "httpd.h"
#include "ap_alloc.h"
#include <Foundation/Foundation.h>

@implementation ApacheResourcePool

- (void)destroyHandle {
  if (self->handle) {
    ap_destroy_pool(self->handle);
    self->handle = NULL;
  }
}
- (id)makeSubPool {
  ap_pool *p;

  if (self->handle == NULL)
    return nil;
  
  if ((p = ap_make_sub_pool(self->handle)) == NULL)
    return nil;
  
  return [[[ApacheResourcePool alloc]
                               initWithHandle:p freeWhenDone:YES]
                               autorelease];
}
- (void)clearPool {
  if (self->handle) ap_clear_pool(self->handle);
}

- (BOOL)isAncestorOf:(ApacheResourcePool *)_pool {
#ifdef POOL_DEBUG
  if (_pool      == NULL) return NO;
  if (self->handle == NULL) return NO;

  return ap_pool_is_ancestor(self->handle, _pool) ? YES : NO;
#else
  return NO;
#endif
}

/* stats */

- (unsigned int)bytesInPool {
  if (self->handle == NULL) return 0;
  return ap_bytes_in_pool(self->handle);
}
+ (unsigned int)bytesInFreeBlocks {
  return ap_bytes_in_free_blocks();
}

/* memory blocks */

- (void *)malloc:(unsigned)size {
  if (self->handle == NULL) return NULL;
  return ap_palloc(self->handle, size);
}
- (void *)mallocAtomic:(unsigned)size {
  if (self->handle == NULL) return NULL;
  return ap_palloc(self->handle, size);
}
- (void *)calloc:(unsigned)numElems byteSize:(unsigned)byteSize {
  if (self->handle == NULL) return NULL;
  return ap_pcalloc(self->handle, byteSize * numElems);
}
- (void *)callocAtomic:(unsigned)numElems byteSize:(unsigned)byteSize {
  if (self->handle == NULL) return NULL;
  return ap_pcalloc(self->handle, byteSize * numElems);
}

- (void *)realloc:(void*)pointer size:(unsigned)size {
  return NULL;
}
- (void)freePointer:(void *)pointer {
}

/* string allocations */

- (unsigned char *)strdup:(const unsigned char *)_cstr {
  if (self->handle == NULL) return NULL;
  return ap_pstrdup(self->handle, _cstr);
}
- (unsigned char *)strdup:(const unsigned char *)_cstr length:(unsigned)_l {
  if (self->handle == NULL) return NULL;
  return ap_pstrndup(self->handle, _cstr, _l);
}
- (unsigned char *)strcat:(const unsigned char *)_cstr {
  if (self->handle == NULL) return NULL;
  return ap_pstrcat(self->handle, _cstr, NULL);
}
- (unsigned char *)pvsprintf:(const unsigned char *)_fmt arguments:(va_list)va{
  if (self->handle == NULL) return NULL;
  return ap_pvsprintf(self->handle, _fmt, va);
}

/* file allocations */

- (FILE *)openFile:(NSString *)_name mode:(NSString *)_mode {
  return ap_pfopen(self->handle, [_name cString], [_mode cString]);
}
- (FILE *)openFD:(int)_fd mode:(NSString *)_mode {
  return ap_pfdopen(self->handle, _fd, [_mode cString]);
}
- (int)popenf:(NSString *)_name flag:(int)_flg mode:(int)_mode {
  return ap_popenf(self->handle, [_name cString], _flg, _mode);
}

- (void)closeFile:(FILE *)_file {
  ap_pfclose(self->handle, _file);
}
- (void)pclosef:(int)_fd {
  ap_pclosef(self->handle, _fd);
}
#ifdef WIN32
- (void)closeHandle:(HANDLE)_h {
  ap_pcloseh(self->handle, _h);
}
#endif

- (void)noteCleanUpsForFile:(FILE *)_file {
  ap_note_cleanups_for_file(self->handle, _file);
}
- (void)noteCleanUpsForFD:(int)_fd {
  ap_note_cleanups_for_fd(self->handle, _fd);
}
#ifdef WIN32
- (void)noteCleanUpsForHandle:(HANDLE)_h {
  ap_note_cleanups_for_h(self->handle, _h);
}
#endif
- (void)killCleanUpsForFD:(int)_fd {
  ap_kill_cleanups_for_fd(self->handle, _fd);
}

/* process management */

+ (void)cleanUpForExec {
  ap_cleanup_for_exec();
}

+ (void)blockAlarms {
  ap_block_alarms();
}
+ (void)unlockAlarms {
  ap_unblock_alarms();
}

/* Objective-C objects */

static void plainReleaseCleanup(void *data) {
  if (data) [(id)data release];
}
static void childReleaseCleanup(void *data) {
  if (data) {
    if ([(id)data respondsToSelector:@selector(cleanupForApacheExec)])
      [(id)data cleanupForApacheExec];
  }
}

- (void)releaseObject:(id)_object {
  if (_object == nil) return;

  ap_block_alarms();
  ap_register_cleanup(self->handle, _object,
                      plainReleaseCleanup,
                      childReleaseCleanup);
  ap_unblock_alarms();
}
- (void)unreleaseObject:(id)_object {
  if (_object == nil) return;
  
  ap_block_alarms();
  ap_kill_cleanup(self->handle, _object, plainReleaseCleanup);
  ap_unblock_alarms();
}

@end /* ApacheResourcePool */
