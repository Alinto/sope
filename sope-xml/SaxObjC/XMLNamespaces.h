/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#ifndef __SaxObjC_XML_Namespaces_H__
#define __SaxObjC_XML_Namespaces_H__

#ifndef XMLNS_OD_BIND
#  define XMLNS_OD_BIND             @"http://www.skyrix.com/od/binding"
#endif
#ifndef XMLNS_OD_CONST
#  define XMLNS_OD_CONST            @"http://www.skyrix.com/od/constant"
#endif
#ifndef XMLNS_OD_ACTION
#  define XMLNS_OD_ACTION           @"http://www.skyrix.com/od/action"
#endif
#ifndef XMLNS_OD_EVALJS
#  define XMLNS_OD_EVALJS           @"http://www.skyrix.com/od/javascript"
#endif
#ifndef XMLNS_XHTML
#  define XMLNS_XHTML               @"http://www.w3.org/1999/xhtml"
#endif
#ifndef XMLNS_HTML40
#  define XMLNS_HTML40              @"http://www.w3.org/TR/REC-html40"
#endif

#ifndef XMLNS_XLINK
#  define XMLNS_XLINK               @"http://www.w3.org/1999/xlink"
#endif

#ifndef XMLNS_XSLT
#  define XMLNS_XSLT                @"http://www.w3.org/1999/XSL/Transform"
#endif
#ifndef XMLNS_XSL_FO
#  define XMLNS_XSL_FO              @"http://www.w3.org/1999/XSL/Format"
#endif

#ifndef XMLNS_RDF
#  define XMLNS_RDF \
     @"http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#endif

#ifndef XMLNS_XUL
#  define XMLNS_XUL \
     @"http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul"
#endif

#ifndef XMLNS_XFORMS
#  define XMLNS_XFORMS @"http://www.w3.org/2001/06/xforms"
#endif

#ifndef XMLNS_SVG
#  define XMLNS_SVG    @"http://www.w3.org/2000/svg"
#endif
#ifndef XMLNS_MATHML
#  define XMLNS_MATHML @"http://www.w3.org/1998/Math/MathML"
#endif

#ifndef XMLNS_WML12
#  define XMLNS_WML12               @"http://www.wapforum.org/DTD/wml_1.2.xml"
#endif

#ifndef XMLNS_XUPDATE
#  define XMLNS_XUPDATE             @"http://www.xmldb.org/xupdate"
#endif

#ifndef XMLNS_WEBDAV
#  define XMLNS_WEBDAV @"DAV:"
#endif

#ifndef XMLNS_XCAL_01
#  define XMLNS_XCAL_01 \
     @"http://www.ietf.org/internet-drafts/draft-ietf-calsch-many-xcal-01.txt"
#endif

#ifndef XMLNS_RELAXNG_STRUCTURE
#  define XMLNS_RELAXNG_STRUCTURE @"http://relaxng.org/ns/structure/1.0"
#endif

#ifndef XMLNS_XINCLUDE
#  define XMLNS_XINCLUDE @"http://www.w3.org/2001/XInclude"
#endif

#ifndef XMLNS_KUPU
#  define XMLNS_KUPU @"http://kupu.oscom.org/namespaces/dist"
#endif

/* Microsoft related namespaces */

#ifndef XMLNS_MS_OFFICE_WORDML
#  define XMLNS_MS_OFFICE_WORDML \
     @"http://schemas.microsoft.com/office/word/2003/wordml"
#endif

#ifndef XMLNS_MS_OFFICE_OFFICE
#  define XMLNS_MS_OFFICE_OFFICE @"urn:schemas-microsoft-com:office:office"
#endif

#ifndef XMLNS_MS_OFFICE_WORD
#  define XMLNS_MS_OFFICE_WORD @"urn:schemas-microsoft-com:office:word"
#endif

#ifndef XMLNS_MS_HOTMAIL
#  define XMLNS_MS_HOTMAIL  @"http://schemas.microsoft.com/hotmail/"
#endif

#ifndef XMLNS_MS_HTTPMAIL
#  define XMLNS_MS_HTTPMAIL @"urn:schemas:httpmail:"
#endif

#ifndef XMLNS_MS_EXCHANGE
#  define XMLNS_MS_EXCHANGE @"http://schemas.microsoft.com/exchange/"
#endif
#ifndef XMLNS_MS_EX_CALENDAR
#  define XMLNS_MS_EX_CALENDAR @"urn:schemas:calendar:"
#endif
#ifndef XMLNS_MS_EX_CONTACTS
#  define XMLNS_MS_EX_CONTACTS @"urn:schemas:contacts:"
#endif

/* WebDAV related namespaces */

#ifndef XMLNS_WEBDAV_APACHE
#  define XMLNS_WEBDAV_APACHE @"http://apache.org/dav/props/"
#endif
#ifndef XMLNS_CADAVER_PROPS
#  define XMLNS_CADAVER_PROPS @"http://webdav.org/cadaver/custom-properties/"
#endif
#ifndef XMLNS_NAUTILUS_PROPS
#  define XMLNS_NAUTILUS_PROPS @"http://services.eazel.com/namespaces"
#endif

/* OpenOffice.org namespaces */

#ifndef XMLNS_OOo_UCB_WEBDAV
#  define XMLNS_OOo_UCB_WEBDAV   @"http://ucb.openoffice.org/dav/props/"
#endif

#ifndef XMLNS_OOo_MANIFEST
#  define XMLNS_OOo_MANIFEST     @"http://openoffice.org/2001/manifest"
#endif

#ifndef XMLNS_OOo_OFFICE
#  define XMLNS_OOo_OFFICE       @"http://openoffice.org/2000/office"
#endif
#ifndef XMLNS_OOo_TEXT
#  define XMLNS_OOo_TEXT         @"http://openoffice.org/2000/text"
#endif
#ifndef XMLNS_OOo_META
#  define XMLNS_OOo_META         @"http://openoffice.org/2000/meta"
#endif
#ifndef XMLNS_OOo_STYLE
#  define XMLNS_OOo_STYLE        @"http://openoffice.org/2000/style"
#endif
#ifndef XMLNS_OOo_TABLE
#  define XMLNS_OOo_TABLE        @"http://openoffice.org/2000/table"
#endif
#ifndef XMLNS_OOo_DRAWING
#  define XMLNS_OOo_DRAWING      @"http://openoffice.org/2000/drawing"
#endif
#ifndef XMLNS_OOo_DATASTYLE
#  define XMLNS_OOo_DATASTYLE    @"http://openoffice.org/2000/datastyle"
#endif
#ifndef XMLNS_OOo_PRESENTATION
#  define XMLNS_OOo_PRESENTATION @"http://openoffice.org/2000/presentation"
#endif
#ifndef XMLNS_OOo_CHART
#  define XMLNS_OOo_CHART        @"http://openoffice.org/2000/chart"
#endif
#ifndef XMLNS_OOo_DRAW3D
#  define XMLNS_OOo_DRAW3D       @"http://openoffice.org/2000/dr3d"
#endif
#ifndef XMLNS_OOo_FORM
#  define XMLNS_OOo_FORM         @"http://openoffice.org/2000/form"
#endif
#ifndef XMLNS_OOo_SCRIPT
#  define XMLNS_OOo_SCRIPT       @"http://openoffice.org/2000/script"
#endif

#ifndef XMLNS_DublinCore
#  define XMLNS_DublinCore @"http://purl.org/dc/elements/1.1/"
#endif

#ifndef XMLNS_PROPRIETARY_SLOX
#  define XMLNS_PROPRIETARY_SLOX @"SLOX:"
#endif

/* Zope */

#ifndef XMLNS_Zope_TAL
#  define XMLNS_Zope_TAL @"http://xml.zope.org/namespaces/tal"
#endif
#ifndef XMLNS_Zope_METAL
#  define XMLNS_Zope_METAL @"http://xml.zope.org/namespaces/metal"
#endif

/* SOAP */

#ifndef XMLNS_SOAP_ENVELOPE
#  define XMLNS_SOAP_ENVELOPE @"http://schemas.xmlsoap.org/soap/envelope/"
#endif
#ifndef XMLNS_SOAP_ENCODING
#  define XMLNS_SOAP_ENCODING @"http://schemas.xmlsoap.org/soap/encoding/"
#endif

#ifndef XMLNS_XMLSchema
#  define XMLNS_XMLSchema @"http://www.w3.org/1999/XMLSchema"
#endif
#ifndef XMLNS_XMLSchemaInstance1999
#  define XMLNS_XMLSchemaInstance1999 \
            @"http://www.w3.org/1999/XMLSchema-instance"
#endif
#ifndef XMLNS_XMLSchemaInstance2001
#  define XMLNS_XMLSchemaInstance2001 \
            @"http://www.w3.org/2001/XMLSchema-instance"
#endif

/* Novell */

#ifndef XMLNS_Novell_NCSP_Types
#  define XMLNS_Novell_NCSP_Types \
            @"http://schemas.novell.com/2003/10/NCSP/types.xsd"
#endif
#ifndef XMLNS_Novell_NCSP_Methods
#  define XMLNS_Novell_NCSP_Methods \
            @"http://schemas.novell.com/2003/10/NCSP/methods.xsd"
#endif

/* XML vCards */

#ifndef XMLNS_VCARD_XML_03
#  define XMLNS_VCARD_XML_03 \
     @"http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-03.txt"
#endif

/* ATOM */

#ifndef XMLNS_ATOM_2005
#  define XMLNS_ATOM_2005 @"http://www.w3.org/2005/Atom"
#endif

/* Google */

#ifndef XMLNS_GOOGLE_2005
#  define XMLNS_GOOGLE_2005 @"http://schemas.google.com/g/2005"
#endif

#ifndef XMLNS_GOOGLE_CAL_2005
#  define XMLNS_GOOGLE_CAL_2005 @"http://schemas.google.com/gCal/2005"
#endif

#ifndef XMLNS_OPENSEARCH_RSS
#  define XMLNS_OPENSEARCH_RSS @"http://a9.com/-/spec/opensearchrss/1.0/"
#endif

/* GroupDAV */

#ifndef XMLNS_GROUPDAV
#  define XMLNS_GROUPDAV @"http://groupdav.org/"
#endif

/* CalDAV / CardDAV */

#ifndef XMLNS_CALDAV
#  define XMLNS_CALDAV @"urn:ietf:params:xml:ns:caldav"
#endif

#ifndef XMLNS_CARDDAV
#  define XMLNS_CARDDAV @"urn:ietf:params:xml:ns:carddav"
#endif

/* Apple CalServer */

#ifndef XMLNS_AppleCalServer
#  define XMLNS_AppleCalServer @"http://apple.com/ns/calendarserver/"
#endif
#ifndef XMLNS_CalendarServerOrg
#  define XMLNS_CalendarServerOrg @"http://calendarserver.org/ns/"
#endif
#ifndef XMLNS_AppleCalApp
#  define XMLNS_AppleCalApp @"com.apple.ical:"
#endif

/* Adobe */

#ifndef XMLNS_MXML_2006
#  define XMLNS_MXML_2006 @"http://www.adobe.com/2006/mxml"
#endif

#endif /* __SaxObjC_XML_Namespaces_H__ */
