# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/
FHS_BIN_DIR=$(FHS_INSTALL_ROOT)/bin/
FHS_SBIN_DIR=$(FHS_INSTALL_ROOT)/sbin/

ifeq ($(findstring _64, $(GNUSTEP_TARGET_CPU)), _64)
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib64/
else
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
endif
FHS_SO_DIR=$(FHS_LIB_DIR)sope-$(MAJOR_VERSION).$(MINOR_VERSION)/products/

NONFHS_LIBDIR="$(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR)/"
NONFHS_LIBNAME="$(LIBRARY_NAME)$(LIBRARY_NAME_SUFFIX)$(SHARED_LIBEXT)"
NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"


fhs-header-dirs ::
	$(MKDIRS) $(FHS_INCLUDE_DIR)$(libSoOFS_HEADER_FILES_INSTALL_DIR)

fhs-bin-dirs ::
	$(MKDIRS) $(FHS_BIN_DIR)

fhs-sbin-dirs ::
	$(MKDIRS) $(FHS_SBIN_DIR)

fhs-products-dirs ::
	$(MKDIRS) $(FHS_SO_DIR)


move-headers-to-fhs :: fhs-header-dirs
	@echo "moving headers to $(FHS_INCLUDE_DIR) .."
	mv $(GNUSTEP_HEADERS)$(libSoOFS_HEADER_FILES_INSTALL_DIR)/*.h \
	  $(FHS_INCLUDE_DIR)$(libSoOFS_HEADER_FILES_INSTALL_DIR)/

move-libs-to-fhs :: 
	@echo "moving libs to $(FHS_LIB_DIR) .."
	mv $(NONFHS_LIBDIR)/$(NONFHS_LIBNAME)* $(FHS_LIB_DIR)/

move-daemons-to-fhs :: fhs-sbin-dirs
	@echo "moving daemons from $(NONFHS_BINDIR) to $(FHS_SBIN_DIR) .."
	for i in $(TOOL_NAME); do \
	  mv "$(NONFHS_BINDIR)/$${i}" $(FHS_SBIN_DIR); \
	done

move-bundles-to-fhs :: fhs-products-dirs
	@echo "moving bundles $(BUNDLE_INSTALL_DIR) to $(FHS_SO_DIR) .."
	for i in $(BUNDLE_NAME); do \
          j="$(FHS_SO_DIR)/$${i}$(BUNDLE_EXTENSION)"; \
	  if test -d $$j; then rm -r $$j; fi; \
	  mv "$(BUNDLE_INSTALL_DIR)/$${i}$(BUNDLE_EXTENSION)" $$j; \
	done

move-to-fhs :: move-headers-to-fhs move-libs-to-fhs move-daemons-to-fhs \
		move-bundles-to-fhs

after-install :: move-to-fhs

endif
