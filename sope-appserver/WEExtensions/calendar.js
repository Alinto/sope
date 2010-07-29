var monthArray = getMonthSelect();
var calDateField;
var calDate;


// innerHTML IS ONLY SUPPORTED BY MSIE...
function rewriteLayerWithData(obj,data) {
  if (isNav) {
    obj.document.clear();
    obj.document.write(data);
    obj.document.close();
  }
  if (isIE) {
    obj.innerHTML = data;
  }
  if (usesNavImages) {
    document.images['dateFieldFirstImg'].src = dateFieldFirst.src;
    document.images['dateFieldPreviousImg'].src = dateFieldPrevious.src;
    document.images['dateFieldTodayImg'].src = dateFieldToday.src;
    document.images['dateFieldNextImg'].src = dateFieldNext.src;
    document.images['dateFieldLastImg'].src = dateFieldLast.src;
    document.images['dateFieldCloseImg'].src = dateFieldClose.src;
  }
}

// DETERMINE BROWSER BRAND
var isNav = false;
var isIE  = false;

if (navigator.appName == "Netscape") {
    isNav = true;
}
else {
    isIE = true;
}

// PRE-BUILD PORTIONS OF THE CALENDAR WHEN THIS JS LIBRARY LOADS INTO THE BROWSER
buildCalParts();


// CALENDAR FUNCTIONS BEGIN HERE ---------------------------------------------------



// SET THE INITIAL VALUE OF THE GLOBAL DATE FIELD
function setDateField(dateField) {

    // ASSIGN THE INCOMING FIELD OBJECT TO A GLOBAL VARIABLE
    calDateField = dateField;    

    // GET THE VALUE OF THE INCOMING FIELD
    inDate = dateField.value;

    // SET calDate TO THE DATE IN THE INCOMING FIELD OR DEFAULT TO TODAY'S DATE
    setInitialDate();

}


// SET THE INITIAL CALENDAR DATE TO TODAY OR TO THE EXISTING VALUE IN dateField
function setInitialDate() {
   
    // CREATE A NEW DATE OBJECT (WILL GENERALLY PARSE CORRECT DATE EXCEPT WHEN "." IS USED AS A DELIMITER)
    // (THIS ROUTINE DOES *NOT* CATCH ALL DATE FORMATS, IF YOU NEED TO PARSE A CUSTOM DATE FORMAT, DO IT HERE)
    // ADD CUSTOM DATE PARSING HERE

    ypos = dateFormat.indexOf('%Y');
    inYear = parseInt(inDate.substr(ypos,4));

    mpos = dateFormat.indexOf('%m');
    if (ypos < mpos) mpos+=2;  // because %Y stands for yyyy, add 2
    inMonth = inDate.substr(mpos,2);
    if (inMonth.charAt(0) == "0") 
      inMonth = inMonth.substr(1,inMonth.length-1);
    inMonth = parseInt(inMonth);
    
    dpos = dateFormat.indexOf('%d');
    if (ypos < dpos) dpos+=2;  // same as mpos
    inDay = inDate.substr(dpos,2);
    if (inDay.charAt(0) == "0") 
      inDay = inDay.substr(1,inDay.length-1);
    inDay = parseInt(inDay);

    if ((inYear) && (inMonth) && (inDay)) {

        calDate = new Date(inYear,inMonth-1,inDay);
    }
    else {

	calDate = new Date();
    }

    // KEEP TRACK OF THE CURRENT DAY VALUE
    calDay  = calDate.getDate();

    // SET DAY VALUE TO 1... TO AVOID JAVASCRIPT DATE CALCULATION ANOMALIES
    // (IF THE MONTH CHANGES TO FEB AND THE DAY IS 30, THE MONTH WOULD CHANGE TO MARCH
    //  AND THE DAY WOULD CHANGE TO 2.  SETTING THE DAY TO 1 WILL PREVENT THAT)
    calDate.setDate(1);
}


// ENABLE MULTIPLE CALENDAR-USING OBJECTS BY USING VARIABLE calendarDiv;
var calendarDiv = false;

function toggleCalendar(dateFieldEl,calObj,calFormat) {
  if ((calendarDiv) &&  (calendarDiv.id != calObj.id)) {
    hideCalendar();
  }
  calendarDiv = calObj;
  
  if (isNav) condition = (calendarDiv.visibility == 'show');
  if (isIE)  condition = (calendarDiv.style.visibility    == 'visible');
  if (condition) {
    hideCalendar();
  }
  else {
    var i,j;
    var dateField;

    for (i = 0; i < document.forms.length; i++) {
      for (j = 0; j < document.forms[i].elements.length; j++) {
        if (document.forms[i].elements[j].name == dateFieldEl) {
          dateField = document.forms[i].elements[j];
        }
      }
    }
    dateFormat = calFormat;
    showCalendar(dateField);
  }
}

// CAPTURE onMouseMove EVENT IF NETSCAPE FOR POSITIONING calendarDiv

if (isNav) {
  document.captureEvents( Event.MOUSEMOVE );
  document.onmousemove = actPos;
}

var curScreenPosX;
var curScreenPosY;

function actPos(e) {
  
  curScreenPosX = e.pageX + 10;
  curScreenPosY = e.pageY;
  return true;
}


function showCalendar(dateField) {

    // SET INITIAL VALUE OF THE DATE FIELD AND CREATE TOP AND BOTTOM FRAMES
    setDateField(dateField);

    writeCalendar();
    if (isNav) {
      calendarDiv.visibility   = 'show';
      calendarDiv.left = curScreenPosX;
      calendarDiv.top  = curScreenPosY;
    }
    if (isIE) {
      calendarDiv.style.visibility      = 'visible';
    }

    return true;
}

function hideCalendar() {
    if (isNav) {
      calendarDiv.visibility = 'hide';
    }
    if (isIE) {
      calendarDiv.style.visibility = 'hidden';
    }
    calendarDiv = false;
}

// NEW: NO FRAMES ANYMORE, ONE <DIV> INSTEAD
function writeCalendar() {

  data = buildTopCalFrame() + buildBottomCalFrame();
  if (isNav) rewriteLayerWithData(calendarDiv, data);
  if (isIE)  rewriteLayerWithData(calendarDiv, data);
}


// CREATE month/year DISPLAY
function buildCalControlMonthYear() {
  month = calDate.getMonth();
  year  = calDate.getFullYear();
  return String(monthArray[month])+" "+String(year);
}



var obj=false;
var X,Y;

function MD() {
  if (isIE) {
    ob = true;
    X=event.offsetX;
    Y=event.offsetY;
    document.onmousemove = MM;
    document.onmouseup   = MU;
  }
}

function MM() {
  if (ob) {
    calendarDiv.style.pixelLeft = event.clientX-X + document.body.scrollLeft;
    calendarDiv.style.pixelTop = event.clientY-Y + document.body.scrollTop;
    return false;
  }
}

function MU() {
  ob = false;
//  document.onmousemove = null;
//  document.onmouseup   = null;
}

// CREATE THE TOP CALENDAR PART
function buildTopCalFrame() {

     var calDoc =
       "<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD BGCOLOR=black>" +
       "<TABLE CELLPADDING=0 CELLSPACING=1 BORDER=0>" +
       "<TR><TD COLSPAN=6 ALIGN=left CLASS=topCal onMouseDown='MD()'>" +
       buildCalControlMonthYear() +
       "</TD>" +
       "<TD ALIGN=right CLASS=topCal>"+
       "<A CLASS=navMonYear HREF='javascript:hideCalendar()'>" +
       dateFieldCloseSRC+"</A>&nbsp;</TD></TR>" +
       "<TR>" +
       "<TD COLSPAN=7 CLASS=topCal ALIGN=center><FONT SIZE=1 FACE='Arial'>"+
       "<A CLASS=navMonYear HREF='javascript:setPreviousYear()'>"+
       dateFieldFirstSRC+"</A>" +
       " <A CLASS=navMonYear HREF='javascript:setPreviousMonth()'>"+
       dateFieldPreviousSRC+"</A>" +
       " <A CLASS=navMonYear HREF='javascript:setToday()'>"+
       dateFieldTodaySRC+"</A>" +
       " <A CLASS=navMonYear HREF='javascript:setNextMonth()'>"+
       dateFieldNextSRC+"</A>"+
       " <A CLASS=navMonYear HREF='javascript:setNextYear()'>"+
       dateFieldLastSRC+"</A>" +
       "</FONT></TD>" +
       "</TR>";
   return calDoc;
}


// CREATE THE BOTTOM CALENDAR PART
function buildBottomCalFrame() {       

    // START CALENDAR DOCUMENT
    var calDoc = calendarBegin;

    // GET MONTH, AND YEAR FROM GLOBAL CALENDAR DATE
    month   = calDate.getMonth();
    year    = calDate.getFullYear();


    // GET GLOBALLY-TRACKED DAY VALUE (PREVENTS JAVASCRIPT DATE ANOMALIES)
    day     = calDay;

    var i   = 0;

    // DETERMINE THE NUMBER OF DAYS IN THE CURRENT MONTH
    var days = getDaysInMonth();

    // IF GLOBAL DAY VALUE IS > THAN DAYS IN MONTH, HIGHLIGHT LAST DAY IN MONTH
    if (day > days) {
        day = days;
    }

    // DETERMINE WHAT DAY OF THE WEEK THE CALENDAR STARTS ON
    var firstOfMonth = new Date (year, month, 1);

    // GET THE DAY OF THE WEEK THE FIRST DAY OF THE MONTH FALLS ON
    var startingPos  = firstOfMonth.getDay();
    days += startingPos;

    // KEEP TRACK OF THE COLUMNS, START A NEW ROW AFTER EVERY 7 COLUMNS
    var columnCount = 0;

    // MAKE BEGINNING NON-DATE CELLS BLANK
    for (i = 0; i < startingPos; i++) {

        calDoc += blankCell;
	columnCount++;
    }

    // SET VALUES FOR DAYS OF THE MONTH
    var currentDay = 0;
    var dayType    = "weekday";

    // DATE CELLS CONTAIN A NUMBER
    for (i = startingPos; i < days; i++) {

	var paddingChar = "&nbsp;";

        // ADJUST SPACING SO THAT ALL LINKS HAVE RELATIVELY EQUAL WIDTHS
        if (i-startingPos+1 < 10) {
            padding = "&nbsp;&nbsp;";
        }
        else {
            padding = "&nbsp;";
        }

        // GET THE DAY CURRENTLY BEING WRITTEN
        currentDay = i-startingPos+1;

        // SET THE TYPE OF DAY, THE focusDay GENERALLY APPEARS AS A DIFFERENT COLOR
        if (currentDay == day) {
            dayType = "focusDay";
        }
        else {
            dayType = "weekDay";
        }

        // ADD THE DAY TO THE CALENDAR STRING
        calDoc += "<TD align=center bgcolor='lightgrey'>" +
                  "<a class='" + dayType + "' href='javascript:returnDate(" + 
                  currentDay + ")'>" + padding + currentDay + paddingChar + "</a></TD>";

        columnCount++;

        // START A NEW ROW WHEN NECESSARY
        if (columnCount % 7 == 0) {
            calDoc += "</TR><TR>";
        }
    }

    // MAKE REMAINING NON-DATE CELLS BLANK
    for (i=days; i<42; i++)  {

        calDoc += blankCell;
	columnCount++;

        // START A NEW ROW WHEN NECESSARY
        if (columnCount % 7 == 0) {
            calDoc += "</TR>";
            if (i<41) {
                calDoc += "<TR>";
            }
        }
    }

    // FINISH THE NEW CALENDAR PAGE
    calDoc += calendarEnd;

    // RETURN THE COMPLETED CALENDAR PAGE
    return calDoc;
}


// SET THE CALENDAR TO TODAY'S DATE AND DISPLAY THE NEW CALENDAR
function setToday() {

    // SET GLOBAL DATE TO TODAY'S DATE
    calDate = new Date();

    // DISPLAY THE NEW CALENDAR
    writeCalendar();
}


// SET THE GLOBAL DATE TO THE PREVIOUS YEAR AND REDRAW THE CALENDAR
function setPreviousYear() {

    var year  = calDate.getFullYear();

    if (year > 1000) {
        year--;
        calDate.setFullYear(year);
        writeCalendar();
    }
}


// SET THE GLOBAL DATE TO THE PREVIOUS MONTH AND REDRAW THE CALENDAR
function setPreviousMonth() {

    var year  = calDate.getFullYear();
    var month = calDate.getMonth();
   
    // IF MONTH IS JANUARY, SET MONTH TO DECEMBER AND DECREMENT THE YEAR
    if (month == 0) {
        month = 11;
        if (year > 1000) {
            year--;
            calDate.setFullYear(year);
        }
    }
    else {
        month--;
    }
    calDate.setMonth(month);
    writeCalendar();
}


// SET THE GLOBAL DATE TO THE NEXT MONTH AND REDRAW THE CALENDAR
function setNextMonth() {

    var year = calDate.getFullYear();

        var month = calDate.getMonth();

        // IF MONTH IS DECEMBER, SET MONTH TO JANUARY AND INCREMENT THE YEAR
        if (month == 11) {
            month = 0;
            year++;
            calDate.setFullYear(year);
        }
        else {
            month++;
        }
        calDate.setMonth(month);
        writeCalendar();
}


// SET THE GLOBAL DATE TO THE NEXT YEAR AND REDRAW THE CALENDAR
function setNextYear() {

    var year  = calDate.getFullYear();
        year++;
        calDate.setFullYear(year);
        writeCalendar();
}


// GET NUMBER OF DAYS IN MONTH
function getDaysInMonth()  {

    var days;
    var month = calDate.getMonth()+1;
    var year  = calDate.getFullYear();

    // RETURN 31 DAYS
    if (month==1 || month==3 || month==5 || month==7 || month==8 ||
        month==10 || month==12)  {
        days=31;
    }
    // RETURN 30 DAYS
    else if (month==4 || month==6 || month==9 || month==11) {
        days=30;
    }
    // RETURN 29 DAYS
    else if (month==2)  {
        if (isLeapYear(year)) {
            days=29;
        }
        // RETURN 28 DAYS
        else {
            days=28;
        }
    }
    return (days);
}


// CHECK TO SEE IF YEAR IS A LEAP YEAR
function isLeapYear (Year) {

    if (((Year % 4)==0) && ((Year % 100)!=0) || ((Year % 400)==0)) {
        return (true);
    }
    else {
        return (false);
    }
}


// BUILD THE MONTH SELECT LIST
function getMonthSelect() {

    // IF SET BY A PARAMETER (WRITTEN AT THE BEGINNING BY WOCalendar)
    if (externMonths) {
      monthArray = externMonths;
    }
    else {
        monthArray = new Array('January', 'February', 'March', 'April', 
           'May', 'June', 'July', 'August', 
           'September', 'October', 'November', 'December');
    }
    return monthArray;
}


// SET DAYS OF THE WEEK DEPENDING ON LANGUAGE
function createWeekdayList() {

    // IF SET BY A PARAMETER (WRITTEN AT THE BEGINNING BY WODateFieldScript)
    if (externWeekdays) {
      weekdayArray = externWeekdays;
    }
    else {
        weekdayArray = new Array('Su','Mo','Tu','We','Th','Fr','Sa');
    }

    var weekdays = "<TR BGCOLOR='white'>";
    for (i in weekdayArray) {
        weekdays += "<TD class='heading' align=center>"
                 + weekdayArray[i] + "</TD>";
    }
    weekdays += "</TR>";

    return weekdays;
}


// PRE-BUILD PORTIONS OF THE CALENDAR (FOR PERFORMANCE REASONS)
function buildCalParts() {

    // BUILD THE BLANK CELL ROWS
    blankCell = "<TD align=center bgcolor='lightGrey'>&nbsp;&nbsp;&nbsp;</TD>";

    // BUILD THE TOP PORTION OF THE CALENDAR PAGE USING CSS TO CONTROL SOME DISPLAY ELEMENTS
    calendarBegin = createWeekdayList() + "<TR>";

    // BUILD THE BOTTOM PORTION OF THE CALENDAR PAGE
    calendarEnd = "";

        // END THE TABLE AND HTML DOCUMENT
        calendarEnd +=
            "</TABLE></TD></TR></TABLE>";
}


// REPLACE ALL INSTANCES OF find WITH replace
// inString: the string you want to convert
// find:     the value to search for
// replace:  the value to substitute
//
// usage:    jsReplace(inString, find, replace);
// example:  jsReplace("To be or not to be", "be", "ski");
//           result: "To ski or not to ski"
//
function jsReplace(inString, find, replace) {

    var outString = "";

    if (!inString) {
        return "";
    }

    // REPLACE ALL INSTANCES OF find WITH replace
    if (inString.indexOf(find) != -1) {
        // SEPARATE THE STRING INTO AN ARRAY OF STRINGS USING THE VALUE IN find
        t = inString.split(find);

        // JOIN ALL ELEMENTS OF THE ARRAY, SEPARATED BY THE VALUE IN replace
        return (t.join(replace));
    }
    else {
        return inString;
    }
}


// JAVASCRIPT FUNCTION -- DOES NOTHING (USED FOR THE HREF IN THE CALENDAR CALL)
function doNothing() {
}


// ENSURE THAT VALUE IS TWO DIGITS IN LENGTH
function makeTwoDigit(inValue) {

    var numVal = parseInt(inValue, 10);

    // VALUE IS LESS THAN TWO DIGITS IN LENGTH
    if (numVal < 10) {

        // ADD A LEADING ZERO TO THE VALUE AND RETURN IT
        return("0" + numVal);
    }
    else {
        return numVal;
    }
}


// SET FIELD VALUE TO THE DATE SELECTED AND CLOSE THE CALENDAR WINDOW
function returnDate(inDay)
{

    // inDay = THE DAY THE USER CLICKED ON
    calDate.setDate(inDay);

    // SET THE DATE RETURNED TO THE USER
    var day           = calDate.getDate();
    var month         = calDate.getMonth()+1;
    var year          = calDate.getFullYear();

    outDate = dateFormat;
    outDate = jsReplace(outDate,'%Y',String(year));
    outDate = jsReplace(outDate,'%m',makeTwoDigit(month));
    outDate = jsReplace(outDate,'%d',makeTwoDigit(day));

    // SET THE VALUE OF THE FIELD THAT WAS PASSED TO THE CALENDAR
    calDateField.value = outDate;

    // CLOSE THE CALENDAR WINDOW
    hideCalendar();
}
