# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_LIB_DIR=$(CONFIGURE_FHS_INSTALL_LIBDIR)
FHS_DB_DIR=$(FHS_LIB_DIR)sope-$(SOPE_MAJOR_VERSION).$(SOPE_MINOR_VERSION)/dbadaptors/

fhs-db-dirs ::
	$(MKDIRS) $(FHS_DB_DIR)

move-bundles-to-fhs :: fhs-db-dirs
	@echo "moving bundles $(BUNDLE_INSTALL_DIR) to $(FHS_DB_DIR) .."
	for i in $(BUNDLE_NAME); do \
          j="$(FHS_DB_DIR)/$${i}$(BUNDLE_EXTENSION)"; \
	  if test -d $$j; then rm -r $$j; fi; \
	  mv "$(BUNDLE_INSTALL_DIR)/$${i}$(BUNDLE_EXTENSION)" $$j; \
	done

move-to-fhs :: move-bundles-to-fhs

after-install :: move-to-fhs

endif
