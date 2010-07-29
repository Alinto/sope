# build umbrella framework for this subproject

ifeq ($(frameworks),yes)

SOPE_ROOT=..

FRAMEWORK_NAME = sope-appserver

sope-appserver_C_FILES = dummy.c

sope-appserver_UMBRELLA_FRAMEWORKS = \
	sope-xml	\
	sope-core	\
	\
	NGMail		\
	\
	NGObjWeb	\
	WEExtensions	\
	WOExtensions	\
	WOXML		\
	SoOFS		\
	NGXmlRpc	\

sope-appserver_PREBIND_ADDR = # TODO

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


# umbrella dependencies


# library/framework search pathes

DEP_DIRS += \
	$(SOPE_ROOT)/sope-core			\
	$(SOPE_ROOT)/sope-xml			\
	$(SOPE_ROOT)/sope-core/EOControl	\
	$(SOPE_ROOT)/sope-core/NGExtensions	\
	$(SOPE_ROOT)/sope-core/NGStreams	\
	$(SOPE_ROOT)/sope-xml/DOM		\
	$(SOPE_ROOT)/sope-xml/XmlRpc		\
	$(SOPE_ROOT)/sope-xml/SaxObjC		\
	$(SOPE_ROOT)/sope-mime			\
	$(SOPE_ROOT)/sope-mime/NGMail		\
	NGObjWeb	\
	WEExtensions	\
	WOExtensions	\
	WOXML		\
	SoOFS		\
	NGXmlRpc	\

ADDITIONAL_LIB_DIRS += \
	$(foreach dir,$(DEP_DIRS),-F$(GNUSTEP_BUILD_DIR)/$(dir))

endif
