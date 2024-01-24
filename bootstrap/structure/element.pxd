#     Copyright (C) 2006-2024 The SageMath Developers
#     Copyright (C) 2024 LaiTeP and contributors
#
#     This file is part of the sage_libgap distribution.
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

# Modified version of sage.structure.element for sage_libgap


from sage.structure.sage_object cimport SageObject


cpdef inline parent(x) noexcept:
    """
    Return the parent of the element ``x``.

    Usually, this means the mathematical object of which ``x`` is an
    element.

    INPUT:

    - ``x`` -- an element

    OUTPUT:

    - If ``x`` is a Sage :class:`Element`, return ``x.parent()``.

    - Otherwise, return ``type(x)``.

    .. SEEALSO::

        `Parents, Conversion and Coercion <http://doc.sagemath.org/html/en/tutorial/tour_coercion.html>`_
        Section in the Sage Tutorial

    EXAMPLES::

        sage: a = 42
        sage: parent(a)
        Integer Ring
        sage: b = 42/1
        sage: parent(b)
        Rational Field
        sage: c = 42.0
        sage: parent(c)                                                                 # needs sage.rings.real_mpfr
        Real Field with 53 bits of precision

    Some more complicated examples::

        sage: x = Partition([3,2,1,1,1])                                                # needs sage.combinat
        sage: parent(x)                                                                 # needs sage.combinat
        Partitions
        sage: v = vector(RDF, [1,2,3])                                                  # needs sage.modules
        sage: parent(v)                                                                 # needs sage.modules
        Vector space of dimension 3 over Real Double Field

    The following are not considered to be elements, so the type is
    returned::

        sage: d = int(42)  # Python int
        sage: parent(d)
        <... 'int'>
        sage: L = list(range(10))
        sage: parent(L)
        <... 'list'>
    """
    if isinstance(x, Element):
        return (<Element>x)._parent
    return type(x)


cdef inline int classify_elements(left, right) noexcept:
    """
    Given two objects, at least one which is an :class:`Element`,
    classify their type and parent. This is a finer version of
    :func:`have_same_parent`.

    OUTPUT: the sum of the following bits:

    - 0o01: left is an Element
    - 0o02: right is an Element
    - 0o04: both are Element
    - 0o10: left and right have the same type
    - 0o20: left and right have the same parent

    These are the possible outcomes:

    - 0o01: left is an Element, right is not
    - 0o02: right is an Element, left is not
    - 0o07: both are Element, different types, different parents
    - 0o17: both are Element, same type, different parents
    - 0o27: both are Element, different types, same parent
    - 0o37: both are Element, same type, same parent
    """
    if type(left) is type(right):
        # We know at least one of the arguments is an Element. So if
        # their types are *equal* (fast to check) then they are both
        # Elements.
        if (<Element>left)._parent is (<Element>right)._parent:
            return 0o37
        else:
            return 0o17
    if not isinstance(right, Element):
        return 0o01
    if not isinstance(left, Element):
        return 0o02
    if (<Element>left)._parent is (<Element>right)._parent:
        return 0o27
    else:
        return 0o07

# Functions to help understand the result of classify_elements()
cdef inline bint BOTH_ARE_ELEMENT(int cl) noexcept:
    return cl & 0o04
cdef inline bint HAVE_SAME_PARENT(int cl) noexcept:
    return cl & 0o20


cpdef inline bint have_same_parent(left, right) noexcept:
    """
    Return ``True`` if and only if ``left`` and ``right`` have the
    same parent.

    .. WARNING::

        This function assumes that at least one of the arguments is a
        Sage :class:`Element`. When in doubt, use the slower
        ``parent(left) is parent(right)`` instead.

    EXAMPLES::

        sage: from sage.structure.element import have_same_parent
        sage: have_same_parent(1, 3)
        True
        sage: have_same_parent(1, 1/2)
        False
        sage: have_same_parent(gap(1), gap(1/2))                                        # needs sage.libs.gap
        True

    These have different types but the same parent::

        sage: a = RLF(2)
        sage: b = exp(a)
        sage: type(a)
        <... 'sage.rings.real_lazy.LazyWrapper'>
        sage: type(b)
        <... 'sage.rings.real_lazy.LazyNamedUnop'>
        sage: have_same_parent(a, b)
        True
    """
    return HAVE_SAME_PARENT(classify_elements(left, right))


cdef unary_op_exception(op, x) noexcept
cdef bin_op_exception(op, x, y) noexcept


cdef class Element(SageObject):
    cdef object _parent
    cpdef _richcmp_(left, right, int op) noexcept

    cpdef _act_on_(self, x, bint self_on_left) noexcept
    cpdef _acted_upon_(self, x, bint self_on_left) noexcept

    cdef _add_(self, other) noexcept
    cdef _sub_(self, other) noexcept
    cdef _neg_(self) noexcept
    cdef _add_long(self, long n) noexcept

    cdef _mul_(self, other) noexcept
    cdef _mul_long(self, long n) noexcept
    cdef _matmul_(self, other) noexcept
    cdef _div_(self, other) noexcept
    cdef _floordiv_(self, other) noexcept
    cdef _mod_(self, other) noexcept

    cdef _pow_(self, other) noexcept
    cdef _pow_int(self, n) noexcept
    cdef _pow_long(self, long n) noexcept
