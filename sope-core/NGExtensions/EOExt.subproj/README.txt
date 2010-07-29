Extensions for EOControl
========================

This subproject contains categories and additional classes to enhance
functionality provided by EOControl.


General additions:
a) plist init methods, like -initWithPropertyList:,
   -initWithPropertyList:owner:, -initWithString:, -initWithDictionary:, etc


DataSources
===========

General Additions
*****************

NGExtensions adds the following to datasources:
a) standardized -setFetchSpecification:/-fetchSpecification
b) -updateObject: for triggering updates in 'raw' datasources
c) -postDataSourceChanged, to notify the system of changed datasource
   fetch specifications

EOCacheDataSource
*****************

A "regular" EODataSource in SOPE is not supposed to cache the results it
fetches, it should just perform the raw fetch and then tidy up. To provide
caching, you can wrap an arbitary datasource in an EOCacheDataSource which
will manage the cache, perform on-demand loads etc.

To keep the cache consistent, in SOPE a EODataSource is supposed to call
-postDataSourceChanged when its fetch-specification changes in a way which
would lead to different fetch results.

(Notably an EODatabaseDataSource in EOF2 often has implicit caching in the
 EOObjectStore/EOEditingContext, the above applies more to SOPE and OGo
 datasources like the NGLdapDataSource, NGImap4FolderDataSource,
 EOAdaptorDataSource etc).

EOCompoundDataSource
********************

As the name suggests this datasource joins the results of other datasources
into one.
In the context of create/insert/delete/update operations, the datasource tries
each of the child datasources in sequence until one of them succeeds in the
delete and otherwise calls the super method.

Finally this datasource has own sort-orderings and an own auxiliaryQualifier.

EOFilterDataSource
******************

This datasource is somewhat similiar to EOCompoundDataSource but intended for
subclassing and has just one source datasources. It provides own
sort-orderings, groupings and an own auxiliaryQualifier.
It can be used as-is to add grouping capabilities to datasources.

EOKeyMapDataSource
******************
TODO: document
- EOMappedObject
- EOKeyMapDataSourceEnumerator


Grouping
========

TODO document.

- Groupings on an EODataSource still return an array, but one sorted by the
  'grouping keys'. Remember that the grouping does *not* need to be a plain
  KVC key but can be arbitary.

- You can add grouping facilities to arbitary datasources using
  EOFilterDataSource.

Convenience methods
*******************
NSArray
- (NSArray *)arrayGroupedBy:(EOGrouping *)_grouping;

EOFetchSpecification:
- setGroupings:(NSArray *)_groupings; // sets 'EOGroupingHint'
- (NSArray *)groupings;

Classes
*******
  <NSObject>
    EOGrouping
      EOGroupingSet
      EOKeyGrouping
      EOQualifierGrouping
