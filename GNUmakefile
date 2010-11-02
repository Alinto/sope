# GNUstep makefile

include ./config.make

ifeq ($(GNUSTEP_MAKEFILES),)

$(warning Note: Your $(GNUSTEP_MAKEFILES) environment variable is empty!)
$(warning       Either use ./configure or source GNUstep.sh.)

else

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS += \
	sope-xml	\
	sope-core	\
	sope-mime	\
	sope-appserver	\
	sope-gdl1 \
	sope-json

ifeq ($(HAS_LIBRARY_ldap),yes)
SUBPROJECTS += sope-ldap
endif

ifeq ($(FOUNDATION_LIB),apple)
ifeq ($(frameworks),yes)
SUBPROJECTS += sopex
endif
endif


-include $(GNUSTEP_MAKEFILES)/GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include $(GNUSTEP_MAKEFILES)/GNUmakefile.postamble

endif

distclean ::
	if test -f config.make; then rm config.make; fi
	if test -d .gsmake; then rm -r .gsmake; fi
	if test -f config-NGStreams.log; then rm config-NGStreams.log; fi
	if test -f config-gstepmake.log; then rm config-gstepmake.log; fi

macosx-pkg ::
	for i in $(SUBPROJECTS); do \
	  (cd $$i; $(MAKE) macosx-pkg); \
	done
	./maintenance/make-osxmpkg.sh \
	  "SOPE-$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)"

macosx-dmg :: macosx-pkg
	./maintenance/make-osxdmg.sh \
	  "SOPE-$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)" \
	  osxpkgbuild \
	  "SOPE $(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)"
