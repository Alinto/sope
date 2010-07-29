# GNUstep makefile

include ../../../config.make
include ../../common.make

SUBPROJECT_NAME = NGLogging

NGLogging_PCH_FILE = common.h

NGLogging_OBJC_FILES += \
	NGLogger.m			\
	NGLoggerManager.m		\
	NGLogEvent.m			\
	NGLogEventFormatter.m		\
	NGLogEventDetailedFormatter.m	\
	NGLogAppender.m			\
	NGLogFileHandleAppender.m	\
	NGLogStdoutAppender.m		\
	NGLogStderrAppender.m		\

# TODO: disable on Windows
NGLogging_OBJC_FILES += \
	NGLogSyslogAppender.m

ADDITIONAL_INCLUDE_DIRS += -I. -I../NGExtensions/ -I.. -I../..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
