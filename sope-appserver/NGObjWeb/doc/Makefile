# makefile to generate manpages from .api files

-include ../../../config.make
include ../../../Version
include ../Version

API2MAN = ../woapi2man.py
SECTION = 3

all :: regenerate

regenerate ::
	for apifile in ../DynamicElements/*.api; do \
	  OUTFILE="`basename $$apifile | sed s/\\.api/.3/g`"; \
	  $(API2MAN) $$apifile $$SECTION $(MAJOR_VERSION) $(MINOR_VERSION) $(SUBMINOR_VERSION) >$$OUTFILE; \
	done
