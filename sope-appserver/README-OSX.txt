Please refer to ../README-OSX.txt for compilation directives.

Building Notes
==============

Prerequisites:
- sope-xml
- sope-core


Prebinding Notes (DEPRECATED, for reference only)
=================================================

sope-appserver: 0xC3000000 - 0xC5FFFFFF

0xC3000000 NGScripting  [REMOVED]
0xC3200000 NGJavaScript [REMOVED]
0xC3400000 NGHttp		[not available in gstep-make]
0xC3700000 WebDAV		[not available in gstep-make]
0xC3A00000 SoOFS
0xC3D00000 NGXmlRpc
0xC4000000 WEExtensions
0xC4300000 WOExtensions
0xC4600000 NGObjDOM	[REMOVED]
0xC4900000 NGObjWeb
0xC5AF0000 SoObjects	[NEW]
0xC5B00000 WOXML
0xC5E00000 WEPrototype
0xC5FF0000 SOPE
