# makefile to generate manpages from .api files

SOPE_ROOT=../../..

-include $(SOPE_ROOT)/config.make
include $(SOPE_ROOT)/Version
include ../Version

API2MAN = ../../NGObjWeb/woapi2man.py
SECTION = 3

all :: regenerate

regenerate ::
	for apifile in ../*.api; do \
	  OUTFILE="`basename $$apifile | sed s/\\.api/.3/g`"; \
	  $(API2MAN) $$apifile $$SECTION $(MAJOR_VERSION) $(MINOR_VERSION) $(SUBMINOR_VERSION) >$$OUTFILE; \
	done
