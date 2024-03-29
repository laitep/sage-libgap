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

from cpython.object cimport PyObject, PyTypeObject

cdef extern from *:
    ctypedef object (*wrapperfunc)(self, args, void* wrapped)
    ctypedef object (*wrapperfunc_kwds)(self, args, void* wrapped, kwds)

    struct wrapperbase:
        char* name
        int offset
        void* function
        wrapperfunc wrapper
        char* doc
        int flags
        PyObject* name_strobj

    int PyWrapperFlag_KEYWORDS

    ctypedef class sage_libgap.cpython.builtin_types.wrapper_descriptor [object PyWrapperDescrObject]:
        cdef type d_type
        cdef d_name
        cdef wrapperbase* d_base
        cdef void* d_wrapped

    PyDescr_NewWrapper(PyTypeObject* cls, wrapperbase* wrapper, void* wrapped)


cdef wrapperdescr_fastcall(wrapper_descriptor slotwrapper, self, args, kwds) noexcept


cdef inline wrapperbase* get_slotdef(wrapper_descriptor slotwrapper) except NULL:
    """
    Given a slot wrapper, return the corresponding ``slotdef``.

    A ``slotdef`` is associated to a specific slot like ``__eq__``
    and does not depend at all on the type. In other words, calling
    ``get_slotdef(t.__eq__)`` will return the same ``slotdef``
    independent of the type ``t`` (provided that the type implements
    rich comparison in C).

    TESTS::

        sage: # needs sage_libgap.misc.cython
        sage: cython(
        ....: '''
        ....: from sage_libgap.cpython.wrapperdescr cimport get_slotdef
        ....: from cpython.long cimport PyLong_FromVoidPtr
        ....: def py_get_slotdef(slotwrapper):
        ....:     return PyLong_FromVoidPtr(get_slotdef(slotwrapper))
        ....: ''')
        sage: py_get_slotdef(object.__init__)  # random
        140016903442416
        sage: py_get_slotdef(bytes.__lt__)  # random
        140016903441800
        sage: py_get_slotdef(bytes.__lt__) == py_get_slotdef(Integer.__lt__)
        True
        sage: py_get_slotdef(bytes.__lt__) == py_get_slotdef(bytes.__gt__)
        False
        sage: class X():
        ....:     def __eq__(self, other):
        ....:         return False
        sage: py_get_slotdef(X.__eq__)
        Traceback (most recent call last):
        ...
        TypeError: Cannot convert ... to wrapper_descriptor
    """
    return slotwrapper.d_base
