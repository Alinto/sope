/*
**  err.m
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

#include "err.h"

#include <Foundation/Foundation.h>

void checkerr(OCIError *errhp, sword status)
{
  text errbuf[512];
  sb4 errcode;

  if (status == OCI_SUCCESS) return;

  switch (status)
    {
    case OCI_SUCCESS_WITH_INFO:
      NSLog(@"Error - OCI_SUCCESS_WITH_INFO\n");
      OCIErrorGet ((dvoid *) errhp, (ub4) 1, (text *) NULL, &errcode,
		   errbuf, (ub4) sizeof(errbuf), (ub4) OCI_HTYPE_ERROR);
      NSLog(@"Error - %s\n", errbuf);
      break;
    case OCI_NEED_DATA:
      NSLog(@"Error - OCI_NEED_DATA\n");
      break;
    case OCI_NO_DATA:
      NSLog(@"Error - OCI_NO_DATA\n");
      break;
    case OCI_ERROR:
      OCIErrorGet ((dvoid *) errhp, (ub4) 1, (text *) NULL, &errcode,
		   errbuf, (ub4) sizeof(errbuf), (ub4) OCI_HTYPE_ERROR);
      NSLog(@"Error - %s\n", errbuf);
      break;
    case OCI_INVALID_HANDLE:
      NSLog(@"Error - OCI_INVALID_HANDLE\n");
      break;
    case OCI_STILL_EXECUTING:
      NSLog(@"Error - OCI_STILL_EXECUTING\n");
      break;
    case OCI_CONTINUE:
      NSLog(@"Error - OCI_CONTINUE\n");
      break;
    default:
      NSLog(@"Error - %d\n", status);
      break;
    }
}
