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

#include <NGObjWeb/WODisplayGroup.h>
#import <EOControl/EOControl.h>
#import <EOControl/EOKeyValueArchiver.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSNotification.h>
#include "common.h"

@interface EODataSource(DGQualifierSetting)
- (void)setAuxiliaryQualifier:(EOQualifier *)_q;
- (void)setQualifier:(EOQualifier *)_q;
- (void)setQualifierBindings:(NSDictionary *)_bindings;
@end

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)notImplemented:(SEL)cmd;
@end
#endif


@interface NSObject(EditingContext)
- (id)editingContext;
- (void)addEditor:(id)_editor;
- (void)removeEditor:(id)_editor;
- (void)setMessageHandler:(id)_handler;
- (id)messageHandler;
@end


@implementation WODisplayGroup

static NSNumber *uint0 = nil;
static NSArray  *uint0Array = nil;

+ (void)initialize {
  if (uint0 == nil)
    uint0 = [[NSNumber alloc] initWithUnsignedInt:0];
  if (uint0Array == nil)
    uint0Array = [[NSArray alloc] initWithObjects:&uint0 count:1];
}

- (id)init {
  if ((self = [super init])) {
    [self setDefaultStringMatchFormat:
            [[self class] globalDefaultStringMatchFormat]];
    [self setDefaultStringMatchOperator:
            [[self class] globalDefaultStringMatchOperator]];
    self->currentBatchIndex = 1;
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self setDataSource:nil];

  [self->_queryMatch                release];
  [self->_queryMin                  release];
  [self->_queryMax                  release];
  [self->_queryOperator             release];
  [self->_queryBindings             release];
  [self->defaultStringMatchFormat   release];
  [self->defaultStringMatchOperator release];
  [self->qualifier                  release];
  [self->objects                    release];
  [self->displayObjects             release];
  [self->selectionIndexes           release];
  [self->sortOrderings              release];
  [self->insertedObjectDefaults     release];
  [super dealloc];
}

/* notifications */

- (void)_objectsChangedInEC:(NSNotification *)_notification {
  id d;
  BOOL doRedisplay;

  doRedisplay = YES;
  if ((d = [self delegate]) != nil) {
    if ([d respondsToSelector:
       @selector(displayGroup:shouldRedisplayForChangesInEditingContext:)]) {
      doRedisplay = [d displayGroup:self
                       shouldRedisplayForEditingContextChangeNotification:
                         _notification];
    }
  }

  if (doRedisplay)
    [self redisplay];
}

/* display */

- (void)redisplay {
  /* contents changed notification ??? */
}

/* accessors */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

- (void)setDataSource:(EODataSource *)_ds {
  NSNotificationCenter *nc = nil;
  id ec;
  
  if (_ds == self->dataSource)
    return;
  
  /* unregister with old editing context */
  if ([self->dataSource respondsToSelector:@selector(editingContext)]) {
    if ((ec = [self->dataSource editingContext]) != nil) {
      [ec removeEditor:self];
      if ([ec messageHandler] == self)
        [ec setMessageHandler:nil];
    
      [[NSNotificationCenter defaultCenter]
	removeObserver:self
	name:@"EOObjectsChangedInEditingContext"
	object:ec];
    }
  }
  
  ASSIGN(self->dataSource, _ds);
  
  /* register with new editing context */
  if ([self->dataSource respondsToSelector:@selector(editingContext)]) {
    if ((ec = [self->dataSource editingContext]) != nil) {
      [ec addEditor:self];
      if ([ec messageHandler] == nil)
        [ec setMessageHandler:self];
      
      [nc addObserver:self
          selector:@selector(_objectsChangedInEC:)
          name:@"EOObjectsChangedInEditingContext"
          object:ec];
    }
  }
  
  if ([self->delegate respondsToSelector:
               @selector(displayGroupDidChangeDataSource:)])
    [self->delegate displayGroupDidChangeDataSource:self];
}
- (EODataSource *)dataSource {
  return self->dataSource;
}

- (void)setSortOrderings:(NSArray *)_orderings {
  ASSIGNCOPY(self->sortOrderings, _orderings);
}
- (NSArray *)sortOrderings {
  return self->sortOrderings;
}

- (void)setFetchesOnLoad:(BOOL)_flag {
  self->flags.fetchesOnLoad = _flag ? 1 : 0;
}
- (BOOL)fetchesOnLoad {
  return self->flags.fetchesOnLoad ? YES : NO;
}

- (void)setInsertedObjectDefaultValues:(NSDictionary *)_values {
  ASSIGNCOPY(self->insertedObjectDefaults, [_values copy]);
}
- (NSDictionary *)insertedObjectDefaultValues {
  return self->insertedObjectDefaults;
}

- (void)setNumberOfObjectsPerBatch:(unsigned)_count {
  self->numberOfObjectsPerBatch = _count;
}
- (unsigned)numberOfObjectsPerBatch {
  return self->numberOfObjectsPerBatch;
}

- (void)setSelectsFirstObjectAfterFetch:(BOOL)_flag {
  self->flags.selectFirstAfterFetch = _flag ? 1 : 0;
}
- (BOOL)selectsFirstObjectAfterFetch {
  return self->flags.selectFirstAfterFetch ? YES : NO;
}

- (void)setValidatesChangesImmediatly:(BOOL)_flag {
  self->flags.validatesChangesImmediatly = _flag ? 1 : 0;
}
- (BOOL)validatesChangesImmediatly {
  return self->flags.validatesChangesImmediatly ? YES : NO;
}

/* batches */

- (BOOL)hasMultipleBatches {
  return [self batchCount] > 1 ? YES : NO;
}
- (unsigned)batchCount {
  unsigned doc, nob;
  
  doc = [[self allObjects] count];
  nob = [self numberOfObjectsPerBatch];
  
  return (nob == 0)
    ? 1
    : doc / nob + ((doc % nob) ? 1 : 0) ;
}

- (void)setCurrentBatchIndex:(unsigned)_index {
  self->currentBatchIndex = (_index <= [self batchCount]) ? _index : 1;
}
- (unsigned)currentBatchIndex {
  if (self->currentBatchIndex > [self batchCount])
    self->currentBatchIndex = 1;
  return self->currentBatchIndex;
}

- (unsigned)indexOfFirstDisplayedObject {
  return ([self currentBatchIndex] - 1) * [self numberOfObjectsPerBatch];
}

- (unsigned)indexOfLastDisplayedObject {
  unsigned nob = [self numberOfObjectsPerBatch];
  unsigned cnt = [[self allObjects] count];

  if (nob == 0)
    return cnt-1;
  else
    return (([self indexOfFirstDisplayedObject] + nob) < cnt)
      ? ([self indexOfFirstDisplayedObject] + nob) - 1
      : cnt-1;
}

- (id)displayNextBatch {
  [self clearSelection];
  
  self->currentBatchIndex++;
  if (self->currentBatchIndex > [self batchCount])
    self->currentBatchIndex = 1;

  [self updateDisplayedObjects];
  
  return nil;
}
- (id)displayPreviousBatch {
  [self clearSelection];

  self->currentBatchIndex--;
  if ([self currentBatchIndex] <= 0)
    self->currentBatchIndex = [self batchCount];
  
  [self updateDisplayedObjects];
  
  return nil;
}
- (id)displayBatchContainingSelectedObject {
  [self warnWithFormat:@"%s not implemenented", __PRETTY_FUNCTION__];
  [self updateDisplayedObjects];
  return nil;
}

/* selection */

- (BOOL)setSelectionIndexes:(NSArray *)_selection {
  BOOL ok;
  id   d;
  NSSet *before, *after;

  ok = YES;
  if ((d = [self delegate])) {
    if ([d respondsToSelector:
             @selector(displayGroup:shouldChangeSelectionToIndexes:)]) {
      ok = [d displayGroup:self shouldChangeSelectionToIndexes:_selection];
    }
  }
  if (!ok)
    return NO;
  
  /* apply selection */

  before = [NSSet setWithArray:self->selectionIndexes];
  after  = [NSSet setWithArray:_selection];
  
  ASSIGN(self->selectionIndexes, _selection);
  
  if (![before isEqual:after]) {
    [d displayGroupDidChangeSelection:self];
    [d displayGroupDidChangeSelectedObjects:self];
  }
  return YES;
}
- (NSArray *)selectionIndexes {
  return self->selectionIndexes;
}

- (BOOL)clearSelection {
  static NSArray *emptyArray = nil;
  if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
  return [self setSelectionIndexes:emptyArray];
}

- (id)selectNext {
  unsigned int idx;
  
  if (![self->displayObjects isNotEmpty])
    return nil;
  
  if (![self->selectionIndexes isNotEmpty]) {
    [self setSelectionIndexes:uint0Array];
    return nil;
  }
  
  idx = [[self->selectionIndexes lastObject] unsignedIntValue];
  if (idx >= ([self->displayObjects count] - 1)) {
    /* last object is already selected, select first one */
    [self setSelectionIndexes:uint0Array];
    return nil;
  }
  
  /* select next object .. */
  [self setSelectionIndexes:
          [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:(idx + 1)]]];
  return nil;
}

- (id)selectPrevious {
  unsigned int idx;
  
  if (![self->displayObjects isNotEmpty])
    return nil;
  
  if (![self->selectionIndexes isNotEmpty]) {
    [self setSelectionIndexes:uint0Array];
    return nil;
  }
  
  idx = [[self->selectionIndexes objectAtIndex:0] unsignedIntValue];
  if (idx == 0) {
    /* first object is selected, now select last one */
    NSNumber *sidx;
    sidx = [NSNumber numberWithUnsignedInt:([self->displayObjects count] - 1)];
    [self setSelectionIndexes:[NSArray arrayWithObject:sidx]];
  }
  
  /* select previous object .. */
  [self setSelectionIndexes:
          [NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:(idx - 1)]]];
  return nil;
}

- (void)setSelectedObject:(id)_obj {
  unsigned idx;
  NSNumber *idxNumber;
  
  // TODO: maybe we need to retain the selection array and just swap the first
  
  idx = [self->objects indexOfObject:_obj];
  idxNumber = (idx != NSNotFound)
    ? [NSNumber numberWithUnsignedInt:idx] : (NSNumber *)nil;

  if (idxNumber != nil) {
    NSArray *a;
    
    a = [[NSArray alloc] initWithObjects:&idxNumber count:1];
    [self setSelectionIndexes:a];
    [a release]; a = nil;
  }
  else
    [self setSelectionIndexes:nil];
}
- (id)selectedObject {
  unsigned int i, sCount;
  
  if ((sCount = [self->selectionIndexes count]) == 0)
    return nil;
  
  i = [[self->selectionIndexes objectAtIndex:0] unsignedIntValue];
  if (i >= [self->objects count])
    return nil;
  
  // TODO: need to ensure selection is in displayedObjects?
  return [self->objects objectAtIndex:i];
}

- (void)setSelectedObjects:(NSArray *)_objs {
  [self selectObjectsIdenticalTo:_objs];
  //  [self warnWithFormat:@"%s not implemented.", __PRETTY_FUNCTION__];
}
- (NSArray *)selectedObjects {
  NSMutableArray *result;
  unsigned int i, sCount, oCount;

  sCount = [self->selectionIndexes count];
  oCount = [self->objects count];
  result = [NSMutableArray arrayWithCapacity:sCount];
  
  for (i = 0; i < sCount; i++) {
    unsigned int idx;

    idx = [[self->selectionIndexes objectAtIndex:i] unsignedIntValue];
    if (idx < oCount)
      [result addObject:[self->objects objectAtIndex:idx]];
  }
  return result;
}

- (BOOL)selectObject:(id)_obj {
  /* returns YES if displayedObjects contains _obj otherwise NO */
  NSNumber *idxNumber;
  unsigned idx;
  
  if (![self->displayObjects containsObject:_obj])
    return NO;
  
  idx = [self->objects indexOfObject:_obj];
  idxNumber = (idx != NSNotFound) 
    ? [NSNumber numberWithUnsignedInt:idx] : (NSNumber *)nil;

  // TODO: should we just exchange the first item and/or call
  //       -setSelectedObject: ?
  
#if 0 /* this was wrong? */
  if ([self->selectionIndexes containsObject:idxNumber])
    /* already selected => could be many => move to top? */
    return YES;
  
  tmp = [NSMutableArray arrayWithObjects:self->selectionIndexes];
  [tmp addObject:idxNumber];
  [self setSelectionIndexes:tmp];
#else
  if (idxNumber != nil)
    [self setSelectionIndexes:[NSArray arrayWithObjects:&idxNumber count:1]];
  else
    [self setSelectionIndexes:nil];
#endif
  return YES;
}


/* returns YES if at least one obj matches otherwise NO */
- (BOOL)selectObjectsIdenticalTo:(NSArray *)_objs {
  NSMutableArray *newIndexes;
  unsigned       i, cnt;
  BOOL           ok = NO;

  cnt = [_objs count];
  
  if (cnt == 0)
    return NO;

  newIndexes = [NSMutableArray arrayWithCapacity:cnt];
  
  for (i=0; i<cnt; i++) {
    NSNumber *idxNumber;
    unsigned idx;
    id       obj;

    obj = [_objs objectAtIndex:i];
    if (![self->objects containsObject:obj])
      continue;

    ok = YES;
    idx = [self->objects indexOfObject:obj];
    idxNumber = [NSNumber numberWithUnsignedInt:idx];
    
    if ([self->selectionIndexes containsObject:idxNumber])
      continue;

    [newIndexes addObject:idxNumber];
  }
  if (!ok)
    return NO;

  [newIndexes addObjectsFromArray:self->selectionIndexes];
  [self setSelectionIndexes:newIndexes];
  
  return YES;
}

- (BOOL)selectObjectsIdenticalTo:(NSArray *)_objs
  selectFirstOnNoMatch:(BOOL)_flag
{
  if ([self selectObjectsIdenticalTo:_objs])
    return YES;
  
  if (_flag)
    return [self selectObject:[self->displayObjects objectAtIndex:0]];
  else
    return NO;
}

/* objects */

- (void)setObjectArray:(NSArray *)_objects {
  ASSIGN(self->objects, _objects);
  
  /* should try to restore selection */
  [self clearSelection];
  if ([_objects isNotEmpty] && [self selectsFirstObjectAfterFetch])
    [self setSelectionIndexes:uint0Array];
}
 
- (NSArray *)allObjects {
  return self->objects;
}

- (NSArray *)displayedObjects {
  return self->displayObjects;
}

- (id)fetch {
  NSArray *objs;
  
  if ([self->delegate respondsToSelector:@selector(displayGroupShouldFetch:)]){
    if (![self->delegate displayGroupShouldFetch:self])
      /* delegate rejected fetch-request */
      return nil;
  }

  objs = [[self dataSource] fetchObjects];

  [self setObjectArray:objs];

  if ([self->delegate respondsToSelector:
           @selector(displayGroup:didFetchObjects:)]) {
    [self->delegate displayGroup:self didFetchObjects:objs];
  }

  [self updateDisplayedObjects];
  
  if ([self selectsFirstObjectAfterFetch]) {
    [self clearSelection];
    
    if ([objs isNotEmpty])
      [self setSelectedObject:[objs objectAtIndex:0]];
  }
  
  return nil /* stay on page */;
}

- (void)updateDisplayedObjects {
  NSArray *darray; // display  objects
  NSArray *sarray; // selected objects

  sarray = [self selectedObjects];
  
  if ([self->delegate respondsToSelector:
           @selector(displayGroup:displayArrayForObjects:)]) {
    darray = [self->delegate displayGroup:self
                             displayArrayForObjects:[self allObjects]];

    ASSIGNCOPY(self->displayObjects, darray);
    return;
  }
  
  {
//    EOQualifier *q;
    NSArray     *so, *ao;
    
    ao = [self allObjects];

    /* apply qualifier */
#if 0
    if ((q = [self qualifier]))
      ao = [ao filteredArrayUsingQualifier:q];
#endif // should be done in qualifyDisplayGroup

    /* apply sort orderings */
    if ((so = [self sortOrderings]))
      ao = [ao sortedArrayUsingKeyOrderArray:so];

    if (ao != self->objects)
      [self setObjectArray:ao];

    darray = ao;

    /* apply batch */
    if ([self batchCount] > 1) {
      unsigned first = [self indexOfFirstDisplayedObject];
      unsigned last  = [self indexOfLastDisplayedObject];

      darray = [darray subarrayWithRange:NSMakeRange(first, last-first+1)];
    }
  }
  
  darray = [darray copy];
  RELEASE(self->displayObjects);
  self->displayObjects = darray;

  [self selectObjectsIdenticalTo:sarray];
}

/* query */

- (void)setInQueryMode:(BOOL)_flag {
  self->flags.inQueryMode = _flag ? 1 : 0;
}
- (BOOL)inQueryMode {
  return self->flags.inQueryMode ? YES : NO;
}

- (EOQualifier *)qualifierFromQueryValues {
  NSMutableDictionary *qm, *qmin, *qmax, *qop;
  NSMutableArray *quals;
  NSEnumerator   *keys;
  NSString       *key;
  
  qm   = [self queryMatch];
  qmin = [self queryMin];
  qmax = [self queryMax];
  qop  = [self queryOperator];
  
  quals = [NSMutableArray arrayWithCapacity:[qm count]];
  
  /* construct qualifier for all query-match entries */
  
  keys = [qm keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    NSString *op;
    SEL      ops;
    id       value;
    EOQualifier *q;
    
    value = [qm objectForKey:key];
    
    if ((op = [qop objectForKey:key]) == nil) {
      /* default operator is equality */
      op  = @"=";
      ops = EOQualifierOperatorEqual;
    }
    else if ([value isKindOfClass:[NSString class]]) {
      /* strings are treated in a special way */
      NSString *fmt;

      fmt = [self defaultStringMatchFormat];
      op  = [self defaultStringMatchOperator];
      ops = [EOQualifier operatorSelectorForString:op];
      
      value = [NSString stringWithFormat:fmt, value];
    }
    else {
      ops = [EOQualifier operatorSelectorForString:op];
    }

    q = [[EOKeyValueQualifier alloc]
                              initWithKey:key
                              operatorSelector:ops
                              value:value];
    [quals addObject:q];
    [q release]; q = nil;
  }
  
  /* construct min qualifiers */

  keys = [qmin keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    EOQualifier *q;
    id value;
    
    value = [qmin objectForKey:key];

    q = [[EOKeyValueQualifier alloc]
                              initWithKey:key
                              operatorSelector:EOQualifierOperatorGreaterThan
                              value:value];
    [quals addObject:q];
    [q release];
  }

  /* construct max qualifiers */
  
  keys = [qmax keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    EOQualifier *q;
    id value;
    
    value = [qmax objectForKey:key];

    q = [[EOKeyValueQualifier alloc]
                              initWithKey:key
                              operatorSelector:EOQualifierOperatorLessThan
                              value:value];
    [quals addObject:q];
    [q release];
  }

  if (![quals isNotEmpty])
    return nil;
  if ([quals count] == 1)
    return [quals objectAtIndex:0];
  
  return [[[EOAndQualifier alloc] initWithQualifierArray:quals] autorelease];
}

- (NSMutableDictionary *)queryBindings {
  if (self->_queryBindings == nil)
    self->_queryBindings = [[NSMutableDictionary alloc] initWithCapacity:8];
  return self->_queryBindings;
}
- (NSMutableDictionary *)queryMatch {
  if (self->_queryMatch == nil)
    self->_queryMatch = [[NSMutableDictionary alloc] initWithCapacity:8];
  return self->_queryMatch;
}
- (NSMutableDictionary *)queryMin {
  if (self->_queryMin == nil)
    self->_queryMin = [[NSMutableDictionary alloc] initWithCapacity:8];
  return self->_queryMin;
}
- (NSMutableDictionary *)queryMax {
  if (self->_queryMax == nil)
    self->_queryMax = [[NSMutableDictionary alloc] initWithCapacity:8];
  return self->_queryMax;
}
- (NSMutableDictionary *)queryOperator {
  if (self->_queryOperator == nil)
    self->_queryOperator = [[NSMutableDictionary alloc] initWithCapacity:8];
  return self->_queryOperator;
}

- (void)setDefaultStringMatchFormat:(NSString *)_tmp {
  ASSIGNCOPY(self->defaultStringMatchFormat, _tmp);
}
- (NSString *)defaultStringMatchFormat {
  return self->defaultStringMatchFormat;
}
- (void)setDefaultStringMatchOperator:(NSString *)_tmp {
  ASSIGNCOPY(self->defaultStringMatchOperator, _tmp);
}
- (NSString *)defaultStringMatchOperator {
  return self->defaultStringMatchOperator;
}
+ (NSString *)globalDefaultStringMatchFormat {
  return @"%@*";
}
+ (NSString *)globalDefaultStringMatchOperator {
  return @"caseInsensitiveLike";
}


/* qualfiers */

- (void)setQualifier:(EOQualifier *)_q {
  ASSIGN(self->qualifier, _q);
}
- (EOQualifier *)qualifier {
  return self->qualifier;
}

- (NSArray *)allQualifierOperators {
  static NSArray *quals = nil;
  if (quals == nil) {
    quals = [[NSArray alloc] initWithObjects:
                               @"=", @"!=", @"<", @"<=", @">", @">=",
                               @"like", @"caseInsensitiveLike", nil];
  }
  return quals;
}
- (NSArray *)stringQualifierOperators {
  static NSArray *quals = nil;
  if (quals == nil) {
    quals = [[NSArray alloc] initWithObjects:
                               @"starts with",
                               @"contains",
                               @"ends with",
                               @"is",
                               @"like",
                               nil];
  }
  return quals;
}
- (NSArray *)relationalQualifierOperators {
  static NSArray *quals = nil;
  if (quals == nil) {
    quals = [[NSArray alloc] initWithObjects:
                               @"=", @"!=", @"<", @"<=", @">", @">=", nil];
  }
  return quals;
}

- (void)qualifyDisplayGroup {
  EOQualifier *q;

  if ((q = [self qualifierFromQueryValues]) != nil)
    [self setQualifier:q];
  
  [self updateDisplayedObjects];
  
  if ([self inQueryMode])
    [self setInQueryMode:NO];
}

- (void)qualifyDataSource {
  EODataSource *ds;
  EOQualifier  *q;
  NSDictionary *bindings;

  if ((ds = [self dataSource]) == nil)
    [self warnWithFormat:@"no datasource set: %@", NSStringFromSelector(_cmd)];

  /* build qualifier */
  
  if ((q = [self qualifierFromQueryValues]) != nil)
    [self setQualifier:q];
  
  /* set qualifier in datasource */
  
  if ([ds respondsToSelector:@selector(setAuxiliaryQualifier:)]) {
    [ds setAuxiliaryQualifier:[self qualifier]];
    //[self logWithFormat:@"set aux qualifier in %@: %@", ds,[self qualifier]];
  }
  else if ([ds respondsToSelector:@selector(setQualifier:)])
    [ds setQualifier:[self qualifier]];
  else {
    /* could not qualify ds */
    [self warnWithFormat:@"could not qualify datasource: %@", ds];
  }
  
  /* set bindings in datasource */

  if ([(bindings = [self queryBindings]) isNotEmpty]) {
    if ([ds respondsToSelector:@selector(setQualifierBindings:)])
      [ds setQualifierBindings:bindings];
    else {
      [self warnWithFormat:@"could not set bindings in datasource %@: %@", 
	      ds, bindings];
    }
  }
  
  /* perform fetch */
  
  /* action method, returns 'nil' to stay on page */
  [self fetch];
  
  if ([self inQueryMode])
    [self setInQueryMode:NO];
}

- (id)qualifyDataSourceAndReturnDisplayCount {
  /* 
     This is a 'hack' created because we can't bind (and therefore 'call')
     'void' methods in .wod files.
  */
  [self qualifyDataSource];
  return [NSNumber numberWithUnsignedInt:[[self displayedObjects] count]];
}

/* object creation */

- (id)insert {
  unsigned idx;

  idx = [self->selectionIndexes isNotEmpty]
    ? ([[self->selectionIndexes objectAtIndex:0] unsignedIntValue] + 1)
    : [self->objects count];
  
  return [self insertObjectAtIndex:idx]; /* returns 'nil' */
}

- (id)insertObjectAtIndex:(unsigned)_idx {
  id newObject;
  
  if ((newObject = [[self dataSource] createObject]) == nil) {
    [self errorWithFormat:@"Failed to create new object in datasource: %@",
	    [self dataSource]];
    
    if ([self->delegate respondsToSelector:
	       @selector(displayGroup:createObjectFailedForDataSource:)]) {
      [self->delegate displayGroup:self 
		      createObjectFailedForDataSource:[self dataSource]];
    }
    return nil /* refresh page */;
  }

  /* apply default values */
  
  [newObject takeValuesFromDictionary:[self insertedObjectDefaultValues]];
  
  /* insert */

  [self insertObject:newObject atIndex:_idx];
  
  return nil /* refresh page */;
}

- (void)insertObject:(id)_o atIndex:(unsigned)_idx {
  NSMutableArray *ma;
  
  /* ask delegate whether we should insert */
  if ([self->delegate respondsToSelector:
	     @selector(displayGroup:shouldInsertObject:atIndex:)]) {
    if (![self->delegate displayGroup:self shouldInsertObject:_o atIndex:_idx])
      return;
  }
  
  /* insert in datasource */
  
  [[self dataSource] insertObject:_o];
  
  /* update object-array (ignores qualifier for new objects!) */
  
  ma = [self->objects mutableCopy];
  if (_idx <= [ma count])
    [ma insertObject:_o atIndex:_idx];
  else
    [ma addObject:_o];
  
  [self setObjectArray:ma];
  [ma release]; ma = nil;
  [self updateDisplayedObjects];

  /* select object */
  
  [self selectObject:_o]; // TODO: or use setSelectedObject:?
  
  /* let delegate know */
  if ([self->delegate respondsToSelector:
	     @selector(displayGroup:didInsertObject:)])
    [self->delegate displayGroup:self didInsertObject:_o];
}


/* object deletion */

- (id)delete {
  [self deleteSelection];
  return nil;
}

- (BOOL)deleteSelection {
  NSArray  *objsToDelete;
  unsigned i, count;
  
  objsToDelete = [[[self selectedObjects] shallowCopy] autorelease];

  for (i = 0, count = [objsToDelete count]; i < count; i++) {
    unsigned idx;
    
    idx = [self->objects indexOfObject:[objsToDelete objectAtIndex:i]];
    if (idx == NSNotFound) {
      [self errorWithFormat:@"Did not find object in selection: %@",
	      objsToDelete];
      return NO;
    }
    
    if (![self deleteObjectAtIndex:idx])
      return NO;
  }
  return YES;
}

- (BOOL)deleteObjectAtIndex:(unsigned)_idx {
  NSMutableArray *ma;
  id   object;
  BOOL ok;

  /* find object */
  
  object = (_idx < [self->objects count])
    ? [[[self->objects objectAtIndex:_idx] retain] autorelease]
    : nil;
  // TODO: check for nil?
  
  /* ask delegate */
  
  if ([self->delegate respondsToSelector:
	     @selector(displayGroup:shouldDeleteObject:)]) {
    if (![self->delegate displayGroup:self shouldDeleteObject:object])
      return NO;
  }
  
  /* delete in datasource */
  
  ok = YES;
  NS_DURING
    [[self dataSource] deleteObject:object];
  NS_HANDLER
    *(&ok) = NO;
  NS_ENDHANDLER;

  if (!ok)
    return NO;
  
  /* update array */
  
  ma = [self->objects mutableCopy];
  [ma removeObject:object];
  [self setObjectArray:ma];
  [ma release]; ma = nil;
  [self updateDisplayedObjects];
  
  /* notify delegate */

  if ([self->delegate respondsToSelector:
	     @selector(displayGroup:didDeleteObject:)])
    [self->delegate displayGroup:self didDeleteObject:object];
  return YES;
}


/* master / detail */

- (BOOL)hasDetailDataSource {
  return [[self dataSource] isKindOfClass:[EODetailDataSource class]];
}

- (void)setDetailKey:(NSString *)_key {
  // TODO: fix me, probably we want to store the key for later
#if 0
  EODataSource *ds;
  
  if ([(ds = [self dataSource]) respondsToSelector:_cmd])
    [(EODetailDataSource *)ds setDetailKey:_key];
#endif
}
- (NSString *)detailKey {
  EODataSource *ds;
  
  return ([(ds = [self dataSource]) respondsToSelector:_cmd])
    ? [(EODetailDataSource *)ds detailKey] : (NSString *)nil;
}

- (void)setMasterObject:(id)_object {
  [[self dataSource] qualifyWithRelationshipKey:[self detailKey]
		     ofObject:_object];
  
  if ([self fetchesOnLoad])
    [self fetch];
}
- (id)masterObject {
  EODataSource *ds;
  
  return ([(ds = [self dataSource]) respondsToSelector:_cmd])
    ? [(EODetailDataSource *)ds masterObject] : nil;
}


/* KVC */

- (void)takeValue:(id)_value forKeyPath:(NSString *)_keyPath {
  if([_keyPath hasPrefix:@"queryMatch."]) {
    [[self queryMatch] takeValue:_value 
		       forKey:[_keyPath substringFromIndex:11]];
  }
  else if([_keyPath hasPrefix:@"queryMax."])
    [[self queryMax] takeValue:_value forKey:[_keyPath substringFromIndex:9]];
  else if([_keyPath hasPrefix:@"queryMin."])
    [[self queryMin] takeValue:_value forKey:[_keyPath substringFromIndex:9]];
  else if([_keyPath hasPrefix:@"queryOperator."]) {
    [[self queryOperator] takeValue:_value 
			  forKey:[_keyPath substringFromIndex:14]];
  }
  else
    [super takeValue:_value forKeyPath:_keyPath];
}
- (id)valueForKeyPath:(NSString *)_keyPath {
  if ([_keyPath hasPrefix:@"queryMatch."])
    return [[self queryMatch] valueForKey:[_keyPath substringFromIndex:11]];
  if ([_keyPath hasPrefix:@"queryMax."])
    return [[self queryMax] valueForKey:[_keyPath substringFromIndex:9]];
  if ([_keyPath hasPrefix:@"queryMin."])
    return [[self queryMin] valueForKey:[_keyPath substringFromIndex:9]];
  if ([_keyPath hasPrefix:@"queryOperator."])
    return [[self queryOperator] valueForKey:[_keyPath substringFromIndex:14]];

  return [super valueForKeyPath:_keyPath];
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)_coder {
  self->dataSource                 = [[_coder decodeObject] retain];
  self->delegate                   = [_coder decodeObject];
  self->sortOrderings              = [[_coder decodeObject] copy];
  self->insertedObjectDefaults     = [[_coder decodeObject] copy];
  self->qualifier                  = [[_coder decodeObject] copy];
  self->defaultStringMatchFormat   = [[_coder decodeObject] copy];
  self->defaultStringMatchOperator = [[_coder decodeObject] copy];
  self->_queryBindings             = [[_coder decodeObject] copy];
  self->_queryMatch                = [[_coder decodeObject] copy];
  self->_queryMin                  = [[_coder decodeObject] copy];
  self->_queryMax                  = [[_coder decodeObject] copy];
  self->_queryOperator             = [[_coder decodeObject] copy];
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->dataSource];
  [_coder encodeObject:self->delegate];
  [_coder encodeObject:self->sortOrderings];
  [_coder encodeObject:self->insertedObjectDefaults];
  [_coder encodeObject:self->qualifier];
  [_coder encodeObject:self->defaultStringMatchFormat];
  [_coder encodeObject:self->defaultStringMatchOperator];
  [_coder encodeObject:self->_queryBindings];
  [_coder encodeObject:self->_queryMatch];
  [_coder encodeObject:self->_queryMin];
  [_coder encodeObject:self->_queryMax];
  [_coder encodeObject:self->_queryOperator];
  
  [self notImplemented:_cmd];
}

/* KVCArchiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  if ((self = [self init]) != nil) {
    id tmp;
    
    if ((tmp = [_unarchiver decodeObjectForKey:@"formatForLikeQualifier"]))
      [self setDefaultStringMatchFormat:tmp];
    
    if ((tmp = [_unarchiver decodeObjectForKey:@"dataSource"]))
      [self setDataSource:tmp];

    if ((tmp = [_unarchiver decodeObjectForKey:@"numberOfObjectsPerBatch"]))
      [self setNumberOfObjectsPerBatch:[tmp intValue]];
    
    [self setFetchesOnLoad:[_unarchiver decodeBoolForKey:@"fetchesOnLoad"]];
    [self setSelectsFirstObjectAfterFetch:
          [_unarchiver decodeBoolForKey:@"selectsFirstObjectAfterFetch"]];
  }
  return self;
}

- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeObject:[self defaultStringMatchFormat]
             forKey:@"formatForLikeQualifier"];
  [_archiver encodeObject:[self dataSource]
             forKey:@"dataSource"];
  [_archiver encodeObject:
               [NSNumber numberWithUnsignedInt:[self numberOfObjectsPerBatch]]
             forKey:@"numberOfObjectsPerBatch"];
  [_archiver encodeBool:[self fetchesOnLoad]
             forKey:@"fetchesOnLoad"];
  [_archiver encodeBool:[self selectsFirstObjectAfterFetch]
             forKey:@"selectFirstAfterFetch"];
}

- (void)awakeFromKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  if ([self fetchesOnLoad])
    [self fetch];
}

/* EOEditorsImpl */

- (void)editingContextWillSaveChanges:(id)_ec {
}
- (BOOL)editorHasChangesForEditingContext:(id)_ec {
  return NO;
}

/* EOMessageHandlersImpl */

- (void)editingContext:(id)_ec
  presentErrorMessage:(NSString *)_msg
{
}

- (BOOL)editingContext:(id)_ec
  shouldContinueFetchingWithCurrentObjectCount:(unsigned)_oc
  originalLimit:(unsigned)_olimit
  objectStore:(id)_store
{
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p %@: ds=%@>",
                     self, NSStringFromClass([self class]),
                     [self dataSource]];
}

@end /* WODisplayGroup */
