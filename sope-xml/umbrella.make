# build umbrella framework for this subproject

ifeq ($(frameworks),yes)

FRAMEWORK_NAME = sope-xml
sope-xml_RESOURCE_FILES += Version

sope-xml_C_FILES = dummy.c

sope-xml_UMBRELLA_FRAMEWORKS = \
	SaxObjC	\
	DOM	\
	XmlRpc

sope-xml_PREBIND_ADDR = 0xC0FF0000


# generic (consolidate in gstep-make)
$(FRAMEWORK_NAME)_LDFLAGS += \
	$(foreach fwname,$($(FRAMEWORK_NAME)_UMBRELLA_FRAMEWORKS),\
          -framework $(fwname)) \
	$(foreach fwname,$($(FRAMEWORK_NAME)_UMBRELLA_FRAMEWORKS),\
          -sub_umbrella $(fwname)) \
	-headerpad_max_install_names \
	-seg1addr $($(FRAMEWORK_NAME)_PREBIND_ADDR)


# library/framework search pathes

DEP_DIRS += SaxObjC DOM XmlRpc

ADDITIONAL_LIB_DIRS += \
	$(foreach dir,$(DEP_DIRS),-F$(GNUSTEP_BUILD_DIR)/$(dir))

endif
