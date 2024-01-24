# Compile this with -Os because it works around a bug with
# GCC-4.7.3 + Cython 0.19 on Itanium, see Issue #14452. Moreover, it
# actually results in faster code than -O3.
#
# distutils: extra_compile_args = -Os

r"""
Elements

AUTHORS:

- David Harvey (2006-10-16): changed CommutativeAlgebraElement to
  derive from CommutativeRingElement instead of AlgebraElement

- David Harvey (2006-10-29): implementation and documentation of new
  arithmetic architecture

- William Stein (2006-11): arithmetic architecture -- pushing it
  through to completion.

- Gonzalo Tornaria (2007-06): recursive base extend for coercion --
  lots of tests

- Robert Bradshaw (2007-2010): arithmetic operators and coercion

- Maarten Derickx (2010-07): added architecture for is_square and sqrt

- Jeroen Demeyer (2016-08): moved all coercion to the base class
  :class:`Element`, see :trac:`20767`

The Abstract Element Class Hierarchy
====================================

This is the abstract class hierarchy, i.e., these are all
abstract base classes.

::

    SageObject
        Element
            ModuleElement
                RingElement
                    CommutativeRingElement
                        IntegralDomainElement
                            DedekindDomainElement
                                PrincipalIdealDomainElement
                                    EuclideanDomainElement
                        FieldElement
                        CommutativeAlgebraElement
                        Expression
                    AlgebraElement
                        Matrix
                    InfinityElement
                AdditiveGroupElement
                Vector

            MonoidElement
                MultiplicativeGroupElement
        ElementWithCachedMethod


How to Define a New Element Class
=================================

Elements typically define a method ``_new_c``, e.g.,

.. code-block:: cython

    cdef _new_c(self, defining data):
        cdef FreeModuleElement_generic_dense x
        x = FreeModuleElement_generic_dense.__new__(FreeModuleElement_generic_dense)
        x._parent = self._parent
        x._entries = v

that creates a new sibling very quickly from defining data
with assumed properties.

.. _element_arithmetic:

Arithmetic for Elements
-----------------------

Sage has a special system for handling arithmetic operations on Sage
elements (that is instances of :class:`Element`), in particular to
manage uniformly mixed arithmetic operations using the :mod:`coercion
model <sage_libgap.structure.coerce>`. We describe here the rules that must
be followed by both arithmetic implementers and callers.

A quick summary for the impatient
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To implement addition for any :class:`Element` subclass, override the
``def _add_(self, other)`` method instead of the usual Python
``__add__`` :python:`special method <reference/datamodel.html#special-method-names>`.
Within ``_add_(self, other)``, you may assume that ``self`` and
``other`` have the same parent.

If the implementation is generic across all elements in a given
category `C`, then this method can be put in ``C.ElementMethods``.

When writing *Cython* code, ``_add_`` should be a cpdef method:
``cpdef _add_(self, other)``.

When doing arithmetic with two elements having different parents,
the :mod:`coercion model <sage_libgap.structure.coerce>` is responsible for
"coercing" them to a common parent and performing arithmetic on the
coerced elements.

Arithmetic in more detail
^^^^^^^^^^^^^^^^^^^^^^^^^

The aims of this system are to provide (1) an efficient calling protocol
from both Python and Cython, (2) uniform coercion semantics across Sage,
(3) ease of use, (4) readability of code.

We will take addition as an example; all other operators are similar.
There are two relevant functions, with differing names
(single vs. double underscores).

-  **def Element.__add__(left, right)**

   This function is called by Python or Cython when the binary "+"
   operator is encountered. It assumes that at least one of its
   arguments is an :class:`Element`.

   It has a fast pathway to deal with the most common case where both
   arguments have the same parent. Otherwise, it uses the coercion
   model to work out how to make them have the same parent. The
   coercion model then adds the coerced elements (technically, it calls
   ``operator.add``). Note that the result of coercion is not required
   to be a Sage :class:`Element`, it could be a plain Python type.

   Note that, although this function is declared as ``def``, it doesn't
   have the usual overheads associated with Python functions (either
   for the caller or for ``__add__`` itself). This is because Python
   has optimised calling protocols for such special functions.

-  **def Element._add_(self, other)**

   This is the function that you should override to implement addition
   in a subclass of :class:`Element`.

   The two arguments to this function are guaranteed to have the **same
   parent**, but not necessarily the same Python type.

   When implementing ``_add_`` in a Cython extension type, use
   ``cpdef _add_`` instead of ``def _add_``.

   In Cython code, if you want to add two elements and you know that
   their parents are identical, you are encouraged to call this
   function directly, instead of using ``x + y``. This only works if
   Cython knows that the left argument is an ``Element``. You can
   always cast explicitly: ``(<Element>x)._add_(y)`` to force this.
   In plain Python, ``x + y`` is always the fastest way to add two
   elements because the special method ``__add__`` is optimized
   unlike the normal method ``_add_``.

The difference in the names of the arguments (``left, right``
versus ``self, other``) is intentional: ``self`` is guaranteed to be an
instance of the class in which the method is defined. In Cython, we know
that at least one of ``left`` or ``right`` is an instance of the class
but we do not know a priori which one.

Powering is a special case: first of all, the 3-argument version of
``pow()`` is not supported. Second, the coercion model checks whether
the exponent looks like an integer. If so, the function ``_pow_int``
is called. If the exponent is not an integer, the arguments are coerced
to a common parent and ``_pow_`` is called. So, if your type only
supports powering to an integer exponent, you should implement only
``_pow_int``. If you want to support arbitrary powering, implement both
``_pow_`` and ``_pow_int``.

For addition, multiplication and powering (not for other operators),
there is a fast path for operations with a C ``long``. For example,
implement ``cdef _add_long(self, long n)`` with optimized code for
``self + n``. The addition and multiplication are assumed to be
commutative, so they are also called for ``n + self`` or ``n * self``.
From Cython code, you can also call ``_add_long`` or ``_mul_long``
directly. This is strictly an optimization: there is a default
implementation falling back to the generic arithmetic function.

Examples
^^^^^^^^

We need some :class:`Parent` to work with::

    sage: from sage_libgap.structure.parent import Parent
    sage: class ExampleParent(Parent):
    ....:     def __init__(self, name, **kwds):
    ....:         Parent.__init__(self, **kwds)
    ....:         self.rename(name)

We start with a very basic example of a Python class implementing
``_add_``::

    sage: from sage_libgap.structure.element import Element
    sage: class MyElement(Element):
    ....:     def _add_(self, other):
    ....:         return 42
    sage: p = ExampleParent("Some parent")
    sage: x = MyElement(p)
    sage: x + x
    42

When two different parents are involved, this no longer works since
there is no coercion::

    sage: q = ExampleParent("Other parent")
    sage: y = MyElement(q)
    sage: x + y
    Traceback (most recent call last):
    ...
    TypeError: unsupported operand parent(s) for +: 'Some parent' and 'Other parent'

If ``_add_`` is not defined, an error message is raised, referring to
the parents::

    sage: x = Element(p)
    sage: x._add_(x)
    Traceback (most recent call last):
    ...
    AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_add_'...
    sage: x + x
    Traceback (most recent call last):
    ...
    TypeError: unsupported operand parent(s) for +: 'Some parent' and 'Some parent'
    sage: y = Element(q)
    sage: x + y
    Traceback (most recent call last):
    ...
    TypeError: unsupported operand parent(s) for +: 'Some parent' and 'Other parent'

We can also implement arithmetic generically in categories::

    sage: class MyCategory(Category):
    ....:     def super_categories(self):
    ....:         return [Sets()]
    ....:     class ElementMethods:
    ....:         def _add_(self, other):
    ....:             return 42
    sage: p = ExampleParent("Parent in my category", category=MyCategory())
    sage: x = Element(p)
    sage: x + x
    42

Implementation details
^^^^^^^^^^^^^^^^^^^^^^

Implementing the above features actually takes a bit of magic. Casual
callers and implementers can safely ignore it, but here are the
details for the curious.

To achieve fast arithmetic, it is critical to have a fast path in Cython
to call the ``_add_`` method of a Cython object. So we would like
to declare ``_add_`` as a ``cpdef`` method of class :class:`Element`.
Remember however that the abstract classes coming
from categories come after :class:`Element` in the method resolution
order (or fake method resolution order in case of a Cython
class). Hence any generic implementation of ``_add_`` in such an
abstract class would in principle be shadowed by ``Element._add_``.
This is worked around by defining ``Element._add_`` as a ``cdef``
instead of a ``cpdef`` method. Concrete implementations in subclasses
should be ``cpdef`` or ``def`` methods.

Let us now see what happens upon evaluating ``x + y`` when ``x`` and ``y``
are instances of a class that does not implement ``_add_`` but where
``_add_`` is implemented in the category.
First, ``x.__add__(y)`` is called, where ``__add__`` is implemented
in :class:`Element`.
Assuming that ``x`` and ``y`` have the same parent, a Cython call to
``x._add_(y)`` will be done.
The latter is implemented to trigger a Python level call to ``x._add_(y)``
which will succeed as desired.

In case that Python code calls ``x._add_(y)`` directly,
``Element._add_`` will be invisible, and the method lookup will
continue down the MRO and find the ``_add_`` method in the category.
"""

# ****************************************************************************
#       Copyright (C) 2006-2016 ...
#       Copyright (C) 2016 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#       Copyright (C) 2024 LaiTeP and contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  https://www.gnu.org/licenses/
# ****************************************************************************

# Modified version of sage_libgap.structure.element for sage_libgap

cimport cython
from cpython cimport *

cdef add, sub, mul, truediv, floordiv, mod, matmul, pow
from operator import (add, sub, mul, truediv, floordiv, mod, matmul, pow)

cdef dict _coerce_op_symbols = dict(
        add='+', sub='-', mul='*', truediv='/', floordiv='//', mod='%', matmul='@', pow='^',
        iadd='+', isub='-', imul='*', itruediv='/', ifloordiv='//', imod='%', imatmul='@', ipow='^')

from sage_libgap.structure.richcmp cimport rich_to_bool
from sage_libgap.cpython.getattr cimport getattr_from_other_class
from sage_libgap.arith.long cimport integer_check_long_py


cdef unary_op_exception(op, x) noexcept:
    try:
        op = op.__name__
        op = _coerce_op_symbols[op]
    except (AttributeError, KeyError):
        pass
    px = parent(x)
    return TypeError(f"unsupported operand parent for {op}: '{px}'")


cdef bin_op_exception(op, x, y) noexcept:
    try:
        op = op.__name__
        op = _coerce_op_symbols[op]
    except (AttributeError, KeyError):
        pass
    px = parent(x)
    py = parent(y)
    return TypeError(f"unsupported operand parent(s) for {op}: '{px}' and '{py}'")


def is_Element(x):
    """
    Return ``True`` if x is of type Element.

    EXAMPLES::

        sage: from sage_libgap.structure.element import is_Element
        sage: is_Element(2/3)
        True
        sage: is_Element(QQ^3)                                                          # needs sage.modules
        False
    """
    return isinstance(x, Element)


cdef class Element(SageObject):
    """
    Generic element of a structure. All other types of elements
    (:class:`RingElement`, :class:`ModuleElement`, etc)
    derive from this type.

    Subtypes must either call ``__init__()`` to set ``_parent``, or may
    set ``_parent`` themselves if that would be more efficient.

    .. automethod:: _richcmp_
    .. automethod:: __add__
    .. automethod:: __sub__
    .. automethod:: __neg__
    .. automethod:: __mul__
    .. automethod:: __truediv__
    .. automethod:: __floordiv__
    .. automethod:: __mod__
    """

    def __init__(self, parent):
        r"""
        INPUT:

        - ``parent`` - a SageObject
        """
        self._parent = parent

    def __getattr__(self, name):
        """
        Lookup a method or attribute from the category abstract classes.

        Let ``P`` be a parent in a category ``C``. Usually the methods
        of ``C.element_class`` are made directly available to elements
        of ``P`` via standard class inheritance. This is not the case
        any more if the elements of ``P`` are instances of an
        extension type. See :class:`Category` for details.

        The purpose of this method is to emulate this inheritance: for
        ``e`` and element of ``P``, if an attribute or method
        ``e.foo`` is not found in the super classes of ``e``, it's
        looked up manually in ``C.element_class`` and bound to ``e``.

        .. NOTE::

            - The attribute or method is actually looked up in
              ``P._abstract_element_class``. In most cases this is
              just an alias for ``C.element_class``, but some parents,
              notably homsets, customizes this to let elements also
              inherit from other abstract classes. See
              :meth:`Parent._abstract_element_class` and
              :meth:`Homset._abstract_element_class` for details.

            - This mechanism may also enter into action when the
              category of `P` is refined on the fly, leaving
              previously constructed elements in an outdated element
              class.

              See :class:`~sage_libgap.rings.polynomial.polynomial_quotient_ring.PolynomialQuotientRing_generic`
              for an example.

        EXAMPLES:

        We test that ``1`` (an instance of the extension type
        ``Integer``) inherits the methods from the categories of
        ``ZZ``, that is from ``CommutativeRings().element_class``::

            sage: 1.is_idempotent(), 2.is_idempotent()
            (True, False)

        This method is actually provided by the ``Magmas()`` super
        category of ``CommutativeRings()``::

            sage: 1.is_idempotent
            <bound method Magmas.ElementMethods.is_idempotent of 1>
            sage: 1.is_idempotent.__module__
            'sage.categories.magmas'

        TESTS::

            sage: 1.blah_blah
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.rings.integer.Integer' object has no attribute 'blah_blah'...
            sage: Semigroups().example().an_element().is_idempotent
            <bound method LeftZeroSemigroup.Element.is_idempotent of 42>
            sage: Semigroups().example().an_element().blah_blah
            Traceback (most recent call last):
            ...
            AttributeError: 'LeftZeroSemigroup_with_category.element_class' object has no attribute 'blah_blah'...
        """
        return getattr_from_other_class(self, type, name)

    def __dir__(self):
        """
        Emulate ``__dir__`` for elements with dynamically attached methods.

        Let cat be the category of the parent of ``self``. This method
        emulates ``self`` being an instance of both ``Element`` and
        ``cat.element_class`` (and the corresponding ``morphism_class`` in the
        case of a morphism), in that order, for attribute directory.

        EXAMPLES::

            sage: dir(1/2)
            [..., 'is_idempotent', 'is_integer', 'is_integral', ...]

        Caveat: dir on Integer's and some other extension types seem to ignore __dir__::

            sage: 1.__dir__()
            [..., 'is_idempotent', 'is_integer', 'is_integral', ...]
            sage: dir(1)         # todo: not implemented
            [..., 'is_idempotent', 'is_integer', 'is_integral', ...]

        TESTS:

        Check that morphism classes are handled correctly (:trac:`29776`)::

            sage: R.<x,y> = QQ[]
            sage: f = R.hom([x, y+1], R)
            sage: 'cartesian_product' in dir(f)
            True
            sage: 'extend_to_fraction_field' in dir(f)
            True
        """
        from sage_libgap.cpython.getattr import dir_with_other_class
        ec = self.parent().category().element_class
        try:
            mc = self.category_for().morphism_class
        except AttributeError:
            return dir_with_other_class(self, ec)
        else:
            return dir_with_other_class(self, ec, mc)

    def _repr_(self):
        return "Generic element of a structure"

    def __getstate__(self):
        """
        Return a tuple describing the state of your object.

        This should return all information that will be required to unpickle
        the object. The functionality for unpickling is implemented in
        __setstate__().

        TESTS::

            sage: R.<x,y> = QQ[]
            sage: i = ideal(x^2 - y^2 + 1)
            sage: i.__getstate__()
            (Monoid of ideals of Multivariate Polynomial Ring in x, y over Rational Field,
             {'_Ideal_generic__gens': (x^2 - y^2 + 1,),
              '_Ideal_generic__ring': Multivariate Polynomial Ring in x, y over Rational Field,
              '_gb_by_ordering': {}})
        """
        return self.__dict__

    def __setstate__(self, state_dict):
        """
        Initializes the state of the object from data saved in a pickle.

        During unpickling __init__ methods of classes are not called, the saved
        data is passed to the class via this function instead.

        TESTS::

            sage: R.<x,y> = QQ[]
            sage: i = ideal(x); i
            Ideal (x) of Multivariate Polynomial Ring in x, y over Rational Field
            sage: S.<x,y,z> = ZZ[]
            sage: i.__setstate__((R,{'_Ideal_generic__ring':S,'_Ideal_generic__gens': (S(x^2 - y^2 + 1),)}))
            sage: i
            Ideal (x^2 - y^2 + 1) of Multivariate Polynomial Ring in x, y, z over Integer Ring
        """
        self.__dict__ = state_dict

    def __copy__(self):
        """
        Return a copy of ``self``.

        OUTPUT:

          - a new object which is a copy of ``self``.

        This implementation ensures that ``self.__dict__`` is properly copied
        when it exists (typically for instances of classes deriving from
        :class:`Element`).

        TESTS::

            sage: from sage_libgap.structure.element import Element
            sage: el = Element(parent = ZZ)
            sage: el1 = copy(el)
            sage: el1 is el
            False

            sage: class Demo(Element): pass
            sage: el = Demo(parent = ZZ)
            sage: el.x = [1,2,3]
            sage: el1 = copy(el)
            sage: el1 is el
            False
            sage: el1.__dict__ is el.__dict__
            False
        """
        cls = self.__class__
        cdef Element res = cls.__new__(cls)
        res._parent = self._parent
        try:
            D = self.__dict__
        except AttributeError:
            return res
        for k,v in D.iteritems():
            try:
                setattr(res, k, v)
            except AttributeError:
                pass
        return res

    def _im_gens_(self, codomain, im_gens, base_map=None):
        """
        Return the image of ``self`` in codomain under the map that sends
        the images of the generators of the parent of ``self`` to the
        tuple of elements of im_gens.
        """
        raise NotImplementedError

    def parent(self, x=None):
        """
        Return the parent of this element; or, if the optional argument x is
        supplied, the result of coercing x into the parent of this element.
        """
        if x is None:
            return self._parent
        else:
            return self._parent(x)


    def subs(self, in_dict=None, **kwds):
        """
        Substitutes given generators with given values while not touching
        other generators. This is a generic wrapper around ``__call__``.
        The syntax is meant to be compatible with the corresponding method
        for symbolic expressions.

        INPUT:

        - ``in_dict`` - (optional) dictionary of inputs

        - ``**kwds`` - named parameters

        OUTPUT:

        - new object if substitution is possible, otherwise self.

        EXAMPLES::

            sage: x, y = PolynomialRing(ZZ,2,'xy').gens()
            sage: f = x^2 + y + x^2*y^2 + 5
            sage: f((5,y))
            25*y^2 + y + 30
            sage: f.subs({x:5})
            25*y^2 + y + 30
            sage: f.subs(x=5)
            25*y^2 + y + 30
            sage: (1/f).subs(x=5)
            1/(25*y^2 + y + 30)
            sage: Integer(5).subs(x=4)
            5
        """
        if not callable(self):
            return self
        parent = self._parent
        try:
            ngens = parent.ngens()
        except (AttributeError, NotImplementedError, TypeError):
            return self
        variables=[]
        # use "gen" instead of "gens" as a ParentWithGens is not
        # required to have the latter
        for i in range(ngens):
            gen = parent.gen(i)
            if str(gen) in kwds:
                variables.append(kwds[str(gen)])
            elif in_dict and gen in in_dict:
                variables.append(in_dict[gen])
            else:
                variables.append(gen)
        return self(*variables)

    def substitute(self,in_dict=None,**kwds):
        """
        This is an alias for self.subs().

        INPUT:

        - ``in_dict`` - (optional) dictionary of inputs

        - ``**kwds``  - named parameters

        OUTPUT:

        - new object if substitution is possible, otherwise self.

        EXAMPLES::

            sage: x, y = PolynomialRing(ZZ, 2, 'xy').gens()
            sage: f = x^2 + y + x^2*y^2 + 5
            sage: f((5,y))
            25*y^2 + y + 30
            sage: f.substitute({x: 5})
            25*y^2 + y + 30
            sage: f.substitute(x=5)
            25*y^2 + y + 30
            sage: (1/f).substitute(x=5)
            1/(25*y^2 + y + 30)
            sage: Integer(5).substitute(x=4)
            5
         """
        return self.subs(in_dict,**kwds)

    cpdef _act_on_(self, x, bint self_on_left) noexcept:
        """
        Use this method to implement ``self`` acting on ``x``.

        Return ``None`` or raise a ``CoercionException`` if no
        such action is defined here.
        """
        return None

    cpdef _acted_upon_(self, x, bint self_on_left) noexcept:
        """
        Use this method to implement ``self`` acted on by x.

        Return ``None`` or raise a ``CoercionException`` if no
        such action is defined here.
        """
        return None

    def __xor__(self, right):
        raise RuntimeError("Use ** for exponentiation, not '^', which means xor\n"
                           "in Python, and has the wrong precedence.")

    def __pos__(self):
        return self

    def _coeff_repr(self, no_space=True):
        if self._is_atomic():
            s = repr(self)
        else:
            s = "(%s)"%repr(self)
        if no_space:
            return s.replace(' ','')
        return s

    def _latex_coeff_repr(self):
        try:
            s = self._latex_()
        except AttributeError:
            s = str(self)
        if self._is_atomic():
            return s
        else:
            return "\\left(%s\\right)"%s

    def _is_atomic(self):
        """
        Return ``True`` if and only if parenthesis are not required when
        *printing* out any of `x - s`, `x + s`, `x^s` and `x/s`.

        EXAMPLES::

            sage: n = 5; n._is_atomic()
            True
            sage: n = x + 1; n._is_atomic()                                             # needs sage.symbolic
            False
        """
        if self._parent._repr_option('element_is_atomic'):
            return True
        s = str(self)
        return s.find("+") == -1 and s.find("-") == -1 and s.find(" ") == -1

    def __bool__(self):
        r"""
        Return whether this element is equal to ``self.parent()(0)``.

        Note that this is automatically called when converting to
        boolean, as in the conditional of an if or while statement.

        EXAMPLES::

            sage: bool(1) # indirect doctest
            True

        If ``self.parent()(0)`` raises an exception (because there is no
        meaningful zero element,) then this method returns ``True``. Here,
        there is no zero morphism of rings that goes to a non-trivial ring::

            sage: bool(Hom(ZZ, Zmod(2)).an_element())
            True

        But there is a zero morphism to the trivial ring::

            sage: bool(Hom(ZZ, Zmod(1)).an_element())
            False

        TESTS:

        Verify that :trac:`5185` is fixed::

            sage: # needs sage.modules
            sage: v = vector({1: 1, 3: -1})
            sage: w = vector({1: -1, 3: 1})
            sage: v + w
            (0, 0, 0, 0)
            sage: (v + w).is_zero()
            True
            sage: bool(v + w)
            False

        """
        try:
            zero = self._parent.zero()
        except Exception:
            return True # by convention

        return self != zero

    def is_zero(self):
        """
        Return ``True`` if ``self`` equals ``self.parent()(0)``.

        The default implementation is to fall back to ``not
        self.__bool__``.

        .. WARNING::

            Do not re-implement this method in your subclass but
            implement ``__bool__`` instead.
        """
        return not self

    def _cache_key(self):
        """
        Provide a hashable key for an element if it is not hashable.

        EXAMPLES::

            sage: a = sage_libgap.structure.element.Element(ZZ)
            sage: a._cache_key()
            (Integer Ring, 'Generic element of a structure')
        """
        return self.parent(), str(self)

    ####################################################################
    # In a Cython or a Python class, you must define _richcmp_
    #
    # Rich comparisons (like a < b) will use _richcmp_
    #
    # In the _richcmp_ method, you can assume that both arguments have
    # identical parents.
    ####################################################################
    def __richcmp__(self, other, int op):
        """
        Compare ``self`` and ``other`` using the coercion framework,
        comparing according to the comparison operator ``op``.

        Normally, a class will not redefine ``__richcmp__`` but rely on
        this ``Element.__richcmp__`` method which uses coercion if
        needed to compare elements. After coercion (or if no coercion
        is needed), ``_richcmp_`` is called.

        If a class wants to implement rich comparison without coercion,
        then ``__richcmp__`` should be defined.
        See :class:`sage.numerical.linear_functions.LinearConstraint`
        for such an example.

        For efficiency reasons, a class can do certain "manual"
        coercions directly in ``__richcmp__``, using
        ``coercion_model.richcmp()`` for the remaining cases.
        This is done for example in :class:`Integer`.
        """
        if have_same_parent(self, other):
            # Same parents, in particular self and other must both be
            # an instance of Element. The explicit casts below make
            # Cython generate optimized code for this call.
            return (<Element>self)._richcmp_(other, op)
        else:
            raise ValueError(f"Objects {self} and {other} do not have the same parent.")

    cpdef _richcmp_(left, right, int op) noexcept:
        r"""
        Basic default implementation of rich comparisons for elements with
        equal parents.

        It does a comparison by id for ``==`` and ``!=``. Calling this
        default method with ``<``, ``<=``, ``>`` or ``>=`` will return
        ``NotImplemented``.

        EXAMPLES::

            sage: from sage_libgap.structure.parent import Parent
            sage: from sage_libgap.structure.element import Element
            sage: P = Parent()
            sage: e1 = Element(P); e2 = Element(P)
            sage: e1 == e1    # indirect doctest
            True
            sage: e1 == e2    # indirect doctest
            False
            sage: e1 < e2     # indirect doctest
            Traceback (most recent call last):
            ...
            TypeError: '<' not supported between instances of 'sage_libgap.structure.element.Element' and 'sage_libgap.structure.element.Element'

        We now create an ``Element`` class where we define ``_richcmp_``
        and check that comparison works::

            sage: # needs sage_libgap.misc.cython
            sage: cython(
            ....: '''
            ....: from sage_libgap.structure.richcmp cimport rich_to_bool
            ....: from sage_libgap.structure.element cimport Element
            ....: cdef class FloatCmp(Element):
            ....:     cdef float x
            ....:     def __init__(self, float v):
            ....:         self.x = v
            ....:     cpdef _richcmp_(self, other, int op):
            ....:         cdef float x1 = (<FloatCmp>self).x
            ....:         cdef float x2 = (<FloatCmp>other).x
            ....:         return rich_to_bool(op, (x1 > x2) - (x1 < x2))
            ....: ''')
            sage: a = FloatCmp(1)
            sage: b = FloatCmp(2)
            sage: a <= b, b <= a
            (True, False)
        """
        # Obvious case
        if left is right:
            return rich_to_bool(op, 0)
        # Check equality by id(), knowing that left is not right
        if op == Py_EQ:
            return False
        if op == Py_NE:
            return True
        return NotImplemented

    ##################################################
    # Arithmetic using the coercion model
    ##################################################

    def __add__(left, right):
        """
        Top-level addition operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _add_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e + e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: e + e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for +: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 + e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for +: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e + 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for +: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) + e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for +: 'int' and 'sage_libgap.structure.element.Element'
            sage: e + int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for +: 'sage_libgap.structure.element.Element' and 'int'
            sage: None + e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for +: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e + None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for +: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._add_(right)
        # Left and right are Sage elements => use coercion model
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._add_(right)

        cdef long value
        cdef int err = -1
        try:
            # Special case addition with Python int
            integer_check_long_py(right, &value, &err)
            if not err:
                return (<Element>left)._add_long(value)
            integer_check_long_py(left, &value, &err)
            if not err:
                return (<Element>right)._add_long(value)
            return (<Element>left)._add_(right)
        except TypeError:
            # Either coercion failed or arithmetic is not defined.
            #
            # According to the Python convention, we should return
            # NotImplemented now. This will cause Python to try the
            # reversed addition (__radd__).
            return NotImplemented

    cdef _add_(self, other) noexcept:
        """
        Virtual addition method for elements with identical parents.

        This default Cython implementation of ``_add_`` calls the
        Python method ``self._add_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._add_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_add_'...
        """
        try:
            python_op = (<object>self)._add_
        except AttributeError:
            raise bin_op_exception('+', self, other)
        else:
            return python_op(other)

    cdef _add_long(self, long n) noexcept:
        """
        Generic path for adding a C long, assumed to commute.

        EXAMPLES::

            sage: # needs sage_libgap.misc.cython
            sage: cython(                       # long time
            ....: '''
            ....: from sage_libgap.structure.element cimport Element
            ....: cdef class MyElement(Element):
            ....:     cdef _add_long(self, long n):
            ....:         return n
            ....: ''')
            sage: e = MyElement(Parent())       # long time
            sage: i = int(42)
            sage: i + e, e + i                  # long time
            (42, 42)
        """
        return (<Element>self)._add_(n)

    def __sub__(left, right):
        """
        Top-level subtraction operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _sub_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e - e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: e - e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for -: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 - e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for -: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e - 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for -: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) - e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for -: 'int' and 'sage_libgap.structure.element.Element'
            sage: e - int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for -: 'sage_libgap.structure.element.Element' and 'int'
            sage: None - e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for -: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e - None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for -: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        # See __add__ for comments
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._sub_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._sub_(right)

        try:
            return (<Element>left)._sub_(right)
        except TypeError:
            return NotImplemented

    cdef _sub_(self, other) noexcept:
        """
        Virtual subtraction method for elements with identical parents.

        This default Cython implementation of ``_sub_`` calls the
        Python method ``self._sub_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._sub_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_sub_'...
        """
        try:
            python_op = (<object>self)._sub_
        except AttributeError:
            raise bin_op_exception('-', self, other)
        else:
            return python_op(other)

    def __neg__(self):
        """
        Top-level negation operator for :class:`Element`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _neg_(self):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: -e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: -e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent for unary -: '<sage_libgap.structure.parent.Parent object at ...>'
        """
        return self._neg_()

    cdef _neg_(self) noexcept:
        """
        Virtual unary negation method for elements.

        This default Cython implementation of ``_neg_`` calls the
        Python method ``self._neg_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._neg_()
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_neg_'...
        """
        try:
            python_op = (<object>self)._neg_
        except AttributeError:
            raise unary_op_exception('unary -', self)
        else:
            return python_op()

    def __mul__(left, right):
        """
        Top-level multiplication operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _mul_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e * e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: e * e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for *: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 * e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for *: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e * 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for *: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) * e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for *: 'int' and 'sage_libgap.structure.element.Element'
            sage: e * int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for *: 'sage_libgap.structure.element.Element' and 'int'
            sage: None * e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for *: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e * None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for *: 'sage_libgap.structure.element.Element' and 'NoneType'

        ::

            sage: # needs sage.combinat sage.modules
            sage: A = AlgebrasWithBasis(QQ).example(); A
            An example of an algebra with basis: the free algebra
            on the generators ('a', 'b', 'c') over Rational Field
            sage: x = A.an_element()
            sage: x
            B[word: ] + 2*B[word: a] + 3*B[word: b] + B[word: bab]
            sage: x.__mul__(x)
            B[word: ] + 4*B[word: a] + 4*B[word: aa] + 6*B[word: ab]
            + 2*B[word: abab] + 6*B[word: b] + 6*B[word: ba]
            + 2*B[word: bab] + 2*B[word: baba] + 3*B[word: babb]
            + B[word: babbab] + 9*B[word: bb] + 3*B[word: bbab]
        """
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._mul_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._mul_(right)

        cdef long value
        cdef int err = -1
        try:
            # Special case multiplication with Python int
            integer_check_long_py(right, &value, &err)
            if not err:
                return (<Element>left)._mul_long(value)
            integer_check_long_py(left, &value, &err)
            if not err:
                return (<Element>right)._mul_long(value)
            return (<Element>left)._mul_(right)
        except TypeError:
            return NotImplemented

    cdef _mul_(self, other) noexcept:
        """
        Virtual multiplication method for elements with identical parents.

        This default Cython implementation of ``_mul_`` calls the
        Python method ``self._mul_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._mul_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_mul_'...
        """
        try:
            python_op = (<object>self)._mul_
        except AttributeError:
            raise bin_op_exception('*', self, other)
        else:
            return python_op(other)

    cdef _mul_long(self, long n) noexcept:
        """
        Generic path for multiplying by a C long, assumed to commute.

        EXAMPLES::

            sage: # needs sage_libgap.misc.cython
            sage: cython(                       # long time
            ....: '''
            ....: from sage_libgap.structure.element cimport Element
            ....: cdef class MyElement(Element):
            ....:     cdef _mul_long(self, long n):
            ....:         return n
            ....: ''')
            sage: e = MyElement(Parent())       # long time
            sage: i = int(42)
            sage: i * e, e * i                  # long time
            (42, 42)
        """
        return (<Element>self)._mul_(n)

    def __matmul__(left, right):
        """
        Top-level matrix multiplication operator for :class:`Element`
        invoking the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _matmul_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: from operator import matmul
            sage: matmul(e, e)
            42

        TESTS::

            sage: e = Element(Parent())
            sage: matmul(e, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for @: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: matmul(1, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for @: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: matmul(e, 1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for @: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: matmul(int(1), e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for @: 'int' and 'sage_libgap.structure.element.Element'
            sage: matmul(e, int(1))
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for @: 'sage_libgap.structure.element.Element' and 'int'
            sage: matmul(None, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for @: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: matmul(e, None)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for @: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._matmul_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._matmul_(right)

        try:
            return (<Element>left)._matmul_(right)
        except TypeError:
            return NotImplemented

    cdef _matmul_(self, other) noexcept:
        """
        Virtual matrix multiplication method for elements with
        identical parents.

        This default Cython implementation of ``_matmul_`` calls the
        Python method ``self._matmul_`` if it exists. This method may
        be defined in the ``ElementMethods`` of the category of the
        parent. If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._matmul_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_matmul_'...
        """
        try:
            python_op = (<object>self)._matmul_
        except AttributeError:
            raise bin_op_exception('@', self, other)
        else:
            return python_op(other)

    def __truediv__(left, right):
        """
        Top-level true division operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: operator.truediv(2, 3)
            2/3
            sage: operator.truediv(pi, 3)                                               # needs sage.symbolic
            1/3*pi
            sage: x = polygen(QQ, 'x')
            sage: K.<i> = NumberField(x^2 + 1)                                          # needs sage_libgap.rings.number_field
            sage: operator.truediv(2, K.ideal(i + 1))                                   # needs sage_libgap.rings.number_field
            Fractional ideal (-i + 1)

        ::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _div_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: operator.truediv(e, e)
            42

        TESTS::

            sage: e = Element(Parent())
            sage: operator.truediv(e, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for /: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: operator.truediv(1, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for /: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: operator.truediv(e, 1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for /: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: operator.truediv(int(1), e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for /: 'int' and 'sage_libgap.structure.element.Element'
            sage: operator.truediv(e, int(1))
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for /: 'sage_libgap.structure.element.Element' and 'int'
            sage: operator.truediv(None, e)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for /: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: operator.truediv(e, None)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for /: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        # See __add__ for comments
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._div_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._div_(right)

        try:
            return (<Element>left)._div_(right)
        except TypeError:
            return NotImplemented

    cdef _div_(self, other) noexcept:
        """
        Virtual division method for elements with identical parents.
        This is called for Python 2 division as well as true division.

        This default Cython implementation of ``_div_`` calls the
        Python method ``self._div_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._div_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_div_'...
        """
        try:
            python_op = (<object>self)._div_
        except AttributeError:
            raise bin_op_exception('/', self, other)
        else:
            return python_op(other)

    def __floordiv__(left, right):
        """
        Top-level floor division operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: 7 // 3
            2
            sage: 7 // int(3)
            2
            sage: int(7) // 3
            2

        ::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _floordiv_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e // e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: e // e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for //: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 // e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for //: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e // 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for //: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) // e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for //: 'int' and 'sage_libgap.structure.element.Element'
            sage: e // int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for //: 'sage_libgap.structure.element.Element' and 'int'
            sage: None // e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for //: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e // None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for //: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        # See __add__ for comments
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._floordiv_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._floordiv_(right)

        try:
            return (<Element>left)._floordiv_(right)
        except TypeError:
            return NotImplemented

    cdef _floordiv_(self, other) noexcept:
        """
        Virtual floor division method for elements with identical parents.

        This default Cython implementation of ``_floordiv_`` calls the
        Python method ``self._floordiv_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._floordiv_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_floordiv_'...
        """
        try:
            python_op = (<object>self)._floordiv_
        except AttributeError:
            raise bin_op_exception('//', self, other)
        else:
            return python_op(other)

    def __mod__(left, right):
        """
        Top-level modulo operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: 7 % 3
            1
            sage: 7 % int(3)
            1
            sage: int(7) % 3
            1

        ::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _mod_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e % e
            42

        TESTS::

            sage: e = Element(Parent())
            sage: e % e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for %: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 % e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for %: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e % 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for %: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) % e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for %: 'int' and 'sage_libgap.structure.element.Element'
            sage: e % int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for %: 'sage_libgap.structure.element.Element' and 'int'
            sage: None % e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for %: 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e % None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for %: 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        # See __add__ for comments
        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._mod_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._mod_(right)

        try:
            return (<Element>left)._mod_(right)
        except TypeError:
            return NotImplemented

    cdef _mod_(self, other) noexcept:
        """
        Virtual modulo method for elements with identical parents.

        This default Cython implementation of ``_mod_`` calls the
        Python method ``self._mod_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._mod_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_mod_'...
        """
        try:
            python_op = (<object>self)._mod_
        except AttributeError:
            raise bin_op_exception('%', self, other)
        else:
            return python_op(other)

    def __pow__(left, right, modulus):
        """
        Top-level power operator for :class:`Element` invoking
        the coercion model.

        See :ref:`element_arithmetic`.

        EXAMPLES::

            sage: from sage_libgap.structure.element import Element
            sage: class MyElement(Element):
            ....:     def _add_(self, other):
            ....:         return 42
            sage: e = MyElement(Parent())
            sage: e + e
            42
            sage: a = Integers(389)['x']['y'](37)
            sage: p = sage_libgap.structure.element.RingElement.__pow__
            sage: p(a, 2)
            202
            sage: p(a, 2, 1)
            Traceback (most recent call last):
            ...
            TypeError: the 3-argument version of pow() is not supported

        ::

            sage: # needs sage.symbolic
            sage: (2/3)^I
            (2/3)^I
            sage: (2/3)^sqrt(2)
            (2/3)^sqrt(2)
            sage: var('x,y,z,n')
            (x, y, z, n)
            sage: (2/3)^(x^n + y^n + z^n)
            (2/3)^(x^n + y^n + z^n)
            sage: (-7/11)^(tan(x)+exp(x))
            (-7/11)^(e^x + tan(x))

            sage: float(1.2)**(1/2)
            1.0954451150103321
            sage: complex(1,2)**(1/2)                                                   # needs sage_libgap.rings.complex_double
            (1.272019649514069+0.786151377757423...j)

        TESTS::

            sage: e = Element(Parent())
            sage: e ^ e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for ^: '<sage_libgap.structure.parent.Parent object at ...>' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: 1 ^ e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for ^: 'Integer Ring' and '<sage_libgap.structure.parent.Parent object at ...>'
            sage: e ^ 1
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand parent(s) for ^: '<sage_libgap.structure.parent.Parent object at ...>' and 'Integer Ring'
            sage: int(1) ^ e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for ** or pow(): 'int' and 'sage_libgap.structure.element.Element'
            sage: e ^ int(1)
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for ** or pow(): 'sage_libgap.structure.element.Element' and 'int'
            sage: None ^ e
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for ** or pow(): 'NoneType' and 'sage_libgap.structure.element.Element'
            sage: e ^ None
            Traceback (most recent call last):
            ...
            TypeError: unsupported operand type(s) for ** or pow(): 'sage_libgap.structure.element.Element' and 'NoneType'
        """
        # The coercion model does not support a modulus
        if modulus is not None:
            raise TypeError("the 3-argument version of pow() is not supported")

        cdef int cl = classify_elements(left, right)
        if HAVE_SAME_PARENT(cl):
            return (<Element>left)._pow_(right)
        if BOTH_ARE_ELEMENT(cl):
            return (<Element>left)._pow_(right)

        cdef long value
        cdef int err = -1
        try:
            # Special case powering with Python integers
            integer_check_long_py(right, &value, &err)
            if not err:
                return (<Element>left)._pow_long(value)
            return (<Element>left)._pow_(right)
        except TypeError:
            return NotImplemented

    cdef _pow_(self, other) noexcept:
        """
        Virtual powering method for elements with identical parents.

        This default Cython implementation of ``_pow_`` calls the
        Python method ``self._pow_`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._pow_(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_pow_'...
        """
        try:
            python_op = (<object>self)._pow_
        except AttributeError:
            raise bin_op_exception('^', self, other)
        else:
            return python_op(other)

    cdef _pow_int(self, other) noexcept:
        """
        Virtual powering method for powering to an integer exponent.

        This default Cython implementation of ``_pow_int`` calls the
        Python method ``self._pow_int`` if it exists. This method may be
        defined in the ``ElementMethods`` of the category of the parent.
        If the method is not found, a ``TypeError`` is raised
        indicating that the operation is not supported.

        See :ref:`element_arithmetic`.

        EXAMPLES:

        This method is not visible from Python::

            sage: from sage_libgap.structure.element import Element
            sage: e = Element(Parent())
            sage: e._pow_int(e)
            Traceback (most recent call last):
            ...
            AttributeError: 'sage_libgap.structure.element.Element' object has no attribute '_pow_int'...
        """
        try:
            python_op = (<object>self)._pow_int
        except AttributeError:
            raise bin_op_exception('^', self, other)
        else:
            return python_op(other)

    cdef _pow_long(self, long n) noexcept:
        """
        Generic path for powering with a C long.
        """
        return self._pow_int(n)

    def sage(self):
        r"""
        Return the Sage equivalent of the :class:`GapElement`

        EXAMPLES::

            sage: libgap(1).sage()
            1
            sage: type(_)
            <class 'sage_libgap.rings.integer.Integer'>

            sage: libgap(3/7).sage()
            3/7
            sage: type(_)
            <class 'sage_libgap.rings.rational.Rational'>

            sage: libgap.eval('5 + 7*E(3)').sage()
            7*zeta3 + 5

            sage: libgap(Infinity).sage()
            +Infinity
            sage: libgap(-Infinity).sage()
            -Infinity

            sage: libgap(True).sage()
            True
            sage: libgap(False).sage()
            False
            sage: type(_)
            <... 'bool'>

            sage: libgap('this is a string').sage()
            'this is a string'
            sage: type(_)
            <... 'str'>

            sage: x = libgap.Integers.Indeterminate("x")

            sage: p = x^2 - 2*x + 3
            sage: p.sage()
            x^2 - 2*x + 3
            sage: p.sage().parent()
            Univariate Polynomial Ring in x over Integer Ring

            sage: p = x^-2 + 3*x
            sage: p.sage()
            x^-2 + 3*x
            sage: p.sage().parent()
            Univariate Laurent Polynomial Ring in x over Integer Ring

            sage: p = (3 * x^2 + x) / (x^2 - 2)
            sage: p.sage()
            (3*x^2 + x)/(x^2 - 2)
            sage: p.sage().parent()
            Fraction Field of Univariate Polynomial Ring in x over Integer Ring

        TESTS:

        Check :trac:`30496`::

            sage: x = libgap.Integers.Indeterminate("x")

            sage: p = x^2 - 2*x
            sage: p.sage()
            x^2 - 2*x
        """
        if self.value is None:
            return None

        if self.IsInfinity():
            from sage_libgap.rings.infinity import Infinity
            return Infinity

        elif self.IsNegInfinity():
            from sage_libgap.rings.infinity import Infinity
            return -Infinity

        elif self.IsList():
            # May be a list-like collection of some other type of GapElements
            # that we can convert
            return [item.sage() for item in self.AsList()]

        raise NotImplementedError('cannot construct equivalent Sage object')
