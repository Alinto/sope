# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = DynamicElements

# does not work yet: DynamicElements_PCH_FILE = decommon.h

DynamicElements_OBJC_FILES = \
        WOxHTMLElemBuilder.m	\
        WOxControlElemBuilder.m	\
	WOxMiscElemBuilder.m	\
	WOxXULElemBuilder.m	\
	WOxTalElemBuilder.m	\
        \
	WOActionURL.m		\
	WOBody.m		\
	WOBrowser.m		\
	WOCheckBox.m		\
	WOCheckBoxList.m	\
	WOComponentContent.m	\
	WOComponentReference.m	\
	WOCompoundElement.m	\
	WOConditional.m		\
	WOEmbeddedObject.m	\
	WOFileUpload.m		\
	WOForm.m		\
	WOFrame.m		\
	WOFragment.m		\
	WOGenericContainer.m	\
	WOGenericElement.m	\
	WOHtml.m		\
	WOHTMLDynamicElement.m	\
	WOHiddenField.m		\
	WOHyperlink.m		\
	WOHyperlinkInfo.m	\
	WOImage.m		\
	WOImageButton.m		\
	WOInput.m		\
	WOIFrame.m		\
	WOJavaScript.m		\
	WOMetaRefresh.m		\
	WONestedList.m		\
	WOPasswordField.m	\
	WOPopUpButton.m		\
	WORadioButton.m		\
	WORadioButtonList.m	\
	WORepetition.m		\
	WOResetButton.m		\
	WOResourceURL.m		\
	WOString.m		\
	WOSubmitButton.m	\
	WOSwitchComponent.m	\
	WOText.m		\
	WOTextField.m		\
	WOVBScript.m		\
	WOEntity.m		\
	WOSetCursor.m		\
	WOCopyValue.m		\
	WOSetHeader.m		\
	\
	WONoContentElement.m	\
	_WOStaticHTMLElement.m	\

DynamicElements_OBJC_FILES += \
	_WOConstResourceImage.m	\
	_WOResourceImage.m

DynamicElements_OBJC_FILES += \
	_WOComplexHyperlink.m		\
	_WOTemporaryHyperlink.m		\
	_WOCommonStaticDAHyperlink.m	\
	_WOSimpleActionHyperlink.m	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble

$(GNUSTEP_OBJ_DIR)/WOGenericContainer.o : WOGenericElement.h WOGenericElement.m WOGenericContainer.m
