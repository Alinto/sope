/*
   Defaults.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: October 1997

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/Foundation.h>

static void usage (void)
{
    puts ("Tool to manipulate the defaults database of a generic implementation of");
    puts ("OpenStep Foundation.\n");

    puts ("Show the defaults for all the domains:");
    puts ("\tDefaults read");

    puts ("Show the defaults for a given domain:");
    puts ("\tDefaults read \"domain's name\"");

    puts ("Show the defaults for a given key of a given domain:");
    puts ("\tDefaults read \"domain's name\" \"key\"");

    puts ("Update the defaults for a given domain:");
    puts ("\tDefaults write \"domain's name\" \"domain's plist representation\"");

    puts ("Update the defaults for a given key in a given domain:");
    puts ("\tDefaults write \"domain's name\" \"key\" \"value\"");

    puts ("Delete the defaults for a given domain:");
    puts ("\tDefaults delete \"domain's name\"");

    puts ("Delete the defaults for a given key in a given domain:");
    puts ("\tDefaults delete \"domain's name\" \"key\"");

    puts ("Show all the existing domains:");
    puts ("\tDefaults domains");

    puts ("\nCopyright 1995-1997, Ovidiu Predescu and Mircea Oancea. See the libFoundation's");
    puts ("license for more information.");
    exit (0);
}

void read_command (NSArray *arguments)
{
    NSUserDefaults      *defaults;
    NSMutableDictionary *result;
    unsigned            argumentsCount;

    defaults       = [NSUserDefaults standardUserDefaults];
    result         = [NSMutableDictionary dictionaryWithCapacity:4];
    argumentsCount = [arguments count];

    if (argumentsCount == 2) {	/* Defaults read */
	/* Show the defaults for all the persistent domains */
	NSArray  *persistentDomainNames;
	unsigned i, count;
	NSString *key;

	persistentDomainNames = [defaults persistentDomainNames];
	
	for (i = 0, count = [persistentDomainNames count]; i < count; i++) {
	    key = [persistentDomainNames objectAtIndex:i];
	    [result setObject:[defaults persistentDomainForName:key]
		    forKey:key];
	}
    }
    else if (argumentsCount == 3 || argumentsCount == 4) {
	/* Defaults read "domain name" [key] */
	/* Show the defaults for a given domain */
	NSString *domainName = [arguments objectAtIndex:2];

	result = (NSMutableDictionary *)
	    [defaults persistentDomainForName:domainName];
	if (result == nil) {
	    NSLog(@"Domain '%@' does not exist!", domainName);
	    exit (1);
	}

	if (argumentsCount == 4) {
	    NSString *key  = [arguments objectAtIndex:3];
	    id       value = [result objectForKey:key];
	    
	    if (value == nil) {
		NSLog(@"There is no key '%@' under the '%@' domain!",
                      key, domainName);
		exit (1);
	    }
	    else
		result = value;
	}
    }
    else if (argumentsCount == 4) {	/* Defaults read "domain name" key */
	/* Show the defaults for a given key in a domain */
	NSString *domainName;

	domainName = [arguments objectAtIndex:2];
	result = (NSMutableDictionary *)
	    [defaults persistentDomainForName:domainName];
	if (result == nil) {
	    NSLog (@"Domain '%@' does not exist!", domainName);
	    exit (1);
	}
    }
    else
        usage ();
    printf ("%s\n", [[result description] cString]);
}

void write_command (NSArray* arguments)
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    int argumentsCount = [arguments count];

    if (argumentsCount == 4) { /* Defaults write "domain name" "plist" */
	/* Define here the format to avoid a bug in gcc. */
	id format = @"Cannot parse the representation of the domain name: '%@'";
	NSString* domainName = [arguments objectAtIndex:2];
	id value;

	NS_DURING
	    *(&value) = [[arguments objectAtIndex:3] propertyList];
            if (![value isKindOfClass:[NSDictionary class]]) {
                NSLog (@"The domain's value should be a dictionary object! "
                       @"(got '%@')", value);
                exit (1);
            }
	NS_HANDLER
	    NSLog (format, [arguments objectAtIndex:3]);
	    exit (1);
	NS_ENDHANDLER

	[defaults removePersistentDomainForName:domainName];
	[defaults setPersistentDomain:value forName:domainName];
    }
    else if (argumentsCount == 5) {/* Defaults write "domain name" key value */
	/* Define here the format to avoid a bug in gcc. */
	id format =
            @"Cannot parse the value of key '%@' for the domain name '%@': %@";
	NSString* domainName = [arguments objectAtIndex:2];
	id key = [arguments objectAtIndex:3];
	NSMutableDictionary* domainValue;
	id value;

	NS_DURING {
	    *(&value) = [[arguments objectAtIndex:4] propertyList];
        }
	NS_HANDLER {
	    NSLog (format, key, [arguments objectAtIndex:4], localException);
	    exit (1);
        }
	NS_ENDHANDLER

	domainValue = [[[defaults persistentDomainForName:domainName]
			  mutableCopy]
			  autorelease];
	if (domainValue == nil)
	    domainValue = [NSMutableDictionary dictionary];
	else
	    [defaults removePersistentDomainForName:domainName];

	[domainValue setObject:value forKey:key];
	[defaults setPersistentDomain:domainValue forName:domainName];
    }
    else
	usage ();

    if (![defaults synchronize])
        NSLog(@"errors during synchronization of defaults !");
}

void delete_command(NSArray *arguments) {
    /* Defaults delete "domain name" [key] */
    NSUserDefaults      *defaults;
    NSMutableDictionary *domainValue;
    NSString            *domainName;
    int                 argumentsCount;
    
    defaults       = [NSUserDefaults standardUserDefaults];
    argumentsCount = [arguments count];
    
    if (argumentsCount < 3 || argumentsCount > 4) {
        usage();
        return;
    }
    
    domainName = [arguments objectAtIndex:2];
    
    domainValue = [[[defaults persistentDomainForName:domainName]
			  mutableCopy]
			  autorelease];
    if (domainValue == nil) {
        NSLog(@"Domain '%@' does not exist!", domainName);
        exit(1);
    }
    
    if (argumentsCount == 3) {
        [defaults removePersistentDomainForName:domainName];

        // TODO: this prints a warning, but it is required
        [defaults synchronize];
    }
    else if (argumentsCount == 4) {
        id key = [arguments objectAtIndex:3];
        
        if ([domainValue objectForKey:key] == nil) {
            NSLog(@"Cannot find the key '%@' under domain name '%@'!",
                  key, domainName);
            exit(1);
        }

        [defaults removePersistentDomainForName:domainName];
        [domainValue removeObjectForKey:key];
        [defaults setPersistentDomain:domainValue forName:domainName];
        
        if (![defaults synchronize])
            NSLog(@"errors during synchronization of defaults !");
    }
}

void show_domains(void) {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSArray* persistentDomainNames = [defaults persistentDomainNames];
    int i, count = [persistentDomainNames count];

    for (i = 0; i < count; i++)
	printf ("%s\n", [[persistentDomainNames objectAtIndex:i] cString]);
}

#include <extensions/GarbageCollector.h>

int main(int argc, char **argv, char **env) {
    NSAutoreleasePool* pool;
    NSArray* arguments;
    NSString* command;
    int count;

#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    pool = [NSAutoreleasePool new];

    arguments = [[NSProcessInfo processInfo] arguments];
    count = [arguments count];

    if (count == 1)
      usage ();

    command = [arguments objectAtIndex:1];

    if ([command isEqual:@"read"])
	read_command (arguments);
    else if ([command isEqual:@"write"])
	write_command (arguments);
    else if ([command isEqual:@"delete"])
	delete_command (arguments);
    else if ([command isEqual:@"domains"])
	show_domains ();
    else
	usage ();

    RELEASE(pool);
    exit (0);
    return 0;
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
