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

#include "common.h"

#define LOG_CONFIG 0

static char *_makeString(char *buf, char *str, int max) {
  if (buf == NULL)
    buf = calloc(max + 10, sizeof(char));
  
  strncpy(buf, str, max);
  buf[max] = '\0';
  return buf;
}

static char *_makePort(char *port, char *str) {
  return _makeString(port, str, MAX_PORTNAME_SIZE);
}

static int _domainFromPort(char *port) {
  if (port == NULL) return AF_INET;
  return *port == '/' ? AF_UNIX : AF_INET;
}

const char *ngobjweb_set_sns_port(cmd_parms *cmd,
                                  ngobjweb_dir_config *cfg,
                                  char *arg)
{
  cfg->snsPort = _makePort(cfg->snsPort, arg);
  cfg->snsPortDomain = _domainFromPort(cfg->snsPort);
  
#if LOG_CONFIG
  fprintf(stderr, "%s: 0x%08X set snsport to %s, domain %i (http=%s)\n",
          __PRETTY_FUNCTION__, (unsigned)cfg,
          cfg->snsPort, cfg->snsPortDomain,
          cfg->useHTTP ? "yes" : "no");
#endif
  return NULL;
}

const char *ngobjweb_set_app_port(cmd_parms *cmd,
                                  ngobjweb_dir_config *cfg,
                                  char *arg)
{
  cfg->appPort = _makePort(cfg->appPort, arg);
  cfg->appPortDomain = _domainFromPort(cfg->appPort);
  
#if LOG_CONFIG
  fprintf(stderr, "%s: 0x%08X set appPort to %s, domain %i (http=%s)\n",
          __PRETTY_FUNCTION__, (unsigned)cfg,
          cfg->appPort, cfg->snsPortDomain,
          cfg->useHTTP ? "yes" : "no");
#endif
  return NULL;
}

const char *ngobjweb_set_app_prefix(cmd_parms *cmd,
                                    ngobjweb_dir_config *cfg,
                                    char *arg)
{
  cfg->appPrefix = _makeString(cfg->appPrefix, arg, MAX_APP_PREFIX_SIZE);
  return NULL;
}

const char *ngobjweb_set_use_http(cmd_parms *cmd,
                                  ngobjweb_dir_config *cfg)
{
#if LOG_CONFIG
  fprintf(stderr, "%s: using HTTP.\n", __PRETTY_FUNCTION__);
#endif
  cfg->useHTTP = 1;
  return NULL;
}

void *ngobjweb_create_dir_config(apr_pool_t *p, char *dummy) {
  ngobjweb_dir_config *new;

  new = apr_palloc(p, sizeof(ngobjweb_dir_config));
  new->snsPort       = NULL;
  new->snsPortDomain = AF_UNIX;
  new->appPort       = NULL;
  new->appPortDomain = AF_INET;
  new->appPrefix     = NULL;
  new->useHTTP       = 0;

#if LOG_CONFIG
  fprintf(stderr,"%s: created directory config 0x%08X ...\n",
          __PRETTY_FUNCTION__, (unsigned)new);
#endif

  return new;
}

void *ngobjweb_merge_dir_configs(apr_pool_t *p, void *basev, void *addv) {
  ngobjweb_dir_config *base;
  ngobjweb_dir_config *add;
  ngobjweb_dir_config *new;

  base = (ngobjweb_dir_config *)basev;
  add  = (ngobjweb_dir_config *)addv;
  if (add == NULL) add = base;
  
  if ((new = apr_palloc(p, sizeof(ngobjweb_dir_config))) == NULL) {
    fprintf(stderr, "%s: couldn't allocate memory of size %ld\n",
            __PRETTY_FUNCTION__,
            (long int) sizeof(ngobjweb_dir_config));
    return NULL;
  }
  
  new->snsPort       = NULL;
  new->snsPortDomain = 0;
  new->appPort       = NULL;
  new->appPortDomain = 0;
  new->appPrefix     = NULL;
  new->useHTTP       = 0;
  
  if ((add == NULL) && (base == NULL))
    goto finish;
  
  /* copy base stuff */
  if (add) {
    if (add->useHTTP)
      new->useHTTP = 1;
    
    if (add->snsPortDomain)
      new->snsPortDomain = add->snsPortDomain;
    else
      new->snsPortDomain = base ? base->snsPortDomain : 0;
    
    if (add->appPortDomain)
      new->appPortDomain = add->appPortDomain;
    else
      new->appPortDomain = base ? base->appPortDomain : 0;
  }
  if (base) {
    if (base->useHTTP)
      new->useHTTP = 1;
  }

  /* copy SNS port */
  if ((add != NULL) && (add->snsPort != NULL)) {
    if ((new->snsPort = _makePort(NULL, add->snsPort)))
      new->snsPortDomain = _domainFromPort(new->snsPort);
  }
  else if ((base != NULL) && (base->snsPort != NULL)) {
    if ((new->snsPort = _makePort(NULL, base->snsPort)))
      new->snsPortDomain = _domainFromPort(new->snsPort);
  }

  /* copy app port */
  if ((add != NULL) && (add->appPort != NULL)) {
    if ((new->appPort = _makePort(NULL, add->appPort)))
      new->appPortDomain = _domainFromPort(new->appPort);
  }
  else if ((base != NULL) && (base->appPort != NULL)) {
    if ((new->appPort = _makePort(NULL, base->appPort)))
      new->appPortDomain = _domainFromPort(new->appPort);
  }
  
  /* copy app prefix */
  if (add->appPrefix) {
    new->appPrefix = _makeString(NULL, add->appPrefix, MAX_APP_PREFIX_SIZE);
  }
  else if (base->appPrefix) {
    new->appPrefix = _makeString(NULL, base->appPrefix, MAX_APP_PREFIX_SIZE);
  }
  
 finish:
#if LOG_CONFIG
  fprintf(stderr,
          "MERGE: (base=0x%08X, add=0x%08X, new=0x%08X\n"
          "  BASE: sns:'%s'%i app:'%s'%i prefix:'%s' http:%s\n"
          "  ADD:  sns:'%s'%i app:'%s'%i prefix:'%s' http:%s\n"
          "  NEW:  sns:'%s'%i app:'%s'%i prefix:'%s' http:%s\n",
          (unsigned)base, (unsigned)add, (unsigned)new,
          base->snsPort,   base->snsPortDomain, 
          base->appPort,   base->appPortDomain,
	  base->appPrefix, base->useHTTP ? "on" : "off",
          add->snsPort,   add->snsPortDomain, 
          add->appPort,   add->appPortDomain,
          add->appPrefix, add->useHTTP ? "on" : "off",
          new->snsPort,   new->snsPortDomain, 
          new->appPort,   new->appPortDomain,
          new->appPrefix, new->useHTTP ? "on" : "off"
         );
#endif
  return new;
}
