#!/usr/bin/env python
# $Id: test.py 2 2004-08-20 10:48:47Z znek $
from sys          import *
from Foundation   import *
from eoaccess     import *
from EOControl    import *
from NGExtensions import *
from GDLExtensions import *
import resource;

defaults = NSUserDefaults();

connDict = defaults["LSConnectionDictionary"];
if connDict is None:
    print "missing connection dictionary\n";
    exit(1);

primKeyGenDict = defaults["pkeyGeneratorDictionary"];
print primKeyGenDict;
if primKeyGenDict is None:
    print "missing pkeyGeneratorDictionary\n";
    exit(1);


print "ConnectionDictionary: ";
print connDict.description();

adaptorName = defaults["LSAdaptor"];
if adaptorName is None:
    adaptorName = "Sybase10";

adaptor = EOAdaptor(adaptorName);
adaptor.setConnectionDictionary(connDict);
adaptor.setPkeyGeneratorDictionary(primKeyGenDict);

adContext = adaptor.createAdaptorContext();
adChannel = adContext.createAdaptorChannel();

def test_database_channel():
    print "adChannel " + adChannel.description() + "\n";
    print "channel   ";
    print "attributesForTableName doc";
    print adChannel.invoke1("attributesForTableName:", "doc");
    print "primaryKeyAttributesForTableName document  _______________________________________\n";
    print adChannel.invoke1("primaryKeyAttributesForTableName:", "document");
    print "primaryKeyAttributesForTableName:, doc _______________________________________\n";    
    print adChannel.invoke1("primaryKeyAttributesForTableName:", "doc");
    print "primaryKeyAttributesForTableName company _______________________________________\n";    
    print adChannel.invoke1("primaryKeyAttributesForTableName:", "company");
    print "primaryKeyAttributesForTableName person_______________________________________\n";    
    print adChannel.invoke1("primaryKeyAttributesForTableName:", "person");
    print "_______________________________________\n";    

def test_adaptor_data_source():
    adaptor = adChannel.adaptorContext().adaptor();
    dict = NSMutableDictionary();
    dict["login"]      = "jan_1";
    dict["name"]       = "JR";
    dict["firstname"]  = "jan";
    dict["is_person"]  = 1;
    dict["number"]     = "12345_1";
    dict["birthday"]   = NSCalendarDate('1999-09-21 13:23', '%Y-%m-%d %H:%M');
    dict["middlename"] = "Ein Unnuetzer middlename";
    

    dataSource = EOAdaptorDataSource(adChannel);
    hints = NSMutableDictionary();
    pks   = NSMutableArray();
    pks.addObject("company_id");
    hints.setObjectForKey(pks, "EOPrimaryKeyAttributeNamesHint")
    
    fetchSpec = EOFetchSpecification();
    fetchSpec.setEntityName("company");
    fetchSpec.setHints(hints);

    dataSource.setFetchSpecification(fetchSpec);
    print "-------------------- {insert ---------------------\n";
    dataSource.insertObject(dict);
    print "-------------------- insert} ---------------------\n";

    print "-------------------- {select with hints ---------------------\n";
    qualifier = EOQualifier("login = %@", ("jan_1", ))
    fetchSpec = EOFetchSpecification();
    fetchSpec.setQualifier(qualifier);
    fetchSpec.setEntityName("company");
    
    hints = NSMutableDictionary();
    pks.addObject("company_id");
    hints.setObjectForKey(NSTimeZone('MET'), "EOFetchResultTimeZoneHint")
    fetchSpec.setHints(hints);

    sortOrderings = NSMutableArray();
    sortOrderings.addObject(EOSortOrdering("login", "compareCaseInsensitiveAscending:"));
    sortOrderings.addObject(EOSortOrdering("company_id", "compareCaseInsensitiveDescending:"));    
    fetchSpec.setSortOrderings(sortOrderings);
    dataSource = EOAdaptorDataSource(adChannel);
    dataSource.setFetchSpecification(fetchSpec);
    objs = dataSource.fetchObjects();
    print objs;
    print "-------------------- select} ---------------------\n";
    obj = objs[0];

    print "-------------------- {update ---------------------\n";
    print obj;
    obj["login"]      = "jan_1_1";
    obj["middlename"] = EONull();
    dataSource.updateObject(obj);
    print "-------------------- update} ---------------------\n";

    qualifier = EOQualifier("login caseInsensitiveLike %@", ("jan_1_*", ))
    fetchSpec.setQualifier(qualifier);
    dataSource.setFetchSpecification(fetchSpec);
    
    print "-------------------- {select ---------------------\n";
    objs = dataSource.fetchObjects();
    print objs;    
    print "-------------------- select} ---------------------\n";

    print "-------------------- {delete ---------------------\n";
    obj = objs[0];
    dataSource.deleteObject(obj);
    print "-------------------- delete} ---------------------\n";

    print "-------------------- {select ---------------------\n";
    objs = dataSource.fetchObjects();
    print objs;    
    print "-------------------- select} ---------------------\n";


def test_cascaded_datasources():

    adaptor = adChannel.adaptorContext().adaptor();
    dict = NSMutableDictionary();
    dict["login"]      = "jan_1";
    dict["name"]       = "JR";
    dict["firstname"]  = "jan";
    dict["is_person"]  = 1;
    dict["number"]     = "12345_1";

    dataSource      = EOAdaptorDataSource(adChannel);
    fetchSpec = EOFetchSpecification();
    fetchSpec.setEntityName("company");
    qualifier = EOQualifier("login like %@", ("j%", ))
    fetchSpec = EOFetchSpecification();
    fetchSpec.setQualifier(qualifier);
    fetchSpec.setEntityName("company");
    sortOrderings = NSMutableArray();
    sortOrderings.addObject(EOSortOrdering("login", "compareCaseInsensitiveAscending:"));
    fetchSpec.setSortOrderings(sortOrderings);    
    hints = NSMutableDictionary();
    pks   = NSMutableArray();
    pks.addObject("company_id");
    hints.setObjectForKey(pks, "EOPrimaryKeyAttributeNamesHint")
    
    fetchSpec.setHints(hints);

    dataSource.setFetchSpecification(fetchSpec);
    cacheDataSource = EOCacheDataSource(dataSource);    
    objs = dataSource.fetchObjects();
    print objs;
    print cacheDataSource.fetchObjects();
    print "-----------------------------\n";
    print cacheDataSource.fetchObjects();
    dataSource.insertObject(dict);
    print "++++++++++++++++++++++++++++\n";

    fetchSpec = EOFetchSpecification();
    fetchSpec.setEntityName("company");
    qualifier = EOQualifier("login = %@", ("jan_1", ))
    fetchSpec = EOFetchSpecification();
    fetchSpec.setQualifier(qualifier);
    fetchSpec.setEntityName("company");
    dataSource.setFetchSpecification(fetchSpec);
    cacheDataSource = EOCacheDataSource(dataSource);    
    objs = dataSource.fetchObjects();
    obj = objs[0];
    print objs;
    print "-----------------------------\n";
    print cacheDataSource.deleteObject(obj);
    print "++++++++++++++++++++++++++++\n";    
    print cacheDataSource.fetchObjects();

def echo_logins(objs):
    for o in objs:
        print o['login'];

def test_sort_datasource():
    dataSource      = EOAdaptorDataSource(adChannel);

    fetchSpec = EOFetchSpecification();
    fetchSpec.setEntityName("company");
    qualifier = EOQualifier("login like %@", ("%a%", ))
    fetchSpec.setQualifier(qualifier);
    
    dataSource.setFetchSpecification(fetchSpec);
    echo_logins(dataSource.fetchObjects());

    sortOrderings = NSMutableArray();
    sO = EOSortOrdering("login", "compareDescending:");
    sortOrderings.addObject(sO);
    fetchSpec.setSortOrderings(sortOrderings);
    dataSource.setFetchSpecification(fetchSpec);

    echo_logins(dataSource.fetchObjects());

print resource.getrlimit(resource.RLIMIT_CORE);
if adChannel.openChannel():
    print "open channel ok";
else:
    print "open channel failed";
    exit(1);
print "adChannel ", adChannel;


#test_database_channel();
test_adaptor_data_source();
#test_cascaded_datasources();
#test_sort_datasource();
