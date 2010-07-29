/*
 * A n t l r  S e t s / E r r o r  F i l e  H e a d e r
 *
 * Generated from: NSStringPropList.g
 *
 * Terence Parr, Russell Quong, Will Cohen, and Hank Dietz: 1989-1995
 * Parr Research Corporation
 * with Purdue University Electrical Engineering
 * With AHPCRC, University of Minnesota
 * ANTLR Version 1.33
 */

#include <stdio.h>
#define ANTLR_VERSION	133
#define zzparser NSStringPropertyListParser
#include "remap.h"

#include <objc/objc.h>

#ifndef __Attrib_def__
#define __Attrib_def__
typedef id Attrib;
#endif

#define USER_ZZSYN
#define zzcr_attr NSStringPropertyListParser_zzcr_attr
void zzcr_attr(Attrib* attr, int token, char* text);
#define zzSET_SIZE 8
#include "antlr.h"
#include "tokens.h"
#include "dlgdef.h"
#include "err.h"

ANTLRChar *NSStringPropertyListParser_zztokens[36]={
	/* 00 */	"Invalid",
	/* 01 */	"Eof",
	/* 02 */	"/\\*",
	/* 03 */	"~[\\n]*\\*/",
	/* 04 */	"\\n",
	/* 05 */	"~[\\n]+",
	/* 06 */	"\\n",
	/* 07 */	"~[\\n]+",
	/* 08 */	"STRING",
	/* 09 */	"\\",
	/* 10 */	"\\a",
	/* 11 */	"\\b",
	/* 12 */	"\\f",
	/* 13 */	"\\n",
	/* 14 */	"\\t",
	/* 15 */	"\\v",
	/* 16 */	"\\~[]",
	/* 17 */	"~[\"\\]+",
	/* 18 */	"DATA",
	/* 19 */	"[\\ \\t]+",
	/* 20 */	"([0-9a-fA-F])+",
	/* 21 */	"~[]",
	/* 22 */	"[\\t\\ ]+",
	/* 23 */	"\\n",
	/* 24 */	"/\\*",
	/* 25 */	"//",
	/* 26 */	"\\*/",
	/* 27 */	"\"",
	/* 28 */	"\\<",
	/* 29 */	"\\(",
	/* 30 */	",",
	/* 31 */	"\\)",
	/* 32 */	"\\{",
	/* 33 */	"=",
	/* 34 */	";",
	/* 35 */	"\\}"
};
SetWordType zzerr1[8] = {0x0,0x1,0x4,0x20, 0x1,0x0,0x0,0x0};
SetWordType setwd1[36] = {0x0,0xd3,0x0,0x0,0x0,0x0,0x0,
	0x0,0x7e,0x0,0x0,0x0,0x0,0x0,0x0,
	0x0,0x0,0x0,0x7e,0x0,0x0,0x0,0x0,
	0x0,0x0,0x0,0x0,0x0,0x0,0x7e,0x5a,
	0x52,0x7e,0x52,0x52,0x52};
