<SCRIPT LANGUAGE="JScript">
<!--
function fnGetInfo(dropElem, myurl) {
  event.returnValue = false;
  event.dataTransfer.dropEffect = "none";
  myData = event.dataTransfer.getData("Text");
  myData = myData.split('?');
  myType = myData[1];
  myID   = myData[0];
  event.dataTransfer.clearData("Text");
  this.location=''+myurl+'?'+myID+'='+myType;
  this.status='url:'+myurl+' data'+myData;
}
function fnCancelDefault(validObj, effect) {
  myData = event.dataTransfer.getData("Text");
  myData = myData.split('?');
  myType = myData[1];
  myID   = myData[0];
  if ((validObj.indexOf(myType) != -1) || (validObj == '*')) {
    event.returnValue = false;
    event.dataTransfer.dropEffect = effect;
  }
  else {
    event.returnValue = false;
    event.dataTransfer.dropEffect = "none";
  }
}
function dropFieldSwapColor(obj,doLight) {
  if (!obj.bgColor && !obj.activeColor && !obj.inactiveColor) return false;
  if (doLight && event.dataTransfer.dropEffect == 'none') return false;

  if (!obj.isColorsSet) {
     obj.inactiveColor = obj.bgColor;
     obj.isColorsSet   = true;
  }

  if (doLight) {
    if (obj.activeColor)
      obj.bgColor = obj.activeColor;
    else if (obj.inactiveColor)
      obj.bgColor = lighterColor(obj.inactiveColor);
  }
  else {
    if (obj.inactiveColor)
      obj.bgColor = obj.inactiveColor;
    else
      obj.removeAttribute("bgColor");
  }
}
      
var lightAddition = 20;
var hex = '0123456789ABCDEF';
function convertHexToDec(h) {
  h1 = hex.indexOf(h.substr(0,1).toUpperCase());
  h2 = hex.indexOf(h.substr(1,1).toUpperCase());
  return (h1 * 16 + h2);
}
function convertDecToHex(d) {
  if (d >= 255) return 'FF';
  if (d <= 0)   return '00';
  d2 = d % 16; d1 = parseInt((d-d2) / 16);
  return hex.substr(d1,1)+hex.substr(d2,1);
}
function lighterColor(c) {
  if (!c) return c;
  if ((c.length != 7) || (c.substr(0,1) != '#')) return c;
  r = convertDecToHex(convertHexToDec(c.substr(1,2)) + lightAddition);
  g = convertDecToHex(convertHexToDec(c.substr(3,2)) + lightAddition);
  b = convertDecToHex(convertHexToDec(c.substr(5,2)) + lightAddition);

  return '#'+r+g+b;
}
// -->
</SCRIPT>
