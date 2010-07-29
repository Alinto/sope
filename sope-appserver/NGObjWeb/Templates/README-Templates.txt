How Templates Work ...
======================

In general we have two kinds of templates, XML based ones and "hash" based 
ones.
The 'hash' templates are simple scanners for strings which start and end with 
"<#" and "</#", while the XML based templates are valid and "namespace'd" XML 
files.

Practical difference:
- XML templates can be created, parsed, transformed, ... with any standard XML
  tool
- hash templates can be used in a non-tag way, eg this is a valid template:
    <a href="<#MyHRef/>">blah</a>
  Since unlike the XML parser the hash parser only scans for "<#", this is OK.
- hash templates use "wod" files for declarations which may or may not improve
  the visual clutter in the template itself
- XML templates do not need to have a 1:1 mapping from tag to WODynamicElement
  and the mapping between tag and element is completely controlled by the
  builder while for hash templates you always use the actuall WODynamicElement
  subclass name in the .wod file

Class Overview
==============

WOTemplate (WOElement)
- an WOElement subclass
- this represents the 'real' root element of the template and contains some
  additional information like the URL it was loaded from and the subcomponents
  declared in the template
- an WOTemplate object will be bound to a WOComponent once instantiated

WOSubcomponentInfo
- used in WOTemplate to track information on the subcomponents declared in
  the template (like bindings and component name)
- if a WOComponent is instantiated this will be used to construct the 
  subcomponents

WODParser
- a parser for the .wod file format
- works someone like a SAX parser and requires a delegate to collect the
  actual information out of the parsed objects

WOHTMLParser
- the parser for the "hash" template format
- requires a callback for instantiation of dynamic elements

WOComponentScript / WOComponentScriptPart
- this is used to collect server side template scripts declared in an
  XML file or or in a name-associated file (eg Main.js). sample:
    <script runat='server'>a = 1 + 2;</script>
- a WOComponentScriptPart is one entry while WOComponentScript is the set of
  all entries (which usually will be joined into one script for evaluation)

WOTemplateBuilder
- the common superclass for the XML and hash based builder classes
- also acts as the build "registry"
    + (WOTemplateBuilder *)templateBuilderForURL:(NSURL *)_url
  this currently returns the WOxTemplateBuilder for .wox extensions and the
  hash builder for all other templates
- one API method:
    - (WOTemplate *)buildTemplateAtURL:(NSURL *)_url

WOWrapperTemplateBuilder (WOTemplateBuilder)
- subclass of WOTemplateBuilder for "hash" templates
- uses WOHTMLParser and WODParser for processing .wo wrappers
- supports language projects inside wrappers (eg a.wo/English.lproj/a.html)
- looks for JavaScript component scripts (Name.js files)

_WODFileEntry
- used in WOWrapperTemplateBuilder
- somewhat like WOSubcomponentInfo, contains information on a parsed WOD
  entry (will be stored in a name=>entry map)

WOxTemplateBuilder (WOTemplateBuilder)
- subclass of WOTemplateBuilder for XML templates (also called 'wox' templates)
- defaults: WOxBuilderClasses
- also scans for "WOxElemBuilder" resources using NGBundleManager
- this one parses a DOM tree from the "build-URL" and then delegates the actual
  building to so called "element builders" (subclasses of WOxElemBuilder)

WOxElemBuilder
- superclass for all other element builders
- has a 'nextBuilder' for passing on unsupported tags

WOxElemBuilderComponentInfo
- somewhat like _WODFileEntry,
- used in WOxElemBuilder for tracking subcomponent references
- some API:
  - (WOElement *)buildTemplateFromDocument:(id<DOMDocument>)_document;
  - (WOElement *)buildNode:(id<DOMNode>)_node templateBuilder:(id)_bld;
  - (NSArray *)buildNodes:(id<DOMNodeList>)_node templateBuilder:(id)_bld;
- also manages WOAssociation to namespace mappings, binds a WOAssociation 
  subclass to a certain namespace, eg:
    "var" => "WOKeyValueAssociation"
    "<td var:width='calculatedWidth'>"

WOxComponentElemBuilder (WOxElemBuilder)
- build subcomponent references:
  - WOChildComponentReference
  - WOComponentReference
  (but currently no WOSwitchComponent?)
- processes: "<script>", "<component>"
- fallback is: use tagname (not recommended), eg:
  <var:Main/>

WOxTagClassElemBuilder (WOxElemBuilder)
- superclass for builders which map an XML tag to a WODynamicElement
- subclasses can return the class required using:
    - (Class)classForElement:(id<DOMElement>)_element
  everything else will be managed by the tag-builder
