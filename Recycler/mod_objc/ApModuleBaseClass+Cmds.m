// $Id: ApModuleBaseClass+Cmds.m,v 1.1 2004/06/08 11:15:58 helge Exp $

#include "ApModuleBaseClass.h"
#include <httpd.h>
#include "http_config.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#include "ApacheServer.h"
#include "ApacheResourcePool.h"
#include "ApacheModule.h"
#include "ApacheCmdParms.h"

@implementation ApModuleBaseClass(ConfigCommands)

static const char *configStubRaw(cmd_parms *p, void *d, char *a0);
static const char *configStubFlag(cmd_parms *p, void *d, int flag);
static const char *configStubTake0(cmd_parms *p, void *d);
static const char *configStubTake1(cmd_parms *p, void *d, char *a0);
static const char *configStubTake2(cmd_parms *p, void *d, char *a0, char *a1);
static const char *configStubTake12(cmd_parms *p, void *d, char *a0, char *a1);
static const char *
  configStubTake3(cmd_parms *p, void *d, char *a0, char *a1, char *a3);
static const char *
  configStubTake123(cmd_parms *p, void *d, char *a0, char *a1, char *a3);

static const char *
  configStubIterate(cmd_parms *p, void *d, char *a0);
static const char *
  configStubIterate2(cmd_parms *p, void *d, char *a0, char *a1);

static const char *serverConfigStubRaw(cmd_parms *p, void *d, char *a0);
static const char *serverConfigStubFlag(cmd_parms *p, void *d, int flag);
static const char *serverConfigStubTake0(cmd_parms *p, void *d);
static const char *serverConfigStubTake1(cmd_parms *p, void *d, char *a0);
static const char *
  serverConfigStubTake2(cmd_parms *p, void *d, char *a0, char *a1);
static const char *
  serverConfigStubTake12(cmd_parms *p, void *d, char *a0, char *a1);
static const char *
  serverConfigStubTake3(cmd_parms *p, void *d, char *a0, char *a1, char *a3);
static const char *
  serverConfigStubTake123(cmd_parms *p, void *d, char *a0, char *a1, char *a3);

static const char *
  serverConfigStubIterate(cmd_parms *p, void *d, char *a0);
static const char *
  serverConfigStubIterate2(cmd_parms *p, void *d, char *a0, char *a1);

typedef struct _ObjCmdDispatchInfo {
  Class        moduleClass;
  SEL          sel;
  const char   *methodName;
  const char   *command;
  enum cmd_how argsHow;
  int          location;
  BOOL         isIterate;
  BOOL         isFlag;
  BOOL         isRaw;
} ApObjCCmdDispatchInfo;

+ (BOOL)logConfigCommandRegistration {
  return NO;
}

+ (command_rec *)apacheCommandTable {
  /*
    How to map selectors to commands ?

      All command selectors start with 'configure', eg:
       
        paras TAKE2, location ACCESS_CONF
        - configureDirectory_ScriptAlias:(NSString *)_fake:(NSString *)_real
          directoryConfig:(id)_cfg
          parameters:(ApacheCmdParms *)_params;
        
        paras TAKE2, location RSRC_CONF
        - configureServer_ScriptAlias:(NSString *)_fake:(NSString *)_real
          parameters:(ApacheCmdParms *)_params;

        paras TAKE1, location OR_FILEINFO
        - configureFileInfo_PassEnv:(NSString *)_arg
          directoryConfig:(id)_cfg
          parameters:(ApacheCmdParms *)_params;
        
        paras FLAG, location OR_FILEINFO
        - configureFileInfo_PassEnvFlag:(BOOL)_flag
          directoryConfig:(id)_cfg
          parameters:(ApacheCmdParms *)_params;
        
        paras ITERATE, location OR_INDEXES
        - configureIndexes_DirectoryIndexIterate:(NSString *)_dir
          directoryConfig:(id)_cfg
          parameters:(ApacheCmdParms *)_params;

      Allowed Prefixes:
        configureDirectory_
        configureServer_
        configureFileInfo_
        configureIndexes_
    
    Parameters:
      RAW_ARGS,			// cmd_func parses command line itself
      TAKE1,			// one argument only
      TAKE2,			// two arguments only
      ITERATE,			// one argument, occuring multiple times
  				// (e.g., IndexIgnore)
      ITERATE2,			// two arguments, 2nd occurs multiple times
  				// (e.g., AddIcon)
      FLAG,			// One of 'On' or 'Off'
      NO_ARGS,			// No args at all, e.g. </Directory>
      TAKE12,			// one or two arguments
      TAKE3,			// three arguments only
      TAKE23,			// two or three arguments
      TAKE123,			// one, two or three arguments
      TAKE13			// one or three arguments
    
    Request Overrides
    * The allowed locations for a configuration directive are the union of
    * those indicated by each set bit in the req_override mask.
    *
    * (req_override & RSRC_CONF)   => *.conf outside <Directory> or <Location>
    * (req_override & ACCESS_CONF) => *.conf inside <Directory> or <Location>
    * (req_override & OR_AUTHCFG)  => *.conf inside <Directory> or <Location>
    *                                 and .htaccess when AllowOverride
    *                                 AuthConfig
    * (req_override & OR_LIMIT)    => *.conf inside <Directory> or <Location>
    *                                 and .htaccess when AllowOverride Limit
    * (req_override & OR_OPTIONS)  => *.conf anywhere
    *                                 and .htaccess when AllowOverride Options
    * (req_override & OR_FILEINFO) => *.conf anywhere
    *                                 and .htaccess when AllowOverride FileInfo
    * (req_override & OR_INDEXES)  => *.conf anywhere
    *                                 and .htaccess when AllowOverride Indexes
    
    typedef struct command_struct {
      const char *name;		// Name of this command 
      const char *(*func) ();	// Function invoked 
      void *cmd_data;		// Extra data, for functions which
				// implement multiple commands...
      int req_override;		// What overrides need to be allowed to
				// enable this command.
      enum cmd_how args_how;	// What the command expects as arguments

      const char *errmsg; // 'usage' message, in case of syntax errors
    } command_rec;
  */
  ApacheModule *bundleHandler = [self bundleHandler];
  command_rec *cmdtable;

  unsigned    count, capacity;
  Class c;
  
  if (bundleHandler == nil)
    return NULL;
  
  count    = 0;
  capacity = 16;
  cmdtable = calloc(capacity + 1, sizeof(command_rec));
  
#if GNU_RUNTIME
  /* for the class and each superclass ... */
  for (c = [bundleHandler class]; c != Nil; c = c->super_class) {
    struct objc_method_list *cm;
    
    /* for each method list of the class */
    for (cm = c->methods; cm != NULL; cm = cm->method_next) {
      register unsigned i;
      
      /* for each method in the list */
      for (i = 0; i < cm->method_count; i++) {
        const char   *methodName;
        const char   *tmp;
        char         *tmp2, *tmp3;
        unsigned     len, argumentCount;
        char         *configName;
        int          reqOverride = 0;
        enum cmd_how argsHow = 0;
        BOOL hasParametersArg;
        BOOL hasDirConfigArg;
        BOOL isIterate;
        BOOL isFlag;
        BOOL isRaw;
        
        if ((methodName = sel_get_name(cm->method_list[i].method_name))==NULL)
          continue;
        if (methodName[0] != 'c')
          /* quick check for 'configure' prefix */
          continue;
        
        if (strstr(methodName, "configure") != methodName)
          /* long check for 'configure' prefix */
          continue;
        
        tmp = methodName + 9;

        /* search for start of config name, eg _PassEnv */
        
        if ((tmp2 = index(tmp, '_')) == NULL)
          continue;
        tmp2++; // skip underscore
        
        /* search for end of config name, copy config name */
        
        if ((tmp3 = index(tmp2, ':')) == NULL)
          continue;
        if ((len = (tmp3 - tmp2)) < 3)
          /* config name to short ... */
          continue;
        
        configName = malloc(len + 2);
        memcpy(&(configName[0]), tmp2, len);
        configName[len] = '\0';
        
        /* count args */
        
        for (argumentCount = 0; *tmp3 == ':'; tmp3++)
          argumentCount++;
        tmp3 = NULL;
        
        if (argumentCount == 0 || argumentCount > 3) {
          printf("ERROR(%s): flag and raw configuration selectors "
                 "only take exactly one argument (sel=%s, command=%s) !!!\n",
                 __PRETTY_FUNCTION__, methodName, configName);
          continue;
        }
        
        /* check suffix (Iterate, Flag) */

        isIterate = NO;
        isFlag    = NO;
        isRaw     = NO;
        if ((tmp3 = rindex(configName, 'I'))) {
          if (strcmp(tmp3, "Iterate") == 0) {
            *tmp3 = '\0';
            isIterate = YES;
          }
        }
        if ((tmp3 = rindex(configName, 'F'))) {
          if (strcmp(tmp3, "Flag") == 0) {
            *tmp3 = '\0';
            isFlag = YES;
          }
        }
        if ((tmp3 = rindex(configName, 'R'))) {
          if (strcmp(tmp3, "Raw") == 0) {
            *tmp3 = '\0';
            isRaw = YES;
          }
        }
        
        /* derive argument style info */
        
        if ((isFlag || isRaw) && (argumentCount != 1)) {
          if (argumentCount != 1) {
            printf("ERROR(%s): flag and raw configuration selectors "
                   "only take exactly one argument (sel=%s, command=%s) !!!\n",
                   __PRETTY_FUNCTION__, methodName, configName);
            continue;
          }
        }
        
        if (isFlag) {
          argsHow = FLAG;
        }
        else if (isIterate) {
          if (argumentCount == 1)
            argsHow = ITERATE;
          else if (argumentCount == 2)
            argsHow = ITERATE2;
          else {
            printf("ERROR(%s): iterate configuration selectors "
                   "only take one or two arguments (sel=%s, command=%s) !!!\n",
                   __PRETTY_FUNCTION__, methodName, configName);
            continue;
          }
        }
        else if (isRaw) {
          argsHow = RAW_ARGS;
        }
        else {
          switch (argumentCount) {
            case 0:
              argsHow = NO_ARGS;
              break;
            case 1:
              argsHow = TAKE1;
              break;
            case 2:
              argsHow = TAKE2;
              break;
            case 3:
              argsHow = TAKE3;
              break;
            default:
              printf("ERROR(%s): configuration selectors "
                     "only take 1-3 arguments (sel=%s, command=%s) !!!\n",
                     __PRETTY_FUNCTION__, methodName, configName);
              continue;
          }
        }
        
        /* search for standard parameters */
        
        hasParametersArg = strstr(tmp2, "parameters:")      != NULL ? YES : NO;
        hasDirConfigArg  = strstr(tmp2, "directoryConfig:") != NULL ? YES : NO;

        if ([self logConfigCommandRegistration]) {
          printf("Found config selector '%s', command '%s' (%i args) ...\n",
                 methodName, configName, argumentCount);
        }
        
        /* check allowed location */
        
        switch (tmp[0]) {
          case 'D':
            if (strstr(tmp, "Directory") == tmp) {
              reqOverride = ACCESS_CONF;
              break;
            }
          case 'S':
            if (strstr(tmp, "Server") == tmp) {
              reqOverride = RSRC_CONF;
              break;
            }
          case 'I':
            if (strstr(tmp, "Indexes") == tmp) {
              reqOverride = OR_INDEXES;
              break;
            }
          case 'F':
            if (strstr(tmp, "FileInfo") == tmp) {
              reqOverride = OR_FILEINFO;
              break;
            }
          case 'O':
            if (strstr(tmp, "Options") == tmp) {
              reqOverride = OR_OPTIONS;
              break;
            }
          case 'L':
            if (strstr(tmp, "Limit") == tmp) {
              reqOverride = OR_OPTIONS;
              break;
            }
          case 'A':
            if (strstr(tmp, "AuthConfig") == tmp) {
              reqOverride = OR_AUTHCFG;
              break;
            }
          default:
            printf("%s:  invalid directory location in selector '%s' !\n",
                   __PRETTY_FUNCTION__, methodName);
            continue;
        }
        
        /* should check for duplicate entries */
        {
          int i;
          
          for (i = 0; i < count; i++) {
            if (strcmp(cmdtable[i].name, configName) == 0) {
              /* this should check for alternate argument counts */
              printf("WARNING(%s): found duplicate entry '%s' ...\n",
                     __PRETTY_FUNCTION__, configName);
              i = -1;
              break;
            }
          }
          if (i == -1) continue;
        }
        
        /* check command table capacity */
        
        if (count >= capacity) {
          /* resize command table ... */
          command_rec *old = cmdtable;
          unsigned oldCapacity = capacity;
          
          capacity *= 2;
          cmdtable = calloc(capacity + 1,sizeof(command_rec));
          memcpy(cmdtable, old, oldCapacity * sizeof(command_rec));
          if (old) free(old);
        }

        /* fill command table entry */
        
        cmdtable[count].name         = configName /* malloced */;
        cmdtable[count].args_how     = argsHow;
        cmdtable[count].req_override = reqOverride;

        {
          NSString *err;
          
          err = [bundleHandler usageForConfigSelector:
                                 cm->method_list[i].method_name];
          
          cmdtable[count].errmsg = [err length] > 0
            ? strdup([err cString])
            : NULL;
        }

        {
          ApObjCCmdDispatchInfo *info;
          
          info = calloc(1, sizeof(ApObjCCmdDispatchInfo));
          info->moduleClass = self;
          info->sel         = cm->method_list[i].method_name;
          info->methodName  = methodName;
          info->command     = configName;
          info->argsHow     = cmdtable[count].args_how;
          info->location    = cmdtable[count].req_override;
          info->isRaw       = isRaw;
          info->isIterate   = isIterate;
          info->isFlag      = isFlag;
          
          cmdtable[count].cmd_data = info;
        }

        {
          void *func;
          
          func = NULL;
          if (reqOverride != RSRC_CONF) {
            switch (cmdtable[count].args_how) {
              case NO_ARGS:  func = configStubTake0;    break;
              case RAW_ARGS: func = configStubRaw;      break;
              case TAKE1:    func = configStubTake1;    break;
              case ITERATE:  func = configStubIterate;  break;
              case TAKE2:    func = configStubTake2;    break;
              case TAKE12:   func = configStubTake12;   break;
              case ITERATE2: func = configStubIterate2; break;
              case TAKE3:    func = configStubTake3;    break;
              case TAKE23:   break;
              case TAKE123:  func = configStubTake123;  break;
              case TAKE13:   break;
              case FLAG:     func = configStubFlag;     break;
              
              default:
                printf("ERROR(%s): unknown argument style %i !!\n",
                       __PRETTY_FUNCTION__, cmdtable[count].args_how);
                break;
            }
          }
          else {
            switch (cmdtable[count].args_how) {
              case NO_ARGS:  func = serverConfigStubTake0;    break;
              case RAW_ARGS: func = serverConfigStubRaw;      break;
              case TAKE1:    func = serverConfigStubTake1;    break;
              case ITERATE:  func = serverConfigStubIterate;  break;
              case TAKE2:    func = serverConfigStubTake2;    break;
              case TAKE12:   func = serverConfigStubTake12;   break;
              case ITERATE2: func = serverConfigStubIterate2; break;
              case TAKE3:    func = serverConfigStubTake3;    break;
              case TAKE23:   break;
              case TAKE123:  func = serverConfigStubTake123;  break;
              case TAKE13:   break;
              case FLAG:     func = serverConfigStubFlag;     break;
              
              default:
                printf("ERROR(%s): unknown argument style %i !!\n",
                       __PRETTY_FUNCTION__, cmdtable[count].args_how);
                break;
            }
          }          
          cmdtable[count].func = func;
        }
        if (cmdtable[count].func)
          count++;
        else {
          printf("ERROR(%s): internal error during cmd table setup ...\n",
                 __PRETTY_FUNCTION__);
        }
      }
    }
  }
#else
#  warning not ported to this runtime yet ...
#endif
  
  if (count == 0) {
    /* found no commands ... */
    if (cmdtable) {
      free(cmdtable);
      cmdtable = NULL;
    }
  }
#if 0
  printf("found %i commands ...\n", count);
#endif
  return cmdtable;
}

#define OBJC_CONFIG_BEGIN \
  NSAutoreleasePool     *pool;\
  ApObjCCmdDispatchInfo *info;\
  ApacheCmdParms        *paras;\
  ApacheModule *bundleHandler;\
  const char *ares;\
  if ((info = p->info) == NULL)\
    return ap_pstrdup(p->pool, "missing Objective-C dispatch info !");\
  pool = [[NSAutoreleasePool alloc] init];\
  paras = [[ApacheCmdParms alloc] initWithHandle:p];\
  bundleHandler = [[info->moduleClass bundleHandler] retain];\
  { id result; result = nil;

#define OBJC_CONFIG_END \
    if (result == nil) ares = NULL;\
    else ares = ap_pstrdup(p->pool, [[result description] cString]);\
  }\
  RELEASE(bundleHandler);\
  RELEASE(paras);\
  RELEASE(pool); \
  return ares;

static const char *configStubRaw(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, id, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *configStubFlag(cmd_parms *p, void *d, int flag) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, BOOL, id, ApacheCmdParms *);
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, flag?YES:NO, d, paras);
    else
      result = @"did not find method for config call ..";
  }
  OBJC_CONFIG_END;
}
static const char *configStubTake1(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, id, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *configStubIterate(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, id, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char
  *configStubIterate2(cmd_parms *p, void *d, char *a0, char *a1)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, id, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *configStubTake0(cmd_parms *p, void *d) {
  return NULL;
}

static const char *configStubTake2(cmd_parms *p, void *d, char *a0, char *a1) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, id, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *configStubTake12(cmd_parms *p, void *d, char *a0, char *a1){
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, id, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *
  configStubTake3(cmd_parms *p, void *d, char *a0, char *a1, char *a2)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, NSString *,id, ApacheCmdParms *);
    NSString *s0, *s1, *s2;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    s2 = a2 ? [[NSString alloc] initWithCString:a2] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, s2, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s2);
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *
  configStubTake123(cmd_parms *p, void *d, char *a0, char *a1, char *a2)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, NSString *,id, ApacheCmdParms *);
    NSString *s0, *s1, *s2;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    s2 = a2 ? [[NSString alloc] initWithCString:a2] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, s2, d, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s2);
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

/* server stubs */

static const char *serverConfigStubRaw(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *serverConfigStubFlag(cmd_parms *p, void *d, int flag) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, BOOL, ApacheCmdParms *);
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, flag?YES:NO, paras);
    else
      result = @"did not find method for config call ..";
  }
  OBJC_CONFIG_END;
}
static const char *serverConfigStubTake1(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *serverConfigStubIterate(cmd_parms *p, void *d, char *a0) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, ApacheCmdParms *);
    NSString *s0;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char
  *serverConfigStubIterate2(cmd_parms *p, void *d, char *a0, char *a1)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *serverConfigStubTake0(cmd_parms *p, void *d) {
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, ApacheCmdParms *);
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, paras);
    else
      result = @"did not find method for config call ..";
  }
  OBJC_CONFIG_END;
}

static const char *
serverConfigStubTake2(cmd_parms *p, void *d, char *a0, char *a1)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

static const char *
serverConfigStubTake12(cmd_parms *p, void *d, char *a0, char *a1)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, ApacheCmdParms *);
    NSString *s0, *s1;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, paras);
    else
      result = @"did not find method for config call ..";
    
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *
  serverConfigStubTake3(cmd_parms *p, void *d, char *a0, char *a1, char *a2)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, NSString *, ApacheCmdParms *);
    NSString *s0, *s1, *s2;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    s2 = a2 ? [[NSString alloc] initWithCString:a2] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, s2, paras);
    else
      result = @"did not find method for config call ..";

    RELEASE(s2);
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}
static const char *
  serverConfigStubTake123(cmd_parms *p, void *d, char *a0, char *a1, char *a2)
{
  OBJC_CONFIG_BEGIN {
    id (*m)(id, SEL, NSString *, NSString *, NSString *, ApacheCmdParms *);
    NSString *s0, *s1, *s2;
    
    s0 = a0 ? [[NSString alloc] initWithCString:a0] : nil;
    s1 = a1 ? [[NSString alloc] initWithCString:a1] : nil;
    s2 = a2 ? [[NSString alloc] initWithCString:a2] : nil;
    
    if ((m = (void *)[bundleHandler methodForSelector:info->sel]))
      result = m(bundleHandler, info->sel, s0, s1, s2, paras);
    else
      result = @"did not find method for config call ..";

    RELEASE(s2);
    RELEASE(s1);
    RELEASE(s0);
  }
  OBJC_CONFIG_END;
}

@end /* ApModuleBaseClass(ConfigCommands) */
