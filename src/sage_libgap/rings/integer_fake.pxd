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

"""
Fake Integer interface

This exists to solve the problem of cyclic imports involving the
``Integer`` class. The problem is that ``Integer`` depends on the
coercion model and the coercion model depends on ``Integer``.

Therefore, this should only be used to implement things at a lower
level than ``Integer``, such as the coercion model.

This provides two functions:

- ``Integer_AS_MPZ(x)``: access the value of the Integer ``x`` as GMP
  ``mpz_t``.

- ``is_Integer(x)``: is ``x`` an Integer?

TESTS::

    sage: cython(                                                                       # needs sage_libgap.misc.cython
    ....: '''
    ....: from sage_libgap.rings.integer_fake cimport Integer_AS_MPZ, is_Integer
    ....: from sage_libgap.rings.integer cimport Integer
    ....: cdef Integer x = Integer(123456789)
    ....: assert is_Integer(x)
    ....: assert Integer_AS_MPZ(x) is x.value
    ....: ''')
"""

#*****************************************************************************
#       Copyright (C) 2017 Jeroen Demeyer <J.Demeyer@UGent.be>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

from cpython.ref cimport PyTypeObject, Py_TYPE
from sage_libgap.libs.gmp.types cimport mpz_ptr

cdef extern from "integer_fake.h":
    PyTypeObject* Integer       # Imported as needed
    mpz_ptr Integer_AS_MPZ(x)
    bint unlikely(bint c)       # Defined by Cython


cdef inline bint is_Integer(x) noexcept:
    global Integer
    if unlikely(Integer is NULL):
        import sage_libgap.rings.integer
        Integer = <PyTypeObject*>sage_libgap.rings.integer.Integer
    return Py_TYPE(x) is Integer