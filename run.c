/*    run.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2004, 2005, 2006, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/* This file contains the main Perl opcode execution loop. It just
 * calls the pp_foo() function associated with each op, and expects that
 * function to return a pointer to the next op to be executed, or null if
 * it's the end of the sub or program or whatever.
 *
 * There is a similar loop in dump.c, Perl_runops_debug(), which does
 * the same, but also checks for various debug flags each time round the
 * loop.
 *
 * Why this function requires a file all of its own is anybody's guess.
 * DAPM.
 */

#include "EXTERN.h"
#define PERL_IN_RUN_C
#include "perl.h"

/*
 * 'Away now, Shadowfax!  Run, greatheart, run as you have never run before!
 *  Now we are come to the lands where you were foaled, and every stone you
 *  know.  Run now!  Hope is in speed!'                    --Gandalf
 *
 *     [p.600 of _The Lord of the Rings_, III/xi: "The Palantír"]
 */

int
Perl_runops_standard(pTHX)
{
    dVAR;
    OP *op = PL_op;
    OP_ENTRY_PROBE(OP_NAME(op));
    while ((PL_op = op = op->op_ppaddr(aTHX))) {
        OP_ENTRY_PROBE(OP_NAME(op));
    }
    PERL_ASYNC_CHECK();

    TAINT_NOT;
    return 0;
}

#if 0
#ifdef PERL_ALT_STACKS
int
Perl_call_runops(pTHX)
{
    __try {
        return PL_runops(aTHX);
    }
    __except(GetExceptionCode() == STATUS_GUARD_PAGE_VIOLATION
             ? Perl_fix_win32stacks(GetExceptionInformation())
             : EXCEPTION_CONTINUE_SEARCH) {
        NOOP;
    }
    croak_no_mem();
}
#endif
#endif

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 et:
 */
