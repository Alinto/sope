# makefile to generate manpages from .api files

-include ../../../config.make
include ../../../Version
include ../Version

API2MAN = ../../NGObjWeb/woapi2man.py
SECTION = 3

all :: regenerate validate

APIEXT   = .api
APIFILES = ../*$(APIEXT) ../WETableView/*$(APIEXT)

regenerate ::
	@echo "generating manpages from .api files, may take a while ..."
	for apifile in $(APIFILES); do \
	  OUTFILE="`basename $$apifile | sed s/\\$(APIEXT)/.$(SECTION)/g`"; \
	  echo $$OUTFILE; \
	  $(API2MAN) $$apifile $$SECTION \
	    $(MAJOR_VERSION) $(MINOR_VERSION) $(SUBMINOR_VERSION) >$$OUTFILE; \
	done
	@echo "done."

validate ::
	@echo "validating manpages using nroff, may take a while ..."
	for i in *.$(SECTION); do \
	  nroff -mandoc  -Tascii $$i >/dev/null; \
	done
	@echo "done."
