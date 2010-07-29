# GNU makefile

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = testurl

testurl_OBJC_FILES = testurl.m

include $(GNUSTEP_MAKEFILES)/tool.make

SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib

# raw tools

all :: testnested

clean ::
	rm -f testnested

LIBDIR="-L/home/helge/OGoRoot/Library/Libraries"
LIBS=-lobjc -lnsl -lm -lpthread -ldl
OPT="-O2"

testnested : testnested.c
	gcc -o $@ -g $(OPT) $(LIBDIR) $< $(LIBS)
