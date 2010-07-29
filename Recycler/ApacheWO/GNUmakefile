# $Id: GNUmakefile,v 1.2 2004/06/14 15:02:00 helge Exp $

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = ApacheWO

ApacheWO_PRINCIPAL_CLASS = ApacheWO
BUNDLE_EXTENSION         = .apache

# NOTE: Ordering seems to be important !!! (sometimes the ObjC runtime
# doesn't find all categories ?!)
ApacheWO_OBJC_FILES += \
	ApacheWO+Echo.m			\
	ApacheWO+woxpage.m		\
	ApacheWO+Echo2.m		\
	ApacheWO+hooks.m		\
	ApacheWO+RequestHandler.m	\
	ApacheWO.m			\
	AWODirectoryConfig.m		\
	AWOServerConfig.m		\
	WORequest+Apache.m		\
	WOResponse+Apache.m		\
	WOComponent+Apache.m            \
	WORequestHandler+Apache.m	\
	ApacheResourceManager.m		\
	AliasMap.m			\
	ApacheWOTransaction.m		\

ApacheWO_BUNDLE_LIBS += \
	-lApacheAPI	\
	-lNGExtensions	\
	-lNGObjWeb	\

ApacheWO_RESOURCE_FILES = ApacheCommands.plist ApacheHandlers.plist

# auto info

ApacheWO_OBJC_FILES += ApacheWO_module_structure.m

ApacheWO_module_structure.m :
	$(GNUSTEP_MAKEFILES)/genApacheModule.sh ApacheWO $@

after-clean ::
	rm -f ApacheWO_module_structure.m

include $(GNUSTEP_MAKEFILES)/bundle.make
