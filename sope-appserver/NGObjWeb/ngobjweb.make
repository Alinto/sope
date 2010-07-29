# settings for NGObjWeb based applications

WO_LDFLAGS =
WO_DEFINE  = -DNGObjWeb_LIBRARY=1

ifneq ($(frameworks),yes)

WO_LIBS    = -lNGObjWeb -lNGMime -lNGStreams -lNGExtensions        

ifeq ($(FOUNDATION_LIB),apple)
WO_LIBS += \
	-lNGMime -lNGStreams -lNGExtensions -lEOControl	\
	-lXmlRpc -lDOM -lSaxObjC
endif

else

WO_LIBS = \
	-framework NGObjWeb	\
	-framework NGMime	\
	-framework NGStreams	\
	-framework NGExtensions        

ifeq ($(FOUNDATION_LIB),apple)
WO_LIBS += \
	-framework NGMime \
	-framework NGStreams -framework NGExtensions -framework EOControl \
	-framework XmlRpc -framework DOM -framework SaxObjC
endif

endif
