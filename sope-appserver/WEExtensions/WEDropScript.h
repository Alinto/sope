/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
/* automatically generated from WEDropScript.js, do not edit ! */
@"<SCRIPT LANGUAGE=\"JScript\">\n"
@"<!--\n"
@"function fnGetInfo(dropElem, myurl) {\n"
@"  event.returnValue = false;\n"
@"  event.dataTransfer.dropEffect = \"none\";\n"
@"  myData = event.dataTransfer.getData(\"Text\");\n"
@"  myData = myData.split('?');\n"
@"  myType = myData[1];\n"
@"  myID   = myData[0];\n"
@"  event.dataTransfer.clearData(\"Text\");\n"
@"  this.location=''+myurl+'?'+myID+'='+myType;\n"
@"  this.status='url:'+myurl+' data'+myData;\n"
@"}\n"
@"function fnCancelDefault(validObj, effect) {\n"
@"  myData = event.dataTransfer.getData(\"Text\");\n"
@"  myData = myData.split('?');\n"
@"  myType = myData[1];\n"
@"  myID   = myData[0];\n"
@"  if ((validObj.indexOf(myType) != -1) || (validObj == '*')) {\n"
@"    event.returnValue = false;\n"
@"    event.dataTransfer.dropEffect = effect;\n"
@"  }\n"
@"  else {\n"
@"    event.returnValue = false;\n"
@"    event.dataTransfer.dropEffect = \"none\";\n"
@"  }\n"
@"}\n"
@"var WODropContainerBgColor = new Array(); \n"
@"function dropFieldSwapColor(obj,color) {\n"
@"  if (color && event.dataTransfer.dropEffect == 'none') return false;\n"
@"  if (color) {\n"
@"    if (!WODropContainerBgColor[obj.id]) {\n"
@"      WODropContainerBgColor[obj.id] = obj.bgColor;\n"
@"    }\n"
@"    color = WODropContainerBgColor[obj.id];\n"
@"    color = lighterColor(color);\n"
@"  } else {\n"
@"    color = WODropContainerBgColor[obj.id];\n"
@"  }\n"
@"  obj.bgColor = color;\n"
@"}\n"
@"      \n"
@"var lightAddition = 20;\n"
@"var hex = '0123456789ABCDEF';\n"
@"function convertHexToDec(h) {\n"
@"  h1 = hex.indexOf(h.substr(0,1).toUpperCase());\n"
@"  h2 = hex.indexOf(h.substr(1,1).toUpperCase());\n"
@"  return (h1 * 16 + h2);\n"
@"}\n"
@"function convertDecToHex(d) {\n"
@"  if (d >= 255) return 'FF';\n"
@"  if (d <= 0)   return '00';\n"
@"  d2 = d % 16; d1 = parseInt((d-d2) / 16);\n"
@"  return hex.substr(d1,1)+hex.substr(d2,1);\n"
@"}\n"
@"function lighterColor(c) {\n"
@"  if (!c) return c;\n"
@"  if ((c.length != 7) || (c.substr(0,1) != '#')) return c;\n"
@"  r = convertDecToHex(convertHexToDec(c.substr(1,2)) + lightAddition);\n"
@"  g = convertDecToHex(convertHexToDec(c.substr(3,2)) + lightAddition);\n"
@"  b = convertDecToHex(convertHexToDec(c.substr(5,2)) + lightAddition);\n"
@"  return '#'+r+g+b;\n"
@"}\n"
@"// -->\n"
@"</SCRIPT>\n"
