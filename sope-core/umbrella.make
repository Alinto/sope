# build umbrella framework for this subproject

ifeq ($(frameworks),yes)

FRAMEWORK_NAME = sope-core

sope-core_C_FILES = dummy.c

sope-core_UMBRELLA_FRAMEWORKS = \
	SaxObjC DOM	\
	EOControl	\
	EOCoreData	\
	NGExtensions	\
	NGStreams	\

sope-core_PREBIND_ADDR = # TODO


# generic (consolidate in gstep-make)
$(FRAMEWORK_NAME)_LDFLAGS += \
	$(foreach fwname,$($(FRAMEWORK_NAME)_UMBRELLA_FRAMEWORKS),\
          -framework $(fwname)) \
	$(foreach fwname,$($(FRAMEWORK_NAME)_UMBRELLA_FRAMEWORKS),\
          -sub_umbrella $(fwname)) \
	-headerpad_max_install_names

ifneq ($($(FRAMEWORK_NAME)_PREBIND_ADDR),)
$(FRAMEWORK_NAME)_LDFLAGS += -seg1addr $($(FRAMEWORK_NAME)_PREBIND_ADDR)
endif


# library/framework search pathes

DEP_DIRS += \
	EOControl EOCoreData NGExtensions NGStreams \
	../sope-xml/SaxObjC ../sope-xml/DOM

ADDITIONAL_LIB_DIRS += \
	$(foreach dir,$(DEP_DIRS),-F$(GNUSTEP_BUILD_DIR)/$(dir))

endif
