
print("setup WoPage1 ...");

var a = 3;
var b = 5;
var c = 0;
var txt = "Hello World !"

function addAB() {
  c = a + b;
  return c;
}

function gotoPage2() {
  print("goto page 2 ...");
  var page = pageWithName("Page2");
  print("  page: " + page);
  return page;
}
