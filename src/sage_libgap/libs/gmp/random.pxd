###############################################################################
# This file was automatically generated by extract_sage_libgap.py. DO NOT EDIT!
###############################################################################
#
#     Copyright (C) 2024 LaiTeP and contributors
#
#     This file is part of the sage_libgap distribution.
#     It is an automatically modified version of a file in the "Sage: a free
#     open-source mathematics software system" software package. Further
#     licensing information may be available further down this file.
#
#     The sage_libgap package is free software; you can redistribute it and/or
#     modify it under the terms of the GNU General Public License as published
#     by the Free Software Foundation, either version 3 of the License, or (at
#     your option) any later version.
#
#     The sage_libgap package is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
#     Public License for more details.
#
#     You should have received a copy of the GNU General Public License along
#     with sage_libgap package. If not, see <https://www.gnu.org/licenses/>.
#
###############################################################################

# distutils: libraries = gmp

from sage_libgap.libs.gmp.types cimport *

cdef extern from "gmp.h":

    ### Random Number Functions ###

    # Random State Initialization
    void gmp_randinit_default (gmp_randstate_t state)
    int gmp_randinit_mt (gmp_randstate_t state)
    void gmp_randinit_lc_2exp (gmp_randstate_t state, mpz_t a, unsigned long c, unsigned long m2exp)
    int gmp_randinit_lc_2exp_size (gmp_randstate_t state, unsigned long size)
    int gmp_randinit_set (gmp_randstate_t rop, gmp_randstate_t op)
    # void gmp_randinit (gmp_randstate_t state, gmp_randalg_t alg, ...)
    void gmp_randclear (gmp_randstate_t state)

    # Random State Seeding
    void gmp_randseed (gmp_randstate_t state, mpz_t seed)
    void gmp_randseed_ui (gmp_randstate_t state, unsigned long int seed)

    # Random State Miscellaneous
    unsigned long gmp_urandomb_ui (gmp_randstate_t state, unsigned long n)
    unsigned long gmp_urandomm_ui (gmp_randstate_t state, unsigned long n)
