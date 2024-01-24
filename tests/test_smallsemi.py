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

from sage_libgap.libgap import libgap as gap


def test_smallsemi():
    gap.LoadPackage("smallsemi")
    m_table = gap([[0, 1], [1, 1]])
    sem = gap.SemigroupByMultiplicationTable(m_table + gap(1))
    sem_id = gap.IdSmallSemigroup(sem)

    assert len(sem_id) == 2
    assert int(sem_id[0]) == 2
    assert int(sem_id[1]) == 3
