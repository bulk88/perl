/*    util.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1999, 2001, 2002, 2003, 2004, 2005,
 *    2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#ifdef VMS
#  define PERL_FILE_IS_ABSOLUTE(f) \
	(*(f) == '/'							\
	 || (strchr(f,':')						\
	     || ((*(f) == '[' || *(f) == '<')				\
		 && (isWORDCHAR((f)[1]) || strchr("$-_]>",(f)[1])))))

#else		/* !VMS */
#  if defined(WIN32) || defined(__CYGWIN__)
#    define PERL_FILE_IS_ABSOLUTE(f) \
	(*(f) == '/' || *(f) == '\\'		/* UNC/rooted path */	\
	 || ((f)[0] && (f)[1] == ':'))		/* drive name */
#  else		/* !WIN32 */
#  ifdef NETWARE
#    define PERL_FILE_IS_ABSOLUTE(f) \
	(((f)[0] && (f)[1] == ':')		/* drive name */	\
	 || ((f)[0] == '\\' && (f)[1] == '\\')	/* UNC path */	\
	 ||	((f)[3] == ':'))				/* volume name, currently only sys */
#  else		/* !NETWARE */
#    if defined(DOSISH) || defined(__SYMBIAN32__)
#      define PERL_FILE_IS_ABSOLUTE(f) \
	(*(f) == '/'							\
	 || ((f)[0] && (f)[1] == ':'))		/* drive name */
#    else	/* NEITHER DOSISH NOR SYMBIANISH */
#      define PERL_FILE_IS_ABSOLUTE(f)	(*(f) == '/')
#    endif	/* DOSISH */
#   endif	/* NETWARE */
#  endif	/* WIN32 */
#endif		/* VMS */

/*
=head1 Miscellaneous Functions

=for apidoc ibcmp

This is a synonym for (! foldEQ())

=for apidoc ibcmp_locale

This is a synonym for (! foldEQ_locale())

=cut
*/
#define ibcmp(s1, s2, len)         cBOOL(! foldEQ(s1, s2, len))
#define ibcmp_locale(s1, s2, len)  cBOOL(! foldEQ_locale(s1, s2, len))

/* outside the core, perl.h undefs HAS_QUAD if IV isn't 64-bit
   We can't swap this to HAS_QUAD, because the logic here affects the type of
   perl_drand48_t below, and that is visible outside of the core.  */
#if defined(U64TYPE) && !defined(USING_MSVC6)
/* use a faster implementation when quads are available,
 * but not with VC6 on Windows */
#    define PERL_DRAND48_QUAD
#endif

#ifdef PERL_DRAND48_QUAD

/* U64 is only defined under PERL_CORE, but this needs to be visible
 * elsewhere so the definition of PerlInterpreter is complete.
 */
typedef U64TYPE perl_drand48_t;

#else

struct PERL_DRAND48_T {
    U16 seed[3];
};

typedef struct PERL_DRAND48_T perl_drand48_t;

#endif

#define PL_RANDOM_STATE_TYPE perl_drand48_t

#define Perl_drand48_init(seed) (Perl_drand48_init_r(&PL_random_state, (seed)))
#define Perl_drand48() (Perl_drand48_r(&PL_random_state))

#ifdef USE_C_BACKTRACE

typedef struct {
    /* The number of frames returned. */
    UV frame_count;
    /* The total size of the Perl_c_backtrace, including this header,
     * the frames, and the name strings. */
    UV total_bytes;
} Perl_c_backtrace_header;

typedef struct {
    void*  addr;  /* the program counter at this frame */

    /* We could use Dl_info (as used by dladdr()) for many of these but
     * that would be naughty towards non-dlfcn systems (hi there, Win32). */

    void*  symbol_addr; /* symbol address (hint: try symbol_addr - addr) */
    void*  object_base_addr;   /* base address of the shared object */

    /* The offsets are from the beginning of the whole backtrace,
     * which makes the backtrace relocatable. */
    STRLEN object_name_offset; /* pathname of the shared object */
    STRLEN object_name_size;   /* length of the pathname */
    STRLEN symbol_name_offset; /* symbol name */
    STRLEN symbol_name_size;   /* length of the symbol name */
    STRLEN source_name_offset; /* source code file name */
    STRLEN source_name_size;   /* length of the source code file name */
    STRLEN source_line_number; /* source code line number */

    /* OS X notes: atos(1) (more recently, "xcrun atos"), but the C
     * API atos() uses is unknown (private "Symbolicator" framework,
     * might require Objective-C even if the API would be known).
     * Currently we open read pipe to "xcrun atos" and parse the
     * output - quite disgusting.  And that won't work if the
     * Developer Tools isn't installed. */

    /* FreeBSD notes: execinfo.h exists, but probably would need also
     * the library -lexecinfo.  BFD exists if the pkg devel/binutils
     * has been installed, but there seems to be a known problem that
     * the "bfd.h" getting installed refers to "ansidecl.h", which
     * doesn't get installed. */

    /* Win32 notes: as moral equivalents of backtrace() + dladdr(),
     * one could possibly first use GetCurrentProcess() +
     * SymInitialize(), and then CaptureStackBackTrace() +
     * SymFromAddr(). */

    /* Note that using the compiler optimizer easily leads into much
     * of this information, like the symbol names (think inlining),
     * and source code locations getting lost or confused.  In many
     * cases keeping the debug information (-g) is necessary.
     *
     * Note that for example with gcc you can do both -O and -g.
     *
     * Note, however, that on some platforms (e.g. OSX + clang (cc))
     * backtrace() + dladdr() works fine without -g. */

    /* For example: the mere presence of <bfd.h> is no guarantee: e.g.
     * OS X has that, but BFD does not seem to work on the OSX executables.
     *
     * Another niceness would be to able to see something about
     * the function arguments, however gdb/lldb manage to do that. */
} Perl_c_backtrace_frame;

typedef struct {
    Perl_c_backtrace_header header;
    Perl_c_backtrace_frame  frame_info[1];
    /* After the header come:
     * (1) header.frame_count frames
     * (2) frame_count times the \0-terminated strings (object_name
     * and so forth).  The frames contain the pointers to the starts
     * of these strings, and the lengths of these strings. */
} Perl_c_backtrace;

#define Perl_free_c_backtrace(bt) Safefree(bt)

#endif /* USE_C_BACKTRACE */

/* Use a packed 32 bit constant "key" to start the handshake. The key defines
   ABI compatibility, and how to process the vararg list.

   Note, some bits may be taken from INTRPSIZE (but then a simple x86 AX register
   can't be used to read it) and 4 bits from API version len can also be taken,
   since v00.00.00 is 9 bytes long. XS version length should not have any bits
   taken since XS_VERSION lengths can get quite long since they are user
   selectable. These spare bits allow for additional features for the varargs
   stuff or ABI compat test flags in the future.
*/
#define HSm_APIVERLEN 0x0000001F /* perl version string won't be more than 31 chars */
#define HS_APIVERLEN_MAX HSm_APIVERLEN
#define HSm_XSVERLEN 0x0000FF00 /* if 0, not present, dont check, die if over 255*/
#define HS_XSVERLEN_MAX 0xFF
/* uses var file to set default filename for newXS_deffile to use for CvFILE */
#define HSf_SETXSUBFN 0x00000020
#define HSf_POPMARK 0x00000040 /* popmark mode or you must supply ax and items */
#define HSf_IMP_CXT 0x00000080 /* ABI, threaded/PERL_IMPLICIT_CONTEXT, pTHX_ present */
#define HSm_INTRPSIZE 0xFFFF0000 /* ABI, interp struct size */
/* A mask of bits in the key which must always match between a XS mod and interp.
   Also if all ABI bits in a key are true, skip all ABI checks, it is very
   the unlikely interp size will all 1 bits */
/* Maybe HSm_APIVERLEN one day if Perl_xs_apiversion_bootcheck is changed to a memcmp */
#define HSm_KEY_MATCH (HSm_INTRPSIZE|HSf_IMP_CXT)
#define HSf_NOCHK HSm_KEY_MATCH  /* if all ABI bits are 1 in the key, dont chk */


#define HS_GETINTERPSIZE(key) ((key) >> 16)
/* if in the future "" and NULL must be separated, XSVERLEN would be 0
means arg not present, 1 is empty string/null byte */
/* (((key) & 0x0000FF00) >> 8) is less efficient on Visual C */
#define HS_GETXSVERLEN(key) ((key) >> 8 & 0xFF)
#define HS_GETAPIVERLEN(key) ((key) & HSm_APIVERLEN)

/* internal to util.h macro to create a packed handshake key, all args must be constants */
/* U32 return = (U16 interpsize, bool cxt, bool setxsubfn, bool popmark,
   U5 (FIVE!) apiverlen, U8 xsverlen) */
#define HS_KEYp(interpsize, cxt, setxsubfn, popmark, apiverlen, xsverlen) \
    (((interpsize)  << 16) \
    | ((xsverlen) > HS_XSVERLEN_MAX \
        ? (Perl_croak_nocontext("panic: handshake overflow"), HS_XSVERLEN_MAX) \
        : (xsverlen) << 8) \
    | (cBOOL(setxsubfn) ? HSf_SETXSUBFN : 0) \
    | (cBOOL(cxt) ? HSf_IMP_CXT : 0) \
    | (cBOOL(popmark) ? HSf_POPMARK : 0) \
    | ((apiverlen) > HS_APIVERLEN_MAX \
        ? (Perl_croak_nocontext("panic: handshake overflow"), HS_APIVERLEN_MAX) \
        : (apiverlen)))
/* overflows above will optimize away unless they will execute */

/* public macro for core usage to create a packed handshake key but this is
   not public API. This more friendly version already collected all ABI info */
/* U32 return = (bool setxsubfn, bool popmark, "litteral_string_api_ver",
   "litteral_string_xs_ver") */
#ifdef PERL_IMPLICIT_CONTEXT
#  define HS_KEY(setxsubfn, popmark, apiver, xsver) \
    HS_KEYp(sizeof(PerlInterpreter), TRUE, setxsubfn, popmark, \
    sizeof("" apiver "")-1, sizeof("" xsver "")-1)
#  define HS_CXT aTHX
#else
#  define HS_KEY(setxsubfn, popmark, apiver, xsver) \
    HS_KEYp(sizeof(struct PerlHandShakeInterpreter), FALSE, setxsubfn, popmark, \
    sizeof("" apiver "")-1, sizeof("" xsver "")-1)
#  define HS_CXT cv
#endif


/* design notes
  -on some CPUs, you must explictly synchronize and flush the caches of all CPUs
   in the system, then lock the mem bus for all reads and/or all writes
   (AKA memory barrier)
  -on some CPUs, anything larger than a U8/char might be synthesized at multiple
   memory reads, so even simple C gets and sets with "=" operator
   could see giberish intermediate values
  -locks come in kernel (void * or 1 machine word sized) and user mode variants
   which are called futexes or Win32's CRITICAL_SECTION, a CRITICAL_SECTION is
   a large >0x20 byte sized struct, not 1 machine word
  -in some CPUs, atomic ops are 1 undivisible asm op (x86), in other RISC CPUs
   the are implemented by 1. locking the mem bus 2. load 3. manipulate 4. store
   5. unlock mem bus, or by 1. mark a memblock faux-RO using a asm op, 2. load
   3. manipulate 4. conditional store if not dirty, else goto 1
  -some CPUs have no atomic operations. PA-RISC has a traditionally useless
   "exchange with null" atomic op, and ARM <= V5 has nothing atomic. On these 2
   platforms, Linux kernel assists in sythesizing usermode atomic ops.
   For ARM <= 5, Linux maintains a CAS function in shared to all processes but
   RO memory at function pointer 0xffff0fc0. The CAS function executes in user
   mode. If an interupt happens in the middle of the magical CAS function, the
   kernel interrupt handler sees the last executed user mode instruction pointer
   is in inside the magical CAS function at 0xffff0fc0, it special cases things
   to make things look atomic to user mode. This isnt SMP safe, but <= ARM V5
   was never mfged as SMP.

   For PA-RISC, Linux uses the PA-RISC "gateway page", which when the CPU jumps
   to code inside the gateway page, the code inside the gateway page executes
   with kernel privilages. Linux does not swap address space to kernel space
   from user mode, but does have to disable interrupts, plus aquire a kernel mode
   spinlock mutex (selected by hashing the atomic user mode address) on the
   memory block to stop other CPUs
   https://github.com/torvalds/linux/blob/master/arch/parisc/kernel/syscall.S
   -whether the OS or the CPU supports atomic ops in user mode, doesn't mean the
   CC supports atomic ops
   -the only thing remotely approaching a standard for atomics is GCC's
   non-standardized __sync_* family, and C++11's __atomic_* family
   -atomics can be intrinsics/builtins, or normal C functions calls to
    a "libc" or syscalls to the kernel, or inline declared C functions containing
    inline asm in the C headers
   -the CC might not support __sync_* and not support __atomic_* but supports
    OS specific atomic ops
   -some CC or OS might be using http://en.wikipedia.org/wiki/Dekker%27s_algorithm
    internally
   -regarding the front end macros, the retval is always an arg, never the
   "return" of the macro, this allows the macro to internally be a do {;} while (0)
   and to declare vars, without proprietary GCC only PERL_USE_GCC_BRACE_GROUPS
*/

#ifdef USE_ITHREADS
#  ifdef USE_ATOMIC
/* make sure there is no accidental usage without the correct macros */
typedef struct {
    U32 val;
} ATOMICU32BOX;
#    define dATOMIC_U32CNT(a)            ATOMICU32BOX a
/* use as a replacement for PERLVAR this is a declaration of a mutex, or empty */
#    define dATOMIC_U32CNT_LOCK          /* empty since it might wind up in a struct and not optimized away */
/* initialize a struct or alloc memory if needed*/
#    define ATOMIC_U32CNT_INIT(a)        ATOMIC_U32CNT_SET(a, 0)
/* initialize a struct or alloc memory if needed*/
#    define ATOMIC_U32CNT_INIT_LOCK      NOOP
/* returns new value in arg b*/
#    define ATOMIC_U32CNT_INC(a, b)      (void)((b) = S_atomic_fetch_addU32(&(a), 1))
/* returns new value in arg b*/
#    define ATOMIC_U32CNT_DEC(a, b)      (void)((b) = S_atomic_fetch_subU32(&(a), 1))
/* returns existing value in arg b*/
#    define ATOMIC_U32CNT_GET(a, b)      (void)((b) = S_atomic_loadU32(&(a)))
/* returns nothing */
#    define ATOMIC_U32CNT_SET(a, b)      S_atomic_storeU32(&(a), (b))
#    define ATOMIC_U32CNT_TERM(a)        NOOP
#    define ATOMIC_U32CNT_TERM_LOCK      NOOP

#  else
/* make sure there is no accidental usage without the correct macros */
typedef struct {
    U32 val;
} ATOMICU32BOX;
#    define dATOMIC_U32CNT(a)            ATOMICU32BOX a
#    define dATOMIC_U32CNT_LOCK          PERLVAR(G, no_atomics_lock, perl_mutex)
#    define ATOMIC_U32CNT_INIT(a)        NOOP
#    define ATOMIC_U32CNT_INIT_LOCK      MUTEX_INIT(&PL_no_atomics_lock)
/* returns new value in arg b*/
#    define ATOMIC_U32CNT_INC(a, b)      (void)((b) = S_u32cnt_fb_inc(&(a)))
/* returns new value in arg b*/
#    define ATOMIC_U32CNT_DEC(a, b)      (void)((b) = S_u32cnt_fb_dec(&(a)))

/*  ATOMIC_ALWAYS_LOCK unconditional reads and writes require locking.
    For example, the CPU is incapable of native U32 loads and stores, and a U32
    read is synthesized by the CC with 4 independent, interruptable, U8 reads,
    or more realistically, 2 U16 reads */
#    ifdef ATOMIC_ALWAYS_LOCK_U32
/* returns existing value */
#      define ATOMIC_U32CNT_GET(a, b)    (void)((b) = S_u32cnt_fb_get(&(a)))
/* returns nothing */
#      define ATOMIC_U32CNT_SET(a, newval) S_u32cnt_fb_set(&(a), newval)
#    else
/* returns existing value in arg b*/
#      define ATOMIC_U32CNT_GET(a, b)       ATOMIC_U32CNT_UNSAFE_GET(a, b)
/* returns nothing */
#      define ATOMIC_U32CNT_SET(a, b)       ATOMIC_U32CNT_UNSAFE_SET(a, b)
/* returns existing value */
#    endif
#    define ATOMIC_U32CNT_UNSAFE_GET(a, b)  (void)((b) = (a).val)
/* returns nothing */
#    define ATOMIC_U32CNT_UNSAFE_SET(a, b)  (void)((a).val = (b))
#    define ATOMIC_U32CNT_TERM(a)           NOOP
#    define ATOMIC_U32CNT_TERM_LOCK         MUTEX_DESTROY(&PL_no_atomics_lock)
#  endif /* ifdef USE_ATOMIC */
#else /* #ifdef USE_ITHREADS */
/* no thread safety/no OS threads version, without thread.h, assume this
    platform has no threads at all, only processes, and processes can't
    communicate through shared memory (one definition of threads are "processes
    that share the same memory space") */
/* make sure there is no accidental usage without the correct macros */
typedef struct {
    U32 val;
} ATOMICU32BOX;
#  define dATOMIC_U32CNT(a)            ATOMICU32BOX a
#  define dATOMIC_U32CNT_LOCK
#  define ATOMIC_U32CNT_INIT(a)        NOOP
#  define ATOMIC_U32CNT_INIT_LOCK      NOOP
/* returns new value */
#  define ATOMIC_U32CNT_INC(a, b)         (void)((b) = ++(a).val)
/* returns new value */
#  define ATOMIC_U32CNT_DEC(a, b)         (void)((b) = --(a).val)
/* returns existing value  in arg b*/
#  define ATOMIC_U32CNT_GET(a, b)         ATOMIC_U32CNT_UNSAFE_GET(a, b)
/* returns nothing */
#  define ATOMIC_U32CNT_SET(a, b)         ATOMIC_U32CNT_UNSAFE_SET(a, b)
#  define ATOMIC_U32CNT_UNSAFE_GET(a, b)  (void)((b) = (a).val)
/* returns nothing */
#  define ATOMIC_U32CNT_UNSAFE_SET(a, b)  (void)((a).val = (b))
#  define ATOMIC_U32CNT_TERM(a)        NOOP
#  define ATOMIC_U32CNT_TERM_LOCK      NOOP
#endif

/*
 * ex: set ts=8 sts=4 sw=4 et:
 */
