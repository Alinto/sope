# custom makefile

-include ../../config.make
-include $(GNUSTEP_MAKEFILES)/common.make

# config

APACHE = /usr
APXS   = $(APACHE)/sbin/apxs
APR    = 

# lowercase are commandline args (eg make apxs=/usr/bin/apxs)
ifneq ($(apxs),no)
ifneq ($(apxs),yes)
ifneq ($(apxs),)
APXS=$(apxs)
else
APXS=$(shell which apxs 2>/dev/null)
endif
else
APXS=$(shell which apxs 2>/dev/null)
endif
else
APXS=
endif

# lowercase are commandline args (eg make apr=/usr/bin/apr)
ifneq ($(apr),no)
ifneq ($(apr),yes)
ifneq ($(apr),)
APR=$(apr)
else
APR=$(shell which apr-config 2>/dev/null)
endif
else
APR=$(shell which apr-config 2>/dev/null)
endif
else
APR=
endif

ifeq ($(APXS),)
APXS=$(shell which apxs2 2>/dev/null)
ifeq ($(APXS),)
APXS   = $(APACHE)/sbin/apxs2
endif
endif

ifneq ($(APXS),)
ifneq ($(shared),no)
APXS_CFLAGS       = $(shell $(APXS) -q CFLAGS_SHLIB) $(shell $(APXS) -q CFLAGS)
APXS_INCLUDE_DIRS = -I$(shell $(APXS) -q INCLUDEDIR)
APXS_LIBS         = $(shell$ (APXS) -q LIBS_SHLIB)
APXS_LDFLAGS      = $(shell $(APXS) -q LDFLAGS_SHLIB)
else
ifneq ($(APXS),)
APXS_CFLAGS       = $(shell $(APXS) -q CFLAGS)
APXS_INCLUDE_DIRS = -I$(shell $(APXS) -q INCLUDEDIR)
else
APXS_CFLAGS       = 
APXS_INCLUDE_DIRS = 
endif
endif
else # no apxs available

APXS_CFLAGS="-DSHARED_MODULE -O2 -DEAPI_MM -fPIC -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -DHARD_SERVER_LIMIT=2048 -DDYNAMIC_MODULE_LIMIT=128 -DLINUX=22 -DMOD_SSL=208103 -DEAPI -DUSE_EXPAT"

endif

ifneq ($(APR),)
APR_INCLUDE_DIRS = -I$(shell $(APR) --includedir)
APR_CFLAGS       = $(shell $(APR) --cppflags)
APR_LDFLAGS      = $(shell $(APR) --ldflags)
APR_LIBS         = $(shell $(APR) --libs)
endif

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)/Library/WOAdaptors/Apache

CC            = gcc
LD            = gcc
SHARED_LIBEXT = .so

CFLAGS  = -Wall -I. -fPIC \
	$(APXS_CFLAGS) $(APR_CFLAGS) \
	$(APXS_INCLUDE_DIRS) $(APR_INCLUDE_DIRS) -O0 -ggdb

LDFLAGS = $(APXS_LDFLAGS) $(APR_LDFLAGS) -shared -fPIC
LDLIBS  = $(APXS_LIBS) $(APR_LIBS)

# adaptor

OFILES = \
	globals.o		\
	handler.o		\
	NGBufferedDescriptor.o	\
	scanhttp.o		\
	sns.o			\
	config.o		\
	ngobjweb_module.o	\

module = ngobjweb

product = mod_$(module)$(SHARED_LIBEXT)

all :: $(product)

clean :: 
	rm -f *.o $(product) *.so *~

distclean :: clean


apache-dir :
	$(MKDIRS) $(GNUSTEP_INSTALLATION_DIR)

install ::
	$(APXS) -i -n $(module) $(product)

install-usr-libexec :: all
	$(INSTALL_PROGRAM) $(product) /usr/libexec/httpd/

$(product) : $(OFILES)
	$(LD) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ $(OFILES) $(LDLIBS)
