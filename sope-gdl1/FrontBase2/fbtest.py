#!/usr/bin/env python
# $Id: fbtest.py 2 2004-08-20 10:48:47Z znek $

from Foundation import *
from eoaccess import *

conDict = { 'userName':     "skyrix",
            'databaseName': "Skyrix",
            'hostName':     "inster" }

adaptor = EOAdaptor(name='FrontBase2')
adaptor.setConnectionDictionary(conDict)
print "got adaptor ",  adaptor.invoke0("class");

ctx = adaptor.createAdaptorContext()
ch  = ctx.createAdaptorChannel()

model = EOModel(contentsOfFile='test.eomodel')
adaptor.setModel(model)
adaptor.setConnectionDictionary(conDict)

ch.setDebugEnabled(YES)

if ch.openChannel():
    print "channel is open"

    if ctx.beginTransaction():
        print "began tx .."

        pool = NSAutoreleasePool()
        
        e     = model.entityNamed('Person')
        q     = e.qualifier()
        attrs = e.attributes()

        if ch.selectAttributes(attrs, q):
            record = ch.fetchAttributes(attrs)
            while record is not None:
                print "  login=%(login)s name=%(name)s bday=%(birthday)s" % \
                      record
                record = ch.fetchAttributes(attrs)
        
        del pool
        
        pool = NSAutoreleasePool()

        e     = model.entityNamed('Person')
        attrs = e.attributes()
        q     = EOKeyValueQualifier('login', EOQualifierOperatorEqual, 'helge')
        q     = q.sqlQualifierForEntity(e)

        if ch.selectAttributes(attrs, q):
            record = ch.fetchAttributes(attrs)
            print "  login=%(login)s name=%(name)s bday=%(birthday)s" % \
                  record
            ch.cancelFetch()

        date = NSCalendarDate()
        print "date in localtime:", date
        date.setTimeZone(NSTimeZone("PST"))
        print "date in pacific time:", date
        
        record['birthday'] = date
        print "  login=%(login)s name=%(name)s bday=%(birthday)s" % record
        
        if ch.updateRow(record, q):
            print "did update .."
        else:
            print "update failed .."

        if ch.selectAttributes(attrs, q):
            nrecord = ch.fetchAttributes(attrs)
            print "  login=%(login)s name=%(name)s bday=%(birthday)s" % \
                  nrecord
            print nrecord['birthday'].__class__
            ch.cancelFetch()
        
        del pool

        ctx.rollbackTransaction()
    else:
        print "couldn't begin tx."

    ch.closeChannel()
else:
    print "couldn't open channel."

