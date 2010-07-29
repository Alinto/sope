/*
**  otest.m
**
**  Copyright (c) 2007  Inverse groupe conseil inc. and Ludovic Marcotte
**
**  Author: Ludovic Marcotte <ludovic@inverse.ca>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <Foundation/Foundation.h>
#import <GDLAccess/GDLAccess.h>

//
//
//
void evaluate(EOAdaptorChannel *c, NSString *s)
{
  NSLog(@"Evaluating:\t%@",s);
  if ([c evaluateExpression: s] && [c isFetchInProgress])
    {
      NSDictionary *record;
      NSArray *attributes;
      
      attributes = [c describeResults];
      NSLog(@"attributes = %@", [attributes description]);
      
      while ((record = [c fetchAttributes: attributes  withZone: NULL]))
	{
	  NSLog(@"record = %@", record);
	}
    }
}

//
//
//
void insert(EOAdaptorChannel *channel, EOEntity *entity, NSMutableDictionary *row)
{
  [row setObject: @"foo"  forKey: @"c_name"];
  [row setObject: @"barrr"  forKey: @"c_content"];
  [row setObject: [NSNumber numberWithInt: 1]  forKey: @"c_creationdate"];
  [row setObject: [NSNumber numberWithInt: 2]  forKey: @"c_lastmodified"];
  [row setObject: [NSNumber numberWithInt: 0]  forKey: @"c_version"];

  [channel insertRow: row  forEntity: entity];
}

//
//
//
void update(EOAdaptorChannel *channel, EOEntity *entity, NSMutableDictionary *row)
{
  EOSQLQualifier *qualifier;

  qualifier = [[EOSQLQualifier alloc] initWithEntity: entity
				      qualifierFormat: @"%A = 'foo'", @"c_name"];
				     
  [row setObject: @"bazzzzzzzzzzz"  forKey: @"c_content"];
  [row setObject: [NSNumber numberWithInt: 2]  forKey: @"c_creationdate"];
  [row setObject: [NSNumber numberWithInt: 3]  forKey: @"c_lastmodified"];
  [row setObject: [NSNumber numberWithInt: 1]  forKey: @"c_version"];
 
  [channel updateRow: row  describedByQualifier: qualifier];
}

//
//
//
int main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;

  EOAdaptorChannel *channel;
  NSMutableDictionary *row;
  EOAdaptorContext *ctx;
  EOAdaptor *adaptor;
  EOEntity *entity;
  EOAttribute *attribute;

  pool = [[NSAutoreleasePool alloc] init];
  [NSProcessInfo initializeWithArguments: argv  count: argc  environment: env];

  adaptor = [EOAdaptor adaptorWithName: @"Oracle8"];
  [adaptor setConnectionDictionary: [NSDictionary dictionaryWithContentsOfFile: @"condict.plist"]];
  ctx = [adaptor createAdaptorContext];
  channel = [ctx createAdaptorChannel];

  [channel openChannel];
  [ctx beginTransaction];
  
  //evaluate(channel, @"SELECT * FROM all_tables");
  evaluate(channel, @"SELECT COUNT(*) FROM all_tables");
  evaluate(channel, @"SELECT 1 FROM dual");
  evaluate(channel, @"SELECT sysdate FROM dual");
  
  evaluate(channel, @"DROP table otest_demo");
  evaluate(channel, @"CREATE TABLE otest_demo (\nc_name VARCHAR2 (256) NOT NULL,\n c_content CLOB NOT NULL,\n c_creationdate INTEGER NOT NULL,\n c_lastmodified INTEGER NOT NULL,\n c_version INTEGER NOT NULL,\n c_deleted INTEGER  DEFAULT 0 NOT NULL\n)");
  
  evaluate(channel, @"DELETE FROM otest_demo where c_name = 'foo'");

  entity = [[EOEntity alloc] init];
  [entity setName: @"otest_demo"];
  [entity setExternalName: @"otest_demo"]; // table name

  attribute = AUTORELEASE([[EOAttribute alloc] init]);
  [attribute setName: @"c_name"];
  [attribute setColumnName: @"c_name"];
  [entity addAttribute: attribute];

  row = [[NSMutableDictionary alloc] init];

  insert(channel, entity, row);
  evaluate(channel, @"SELECT * FROM otest_demo where c_name = 'foo'");
  update(channel, entity, row);
  evaluate(channel, @"SELECT * FROM otest_demo where c_name = 'foo'");

  RELEASE(entity);
  RELEASE(row);

  [ctx commitTransaction];
  [channel closeChannel];
  [pool release];
  
  return 0;
} 
