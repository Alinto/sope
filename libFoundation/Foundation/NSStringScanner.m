
/* parser.dlg -- DLG Description of scanner
 *
 * Generated from: NSStringPropList.g
 *
 * Terence Parr, Will Cohen, and Hank Dietz: 1989-1994
 * Purdue University Electrical Engineering
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
#include "antlr.h"
#include "tokens.h"
#include "dlgdef.h"
LOOKAHEAD
void zzerraction()
{
	(*zzerr)("invalid token");
	zzadvance();
	zzskip();
}
/*
 * D L G tables
 *
 * Generated from: parser.dlg
 *
 * 1989-1998 by  Will Cohen, Terence Parr, and Hank Dietz
 * Purdue University Electrical Engineering
 * DLG Version 1.33MR14
 */

#include "mode.h"




#include <Foundation/NSString.h>

static int level = 0;
extern NSMutableString* NSStringPropertyListParser_errors;

#define ERROR(msg) \
[NSStringPropertyListParser_errors \
appendFormat:[NSString stringWithCString:"line %d: " msg "\n"], zzline]
#define ERROR1(msg, arg) \
[NSStringPropertyListParser_errors \
appendFormat:[NSString stringWithCString:"line %d: " msg "\n"], zzline, arg]

static void act1()
{ 
		NLA = Eof;
	}


static void act2()
{ 
		NLA = 22;
		zzskip();  
	}


static void act3()
{ 
		NLA = 23;
		zzline++; zzskip();  
	}


static void act4()
{ 
		NLA = 24;
		zzmode(COMMENT); level++; zzskip();  
	}


static void act5()
{ 
		NLA = 25;
		zzmode(LINE_COMMENT); zzskip();  
	}


static void act6()
{ 
		NLA = 26;
		ERROR("unexpected comment terminator"); zzskip();  
	}


static void act7()
{ 
		NLA = 27;
		zzmode(STRING_CLASS); zzskip();  
	}


static void act8()
{ 
		NLA = 28;
		zzmode(DATA_CLASS); zzskip();  
	}


static void act9()
{ 
		NLA = STRING;
	}


static void act10()
{ 
		NLA = 29;
	}


static void act11()
{ 
		NLA = 30;
	}


static void act12()
{ 
		NLA = 31;
	}


static void act13()
{ 
		NLA = 32;
	}


static void act14()
{ 
		NLA = 33;
	}


static void act15()
{ 
		NLA = 34;
	}


static void act16()
{ 
		NLA = 35;
	}

static unsigned char shift0[257] = {
  0, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  1, 2, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 1, 16, 5, 7, 8, 16, 16, 
  16, 9, 11, 4, 16, 10, 16, 8, 3, 7, 
  7, 7, 7, 7, 7, 7, 7, 7, 7, 16, 
  14, 6, 13, 16, 16, 7, 7, 7, 7, 7, 
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 
  7, 7, 16, 16, 16, 16, 7, 16, 7, 7, 
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 
  7, 7, 7, 7, 12, 16, 15, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 
  16, 16, 16, 16, 16, 16, 16
};


static void act17()
{ 
		NLA = Eof;
	}


static void act18()
{ 
		NLA = 2;
		level++; zzskip();  
	}


static void act19()
{ 
		NLA = 3;
		if(!--level) zzmode(START); zzskip();  
	}


static void act20()
{ 
		NLA = 4;
		zzline++; zzskip();  
	}


static void act21()
{ 
		NLA = 5;
		zzskip();  
	}

static unsigned char shift1[257] = {
  0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 4, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 2, 3, 3, 3, 3, 1, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
  3, 3, 3, 3, 3, 3, 3
};


static void act22()
{ 
		NLA = Eof;
	}


static void act23()
{ 
		NLA = 6;
		zzmode(START); zzline++; zzskip();  
	}


static void act24()
{ 
		NLA = 7;
		zzskip();  
	}

static unsigned char shift2[257] = {
  0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 1, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
  2, 2, 2, 2, 2, 2, 2
};


static void act25()
{ 
		NLA = Eof;
	}


static void act26()
{ 
		NLA = STRING;
		zzmode(START); zzreplstr("");  
	}


static void act27()
{ 
		NLA = 9;
		zzmore();  
	}


static void act28()
{ 
		NLA = 10;
		{char a[2]={'\a',0}; zzreplstr(a);zzmore();}  
	}


static void act29()
{ 
		NLA = 11;
		{char a[2]={'\b',0}; zzreplstr(a);zzmore();}  
	}


static void act30()
{ 
		NLA = 12;
		{char a[2]={'\f',0}; zzreplstr(a);zzmore();}  
	}


static void act31()
{ 
		NLA = 13;
		{char a[2]={'\n',0}; zzreplstr(a);zzmore();}  
	}


static void act32()
{ 
		NLA = 14;
		{char a[2]={'\t',0}; zzreplstr(a);zzmore();}  
	}


static void act33()
{ 
		NLA = 15;
		{char a[2]={'\v',0}; zzreplstr(a);zzmore();}  
	}


static void act34()
{ 
		NLA = 16;
		{char a[2]={*zzendexpr,0}; zzreplstr(a);zzmore();}  
	}


static void act35()
{ 
		NLA = 17;
		zzmore();  
	}

static unsigned char shift3[257] = {
  0, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 1, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 2, 9, 9, 9, 9, 3, 4, 
  9, 9, 9, 5, 9, 9, 9, 9, 9, 9, 
  9, 6, 9, 9, 9, 9, 9, 7, 9, 8, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 
  9, 9, 9, 9, 9, 9, 9
};


static void act36()
{ 
		NLA = Eof;
	}


static void act37()
{ 
		NLA = DATA;
		zzmode(START); zzreplstr("");  
	}


static void act38()
{ 
		NLA = 19;
		zzreplstr(""); zzmore();  
	}


static void act39()
{ 
		NLA = 20;
		zzmore();  
	}


static void act40()
{ 
		NLA = 21;
		ERROR1("invalid character in description of NSData: '%c'", *zzendexpr); zzskip();  
	}

static unsigned char shift4[257] = {
  0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 2, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 3, 
  3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 
  4, 4, 4, 1, 4, 4, 3, 3, 3, 3, 
  3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 3, 3, 
  3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
  4, 4, 4, 4, 4, 4, 4
};

#define DfaStates	52
typedef unsigned char DfaState;

static DfaState st0[17] = {
  1, 2, 3, 4, 5, 6, 7, 8, 52, 9, 
  10, 11, 12, 13, 14, 15, 52
};

static DfaState st1[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st2[17] = {
  52, 2, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st3[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st4[17] = {
  52, 52, 52, 16, 17, 52, 52, 18, 18, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st5[17] = {
  52, 52, 52, 19, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st6[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st7[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st8[17] = {
  52, 52, 52, 18, 52, 52, 52, 18, 18, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st9[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st10[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st11[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st12[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st13[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st14[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st15[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st16[17] = {
  52, 52, 52, 18, 52, 52, 52, 18, 18, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st17[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st18[17] = {
  52, 52, 52, 18, 52, 52, 52, 18, 18, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st19[17] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52, 52, 52, 52, 52, 52, 52
};

static DfaState st20[6] = {
  21, 22, 23, 24, 25, 52
};

static DfaState st21[6] = {
  52, 52, 52, 52, 52, 52
};

static DfaState st22[6] = {
  52, 24, 26, 24, 52, 52
};

static DfaState st23[6] = {
  52, 27, 23, 24, 52, 52
};

static DfaState st24[6] = {
  52, 24, 23, 24, 52, 52
};

static DfaState st25[6] = {
  52, 52, 52, 52, 52, 52
};

static DfaState st26[6] = {
  52, 27, 23, 24, 52, 52
};

static DfaState st27[6] = {
  52, 24, 23, 24, 52, 52
};

static DfaState st28[4] = {
  29, 30, 31, 52
};

static DfaState st29[4] = {
  52, 52, 52, 52
};

static DfaState st30[4] = {
  52, 52, 52, 52
};

static DfaState st31[4] = {
  52, 52, 31, 52
};

static DfaState st32[11] = {
  33, 34, 35, 36, 36, 36, 36, 36, 36, 36, 
  52
};

static DfaState st33[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st34[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st35[11] = {
  52, 37, 37, 38, 39, 40, 41, 42, 43, 37, 
  52
};

static DfaState st36[11] = {
  52, 52, 52, 36, 36, 36, 36, 36, 36, 36, 
  52
};

static DfaState st37[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st38[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st39[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st40[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st41[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st42[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st43[11] = {
  52, 52, 52, 52, 52, 52, 52, 52, 52, 52, 
  52
};

static DfaState st44[6] = {
  45, 46, 47, 48, 49, 52
};

static DfaState st45[6] = {
  52, 52, 52, 52, 52, 52
};

static DfaState st46[6] = {
  52, 52, 52, 52, 52, 52
};

static DfaState st47[6] = {
  52, 52, 50, 52, 52, 52
};

static DfaState st48[6] = {
  52, 52, 52, 51, 52, 52
};

static DfaState st49[6] = {
  52, 52, 52, 52, 52, 52
};

static DfaState st50[6] = {
  52, 52, 50, 52, 52, 52
};

static DfaState st51[6] = {
  52, 52, 52, 51, 52, 52
};


DfaState *dfa[52] = {
	st0,
	st1,
	st2,
	st3,
	st4,
	st5,
	st6,
	st7,
	st8,
	st9,
	st10,
	st11,
	st12,
	st13,
	st14,
	st15,
	st16,
	st17,
	st18,
	st19,
	st20,
	st21,
	st22,
	st23,
	st24,
	st25,
	st26,
	st27,
	st28,
	st29,
	st30,
	st31,
	st32,
	st33,
	st34,
	st35,
	st36,
	st37,
	st38,
	st39,
	st40,
	st41,
	st42,
	st43,
	st44,
	st45,
	st46,
	st47,
	st48,
	st49,
	st50,
	st51
};


DfaState accepts[53] = {
  0, 1, 2, 3, 9, 0, 7, 8, 9, 10, 
  11, 12, 13, 14, 15, 16, 5, 4, 9, 6, 
  0, 17, 21, 21, 21, 20, 18, 19, 0, 22, 
  23, 24, 0, 25, 26, 27, 35, 34, 28, 29, 
  30, 31, 32, 33, 0, 36, 37, 38, 39, 40, 
  38, 39, 0
};

void (*actions[41])() = {
	zzerraction,
	act1,
	act2,
	act3,
	act4,
	act5,
	act6,
	act7,
	act8,
	act9,
	act10,
	act11,
	act12,
	act13,
	act14,
	act15,
	act16,
	act17,
	act18,
	act19,
	act20,
	act21,
	act22,
	act23,
	act24,
	act25,
	act26,
	act27,
	act28,
	act29,
	act30,
	act31,
	act32,
	act33,
	act34,
	act35,
	act36,
	act37,
	act38,
	act39,
	act40
};

static DfaState dfa_base[] = {
	0,
	20,
	28,
	32,
	44
};

static unsigned char *b_class_no[] = {
	shift0,
	shift1,
	shift2,
	shift3,
	shift4
};



#define ZZSHIFT(c) (b_class_no[zzauto][1+c])
#define MAX_MODE 5
#include "dlgauto.h"
