



// Fix for bug in IE6.0 float handling (don't ask, don't tell ;)

if (document.all && window.attachEvent) window.attachEvent("onload", fixWinIE);
function fixWinIE() {
    try {
        document.getElementById('content').style.display = 'block';
    } catch(er) {}
}


// The calendar popup show/hide:

    function showDay(date) {
        document.getElementById('day' + date).style.visibility = 'visible';
        return true;
    }
    
    function hideDay(date) {
        document.getElementById('day' + date).style.visibility = 'hidden';
        return true;
    }

// Focus on error or tabindex=1
if (window.addEventListener) window.addEventListener("load",setFocus,false);
else if (window.attachEvent) window.attachEvent("onload",setFocus);
function setFocus() {
    var xre = new RegExp(/\berror\b/);
    // Search only forms to avoid spending time on regular text
    for (var f = 0; (formnode = document.getElementsByTagName('form').item(f)); f++) {
        // Search for errors first, focus on first error if found
        for (var i = 0; (node = formnode.getElementsByTagName('div').item(i)); i++) {
            if (xre.exec(node.className)) {
                for (var j = 0; (inputnode = node.getElementsByTagName('input').item(j)); j++) {
                    inputnode.focus();
                    return;   
                }
            }
        }
        // If no error, focus on input element with tabindex 1
        for (var i = 0; (node = formnode.getElementsByTagName('input').item(i)); i++) {
            if (node.getAttribute('tabindex') == 1) {
                 node.focus();
                 return;   
            }
        }
    }
}

/********* Table sorter script *************/
// Table sorter script, thanks to Geir B�kholt for this.
// DOM table sorter originally made by Paul Sowden 

function compare(a,b)
{
    au = new String(a);
    bu = new String(b);

    if (au.charAt(4) != '-' && au.charAt(7) != '-')
    {
    var an = parseFloat(au)
    var bn = parseFloat(bu)
    }
    if (isNaN(an) || isNaN(bn))
        {as = au.toLowerCase()
         bs = bu.toLowerCase()
        if (as > bs)
            {return 1;}
        else
            {return -1;}
        }
    else {
    return an - bn;
    }
}



function getConcatenedTextContent(node) {
    var _result = "";
	  if (node == null) {
		    return _result;
	  }
    var childrens = node.childNodes;
    var i = 0;
    while (i < childrens.length) {
        var child = childrens.item(i);
        switch (child.nodeType) {
            case 1: // ELEMENT_NODE
            case 5: // ENTITY_REFERENCE_NODE
                _result += getConcatenedTextContent(child);
                break;
            case 3: // TEXT_NODE
            case 2: // ATTRIBUTE_NODE
            case 4: // CDATA_SECTION_NODE
                _result += child.nodeValue;
                break;
            case 6: // ENTITY_NODE
            case 7: // PROCESSING_INSTRUCTION_NODE
            case 8: // COMMENT_NODE
            case 9: // DOCUMENT_NODE
            case 10: // DOCUMENT_TYPE_NODE
            case 11: // DOCUMENT_FRAGMENT_NODE
            case 12: // NOTATION_NODE
                // skip
                break;
        }
        i ++;
    }
  	return _result;
}



function sort(e) {
    var el = window.event ? window.event.srcElement : e.currentTarget;

    // a pretty ugly sort function, but it works nonetheless
    var a = new Array();
    // check if the image or the th is clicked. Proceed to parent id it is the image
    // NOTE THAT nodeName IS UPPERCASE
    if (el.nodeName == 'IMG') el = el.parentNode;
    //var name = el.firstChild.nodeValue;
    // This is not very robust, it assumes there is an image as first node then text
    var name = el.childNodes.item(1).nodeValue;
    var dad = el.parentNode;
    var node;
    
    // kill all arrows
    for (var im = 0; (node = dad.getElementsByTagName("th").item(im)); im++) {
        // NOTE THAT nodeName IS IN UPPERCASE
        if (node.lastChild.nodeName == 'IMG')
        {
            lastindex = node.getElementsByTagName('img').length - 1;
            node.getElementsByTagName('img').item(lastindex).setAttribute('src','http://docs.opengroupware.org/arrowBlank.gif');
        }
    }
    
    for (var i = 0; (node = dad.getElementsByTagName("th").item(i)); i++) {
        var xre = new RegExp(/\bnosort\b/);
        // Make sure we are not messing with nosortable columns, then check second node.
        if (!xre.exec(node.className) && node.childNodes.item(1).nodeValue == name) 
        {
            //window.alert(node.childNodes.item(1).nodeValue;
            lastindex = node.getElementsByTagName('img').length -1;
            node.getElementsByTagName('img').item(lastindex).setAttribute('src','http://docs.opengroupware.org/arrowUp.gif');
            break;
        }
    }

    var tbody = dad.parentNode.parentNode.getElementsByTagName("tbody").item(0);
    for (var j = 0; (node = tbody.getElementsByTagName("tr").item(j)); j++) {

        // crude way to sort by surname and name after first choice
        a[j] = new Array();
        a[j][0] = getConcatenedTextContent(node.getElementsByTagName("td").item(i));
        a[j][1] = getConcatenedTextContent(node.getElementsByTagName("td").item(1));
        a[j][2] = getConcatenedTextContent(node.getElementsByTagName("td").item(0));		
        a[j][3] = node;
    }

    if (a.length > 1) {
	
        a.sort(compare);

        // not a perfect way to check, but hell, it suits me fine
        if (a[0][0] == getConcatenedTextContent(tbody.getElementsByTagName("tr").item(0).getElementsByTagName("td").item(i))
	       && a[1][0] == getConcatenedTextContent(tbody.getElementsByTagName("tr").item(1).getElementsByTagName("td").item(i))) 
        {
            a.reverse();
            lastindex = el.getElementsByTagName('img').length - 1;
            el.getElementsByTagName('img').item(lastindex).setAttribute('src','http://docs.opengroupware.org/arrowDown.gif');
        }

    }
	
    for (var j = 0; j < a.length; j++) {
        tbody.appendChild(a[j][3]);
    }
}
    
function init(e) {
    var tbls = document.getElementsByTagName('table');
    for (var t = 0; t < tbls.length; t++)
        {
        // elements of class="listing" can be sorted
        var re = new RegExp(/\blisting\b/)
        // elements of class="nosort" should not be sorted
        var xre = new RegExp(/\bnosort\b/)
        if (re.exec(tbls[t].className) && !xre.exec(tbls[t].className))
        {
            try {
                var tablename = tbls[t].getAttribute('id');
                var thead = document.getElementById(tablename).getElementsByTagName("thead").item(0);
                var node;
                // set up blank spaceholder gifs
                blankarrow = document.createElement('img');
                blankarrow.setAttribute('src','http://docs.opengroupware.org/arrowBlank.gif');
                blankarrow.setAttribute('height',6);
                blankarrow.setAttribute('width',9);
                // the first sortable column should get an arrow initially.
                initialsort = false;
                for (var i = 0; (node = thead.getElementsByTagName("th").item(i)); i++) {
                    // check that the columns does not have class="nosort"
                    if (!xre.exec(node.className)) {
                        node.insertBefore(blankarrow.cloneNode(1), node.firstChild);
                        if (!initialsort) {
                            initialsort = true;
                            uparrow = document.createElement('img');
                            uparrow.setAttribute('src','http://docs.opengroupware.org/arrowUp.gif');
                            uparrow.setAttribute('height',6);
                            uparrow.setAttribute('width',9);
                            node.appendChild(uparrow);
                        } else {
                            node.appendChild(blankarrow.cloneNode(1));
                        }
    
                        if (node.addEventListener) node.addEventListener("click",sort,false);
                        else if (node.attachEvent) node.attachEvent("onclick",sort);
                    }
                }
            } catch(er) {}
        }
    }
}

// initialize the sorter functions 
// add stuff to secure it from broken DOM-implanetations or missing objects.
   
    
    	
//    p.appendChild(document.createTextNode("Change sorting by clicking on each individual heading."));
//    document.getElementById(tablename).parentNode.insertBefore(p,document.getElementById(tablename));
    

if (window.addEventListener) window.addEventListener("load",init,false);
else if (window.attachEvent) window.attachEvent("onload",init);

       
// **** End table sort script ***



// Actions used in the folder_contents view

function submitFolderAction(folderAction) {
    document.folderContentsForm.action = document.folderContentsForm.action+'/'+folderAction;
    document.folderContentsForm.submit();
}

function submitFilterAction() {
    document.folderContentsForm.action = document.folderContentsForm.action+'/folder_contents';
    filter_selection=document.getElementById('filter_selection');
    for (var i =0; i < filter_selection.length; i++){
        if (filter_selection.options[i].selected) {
            if (filter_selection.options[i].value=='#') {
                document.folderContentsForm.filter_state.value='clear_view_filter';
            }
            else {
                document.folderContentsForm.filter_state.value='set_view_filter'
            }
        }						
    }
    document.folderContentsForm.submit();
}
    

// Functions for selecting all checkboxes in folder_contents view

isSelected = false;

function selectAll() {
  checkboxes = document.getElementsByName('ids:list');
  for (i = 0; i < checkboxes.length; i++)
    checkboxes[i].checked = true ;
  isSelected = true;
  return isSelected;
}

function deselectAll() {
  checkboxes = document.getElementsByName('ids:list');
  for (i = 0; i < checkboxes.length; i++)
    checkboxes[i].checked = false ;
  isSelected = false;
  return isSelected;
}

function toggleSelect(selectbutton) {
  if (isSelected == false) {
    selectbutton.setAttribute('src','http://docs.opengroupware.org/select_none_icon.gif');
    return selectAll();
  }
  else {
    selectbutton.setAttribute('src','http://docs.opengroupware.org/select_all_icon.gif');
    return deselectAll();
  }
}
