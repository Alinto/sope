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

#include "iCalPortalPage.h"
#include <NGObjWeb/WODirectAction.h>

@interface iCalPortalRegistrationPage : iCalPortalPage
{
  NSString *login;
  NSString *firstName;
  NSString *lastName;
  NSString *email;
  NSString *address;
  NSString *city;
  NSString *state;
  NSString *zip;
  NSString *country;
  NSString *phone;
  NSString *wantIcalNews;
  NSString *wantSkyrixNews;

  BOOL loginOK;
  BOOL loginAvailable;
  BOOL pwdOK;
  BOOL firstNameOK;
  BOOL lastNameOK;
  BOOL emailOK;
}

- (void)markLoginWrong;
- (void)markLoginUsed;
- (void)markPwdWrong;
- (void)markFirstNameWrong;
- (void)markLastNameWrong;
- (void)markEmailWrong;

@end

@interface iCalPortalRegistrationAction : WODirectAction
@end

#include "common.h"

@interface NSString(EmailAddress)
- (BOOL)isValidEmailAddress;
@end

@implementation iCalPortalRegistrationPage

- (id)init {
  if ((self = [super init])) {
    self->loginOK        = YES;
    self->loginAvailable = YES;
    self->pwdOK          = YES;
    self->firstNameOK    = YES;
    self->lastNameOK     = YES;
    self->emailOK        = YES;
  }
  return self;
}

- (void)dealloc {
  [self->login          release];
  [self->firstName      release];
  [self->lastName       release];
  [self->email          release];
  [self->address        release];
  [self->city           release];
  [self->state          release];
  [self->zip            release];
  [self->country        release];
  [self->phone          release];
  [self->wantIcalNews   release];
  [self->wantSkyrixNews release];
  [super dealloc];
}

/* accessors */

- (void)setLogin:(NSString *)_value {
  ASSIGN(self->login, _value);
}
- (NSString *)login {
  return self->login;
}

- (void)setFirstName:(NSString *)_value {
  ASSIGN(self->firstName, _value);
}
- (NSString *)firstName {
  return self->firstName;
}

- (void)setLastName:(NSString *)_value {
  ASSIGN(self->lastName, _value);
}
- (NSString *)lastName {
  return self->lastName;
}

- (void)setEmail:(NSString *)_value {
  ASSIGN(self->email, _value);
}
- (NSString *)email {
  return self->email;
}

- (void)setAddress:(NSString *)_value {
  ASSIGN(self->address, _value);
}
- (NSString *)address {
  return self->address;
}

- (void)setCity:(NSString *)_value {
  ASSIGN(self->city, _value);
}
- (NSString *)city {
  return self->city;
}

- (void)setState:(NSString *)_value {
  ASSIGN(self->state, _value);
}
- (NSString *)state {
  return self->state;
}

- (void)setZip:(NSString *)_value {
  ASSIGN(self->zip, _value);
}
- (NSString *)zip {
  return self->zip;
}

- (void)setCountry:(NSString *)_value {
  ASSIGN(self->country, _value);
}
- (NSString *)country {
  return self->country;
}

- (void)setPhone:(NSString *)_value {
  ASSIGN(self->phone, _value);
}
- (NSString *)phone {
  return self->phone;
}

- (void)setWantIcalNews:(NSString *)_value {
  ASSIGN(self->wantIcalNews, _value);
}
- (NSString *)wantIcalNews {
  return self->wantIcalNews;
}

- (void)setWantSkyrixNews:(NSString *)_value {
  ASSIGN(self->wantSkyrixNews, _value);
}
- (NSString *)wantSkyrixNews {
  return self->wantSkyrixNews;
}

- (void)markLoginWrong {
  self->loginOK = NO;
}
- (BOOL)loginWrong {
  return !self->loginOK;
}
- (void)markLoginUsed {
  self->loginAvailable = NO;
}
- (BOOL)loginUsed {
  return !self->loginAvailable;
}
- (void)markPwdWrong {
  self->pwdOK = NO;
}
- (BOOL)pwdWrong {
  return !self->pwdOK;
}
- (void)markFirstNameWrong {
  self->firstNameOK = NO;
}
- (BOOL)firstNameWrong {
  return !self->firstNameOK;
}
- (void)markLastNameWrong {
  self->lastNameOK = NO;
}
- (BOOL)lastNameWrong {
  return !self->lastNameOK;
}
- (void)markEmailWrong {
  self->emailOK = NO;
}
- (BOOL)emailWrong {
  return !self->emailOK;
}

/* actions */

- (void)validate {
  // login: 4 to 16
  // pwd:   6 to 20
}

- (BOOL)isSessionProtectedPage {
  return NO;
}

- (id)run {
  return self;
}

@end /* iCalPortalRegistrationPage */

#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"

@implementation iCalPortalRegistrationAction

- (NSMutableDictionary *)collectFormValues {
  static NSString *keys[] = {
    /* do not add passwords here !! */
    @"login",
    @"firstName",
    @"lastName",
    @"email",
    @"address",
    @"city",
    @"state",
    @"zip",
    @"country",
    @"phone",
    @"wantIcalNews",
    @"wantSkyrixNews",
    nil
  };
  NSMutableDictionary *md;
  WORequest *rq;
  NSString  *key;
  unsigned  i;
  
  md = [NSMutableDictionary dictionaryWithCapacity:16];
  rq = [self request];
  
  for (i = 0; (key = keys[i]) != nil; i++) {
    NSString *val;
    
    val = [rq formValueForKey:key];
    if ([val isNotNull])
      [md setObject:val forKey:key];
  }
  
  return md;
}

- (id)saveProfile {
  iCalPortalRegistrationPage *page;
  iCalPortalDatabase  *db;
  NSMutableDictionary *values;
  NSString            *tmp;
  BOOL loginOK        = YES;
  BOOL loginAvailable = YES;
  BOOL pwdOK          = YES;
  BOOL firstNameOK    = YES;
  BOOL lastNameOK     = YES;
  BOOL emailOK        = YES;
  
  if ((db = [(id)[WOApplication application] database]) == nil)
    return nil;
  
  values = [self collectFormValues];
  
  /* validate login */
  
  tmp = [values objectForKey:@"login"];
  if ((loginOK = [db isLoginNameValid:tmp]))
    loginAvailable = [db isLoginNameUsed:tmp] ? NO : YES;
  
  /* validate password */
  
  tmp = [[self request] formValueForKey:@"pwd1"];
  if ((pwdOK = [db isPasswordValid:tmp])) {
    NSString *tmp2;
    
    if ((tmp2 = [[self request] formValueForKey:@"pwd2"])) {
      if (![tmp2 isEqualToString:tmp])
	pwdOK = NO;
    }
    else
      pwdOK = NO;
  }
  
  /* validate names */
  
  tmp = [values objectForKey:@"firstName"];
  if ([tmp length] < 3) firstNameOK = NO;
  tmp = [values objectForKey:@"lastName"];
  if ([tmp length] < 3) lastNameOK = NO;

  /* validate email */
  
  emailOK = [[values objectForKey:@"email"] isValidEmailAddress];
  
  /* process */
  
  if (loginOK&&loginAvailable&&pwdOK&&firstNameOK&&lastNameOK&&emailOK) {
    iCalPortalUser *user = nil;
    NSString *pwd = nil, *login = nil;
    
    pwd = [[self request] formValueForKey:@"pwd1"];
    
    login = [values objectForKey:@"login"];
    
    if ([db createUser:login info:values password:pwd]) {
      [self logWithFormat:@"did create account: %@ ...", login];
      
      user = [db userWithName:[values objectForKey:@"login"] password:pwd];
      if (user == nil) {
	[self logWithFormat:@"login of created account failed ?! (user=%@)",
	        user];
      }
      else {
	[[self session] setObject:user forKey:@"user"];
	return [[self pageWithName:@"iCalPortalHomePage"] performPage];
      }
    }
    else {
      [self logWithFormat:@"failed to create account: %@ ...", user];
    }
  }
  
  page = [self pageWithName:@"iCalPortalRegistrationPage"];
  
  [page takeValuesFromDictionary:values];
  
  if (!loginOK)        [page markLoginWrong];
  if (!loginAvailable) [page markLoginUsed];
  if (!pwdOK)          [page markPwdWrong];
  if (!firstNameOK)    [page markFirstNameWrong];
  if (!lastNameOK)     [page markLastNameWrong];
  if (!emailOK)        [page markEmailWrong];
  
  return [page performPage];
}

- (id)saveProfileAction {
  if ([[[self request] formValueForKey:@"action"] isEqualToString:@"save"])
    return [self saveProfile];
  
  return [self indexPage];
}

@end /* iCalPortalRegistrationAction */

@implementation NSString(EmailAddress)

- (BOOL)isValidEmailAddress {
  BOOL emailOK;
  
  if ([self length] < 3) 
    return NO;
  
  {
    static NSString *forbiddenOnes[] = {
      @"steve@apple.com",
      @"jobs@apple.com",
      @"steve.jobs@apple.com",
      @"bill@microsoft",
      @"gates@microsoft",
      @"bill.gates@microsoft",
      nil
    };
    NSString *tmp;
    unsigned i;
    NSRange  r;
    
    for (i = 0; (tmp = forbiddenOnes[i]) != nil; i++) {
      if ([self rangeOfString:tmp].length > 0) {
	[self logWithFormat:@"someone tried '%@' ...", tmp];
	return NO;
      }
    }
    
    tmp = self;
    
    r = [tmp rangeOfString:@"@"];
    if (r.length == 0)
      emailOK = NO;
    else if (r.location < 2) 
      emailOK = NO;
    else {
      tmp = [tmp substringFromIndex:(r.location + r.length)];
      r = [tmp rangeOfString:@"."];
      if (r.length == 0)
	emailOK = NO;
      else if (r.location == 0)
	emailOK = NO;
      else {
	tmp = [tmp substringFromIndex:(r.location + r.length)];
	emailOK = [tmp length] > 1;
      }
    }
  }
  return emailOK;
}

@end /* NSString(EmailAddress) */
