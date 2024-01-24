# -*- encoding: utf-8 -*-

#     Copyright (C) 2005-2024 The SageMath Developers
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

# Modified version of sage.structure.sage_object for sage_libgap

r"""
Abstract base class for Sage objects
"""

from sage.misc.persist import _base_dumps, _base_save
                               

__all__ = ['SageObject']


cdef class SageObject:
    """
    Base class for all (user-visible) objects in Sage

    Every object that can end up being returned to the user should
    inherit from :class:`SageObject`.

    .. automethod:: _ascii_art_
    .. automethod:: _cache_key
    """
    def _test_new(self, **options):
        """
        Check that ``cls.__new__(cls)`` does not crash Python,
        where ``cls = type(self)``.

        It is perfectly legal for ``__new__`` to raise ordinary
        exceptions.

        EXAMPLES::

            sage: SageObject()._test_new()
        """
        cdef type cls = type(self)
        try:
            cls.__new__(cls)
        except Exception:
            pass

    #######################################################################
    # Textual representation code
    #######################################################################

    def rename(self, x=None):
        r"""
        Change self so it prints as x, where x is a string.

        If x is ``None``, the existing custom name is removed.

        .. NOTE::

           This is *only* supported for Python classes that derive
           from SageObject.

        EXAMPLES::

            sage: x = PolynomialRing(QQ, 'x', sparse=True).gen()
            sage: g = x^3 + x - 5
            sage: g
            x^3 + x - 5
            sage: g.rename('a polynomial')
            sage: g
            a polynomial
            sage: g + x
            x^3 + 2*x - 5
            sage: h = g^100
            sage: str(h)[:20]
            'x^300 + 100*x^298 - '
            sage: h.rename('x^300 + ...')
            sage: h
            x^300 + ...
            sage: g.rename(None)
            sage: g
            x^3 + x - 5

        Real numbers are not Python classes, so rename is not supported::

            sage: a = 3.14
            sage: type(a)                                                               # needs sage.rings.real_mpfr
            <... 'sage.rings.real_mpfr.RealLiteral'>
            sage: a.rename('pi')                                                        # needs sage.rings.real_mpfr
            Traceback (most recent call last):
            ...
            NotImplementedError: object does not support renaming: 3.14000000000000

        .. NOTE::

           The reason C-extension types are not supported by default
           is if they were then every single one would have to carry
           around an extra attribute, which would be slower and waste
           a lot of memory.

           To support them for a specific class, add a
           ``cdef public _SageObject__custom_name`` attribute.
        """
        if x is None:
            self.reset_name()
        else:
            try:
                # TODO: after dropping support for Cython < 3.0.0, all
                # the self._SageObject__custom_name in this class can be
                # changed to self.__custom_name
                self._SageObject__custom_name = str(x)
            except AttributeError:
                raise NotImplementedError("object does not support renaming: %s" % self)

    def reset_name(self):
        """
        Remove the custom name of an object.

        EXAMPLES::

            sage: P.<x> = QQ[]
            sage: P
            Univariate Polynomial Ring in x over Rational Field
            sage: P.rename('A polynomial ring')
            sage: P
            A polynomial ring
            sage: P.reset_name()
            sage: P
            Univariate Polynomial Ring in x over Rational Field
        """
        if hasattr(self, '_SageObject__custom_name'):
            del self._SageObject__custom_name

    def get_custom_name(self):
        """
        Return the custom name of this object, or ``None`` if it is not
        renamed.

        EXAMPLES::

            sage: P.<x> = QQ[]
            sage: P.get_custom_name() is None
            True
            sage: P.rename('A polynomial ring')
            sage: P.get_custom_name()
            'A polynomial ring'
            sage: P.reset_name()
            sage: P.get_custom_name() is None
            True
        """
        try:
            return self._SageObject__custom_name
        except AttributeError:
            return None

    def __repr__(self):
        """
        Default method for string representation.

        .. NOTE::

            Do not overwrite this method. Instead, implement
            a ``_repr_`` (single underscore) method.

        EXAMPLES:

        By default, the string representation coincides with
        the output of the single underscore ``_repr_``::

            sage: P.<x> = QQ[]
            sage: repr(P) == P._repr_()  #indirect doctest
            True

        Using :meth:`rename`, the string representation can
        be customized::

            sage: P.rename('A polynomial ring')
            sage: repr(P) == P._repr_()
            False

        The original behaviour is restored with :meth:`reset_name`.::

            sage: P.reset_name()
            sage: repr(P) == P._repr_()
            True

        If there is no ``_repr_`` method defined, we fall back to the
        super class (typically ``object``)::

            sage: from sage.structure.sage_object import SageObject
            sage: S = SageObject()
            sage: S
            <sage.structure.sage_object.SageObject object at ...>
        """
        try:
            name = self._SageObject__custom_name
            if name is not None:
                return name
        except AttributeError:
            pass
        try:
            reprfunc = self._repr_
        except AttributeError:
            return super().__repr__()
        return reprfunc()

    def __hash__(self):
        r"""
        Not implemented: mutable objects inherit from this class

        EXAMPLES::

            sage: hash(SageObject())
            Traceback (most recent call last):
            ...
            TypeError: <... 'sage.structure.sage_object.SageObject'> is not hashable
        """
        raise TypeError("{} is not hashable".format(type(self)))

    def _cache_key(self):
        r"""
        Return a hashable key which identifies this objects for caching. The
        output must be hashable itself, or a tuple of objects which are
        hashable or define a ``_cache_key``.

        This method will only be called if the object itself is not hashable.

        Some immutable objects (such as `p`-adic numbers) cannot implement a
        reasonable hash function because their ``==`` operator has been
        modified to return ``True`` for objects which might behave differently
        in some computations::

            sage: # needs sage.rings.padics
            sage: K.<a> = Qq(9)
            sage: b = a + O(3)
            sage: c = a + 3
            sage: b
            a + O(3)
            sage: c
            a + 3 + O(3^20)
            sage: b == c
            True
            sage: b == a
            True
            sage: c == a
            False

        If such objects defined a non-trivial hash function, this would break
        caching in many places. However, such objects should still be usable in
        caches. This can be achieved by defining an appropriate
        ``_cache_key``::

            sage: # needs sage.rings.padics
            sage: hash(b)
            Traceback (most recent call last):
            ...
            TypeError: unhashable type: 'sage.rings.padics.qadic_flint_CR.qAdicCappedRelativeElement'
            sage: @cached_method
            ....: def f(x): return x==a
            sage: f(b)
            True
            sage: f(c)  # if b and c were hashable, this would return True
            False
            sage: b._cache_key()
            (..., ((0, 1),), 0, 1)
            sage: c._cache_key()
            (..., ((0, 1), (1,)), 0, 20)

        An implementation must make sure that for elements ``a`` and ``b``,
        if ``a != b``, then also ``a._cache_key() != b._cache_key()``.
        In practice this means that the ``_cache_key`` should always include
        the parent as its first argument::

            sage: S.<a> = Qq(4)                                                         # needs sage.rings.padics
            sage: d = a + O(2)                                                          # needs sage.rings.padics
            sage: b._cache_key() == d._cache_key()  # this would be True if the parents were not included               # needs sage.rings.padics
            False

        """
        try:
            hash(self)
        except TypeError:
            raise TypeError("{} is not hashable and does not implement _cache_key()".format(type(self)))
        else:
            assert False, "_cache_key() must not be called for hashable elements"

    ##########################################################################
    # DATABASE Related code
    ##########################################################################

    def save(self, filename=None, compress=True):
        """
        Save self to the given filename.

        EXAMPLES::

            sage: # needs sage.symbolic
            sage: x = SR.var("x")
            sage: f = x^3 + 5
            sage: from tempfile import NamedTemporaryFile
            sage: with NamedTemporaryFile(suffix=".sobj") as t:
            ....:     f.save(t.name)
            ....:     load(t.name)
            x^3 + 5
        """
        if filename is None:
            try:
                filename = self._default_filename
            except AttributeError:
                raise RuntimeError(
                        "no default filename, so it must be specified")

        filename = _base_save(self, filename, compress=compress)

        try:
            self._default_filename = filename
        except AttributeError:
            pass

    def dump(self, filename, compress=True):
        """
        Same as self.save(filename, compress)
        """
        return self.save(filename, compress=compress)

    def dumps(self, compress=True):
        r"""
        Dump ``self`` to a string ``s``, which can later be reconstituted
        as ``self`` using ``loads(s)``.

        There is an optional boolean argument ``compress`` which defaults to ``True``.

        EXAMPLES::

            sage: from sage.misc.persist import comp
            sage: O = SageObject()
            sage: p_comp = O.dumps()
            sage: p_uncomp = O.dumps(compress=False)
            sage: comp.decompress(p_comp) == p_uncomp
            True
            sage: import pickletools
            sage: pickletools.dis(p_uncomp)
                0: \x80 PROTO      2
                2: c    GLOBAL     'sage.structure.sage_object SageObject'
               41: q    BINPUT     ...
               43: )    EMPTY_TUPLE
               44: \x81 NEWOBJ
               45: q    BINPUT     ...
               47: .    STOP
            highest protocol among opcodes = 2
        """

        return _base_dumps(self, compress=compress)

    #############################################################################
    # Category theory / structure
    #############################################################################

    def parent(self):
        """
        Return the type of ``self`` to support the coercion framework.

        EXAMPLES::

            sage: t = log(sqrt(2) - 1) + log(sqrt(2) + 1); t                            # needs sage.symbolic
            log(sqrt(2) + 1) + log(sqrt(2) - 1)
            sage: u = t.maxima_methods()                                                # needs sage.symbolic
            sage: u.parent()                                                            # needs sage.symbolic
            <class 'sage.symbolic.maxima_wrapper.MaximaWrapper'>
        """
        return type(self)
