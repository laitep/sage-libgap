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

from cpython.object cimport PyTypeObject

cdef extern from *:
    PyTypeObject PyWrapperDescr_Type

wrapper_descriptor = <type>(&PyWrapperDescr_Type)
