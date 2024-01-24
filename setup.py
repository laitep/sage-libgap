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

# Based on the setup.py of E. M. Bray's gappy-system
# https://github.com/embray/gappy/blob/master/setup.py

import os
import pathlib
from shutil import which

from setuptools import setup, Extension
from Cython.Build import cythonize


def find_gap() -> pathlib.Path:
    # Check if the GAP executable is available on the PATH
    gap_exec = which("gap")
    if gap_exec is None:
        # If not, check the environment variable GAP_ROOT
        gap_root_str = os.environ.get("GAP_ROOT", None)
        if gap_root_str is None:
            raise ValueError(
                "GAP not found. Either add the GAP folder to the PATH, or set the "
                "GAP_ROOT environment variable (if using Unix, do not forget to "
                "use the `export` shell command) to point to it."
            )
        gap_root = pathlib.Path(gap_root_str)
    else:
        gap_root = pathlib.Path(gap_exec).parent
    # Check that the "build" and ".libs" folders exists
    assert gap_root.joinpath(".libs").exists(), (
        "Folder with the GAP library not found. "
        f'Expected it in {gap_root.joinpath(".libs")}'
    )
    assert gap_root.joinpath("build", "gap").exists(), (
        "Folder with the GAP headers not found. "
        f'Expected it in {gap_root.joinpath("build", "gap")}'
    )
    return gap_root


def file_to_module(file_path: pathlib.Path, namespace: str) -> str:
    """Converts a file path to a module name.

    :param file_path: Path object with the path to the file
    :type file_path: pathlib.Path
    :param namespace: The parent module name
    :type namespace: str
    :return: Module name
    :rtype: str
    """
    file_path_string = file_path.as_posix()
    module_path = file_path_string[
        file_path_string.find(namespace) : file_path_string.find(".pyx")
    ]
    module_name = module_path.replace(os.sep, ".")
    return module_name


gap_root = find_gap()
setup_dir = pathlib.Path(__file__).parent
src_dir = setup_dir.joinpath("src")
package_dir = src_dir.joinpath("sage_libgap")

extensions = []
for pyx_file in src_dir.glob(os.sep.join(["**", "*.pyx"])):
    relative_to_src_path = pyx_file.relative_to(src_dir)
    relative_to_setup_path = pyx_file.relative_to(setup_dir)
    extensions.append(
        Extension(
            file_to_module(relative_to_src_path, package_dir.name),
            [relative_to_setup_path.as_posix()],
            include_dirs=[os.path.join(gap_root, "build")],
            library_dirs=[os.path.join(gap_root, ".libs")],
        )
    )

ext_modules = cythonize(
    extensions,
    language_level=3,
)

setup(
    ext_modules=ext_modules,
)
