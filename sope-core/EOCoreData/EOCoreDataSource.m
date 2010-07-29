/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#include "EOCoreDataSource.h"
#include "EOFetchSpecification+CoreData.h"
#include "EOQualifier+CoreData.h"
#include "common.h"

static NSString *EODataSourceDidChangeNotification =
  @"EODataSourceDidChangeNotification";

@implementation EOCoreDataSource

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if ((debugOn = [ud boolForKey:@"EOCoreDataSourceDebugEnabled"]))
    NSLog(@"EOCoreDataSource: debugging enabled.");
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)_moc
  entity:(NSEntityDescription *)_entity
{
  if ((self = [super init]) != nil) {
    if (_moc == nil) {
      NSLog(@"ERROR(%s): missing object-context parameter!",
	    __PRETTY_FUNCTION__);
      [self release];
      return nil;
    }
    
    self->ecdFlags.isFetchEnabled = 1;
    self->managedObjectContext = [_moc retain];
    self->entity = [_entity retain];
  }
  return self;
}

- (id)init {
  return [self initWithManagedObjectContext:nil entity:nil];
}

- (void)dealloc {
  [self->qualifierBindings    release];
  [self->entity               release];
  [self->managedObjectContext release];
  [self->fetchSpecification   release];
  [self->auxiliaryQualifier   release];
  [super dealloc];
}

/* post datasource changes */

- (void)postDataSourceChangedNotification {
  /* reimplemented here to avoid linking against NGExtensions */
  static NSNotificationCenter *nc = nil;
  
  if (nc == nil)
    nc = [[NSNotificationCenter defaultCenter] retain];
  
  [nc postNotificationName:EODataSourceDidChangeNotification object:self];
}

/* fetch-spec */

- (void)_resetFetchRequest {
  [self->fetchRequest release]; self->fetchRequest = nil;
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  BOOL isSameEntity;
  
  if ([self->fetchSpecification isEqual:_fspec])
    return;
  
  if ([_fspec isKindOfClass:[NSFetchRequest class]]) {
    /* be tolerant, we ain't no Java ... */
    [self setFetchRequest:(NSFetchRequest *)_fspec];
    return;
  }
  
  isSameEntity = 
    [[self->fetchSpecification entityName] isEqual:[_fspec entityName]];
  
  [self->fetchSpecification autorelease];
  self->fetchSpecification = [_fspec copy];
  
  /* reset derived entities */
  if (self->ecdFlags.isEntityFromFetchSpec && !isSameEntity) {
    self->ecdFlags.isEntityFromFetchSpec = 0;
  }

  [self _resetFetchRequest];
  
  [self postDataSourceChangedNotification];
}

- (EOFetchSpecification *)fetchSpecification {
  return self->fetchSpecification;
}

- (EOFetchSpecification *)fetchSpecificationForFetch {
  EOFetchSpecification *fs;
  EOQualifier  *aq;
  NSDictionary *bindings;
  
  fs = [[[self fetchSpecification] copy] autorelease];
  
  /* add auxiliary-qualifier */
  
  if ((aq = [self auxiliaryQualifier]) != nil) {
    EOQualifier *q;
    
    if ((q = [fs qualifier]) != nil) {
      q = [[EOAndQualifier alloc] initWithQualifiers:q, aq, nil];
      [fs setQualifier:q];
      [q release]; q = nil;
    }
    else
      [fs setQualifier:aq];
  }
  
  /* apply bindings */
  
  if ((bindings = [self qualifierBindings]) != nil ) {
    EOQualifier *q;
    
    if ((q = [fs qualifier]) != nil) {
      q = [q qualifierWithBindings:[self qualifierBindings]
	     requiresAllVariables:YES];
      [fs setQualifier:q];
    }
  }
  
  /* finished */
  return fs;
}

- (void)setAuxiliaryQualifier:(EOQualifier *)_qualifier {
  if ([_qualifier isKindOfClass:[NSPredicate class]]) /* be tolerant */
    _qualifier = [EOQualifier qualifierForPredicate:(NSPredicate *)_qualifier];
  
  if ([self->auxiliaryQualifier isEqual:_qualifier])
    return;

  ASSIGNCOPY(self->auxiliaryQualifier, _qualifier);
  
  [self _resetFetchRequest];
  [self postDataSourceChangedNotification];
}
- (EOQualifier *)auxiliaryQualifier {
  return self->auxiliaryQualifier;
}

- (NSArray *)qualifierBindingKeys {
  NSMutableSet *join;
  NSArray *b, *ab;
  
  b  = [[[self fetchSpecification] qualifier] bindingKeys];
  ab = [[self auxiliaryQualifier] bindingKeys];
  if (ab == nil) return b;
  if (b  == nil) return ab;

  join = [[NSMutableSet alloc] initWithCapacity:16];
  [join addObjectsFromArray:b];
  [join addObjectsFromArray:ab];
  b = [join allObjects];
  [join release];
  return b;
}

- (void)setQualifierBindings:(NSDictionary *)_bindings {
  ASSIGN(self->qualifierBindings, _bindings);
  
  [self _resetFetchRequest];
  [self postDataSourceChangedNotification];
}
- (NSDictionary *)qualifierBindings {
  return self->qualifierBindings;
}

- (void)setIsFetchEnabled:(BOOL)_flag {
  int f;
  
  f = _flag ? 1 : 0;
  if (self->ecdFlags.isFetchEnabled == f)
    return;
  
  self->ecdFlags.isFetchEnabled = f;
  
  [self postDataSourceChangedNotification];
}
- (BOOL)isFetchEnabled {
  return self->ecdFlags.isFetchEnabled ? YES : NO;
}

/* directly access a CoreData fetch request */

- (void)setFetchRequest:(NSFetchRequest *)_fr {
  if (_fr == self->fetchRequest)
    return;
  
  /* reset EO objects */
  [self->fetchSpecification release]; self->fetchSpecification = nil;
  [self->auxiliaryQualifier release]; self->auxiliaryQualifier = nil;
  [self->qualifierBindings  release]; self->qualifierBindings  = nil;
  
  /* use entity of fetch-request */
  if ([_fr entity] != nil) {
    ASSIGN(self->entity, [_fr entity]);
    self->ecdFlags.isEntityFromFetchSpec = 1;
  }
  
  ASSIGN(self->fetchRequest, _fr);
}
- (NSFetchRequest *)fetchRequest {
  return self->fetchRequest;
}

/* accessors */

- (NSEntityDescription *)entity {
  if (self->entity == nil && !self->ecdFlags.isEntityFromFetchSpec) {
    NSManagedObjectContext *moc;
    NSString *n;
    
    self->ecdFlags.isEntityFromFetchSpec = 1; /* also used for caching fails */

    moc = [self managedObjectContext];
    n   = [[self fetchSpecification] entityName];
    if (moc != nil && n != nil) {
      self->entity = [[NSEntityDescription entityForName:n
					   inManagedObjectContext:moc] retain];
    }
  }
  return self->entity;
}
- (NSManagedObjectContext *)managedObjectContext {
  return self->managedObjectContext;
}

/* fetching */

- (NSArray *)fetchObjects {
  EOFetchSpecification *fs;
  NSError        *error = nil;
  NSArray        *results;

  if (debugOn) NSLog(@"fetchObjects");
  
  if (![self isFetchEnabled])
    return [NSArray array];
  
  // TODO: print a warning on entity mismatch?
  if (self->fetchRequest == nil) {
    fs = [self fetchSpecificationForFetch];
    self->fetchRequest = [[fs fetchRequestWithEntity:[self entity]] retain];
  }

  if (debugOn) NSLog(@"  request: %@", self->fetchRequest);
  
  results = [[self managedObjectContext] 
	      executeFetchRequest:self->fetchRequest error:&error];
  if (results == nil) {
    // TODO: improve (-lastException on the datasource or return the error?)
    NSLog(@"ERROR(%s): datasource failed to fetch: %@", __PRETTY_FUNCTION__,
	  error);
    return nil;
  }
  
  if (debugOn) NSLog(@"=> got %d records.", [results count]);
  
  // TODO: add grouping support?
  
  return results;
}

/* operations */

- (void)deleteObject:(id)_object {
  [[self managedObjectContext] deleteObject:_object];
  [self postDataSourceChangedNotification];
}

- (void)insertObject:(id)_object {
  [[self managedObjectContext] insertObject:_object];
  [self postDataSourceChangedNotification];
}

- (id)createObject {
  Class clazz;
  id    newObject;
  
  clazz = NSClassFromString([[self entity] managedObjectClassName]);
  
  newObject = [[clazz alloc] initWithEntity:[self entity]
			     insertIntoManagedObjectContext:
			       [self managedObjectContext]];
  return [newObject autorelease];
}

/* class description */

- (EOClassDescription *)classDescriptionForObjects {
  // TODO: should we create an EOClassDescription or just add
  //       EOClassDescription description stuff to NSEntityDescription?
  return (id)[self entity];
}

/* archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  id lEntity, fs, ec, tmp;

  /* fetch object context */
  
  ec = [_unarchiver decodeObjectReferenceForKey:@"managedObjectContext"];
  if (ec == nil)
    ec = [_unarchiver decodeObjectReferenceForKey:@"editingContext"];
  
  if (ec != nil && ![ec isKindOfClass:[NSManagedObjectContext class]]) {
    NSLog(@"WARNING(%s): decode object context is of unexpected class: %@",
	  __PRETTY_FUNCTION__, ec);
  }
  if (ec == nil) {
    NSLog(@"WARNING(%s): decoded no object context from archive!",
	  __PRETTY_FUNCTION__);
  }
  
  /* fetch fetch specification */
  
  fs = [_unarchiver decodeObjectForKey:@"fetchRequest"];
  if (fs == nil)
    fs = [_unarchiver decodeObjectForKey:@"fetchSpecification"];
  if (fs != nil && [fs isKindOfClass:[NSFetchRequest class]])
    fs = [[[EOFetchSpecification alloc] initWithFetchRequest:fs] autorelease];
  
  /* setup entity */
  
  lEntity = [_unarchiver decodeObjectForKey:@"entity"];
  if (lEntity == nil && fs != nil) {
    /* try to determine entity from fetch-spec */
    lEntity = [(EOFetchSpecification *)fs entityName];
  }
  if ([lEntity isKindOfClass:[NSString class]] && ec != nil) {
    lEntity = [NSEntityDescription entityForName:lEntity
				   inManagedObjectContext:ec];
  }
  
  /* create object */
  
  if ((self = [self initWithManagedObjectContext:ec entity:lEntity]) == nil)
    return nil;
  
  /* add non-initializer settings */
  
  [self setFetchSpecification:fs];
  [self setAuxiliaryQualifier:
	  [_unarchiver decodeObjectForKey:@"auxiliaryQualifier"]];
  [self setQualifierBindings:
	  [_unarchiver decodeObjectForKey:@"qualifierBindings"]];
  
  if ((tmp = [_unarchiver decodeObjectForKey:@"isFetchEnabled"]) != nil)
    [self setIsFetchEnabled:[tmp boolValue]];

  return self;
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  // TODO: do we need to produce the reference on our own?
  [_archiver encodeReferenceToObject:[self managedObjectContext] 
	     forKey:@"managedObjectContext"];
  
  [_archiver encodeObject:[self fetchSpecification] 
	     forKey:@"fetchSpecification"];
  [_archiver encodeObject:[self entity]
             forKey:@"entity"];
  [_archiver encodeObject:[self auxiliaryQualifier] 
	     forKey:@"auxiliaryQualifier"];
  [_archiver encodeObject:[self qualifierBindings] 
	     forKey:@"qualifierBindings"];
  [_archiver encodeBool:[self isFetchEnabled]
	     forKey:@"isFetchEnabled"];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->fetchSpecification != nil) 
    [ms appendFormat:@" fs=%@", self->fetchSpecification];
  
  if (self->auxiliaryQualifier != nil) 
    [ms appendFormat:@" aux=%@", self->auxiliaryQualifier];
  
  if (self->entity != nil) 
    [ms appendFormat:@" entity=%@", [self->entity name]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOCoreDataSource */
