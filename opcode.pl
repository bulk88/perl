#!/usr/bin/perl
BEGIN {
    # Get function prototypes
    require 'regen.pl';
}

$opcode_new = 'opcode.h-new';
$opname_new = 'opnames.h-new';
open(OC, ">$opcode_new") || die "Can't create $opcode_new: $!\n";
open(ON, ">$opname_new") || die "Can't create $opname_new: $!\n";
select OC;

# Read data.

while (<DATA>) {
    chop;
    next unless $_;
    next if /^#/;
    ($key, $desc, $check, $flags, $args) = split(/\t+/, $_, 5);

    warn qq[Description "$desc" duplicates $seen{$desc}\n] if $seen{$desc};
    die qq[Opcode "$key" duplicates $seen{$key}\n] if $seen{$key};
    $seen{$desc} = qq[description of opcode "$key"];
    $seen{$key} = qq[opcode "$key"];

    push(@ops, $key);
    $desc{$key} = $desc;
    $check{$key} = $check;
    $ckname{$check}++;
    $flags{$key} = $flags;
    $args{$key} = $args;
}

# Emit defines.

$i = 0;
print <<"END";
/*
 *    opcode.h
 *
 *    Copyright (c) 1997-2002, Larry Wall
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *  This file is built by opcode.pl from its data.  Any changes made here
 *  will be lost!
 */

#define Perl_pp_i_preinc Perl_pp_preinc
#define Perl_pp_i_predec Perl_pp_predec
#define Perl_pp_i_postinc Perl_pp_postinc
#define Perl_pp_i_postdec Perl_pp_postdec

END

print ON <<"END";
/*
 *    opnames.h
 *
 *    Copyright (c) 1997-2002, Larry Wall
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 *
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *  This file is built by opcode.pl from its data.  Any changes made here
 *  will be lost!
 */

typedef enum opcode {
END

for (@ops) {
    print ON "\t", &tab(3,"OP_\U$_,"), "/* ", $i++, " */\n";
}
print ON "\t", &tab(3,"OP_max"), "\n";
print ON "} opcode;\n";
print ON "\n#define MAXO ", scalar @ops, "\n";
print ON "#define OP_phoney_INPUT_ONLY -1\n";
print ON "#define OP_phoney_OUTPUT_ONLY -2\n\n";

# Emit op names and descriptions.

print <<END;

START_EXTERN_C


#define OP_NAME(o) (o->op_type == OP_CUSTOM ? custom_op_name(o) : \\
                    PL_op_name[o->op_type])
#define OP_DESC(o) (o->op_type == OP_CUSTOM ? custom_op_desc(o) : \\
                    PL_op_desc[o->op_type])

#ifndef DOINIT
EXT char *PL_op_name[];
#else
EXT char *PL_op_name[] = {
END

for (@ops) {
    print qq(\t"$_",\n);
}

print <<END;
};
#endif

END

print <<END;
#ifndef DOINIT
EXT char *PL_op_desc[];
#else
EXT char *PL_op_desc[] = {
END

for (@ops) {
    my($safe_desc) = $desc{$_};

    # Have to escape double quotes and escape characters.
    $safe_desc =~ s/(^|[^\\])([\\"])/$1\\$2/g;

    print qq(\t"$safe_desc",\n);
}

print <<END;
};
#endif

END_EXTERN_C

END

# Emit function declarations.

#for (sort keys %ckname) {
#    print "OP *\t", &tab(3,$_),"(pTHX_ OP* o);\n";
#}
#
#print "\n";
#
#for (@ops) {
#    print "OP *\t", &tab(3, "pp_$_"), "(pTHX);\n";
#}

# Emit ppcode switch array.

print <<END;

START_EXTERN_C

#ifndef DOINIT
EXT OP * (CPERLscope(*PL_ppaddr)[])(pTHX);
#else
EXT OP * (CPERLscope(*PL_ppaddr)[])(pTHX) = {
END

for (@ops) {
    print "\tMEMBER_TO_FPTR(Perl_pp_$_),\n" unless $_ eq "custom";
}

print <<END;
};
#endif

END

# Emit check routines.

print <<END;
#ifndef DOINIT
EXT OP * (CPERLscope(*PL_check)[]) (pTHX_ OP *op);
#else
EXT OP * (CPERLscope(*PL_check)[]) (pTHX_ OP *op) = {
END

for (@ops) {
    print "\t", &tab(3, "MEMBER_TO_FPTR(Perl_$check{$_}),"), "\t/* $_ */\n";
}

print <<END;
};
#endif

END

# Emit allowed argument types.

print <<END;
#ifndef DOINIT
EXT U32 PL_opargs[];
#else
EXT U32 PL_opargs[] = {
END

%argnum = (
    S,	1,		# scalar
    L,	2,		# list
    A,	3,		# array value
    H,	4,		# hash value
    C,	5,		# code value
    F,	6,		# file value
    R,	7,		# scalar reference
);

%opclass = (
    '0',  0,		# baseop
    '1',  1,		# unop
    '2',  2,		# binop
    '|',  3,		# logop
    '@',  4,		# listop
    '/',  5,		# pmop
    '$',  6,		# svop_or_padop
    '#',  7,		# padop
    '"',  8,		# pvop_or_svop
    '{',  9,		# loop
    ';',  10,		# cop
    '%',  11,		# baseop_or_unop
    '-',  12,		# filestatop
    '}',  13,		# loopexop
);

my %OP_IS_SOCKET;
my %OP_IS_FILETEST;

for (@ops) {
    $argsum = 0;
    $flags = $flags{$_};
    $argsum |= 1 if $flags =~ /m/;		# needs stack mark
    $argsum |= 2 if $flags =~ /f/;		# fold constants
    $argsum |= 4 if $flags =~ /s/;		# always produces scalar
    $argsum |= 8 if $flags =~ /t/;		# needs target scalar
    $argsum |= (8|256) if $flags =~ /T/;	# ... which may be lexical
    $argsum |= 16 if $flags =~ /i/;		# always produces integer
    $argsum |= 32 if $flags =~ /I/;		# has corresponding int op
    $argsum |= 64 if $flags =~ /d/;		# danger, unknown side effects
    $argsum |= 128 if $flags =~ /u/;		# defaults to $_
    $flags =~ /([\W\d_])/ or die qq[Opcode "$_" has no class indicator];
    $argsum |= $opclass{$1} << 9;
    $mul = 0x2000;				# 2 ^ OASHIFT
    for $arg (split(' ',$args{$_})) {
	if ($arg =~ /^F/) {
           $OP_IS_SOCKET{$_}   = 1 if $arg =~ s/s//;
           $OP_IS_FILETEST{$_} = 1 if $arg =~ s/-//;
        }
	$argnum = ($arg =~ s/\?//) ? 8 : 0;
        die "op = $_, arg = $arg\n" unless length($arg) == 1;
	$argnum += $argnum{$arg};
	warn "# Conflicting bit 32 for '$_'.\n"
	    if $argnum & 8 and $mul == 0x10000000;
	$argsum += $argnum * $mul;
	$mul <<= 4;
    }
    $argsum = sprintf("0x%08x", $argsum);
    print "\t", &tab(3, "$argsum,"), "/* $_ */\n";
}

print <<END;
};
#endif

END_EXTERN_C
END

if (keys %OP_IS_SOCKET) {
    print ON "\n#define OP_IS_SOCKET(op)	\\\n\t(";
    print ON join(" || \\\n\t ",
               map { "(op) == OP_" . uc() } sort keys %OP_IS_SOCKET);
    print ON ")\n\n";
}

if (keys %OP_IS_FILETEST) {
    print ON "\n#define OP_IS_FILETEST(op)	\\\n\t(";
    print ON join(" || \\\n\t ",
               map { "(op) == OP_" . uc() } sort keys %OP_IS_FILETEST);
    print ON ")\n\n";
}

close OC or die "Error closing opcode.h: $!";
close ON or die "Error closing opnames.h: $!";

foreach ('opcode.h', 'opnames.h') {
    safer_rename_silent $_, "$_-old";
}
safer_rename $opcode_new, 'opcode.h';
safer_rename $opname_new, 'opnames.h';

$pp_proto_new = 'pp_proto.h-new';
$pp_sym_new  = 'pp.sym-new';

open PP, ">$pp_proto_new" or die "Error creating $pp_proto_new: $!";
open PPSYM, ">$pp_sym_new" or die "Error creating $pp_sym_new: $!";

print PP <<"END";
/* !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
   This file is built by opcode.pl from its data.  Any changes made here
   will be lost!
*/

END

print PPSYM <<"END";
#
# !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
#   This file is built by opcode.pl from its data.  Any changes made here
#   will be lost!
#

END


for (sort keys %ckname) {
    print PP "PERL_CKDEF(Perl_$_)\n";
    print PPSYM "Perl_$_\n";
#OP *\t", &tab(3,$_),"(OP* o);\n";
}

print PP "\n\n";

for (@ops) {
    next if /^i_(pre|post)(inc|dec)$/;
    next if /^custom$/;
    print PP "PERL_PPDEF(Perl_pp_$_)\n";
    print PPSYM "Perl_pp_$_\n";
}

close PP or die "Error closing pp_proto.h: $!";
close PPSYM or die "Error closing pp.sym: $!";

foreach ('pp_proto.h', 'pp.sym') {
    safer_rename_silent $_, "$_-old";
}
safer_rename $pp_proto_new, 'pp_proto.h';
safer_rename $pp_sym_new, 'pp.sym';

###########################################################################
sub tab {
    local($l, $t) = @_;
    $t .= "\t" x ($l - (length($t) + 1) / 8);
    $t;
}
###########################################################################

# Some comments about 'T' opcode classifier:

# Safe to set if the ppcode uses:
#	tryAMAGICbin, tryAMAGICun, SETn, SETi, SETu, PUSHn, PUSHTARG, SETTARG,
#	SETs(TARG), XPUSHn, XPUSHu,

# Unsafe to set if the ppcode uses dTARG or [X]RETPUSH[YES|NO|UNDEF]

# lt and friends do SETs (including ncmp, but not scmp)

# Additional mode of failure: the opcode can modify TARG before it "used"
# all the arguments (or may call an external function which does the same).
# If the target coincides with one of the arguments ==> kaboom.

# pp.c	pos substr each not OK (RETPUSHUNDEF)
#	substr vec also not OK due to LV to target (are they???)
#	ref not OK (RETPUSHNO)
#	trans not OK (dTARG; TARG = sv_newmortal();)
#	ucfirst etc not OK: TMP arg processed inplace
#	quotemeta not OK (unsafe when TARG == arg)
#	each repeat not OK too due to list context
#	pack split - unknown whether they are safe
#	sprintf: is calling do_sprintf(TARG,...) which can act on TARG
#	  before other args are processed.

#	Suspicious wrt "additional mode of failure" (and only it):
#	schop, chop, postinc/dec, bit_and etc, negate, complement.

#	Also suspicious: 4-arg substr, sprintf, uc/lc (POK_only), reverse, pack.

#	substr/vec: doing TAINT_off()???

# pp_hot.c
#	readline - unknown whether it is safe
#	match subst not OK (dTARG)
#	grepwhile not OK (not always setting)
#	join not OK (unsafe when TARG == arg)

#	Suspicious wrt "additional mode of failure": concat (dealt with
#	in ck_sassign()), join (same).

# pp_ctl.c
#	mapwhile flip caller not OK (not always setting)

# pp_sys.c
#	backtick glob warn die not OK (not always setting)
#	warn not OK (RETPUSHYES)
#	open fileno getc sysread syswrite ioctl accept shutdown
#	 ftsize(etc) readlink telldir fork alarm getlogin not OK (RETPUSHUNDEF)
#	umask select not OK (XPUSHs(&PL_sv_undef);)
#	fileno getc sysread syswrite tell not OK (meth("FILENO" "GETC"))
#	sselect shm* sem* msg* syscall - unknown whether they are safe
#	gmtime not OK (list context)

#	Suspicious wrt "additional mode of failure": warn, die, select.

__END__

# New ops always go at the end, just before 'custom'

# A recapitulation of the format of this file:
# The file consists of five columns: the name of the op, an English
# description, the name of the "check" routine used to optimize this
# operation, some flags, and a description of the operands.

# The flags consist of options followed by a mandatory op class signifier

# The classes are:
# baseop      - 0            unop     - 1            binop      - 2
# logop       - |            listop   - @            pmop       - /
# padop/svop  - $            padop    - # (unused)   loop       - {
# baseop/unop - %            loopexop - }            filestatop - -
# pvop/svop   - "            cop      - ;

# Other options are:
#   needs stack mark                    - m
#   needs constant folding              - f
#   produces a scalar                   - s
#   produces an integer                 - i
#   needs a target                      - t
#   target can be in a pad              - T
#   has a corresponding integer version - I
#   has side effects                    - d
#   uses $_ if no argument given        - u

# Values for the operands are:
# scalar      - S            list     - L            array     - A
# hash        - H            sub (CV) - C            file      - F
# socket      - Fs           filetest - F-           reference - R
# "?" denotes an optional operand.

# Nothing.

null		null operation		ck_null		0	
stub		stub			ck_null		0
scalar		scalar			ck_fun		s%	S

# Pushy stuff.

pushmark	pushmark		ck_null		s0	
wantarray	wantarray		ck_null		is0	

const		constant item		ck_svconst	s$	

gvsv		scalar variable		ck_null		ds$	
gv		glob value		ck_null		ds$	
gelem		glob elem		ck_null		d2	S S
padsv		private variable	ck_null		ds0
padav		private array		ck_null		d0
padhv		private hash		ck_null		d0
padany		private value		ck_null		d0

pushre		push regexp		ck_null		d/

# References and stuff.

rv2gv		ref-to-glob cast	ck_rvconst	ds1	
rv2sv		scalar dereference	ck_rvconst	ds1	
av2arylen	array length		ck_null		is1	
rv2cv		subroutine dereference	ck_rvconst	d1
anoncode	anonymous subroutine	ck_anoncode	$	
prototype	subroutine prototype	ck_null		s%	S
refgen		reference constructor	ck_spair	m1	L
srefgen		single ref constructor	ck_null		fs1	S
ref		reference-type operator	ck_fun		stu%	S?
bless		bless			ck_fun		s@	S S?

# Pushy I/O.

backtick	quoted execution (``, qx)	ck_open		t%	
# glob defaults its first arg to $_
glob		glob			ck_glob		t@	S?
readline	<HANDLE>		ck_null		t%	F?
rcatline	append I/O operator	ck_null		t$

# Bindable operators.

regcmaybe	regexp internal guard	ck_fun		s1	S
regcreset	regexp internal reset	ck_fun		s1	S
regcomp		regexp compilation	ck_null		s|	S
match		pattern match (m//)	ck_match	d/
qr		pattern quote (qr//)	ck_match	s/
subst		substitution (s///)	ck_null		dis/	S
substcont	substitution iterator	ck_null		dis|	
trans		transliteration (tr///)	ck_null		is"	S

# Lvalue operators.
# sassign is special-cased for op class

sassign		scalar assignment	ck_sassign	s0
aassign		list assignment		ck_null		t2	L L

chop		chop			ck_spair	mts%	L
schop		scalar chop		ck_null		stu%	S?
chomp		chomp			ck_spair	mTs%	L
schomp		scalar chomp		ck_null		sTu%	S?
defined		defined operator	ck_defined	isu%	S?
undef		undef operator		ck_lfun		s%	S?
study		study			ck_fun		su%	S?
pos		match position		ck_lfun		stu%	S?

preinc		preincrement (++)		ck_lfun		dIs1	S
i_preinc	integer preincrement (++)	ck_lfun		dis1	S
predec		predecrement (--)		ck_lfun		dIs1	S
i_predec	integer predecrement (--)	ck_lfun		dis1	S
postinc		postincrement (++)		ck_lfun		dIst1	S
i_postinc	integer postincrement (++)	ck_lfun		disT1	S
postdec		postdecrement (--)		ck_lfun		dIst1	S
i_postdec	integer postdecrement (--)	ck_lfun		disT1	S

# Ordinary operators.

pow		exponentiation (**)	ck_null		fsT2	S S

multiply	multiplication (*)	ck_null		IfsT2	S S
i_multiply	integer multiplication (*)	ck_null		ifsT2	S S
divide		division (/)		ck_null		IfsT2	S S
i_divide	integer division (/)	ck_null		ifsT2	S S
modulo		modulus (%)		ck_null		IifsT2	S S
i_modulo	integer modulus (%)	ck_null		ifsT2	S S
repeat		repeat (x)		ck_repeat	mt2	L S

add		addition (+)		ck_null		IfsT2	S S
i_add		integer addition (+)	ck_null		ifsT2	S S
subtract	subtraction (-)		ck_null		IfsT2	S S
i_subtract	integer subtraction (-)	ck_null		ifsT2	S S
concat		concatenation (.) or string	ck_concat	fsT2	S S
stringify	string			ck_fun		fsT@	S

left_shift	left bitshift (<<)	ck_bitop	fsT2	S S
right_shift	right bitshift (>>)	ck_bitop	fsT2	S S

lt		numeric lt (<)		ck_null		Iifs2	S S
i_lt		integer lt (<)		ck_null		ifs2	S S
gt		numeric gt (>)		ck_null		Iifs2	S S
i_gt		integer gt (>)		ck_null		ifs2	S S
le		numeric le (<=)		ck_null		Iifs2	S S
i_le		integer le (<=)		ck_null		ifs2	S S
ge		numeric ge (>=)		ck_null		Iifs2	S S
i_ge		integer ge (>=)		ck_null		ifs2	S S
eq		numeric eq (==)		ck_null		Iifs2	S S
i_eq		integer eq (==)		ck_null		ifs2	S S
ne		numeric ne (!=)		ck_null		Iifs2	S S
i_ne		integer ne (!=)		ck_null		ifs2	S S
ncmp		numeric comparison (<=>)	ck_null		Iifst2	S S
i_ncmp		integer comparison (<=>)	ck_null		ifst2	S S

slt		string lt		ck_null		ifs2	S S
sgt		string gt		ck_null		ifs2	S S
sle		string le		ck_null		ifs2	S S
sge		string ge		ck_null		ifs2	S S
seq		string eq		ck_null		ifs2	S S
sne		string ne		ck_null		ifs2	S S
scmp		string comparison (cmp)	ck_null		ifst2	S S

bit_and		bitwise and (&)		ck_bitop	fst2	S S
bit_xor		bitwise xor (^)		ck_bitop	fst2	S S
bit_or		bitwise or (|)		ck_bitop	fst2	S S

negate		negation (-)		ck_null		Ifst1	S
i_negate	integer negation (-)	ck_null		ifsT1	S
not		not			ck_null		ifs1	S
complement	1's complement (~)	ck_bitop	fst1	S

# High falutin' math.

atan2		atan2			ck_fun		fsT@	S S
sin		sin			ck_fun		fsTu%	S?
cos		cos			ck_fun		fsTu%	S?
rand		rand			ck_fun		sT%	S?
srand		srand			ck_fun		s%	S?
exp		exp			ck_fun		fsTu%	S?
log		log			ck_fun		fsTu%	S?
sqrt		sqrt			ck_fun		fsTu%	S?

# Lowbrow math.

int		int			ck_fun		fsTu%	S?
hex		hex			ck_fun		fsTu%	S?
oct		oct			ck_fun		fsTu%	S?
abs		abs			ck_fun		fsTu%	S?

# String stuff.

length		length			ck_lengthconst	isTu%	S?
substr		substr			ck_substr	st@	S S S? S?
vec		vec			ck_fun		ist@	S S S

index		index			ck_index	isT@	S S S?
rindex		rindex			ck_index	isT@	S S S?

sprintf		sprintf			ck_fun		mfst@	S L
formline	formline		ck_fun		ms@	S L
ord		ord			ck_fun		ifsTu%	S?
chr		chr			ck_fun		fsTu%	S?
crypt		crypt			ck_fun		fsT@	S S
ucfirst		ucfirst			ck_fun		fstu%	S?
lcfirst		lcfirst			ck_fun		fstu%	S?
uc		uc			ck_fun		fstu%	S?
lc		lc			ck_fun		fstu%	S?
quotemeta	quotemeta		ck_fun		fstu%	S?

# Arrays.

rv2av		array dereference	ck_rvconst	dt1	
aelemfast	constant array element	ck_null		s$	A S
aelem		array element		ck_null		s2	A S
aslice		array slice		ck_null		m@	A L

# Hashes.

each		each			ck_fun		%	H
values		values			ck_fun		t%	H
keys		keys			ck_fun		t%	H
delete		delete			ck_delete	%	S
exists		exists			ck_exists	is%	S
rv2hv		hash dereference	ck_rvconst	dt1	
helem		hash element		ck_null		s2@	H S
hslice		hash slice		ck_null		m@	H L

# Explosives and implosives.

unpack		unpack			ck_fun		@	S S
pack		pack			ck_fun		mst@	S L
split		split			ck_split	t@	S S S
join		join or string		ck_join		mst@	S L

# List operators.

list		list			ck_null		m@	L
lslice		list slice		ck_null		2	H L L
anonlist	anonymous list ([])	ck_fun		ms@	L
anonhash	anonymous hash ({})	ck_fun		ms@	L

splice		splice			ck_fun		m@	A S? S? L
push		push			ck_fun		imsT@	A L
pop		pop			ck_shift	s%	A
shift		shift			ck_shift	s%	A
unshift		unshift			ck_fun		imsT@	A L
sort		sort			ck_sort		m@	C? L
reverse		reverse			ck_fun		mt@	L

grepstart	grep			ck_grep		dm@	C L
grepwhile	grep iterator		ck_null		dt|	

mapstart	map			ck_grep		dm@	C L
mapwhile	map iterator		ck_null		dt|

# Range stuff.

range		flipflop		ck_null		|	S S
flip		range (or flip)		ck_null		1	S S
flop		range (or flop)		ck_null		1

# Control.

and		logical and (&&)		ck_null		|	
or		logical or (||)			ck_null		|	
xor		logical xor			ck_null		fs2	S S	
cond_expr	conditional expression		ck_null		d|	
andassign	logical and assignment (&&=)	ck_null		s|	
orassign	logical or assignment (||=)	ck_null		s|	

method		method lookup		ck_method	d1
entersub	subroutine entry	ck_subr		dmt1	L
leavesub	subroutine exit		ck_null		1	
leavesublv	lvalue subroutine return	ck_null		1	
caller		caller			ck_fun		t%	S?
warn		warn			ck_fun		imst@	L
die		die			ck_die		dimst@	L
reset		symbol reset		ck_fun		is%	S?

lineseq		line sequence		ck_null		@	
nextstate	next statement		ck_null		s;	
dbstate		debug next statement	ck_null		s;	
unstack		iteration finalizer	ck_null		s0
enter		block entry		ck_null		0	
leave		block exit		ck_null		@	
scope		block			ck_null		@	
enteriter	foreach loop entry	ck_null		d{	
iter		foreach loop iterator	ck_null		0	
enterloop	loop entry		ck_null		d{	
leaveloop	loop exit		ck_null		2	
return		return			ck_return	dm@	L
last		last			ck_null		ds}	
next		next			ck_null		ds}	
redo		redo			ck_null		ds}	
dump		dump			ck_null		ds}	
goto		goto			ck_null		ds}	
exit		exit			ck_exit		ds%	S?
# continued below

#nswitch	numeric switch		ck_null		d	
#cswitch	character switch	ck_null		d	

# I/O.

open		open			ck_open		ismt@	F S? L
close		close			ck_fun		is%	F?
pipe_op		pipe			ck_fun		is@	F F

fileno		fileno			ck_fun		ist%	F
umask		umask			ck_fun		ist%	S?
binmode		binmode			ck_fun		s@	F S?

tie		tie			ck_fun		idms@	R S L
untie		untie			ck_fun		is%	R
tied		tied			ck_fun		s%	R
dbmopen		dbmopen			ck_fun		is@	H S S
dbmclose	dbmclose		ck_fun		is%	H

sselect		select system call	ck_select	t@	S S S S
select		select			ck_select	st@	F?

getc		getc			ck_eof		st%	F?
read		read			ck_fun		imst@	F R S S?
enterwrite	write			ck_fun		dis%	F?
leavewrite	write exit		ck_null		1	

prtf		printf			ck_listiob	ims@	F? L
print		print			ck_listiob	ims@	F? L

sysopen		sysopen			ck_fun		s@	F S S S?
sysseek		sysseek			ck_fun		s@	F S S
sysread		sysread			ck_fun		imst@	F R S S?
syswrite	syswrite		ck_fun		imst@	F S S? S?

send		send			ck_fun		imst@	Fs S S S?
recv		recv			ck_fun		imst@	Fs R S S

eof		eof			ck_eof		is%	F?
tell		tell			ck_fun		st%	F?
seek		seek			ck_fun		s@	F S S
# truncate really behaves as if it had both "S S" and "F S"
truncate	truncate		ck_trunc	is@	S S

fcntl		fcntl			ck_fun		st@	F S S
ioctl		ioctl			ck_fun		st@	F S S
flock		flock			ck_fun		isT@	F S

# Sockets.

socket		socket			ck_fun		is@	Fs S S S
sockpair	socketpair		ck_fun		is@	Fs Fs S S S

bind		bind			ck_fun		is@	Fs S
connect		connect			ck_fun		is@	Fs S
listen		listen			ck_fun		is@	Fs S
accept		accept			ck_fun		ist@	Fs Fs
shutdown	shutdown		ck_fun		ist@	Fs S

gsockopt	getsockopt		ck_fun		is@	Fs S S
ssockopt	setsockopt		ck_fun		is@	Fs S S S

getsockname	getsockname		ck_fun		is%	Fs
getpeername	getpeername		ck_fun		is%	Fs

# Stat calls.

lstat		lstat			ck_ftst		u-	F
stat		stat			ck_ftst		u-	F
ftrread		-R			ck_ftst		isu-	F-
ftrwrite	-W			ck_ftst		isu-	F-
ftrexec		-X			ck_ftst		isu-	F-
fteread		-r			ck_ftst		isu-	F-
ftewrite	-w			ck_ftst		isu-	F-
fteexec		-x			ck_ftst		isu-	F-
ftis		-e			ck_ftst		isu-	F-
fteowned	-O			ck_ftst		isu-	F-
ftrowned	-o			ck_ftst		isu-	F-
ftzero		-z			ck_ftst		isu-	F-
ftsize		-s			ck_ftst		istu-	F-
ftmtime		-M			ck_ftst		stu-	F-
ftatime		-A			ck_ftst		stu-	F-
ftctime		-C			ck_ftst		stu-	F-
ftsock		-S			ck_ftst		isu-	F-
ftchr		-c			ck_ftst		isu-	F-
ftblk		-b			ck_ftst		isu-	F-
ftfile		-f			ck_ftst		isu-	F-
ftdir		-d			ck_ftst		isu-	F-
ftpipe		-p			ck_ftst		isu-	F-
ftlink		-l			ck_ftst		isu-	F-
ftsuid		-u			ck_ftst		isu-	F-
ftsgid		-g			ck_ftst		isu-	F-
ftsvtx		-k			ck_ftst		isu-	F-
fttty		-t			ck_ftst		is-	F-
fttext		-T			ck_ftst		isu-	F-
ftbinary	-B			ck_ftst		isu-	F-

# File calls.

chdir		chdir			ck_fun		isT%	S?
chown		chown			ck_fun		imsT@	L
chroot		chroot			ck_fun		isTu%	S?
unlink		unlink			ck_fun		imsTu@	L
chmod		chmod			ck_fun		imsT@	L
utime		utime			ck_fun		imsT@	L
rename		rename			ck_fun		isT@	S S
link		link			ck_fun		isT@	S S
symlink		symlink			ck_fun		isT@	S S
readlink	readlink		ck_fun		stu%	S?
mkdir		mkdir			ck_fun		isT@	S S?
rmdir		rmdir			ck_fun		isTu%	S?

# Directory calls.

open_dir	opendir			ck_fun		is@	F S
readdir		readdir			ck_fun		%	F
telldir		telldir			ck_fun		st%	F
seekdir		seekdir			ck_fun		s@	F S
rewinddir	rewinddir		ck_fun		s%	F
closedir	closedir		ck_fun		is%	F

# Process control.

fork		fork			ck_null		ist0	
wait		wait			ck_null		isT0	
waitpid		waitpid			ck_fun		isT@	S S
system		system			ck_exec		imsT@	S? L
exec		exec			ck_exec		dimsT@	S? L
kill		kill			ck_fun		dimsT@	L
getppid		getppid			ck_null		isT0	
getpgrp		getpgrp			ck_fun		isT%	S?
setpgrp		setpgrp			ck_fun		isT@	S? S?
getpriority	getpriority		ck_fun		isT@	S S
setpriority	setpriority		ck_fun		isT@	S S S

# Time calls.

# NOTE: MacOS patches the 'i' of time() away later when the interpreter
# is created because in MacOS time() is already returning times > 2**31-1,
# that is, non-integers.

time		time			ck_null		isT0	
tms		times			ck_null		0	
localtime	localtime		ck_fun		t%	S?
gmtime		gmtime			ck_fun		t%	S?
alarm		alarm			ck_fun		istu%	S?
sleep		sleep			ck_fun		isT%	S?

# Shared memory.

shmget		shmget			ck_fun		imst@	S S S
shmctl		shmctl			ck_fun		imst@	S S S
shmread		shmread			ck_fun		imst@	S S S S
shmwrite	shmwrite		ck_fun		imst@	S S S S

# Message passing.

msgget		msgget			ck_fun		imst@	S S
msgctl		msgctl			ck_fun		imst@	S S S
msgsnd		msgsnd			ck_fun		imst@	S S S
msgrcv		msgrcv			ck_fun		imst@	S S S S S

# Semaphores.

semget		semget			ck_fun		imst@	S S S
semctl		semctl			ck_fun		imst@	S S S S
semop		semop			ck_fun		imst@	S S

# Eval.

require		require			ck_require	du%	S?
dofile		do "file"		ck_fun		d1	S
entereval	eval "string"		ck_eval		d%	S
leaveeval	eval "string" exit	ck_null		1	S
#evalonce	eval constant string	ck_null		d1	S
entertry	eval {block}		ck_null		|	
leavetry	eval {block} exit	ck_null		@	

# Get system info.

ghbyname	gethostbyname		ck_fun		%	S
ghbyaddr	gethostbyaddr		ck_fun		@	S S
ghostent	gethostent		ck_null		0	
gnbyname	getnetbyname		ck_fun		%	S
gnbyaddr	getnetbyaddr		ck_fun		@	S S
gnetent		getnetent		ck_null		0	
gpbyname	getprotobyname		ck_fun		%	S
gpbynumber	getprotobynumber	ck_fun		@	S
gprotoent	getprotoent		ck_null		0	
gsbyname	getservbyname		ck_fun		@	S S
gsbyport	getservbyport		ck_fun		@	S S
gservent	getservent		ck_null		0	
shostent	sethostent		ck_fun		is%	S
snetent		setnetent		ck_fun		is%	S
sprotoent	setprotoent		ck_fun		is%	S
sservent	setservent		ck_fun		is%	S
ehostent	endhostent		ck_null		is0	
enetent		endnetent		ck_null		is0	
eprotoent	endprotoent		ck_null		is0	
eservent	endservent		ck_null		is0	
gpwnam		getpwnam		ck_fun		%	S
gpwuid		getpwuid		ck_fun		%	S
gpwent		getpwent		ck_null		0	
spwent		setpwent		ck_null		is0	
epwent		endpwent		ck_null		is0	
ggrnam		getgrnam		ck_fun		%	S
ggrgid		getgrgid		ck_fun		%	S
ggrent		getgrent		ck_null		0	
sgrent		setgrent		ck_null		is0	
egrent		endgrent		ck_null		is0	
getlogin	getlogin		ck_null		st0	

# Miscellaneous.

syscall		syscall			ck_fun		imst@	S L

# For multi-threading
lock		lock			ck_rfun		s%	R
threadsv	per-thread value	ck_null		ds0

# Control (contd.)
setstate	set statement info	ck_null		s;
method_named	method with known name	ck_null		d$

dor		defined or (//)			ck_null		|
dorassign	defined or assignment (//=)	ck_null		s|

# Add new ops before this, the custom operator.

custom		unknown custom operator		ck_null		0
