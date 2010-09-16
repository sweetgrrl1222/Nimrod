/* Generated by Nimrod Compiler v0.8.9 */
/*   (c) 2010 Andreas Rumpf */

typedef long long int NI;
typedef unsigned long long int NU;
#include "nimbase.h"

#include <pthread.h>
typedef struct TY54529 TY54529;
typedef struct TNimType TNimType;
typedef struct TNimNode TNimNode;
typedef struct TY54527 TY54527;
typedef struct TY54547 TY54547;
typedef struct TGenericSeq TGenericSeq;
typedef struct NimStringDesc NimStringDesc;
typedef struct TY53011 TY53011;
typedef struct TY53005 TY53005;
typedef struct TNimObject TNimObject;
typedef struct TY54551 TY54551;
typedef struct TY46532 TY46532;
typedef struct TY54525 TY54525;
typedef struct TY54539 TY54539;
typedef struct TY51008 TY51008;
typedef struct TY54543 TY54543;
typedef struct TY10802 TY10802;
typedef struct TY11190 TY11190;
typedef struct TY10818 TY10818;
typedef struct TY10814 TY10814;
typedef struct TY10810 TY10810;
typedef struct TY11188 TY11188;
typedef struct TY58079 TY58079;
typedef struct TY50448 TY50448;
typedef struct TY50036 TY50036;
typedef struct TY54549 TY54549;
typedef struct TY54519 TY54519;
typedef struct TY42013 TY42013;
struct TNimType {
NI size;
NU8 kind;
NU8 flags;
TNimType* base;
TNimNode* node;
void* finalizer;
};
struct TGenericSeq {
NI len;
NI space;
};
struct TY54529 {
TNimType* m_type;
NI Counter;
TY54527* Data;
};
struct TNimNode {
NU8 kind;
NI offset;
TNimType* typ;
NCSTRING name;
NI len;
TNimNode** sons;
};
typedef NIM_CHAR TY239[100000001];
struct NimStringDesc {
  TGenericSeq Sup;
TY239 data;
};
struct TNimObject {
TNimType* m_type;
};
struct TY53005 {
  TNimObject Sup;
NI Id;
};
struct TY46532 {
NI16 Line;
NI16 Col;
int Fileindex;
};
struct TY54539 {
NU8 K;
NU8 S;
NU8 Flags;
TY54551* T;
TY51008* R;
NI A;
};
struct TY54547 {
  TY53005 Sup;
NU8 Kind;
NU8 Magic;
TY54551* Typ;
TY53011* Name;
TY46532 Info;
TY54547* Owner;
NU32 Flags;
TY54529 Tab;
TY54525* Ast;
NU32 Options;
NI Position;
NI Offset;
TY54539 Loc;
TY54543* Annex;
};
struct TY10802 {
NI Refcount;
TNimType* Typ;
};
struct TY10818 {
NI Len;
NI Cap;
TY10802** D;
};
struct TY10814 {
NI Counter;
NI Max;
TY10810* Head;
TY10810** Data;
};
struct TY11188 {
NI Stackscans;
NI Cyclecollections;
NI Maxthreshold;
NI Maxstacksize;
NI Maxstackcells;
NI Cycletablesize;
};
struct TY11190 {
TY10818 Zct;
TY10818 Decstack;
TY10814 Cycleroots;
TY10818 Tempstack;
NI Cyclerootslock;
NI Zctlock;
TY11188 Stat;
};
struct TY58079 {
NI H;
};
struct TY53011 {
  TY53005 Sup;
NimStringDesc* S;
TY53011* Next;
NI H;
};
struct TY50448 {
NimStringDesc* Name;
NI Intsize;
NU8 Endian;
NI Floatsize;
NI Bit;
};
typedef TY50448 TY50461[12];
typedef NimStringDesc* TY50457[2];
struct TY50036 {
NimStringDesc* Name;
NimStringDesc* Pardir;
NimStringDesc* Dllfrmt;
NimStringDesc* Altdirsep;
NimStringDesc* Objext;
NimStringDesc* Newline;
NimStringDesc* Pathsep;
NimStringDesc* Dirsep;
NimStringDesc* Scriptext;
NimStringDesc* Curdir;
NimStringDesc* Exeext;
NimStringDesc* Extsep;
NU8 Props;
};
typedef TY50036 TY50054[21];
struct TY54551 {
  TY53005 Sup;
NU8 Kind;
TY54549* Sons;
TY54525* N;
NU8 Flags;
NU8 Callconv;
TY54547* Owner;
TY54547* Sym;
NI64 Size;
NI Align;
NI Containerid;
TY54539 Loc;
};
struct TY54525 {
TY54551* Typ;
NimStringDesc* Comment;
TY46532 Info;
NU8 Flags;
NU8 Kind;
union {
struct {NI64 Intval;
} S1;
struct {NF64 Floatval;
} S2;
struct {NimStringDesc* Strval;
} S3;
struct {TY54547* Sym;
} S4;
struct {TY53011* Ident;
} S5;
struct {TY54519* Sons;
} S6;
} KindU;
};
struct TY51008 {
  TNimObject Sup;
TY51008* Left;
TY51008* Right;
NI Length;
NimStringDesc* Data;
};
struct TY42013 {
  TNimObject Sup;
TY42013* Prev;
TY42013* Next;
};
struct TY54543 {
  TY42013 Sup;
NU8 Kind;
NIM_BOOL Generated;
TY51008* Name;
TY54525* Path;
};
typedef NI TY8814[8];
struct TY10810 {
TY10810* Next;
NI Key;
TY8814 Bits;
};
struct TY54527 {
  TGenericSeq Sup;
  TY54547* data[SEQ_DECL_SIZE];
};
struct TY54549 {
  TGenericSeq Sup;
  TY54551* data[SEQ_DECL_SIZE];
};
struct TY54519 {
  TGenericSeq Sup;
  TY54525* data[SEQ_DECL_SIZE];
};
N_NIMCALL(void, Definesymbol_62006)(NimStringDesc* Symbol_62008);
N_NIMCALL(TY53011*, Getident_53016)(NimStringDesc* Identifier_53018);
N_NIMCALL(TY54547*, Strtableget_58069)(TY54529* T_58071, TY53011* Name_58072);
N_NIMCALL(void*, newObj)(TNimType* Typ_12507, NI Size_12508);
N_NIMCALL(void, objectInit)(void* Dest_18462, TNimType* Typ_18463);
static N_INLINE(void, asgnRefNoCycle)(void** Dest_12018, void* Src_12019);
static N_INLINE(TY10802*, Usrtocell_11236)(void* Usr_11238);
static N_INLINE(NI, Atomicinc_3001)(NI* Memloc_3004, NI X_3005);
static N_INLINE(NI, Atomicdec_3006)(NI* Memloc_3009, NI X_3010);
static N_INLINE(void, Rtladdzct_11858)(TY10802* C_11860);
N_NOINLINE(void, Addzct_11225)(TY10818* S_11228, TY10802* C_11229);
N_NIMCALL(void, Strtableadd_58064)(TY54529* T_58067, TY54547* N_58068);
N_NIMCALL(void, Undefsymbol_62009)(NimStringDesc* Symbol_62011);
N_NIMCALL(NIM_BOOL, Isdefined_62012)(TY53011* Symbol_62014);
N_NIMCALL(void, Listsymbols_62015)(void);
N_NIMCALL(TY54547*, Inittabiter_58081)(TY58079* Ti_58084, TY54529* Tab_58085);
N_NIMCALL(void, Messageout_46550)(NimStringDesc* S_46552);
N_NIMCALL(TY54547*, Nextiter_58086)(TY58079* Ti_58089, TY54529* Tab_58090);
N_NIMCALL(NI, Countdefinedsymbols_62017)(void);
static N_INLINE(NI, addInt)(NI A_5803, NI B_5804);
N_NOINLINE(void, raiseOverflow)(void);
N_NIMCALL(void, Initdefines_62002)(void);
N_NIMCALL(void, Initstrtable_54746)(TY54529* X_54749);
static N_INLINE(void, appendString)(NimStringDesc* Dest_17592, NimStringDesc* Src_17593);
N_NOINLINE(void, raiseIndexError)(void);
N_NIMCALL(NimStringDesc*, nimIntToStr)(NI X_18203);
N_NIMCALL(NimStringDesc*, rawNewString)(NI Space_17487);
N_NIMCALL(NimStringDesc*, nsuNormalize)(NimStringDesc* S_23546);
N_NIMCALL(void, Deinitdefines_62004)(void);
STRING_LITERAL(TMP62104, "-- List of currently defined symbols --", 39);
STRING_LITERAL(TMP62105, "-- End of list --", 17);
STRING_LITERAL(TMP62152, "nimrod", 6);
STRING_LITERAL(TMP62153, "x86", 3);
STRING_LITERAL(TMP62154, "itanium", 7);
STRING_LITERAL(TMP62155, "x8664", 5);
STRING_LITERAL(TMP62156, "msdos", 5);
STRING_LITERAL(TMP62157, "mswindows", 9);
STRING_LITERAL(TMP62158, "win32", 5);
STRING_LITERAL(TMP62159, "unix", 4);
STRING_LITERAL(TMP62160, "posix", 5);
STRING_LITERAL(TMP62161, "sunos", 5);
STRING_LITERAL(TMP62162, "bsd", 3);
STRING_LITERAL(TMP62163, "macintosh", 9);
STRING_LITERAL(TMP62164, "cpu", 3);
extern NIM_CONST TY50461 Cpu_50460;
extern NIM_CONST TY50457 Endiantostr_50456;
extern NIM_CONST TY50054 Os_50053;
TY54529 Gsymbols_62001;
extern TNimType* NTI54529; /* TStrTable */
extern TNimType* NTI54523; /* PSym */
extern TNimType* NTI54547; /* TSym */
extern TY11190 Gch_11210;
extern NU8 Targetcpu_50560;
extern NU8 Targetos_50562;
static N_INLINE(TY10802*, Usrtocell_11236)(void* Usr_11238) {
TY10802* Result_11239;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "usrToCell";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/gc.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Result_11239 = 0;
F.line = 100;F.filename = "gc.nim";
Result_11239 = ((TY10802*) ((NI64)((NU64)(((NI) (Usr_11238))) - (NU64)(((NI) (((NI)sizeof(TY10802))))))));
framePtr = framePtr->prev;
return Result_11239;
}
static N_INLINE(NI, Atomicinc_3001)(NI* Memloc_3004, NI X_3005) {
NI Result_7408;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "atomicInc";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/systhread.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Result_7408 = 0;
F.line = 29;F.filename = "systhread.nim";
Result_7408 = __sync_add_and_fetch(Memloc_3004, X_3005);
framePtr = framePtr->prev;
return Result_7408;
}
static N_INLINE(NI, Atomicdec_3006)(NI* Memloc_3009, NI X_3010) {
NI Result_7606;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "atomicDec";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/systhread.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Result_7606 = 0;
F.line = 37;F.filename = "systhread.nim";
Result_7606 = __sync_sub_and_fetch(Memloc_3009, X_3010);
framePtr = framePtr->prev;
return Result_7606;
}
static N_INLINE(void, Rtladdzct_11858)(TY10802* C_11860) {
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "rtlAddZCT";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/gc.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
F.line = 211;F.filename = "gc.nim";
if (!NIM_TRUE) goto LA2;
F.line = 211;F.filename = "gc.nim";
pthread_mutex_lock(&Gch_11210.Zctlock);
LA2: ;
F.line = 212;F.filename = "gc.nim";
Addzct_11225(&Gch_11210.Zct, C_11860);
F.line = 213;F.filename = "gc.nim";
if (!NIM_TRUE) goto LA5;
F.line = 213;F.filename = "gc.nim";
pthread_mutex_unlock(&Gch_11210.Zctlock);
LA5: ;
framePtr = framePtr->prev;
}
static N_INLINE(void, asgnRefNoCycle)(void** Dest_12018, void* Src_12019) {
TY10802* C_12020;
NI LOC4;
TY10802* C_12022;
NI LOC9;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "asgnRefNoCycle";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/gc.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
F.line = 244;F.filename = "gc.nim";
if (!!((Src_12019 == NIM_NIL))) goto LA2;
C_12020 = 0;
F.line = 245;F.filename = "gc.nim";
C_12020 = Usrtocell_11236(Src_12019);
F.line = 246;F.filename = "gc.nim";
LOC4 = Atomicinc_3001(&(*C_12020).Refcount, 8);
LA2: ;
F.line = 247;F.filename = "gc.nim";
if (!!(((*Dest_12018) == NIM_NIL))) goto LA6;
C_12022 = 0;
F.line = 248;F.filename = "gc.nim";
C_12022 = Usrtocell_11236((*Dest_12018));
F.line = 249;F.filename = "gc.nim";
LOC9 = Atomicdec_3006(&(*C_12022).Refcount, 8);
if (!((NU64)(LOC9) < (NU64)(8))) goto LA10;
F.line = 250;F.filename = "gc.nim";
Rtladdzct_11858(C_12022);
LA10: ;
LA6: ;
F.line = 251;F.filename = "gc.nim";
(*Dest_12018) = Src_12019;
framePtr = framePtr->prev;
}
N_NIMCALL(void, Definesymbol_62006)(NimStringDesc* Symbol_62008) {
TY53011* I_62022;
TY54547* Sym_62023;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "DefineSymbol";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
I_62022 = 0;
F.line = 27;F.filename = "condsyms.nim";
I_62022 = Getident_53016(Symbol_62008);
Sym_62023 = 0;
F.line = 28;F.filename = "condsyms.nim";
Sym_62023 = Strtableget_58069(&Gsymbols_62001, I_62022);
F.line = 29;F.filename = "condsyms.nim";
if (!(Sym_62023 == NIM_NIL)) goto LA2;
F.line = 30;F.filename = "condsyms.nim";
Sym_62023 = (TY54547*) newObj(NTI54523, sizeof(TY54547));
objectInit(Sym_62023, NTI54547);
F.line = 31;F.filename = "condsyms.nim";
(*Sym_62023).Kind = ((NU8) 1);
F.line = 32;F.filename = "condsyms.nim";
asgnRefNoCycle((void**) &(*Sym_62023).Name, I_62022);
F.line = 33;F.filename = "condsyms.nim";
Strtableadd_58064(&Gsymbols_62001, Sym_62023);
LA2: ;
F.line = 34;F.filename = "condsyms.nim";
(*Sym_62023).Position = 1;
framePtr = framePtr->prev;
}
N_NIMCALL(void, Undefsymbol_62009)(NimStringDesc* Symbol_62011) {
TY54547* Sym_62054;
TY53011* LOC1;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "UndefSymbol";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Sym_62054 = 0;
F.line = 37;F.filename = "condsyms.nim";
LOC1 = 0;
LOC1 = Getident_53016(Symbol_62011);
Sym_62054 = Strtableget_58069(&Gsymbols_62001, LOC1);
F.line = 38;F.filename = "condsyms.nim";
if (!!((Sym_62054 == NIM_NIL))) goto LA3;
F.line = 38;F.filename = "condsyms.nim";
(*Sym_62054).Position = 0;
LA3: ;
framePtr = framePtr->prev;
}
N_NIMCALL(NIM_BOOL, Isdefined_62012)(TY53011* Symbol_62014) {
NIM_BOOL Result_62069;
TY54547* Sym_62070;
NIM_BOOL LOC1;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "isDefined";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Result_62069 = 0;
Sym_62070 = 0;
F.line = 41;F.filename = "condsyms.nim";
Sym_62070 = Strtableget_58069(&Gsymbols_62001, Symbol_62014);
F.line = 42;F.filename = "condsyms.nim";
LOC1 = !((Sym_62070 == NIM_NIL));
if (!(LOC1)) goto LA2;
LOC1 = ((*Sym_62070).Position == 1);
LA2: ;
Result_62069 = LOC1;
framePtr = framePtr->prev;
return Result_62069;
}
N_NIMCALL(void, Listsymbols_62015)(void) {
TY58079 It_62086;
TY54547* S_62088;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "ListSymbols";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
memset((void*)&It_62086, 0, sizeof(It_62086));
S_62088 = 0;
F.line = 46;F.filename = "condsyms.nim";
S_62088 = Inittabiter_58081(&It_62086, &Gsymbols_62001);
F.line = 47;F.filename = "condsyms.nim";
Messageout_46550(((NimStringDesc*) &TMP62104));
F.line = 48;F.filename = "condsyms.nim";
while (1) {
if (!!((S_62088 == NIM_NIL))) goto LA1;
F.line = 49;F.filename = "condsyms.nim";
if (!((*S_62088).Position == 1)) goto LA3;
F.line = 49;F.filename = "condsyms.nim";
Messageout_46550((*(*S_62088).Name).S);
LA3: ;
F.line = 50;F.filename = "condsyms.nim";
S_62088 = Nextiter_58086(&It_62086, &Gsymbols_62001);
} LA1: ;
F.line = 51;F.filename = "condsyms.nim";
Messageout_46550(((NimStringDesc*) &TMP62105));
framePtr = framePtr->prev;
}
static N_INLINE(NI, addInt)(NI A_5803, NI B_5804) {
NI Result_5805;
NIM_BOOL LOC2;
Result_5805 = 0;
Result_5805 = (NI64)((NU64)(A_5803) + (NU64)(B_5804));
LOC2 = (0 <= (NI64)(Result_5805 ^ A_5803));
if (LOC2) goto LA3;
LOC2 = (0 <= (NI64)(Result_5805 ^ B_5804));
LA3: ;
if (!LOC2) goto LA4;
goto BeforeRet;
LA4: ;
raiseOverflow();
BeforeRet: ;
return Result_5805;
}
N_NIMCALL(NI, Countdefinedsymbols_62017)(void) {
NI Result_62108;
TY58079 It_62109;
TY54547* S_62111;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "countDefinedSymbols";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Result_62108 = 0;
memset((void*)&It_62109, 0, sizeof(It_62109));
S_62111 = 0;
F.line = 55;F.filename = "condsyms.nim";
S_62111 = Inittabiter_58081(&It_62109, &Gsymbols_62001);
F.line = 56;F.filename = "condsyms.nim";
Result_62108 = 0;
F.line = 57;F.filename = "condsyms.nim";
while (1) {
if (!!((S_62111 == NIM_NIL))) goto LA1;
F.line = 58;F.filename = "condsyms.nim";
if (!((*S_62111).Position == 1)) goto LA3;
F.line = 58;F.filename = "condsyms.nim";
Result_62108 = addInt(Result_62108, 1);
LA3: ;
F.line = 59;F.filename = "condsyms.nim";
S_62111 = Nextiter_58086(&It_62109, &Gsymbols_62001);
} LA1: ;
framePtr = framePtr->prev;
return Result_62108;
}
static N_INLINE(void, appendString)(NimStringDesc* Dest_17592, NimStringDesc* Src_17593) {
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "appendString";
F.prev = framePtr;
F.filename = "/home/andreas/projects/nimrod/lib/system/sysstr.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
F.line = 150;F.filename = "sysstr.nim";
memcpy(((NCSTRING) (&(*Dest_17592).data[((*Dest_17592).Sup.len)-0])), ((NCSTRING) ((*Src_17593).data)), ((int) ((NI64)((NI64)((*Src_17593).Sup.len + 1) * 1))));
F.line = 151;F.filename = "sysstr.nim";
(*Dest_17592).Sup.len += (*Src_17593).Sup.len;
framePtr = framePtr->prev;
}
N_NIMCALL(void, Initdefines_62002)(void) {
NimStringDesc* LOC1;
NimStringDesc* LOC2;
NimStringDesc* LOC3;
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "InitDefines";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
F.line = 62;F.filename = "condsyms.nim";
Initstrtable_54746(&Gsymbols_62001);
F.line = 63;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62152));
F.line = 66;F.filename = "condsyms.nim";
switch (Targetcpu_50560) {
case ((NU8) 1):
F.line = 67;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62153));
break;
case ((NU8) 7):
F.line = 68;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62154));
break;
case ((NU8) 8):
F.line = 69;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62155));
break;
default:
break;
}
F.line = 72;F.filename = "condsyms.nim";
switch (Targetos_50562) {
case ((NU8) 1):
F.line = 74;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62156));
break;
case ((NU8) 2):
F.line = 76;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62157));
F.line = 77;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62158));
break;
case ((NU8) 4):
case ((NU8) 5):
case ((NU8) 6):
case ((NU8) 8):
case ((NU8) 13):
case ((NU8) 14):
case ((NU8) 16):
case ((NU8) 12):
F.line = 80;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62159));
F.line = 81;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62160));
break;
case ((NU8) 7):
F.line = 83;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62161));
F.line = 84;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62159));
F.line = 85;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62160));
break;
case ((NU8) 9):
case ((NU8) 10):
case ((NU8) 11):
F.line = 87;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62159));
F.line = 88;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62162));
F.line = 89;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62160));
break;
case ((NU8) 18):
F.line = 91;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62163));
break;
case ((NU8) 19):
F.line = 93;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62163));
F.line = 94;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62159));
F.line = 95;F.filename = "condsyms.nim";
Definesymbol_62006(((NimStringDesc*) &TMP62160));
break;
default:
break;
}
F.line = 98;F.filename = "condsyms.nim";
LOC1 = 0;
if (Targetcpu_50560 < 1 || Targetcpu_50560 > 12) raiseIndexError();
LOC2 = 0;
LOC2 = nimIntToStr(Cpu_50460[(Targetcpu_50560)-1].Bit);
LOC1 = rawNewString(LOC2->Sup.len + 3);
appendString(LOC1, ((NimStringDesc*) &TMP62164));
appendString(LOC1, LOC2);
Definesymbol_62006(LOC1);
F.line = 99;F.filename = "condsyms.nim";
if (Targetcpu_50560 < 1 || Targetcpu_50560 > 12) raiseIndexError();
LOC3 = 0;
LOC3 = nsuNormalize(Endiantostr_50456[(Cpu_50460[(Targetcpu_50560)-1].Endian)-0]);
Definesymbol_62006(LOC3);
F.line = 100;F.filename = "condsyms.nim";
if (Targetcpu_50560 < 1 || Targetcpu_50560 > 12) raiseIndexError();
Definesymbol_62006(Cpu_50460[(Targetcpu_50560)-1].Name);
F.line = 101;F.filename = "condsyms.nim";
if (Targetos_50562 < 1 || Targetos_50562 > 21) raiseIndexError();
Definesymbol_62006(Os_50053[(Targetos_50562)-1].Name);
framePtr = framePtr->prev;
}
N_NIMCALL(void, Deinitdefines_62004)(void) {
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "DeinitDefines";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
framePtr = framePtr->prev;
}
N_NOINLINE(void, condsymsInit)(void) {
volatile struct {TFrame* prev;NCSTRING procname;NI line;NCSTRING filename;NI len;
} F;
F.procname = "condsyms";
F.prev = framePtr;
F.filename = "rod/condsyms.nim";
F.line = 0;
framePtr = (TFrame*)&F;
F.len = 0;
Gsymbols_62001.m_type = NTI54529;
framePtr = framePtr->prev;
}
