
TEXI_FILES = libFoundation.texi

DVI_FILES = $(TEXI_FILES:.texi=.dvi)
HTML_FILES = $(foreach file, $(TEXI_FILES:.texi=), $(file)_toc.html)
INFO_FILES = $(TEXI_FILES:.texi=.info)

all: dvi html info

dvi: $(DVI_FILES)
html: $(HTML_FILES)
info: $(INFO_FILES)

%.dvi: %.texi
	-texi2dvi $<

$(HTML_FILES): $(TEXI_FILES)
	-texi2html -split_node $<

%.info: %.texi
	-makeinfo $<

clean distclean:
	rm -f $(DVI_FILES) libFoundation_*.html $(INFO_FILES) \
		*.aux *.cp *.fn *.ky *.log *.pg *.toc *.tp *.vr
