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
/* pwcheck_ldap.c -- check passwords using LDAP
 *
 * Author: Clayton Donley <donley@cig.mot.com>
 *         http://www.wwa.com/~donley/
 * Version: 1.01
 *
 * Note: This works by finding a DN that matches an entered UID and
 * binding to the LDAP server using this UID.  This uses clear-text
 * passwords.  A better approach with servers that support SSL and
 * new LDAPv3 servers that support SASL bind methods like CRAM-MD5
 * and TSL.
 *
 * This version should work with both University of Michigan and Netscape
 * LDAP libraries.  It also gets rid of the requirement for userPassword
 * attribute readability.
 *
 */

//#include <lber.h>
#include <stdio.h>
#include <sys/types.h>
#include <lber.h>
#include <ldap.h>
//#include <libio.h>

/* Set These to your Local Environment */

#define MY_LDAP_SERVER  "imap.mdlink.de"
#define MY_LDAP_BASEDN  "ou=people,o=mdlink.de"
#define MY_LDAP_UIDATTR "uid"

char *pwcheck(char *userid, char *password) {
    LDAP *ld;
    LDAPMessage *result;
    LDAPMessage *entry;
    char *attrs[2];
    char filter[200]; 
    char *dn;
    int ldbind_res;
    char **vals;

/* If the password is NULL, reject the login...Otherwise the bind will
   succeed as a reference bind.  Not good... */

    if (strcmp(password,"") == 0)
    {
       return "Null Password";
    }
    
/* Open the LDAP connection.  Change the second argument if your LDAP
   server is not on port 389. */

    if ((ld = ldap_open(MY_LDAP_SERVER,LDAP_PORT)) == NULL)
    {
       return "Init Failed";
    }

/* Bind anonymously so that you can find the DN of the appropriate user. */

    if (ldap_simple_bind_s(ld,"","") != LDAP_SUCCESS)
    {
        ldap_unbind(ld);
        return "Bind Failed";
    }

/* Generate a filter that will return the entry with a matching UID */

    sprintf(filter,"(%s=%s)",MY_LDAP_UIDATTR,userid);

/* Just return country...This doesn't actually matter, since we will
   not read the attributes and values, only the DN */

    attrs[0] = "c";
    attrs[1] = NULL;

/* Perform the search... */

    if (ldap_search_s(ld,MY_LDAP_BASEDN,LDAP_SCOPE_SUBTREE,filter,attrs,1,&result)
!= LDAP_SUCCESS)
    {
       ldap_unbind(ld);
       return "Search Failed";
    }

/* If the entry count is not equal to one, either the UID was not unique or
   there was no match */

    if ((ldap_count_entries(ld,result)) != 1)
    {
       ldap_unbind(ld);
       return "UserID Unknown";
    }

/* Get the first entry */

    if ((entry = ldap_first_entry(ld,result)) == NULL)
    {
       ldap_unbind(ld);
       return "UserID Unknown";
    }

/* Get the DN of the entry */

    if ((dn = ldap_get_dn(ld,entry)) == NULL)
    {
       ldap_unbind(ld);
       return "DN Not Found";
    }

/* Now bind as the DN with the password supplied earlier...
   Successful bind means the password was correct, otherwise the
   password is invalid. */

    printf("dn: %s\npassword: %s\n", dn, password);
    
    if (ldap_simple_bind_s(ld,dn,password) != LDAP_SUCCESS)
    {
       ldap_unbind(ld);
       return "Invalid Login or Password";
    }

    ldap_unbind(ld);
    return "OK";
}

#include <Foundation/Foundation.h>
#include "NGLdapConnection.h"

int main(int argc, char **argv, char **env) {
  NSArray        *args;
  NSUserDefaults *ud;
  char *uid, *pwd;

#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  args = [[NSProcessInfo processInfo] arguments];
  ud   = [NSUserDefaults standardUserDefaults];
  
  if (argc < 3)
    exit(10);

#if 0
  uid = argv[1];
  pwd = argv[2];
  
  printf("pwcheck('%s', '%s'): %s\n", uid, pwd,
         pwcheck(uid, pwd));
#else
  
  if ([NGLdapConnection checkPassword:[ud stringForKey:@"LDAPPassword"]
                        ofLogin:[ud stringForKey:@"LDAPBindDN"]
                        atBaseDN:[ud stringForKey:@"LDAPRootDN"]
                        onHost:[ud stringForKey:@"LDAPHost"]
                        port:0]) {
    NSLog(@"OK: user %@ is authorized.", [ud stringForKey:@"LDAPBindDN"]);
  }
  else {
    NSLog(@"FAIL: user %@ is not authorized.", [ud stringForKey:@"LDAPBindDN"]);
  }
  
#endif
  return 0;
}
