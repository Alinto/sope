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

/*
  TO BE DONE ...

  Usage:

    KeyHandler: KSKeyHandler {
      handleKeys = (
        "<ctrl>@left",
        "<ctrl><right>",
        "<ctrl><shift>s"
      );
      
      modifiers = clickedModifiers;
      key       = clickedKey;
      action    = doKeyAction;
    }
*/

#import <NGObjWeb/WODynamicElement.h>

@interface JSKeyHandler : WODynamicElement
@end

@implementation JSKeyHandler
@end /* JSKeyHandler */

/*
<html>
  <head><title>doof</title></head>
  
  <body>
    Blah<br />

    <form>
	<input type="text" size="20" />
    </form>

    <script>
      function keyDown() {
	if (event.keyCode == 17) {
	  // ctrl
	}
	else if (event.keyCode == 18) {
	  // alt
	}
	else if (event.keyCode == 16) {
	  // shift
	}
	else {
	  if (event.shiftKey)
	    window.status += "_";
	  if (event.ctrlKey)
	    window.status += "^";
	  if (event.altKey)
	    window.status += "@";
	  if (event.keyCode == 37) {
	    window.status += "left,";
	    return false;
	  }
	  else if (event.keyCode == 39) {
	    window.status += "right,";
	    return false;
	  }
	  return true;

	  //window.status += "key:" + event.keyCode + "," + event.shiftKey;

	alert("Modifiers: " + event.modifiers +
	      "\nALT:     " + event.altKey +
	      "\nCTRL:    " + event.ctrlKey +
	      "\nSHIFT:   " + event.shiftKey +
	      "\ntype:    " + event.type +
	      "\nkeyCode: " + event.keyCode +
	      "\nctrl-on: " + isCtrlOn +
	      "\nalt-on:  " + isAltOn
	);

	}
      }
      function keyUp() {
	if (event.keyCode == 17) {
	  // ctrl
	}
	else if (event.keyCode == 18) {
	  // alt
	}
	else if (event.keyCode == 16) {
	  // shift
	}
	else {
	  // window.status += "-" + event.keyCode + ",";
	}
      }

      function keyClicked() {
	alert("Modifiers: " + event.modifiers +
	      "\nALT:     " + event.altKey +
	      "\nCTRL:    " + event.ctrlKey +
	      "\nSHIFT:   " + event.shiftKey +
	      "\ntype:    " + event.type +
	      "\nkeyCode: " + event.keyCode
	);
      }
      var i = 0;
      function ooverride() {
	  window.status = "" + i + "ooverride " + oldHandler.funcname;
	  i += 1;
	return true;
      }

      function setHandler(name, func) {
        oldHandler = document["on" + name];
	if (oldHandler == func) {
	  window.status += "reset handler" + name;
	  return;
        }
	
	document["on" + name] = func;
	
	if (oldHandler) {
	  func.oldHandler = oldHandler;
	  //window.status += "set old handler " + oldHandler;
	}
      }
      
      setHandler("keydown", keyDown);
      setHandler("keyup",   keyUp);

      setHandler("keydown", ooverride);
      setHandler("keyup",   ooverride);
      
      //document.onkeypress=keyClicked;
    </script>
  </body>
</html>
*/
