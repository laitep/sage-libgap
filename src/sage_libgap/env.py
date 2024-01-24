# ****************************************************************************
#       Copyright (C) 2013 R. Andrew Ohana <andrew.ohana@gmail.com>
#       Copyright (C) 2019 Jeroen Demeyer <J.Demeyer@UGent.be>
#       Copyright (C) 2024 LaiTeP and contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  https://www.gnu.org/licenses/
# ****************************************************************************

# Modified version of sage_libgap.env for sage_libgap

import os
import pathlib
import socket
from shutil import which

# system info
HOSTNAME = socket.gethostname()

# ~/.sage
DOT_SAGE = os.path.join(os.environ.get("HOME"), ".sage")

# GAP memory and args

SAGE_GAP_MEMORY = os.environ.get("SAGE_GAP_MEMORY", None)


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
    # Check that the "lib" and "pkg" folders exists
    assert gap_root.joinpath("lib", "init.g").exists(), (
        "Folder `lib` with the GAP `init.g` file not found. "
        f'Expected it in {gap_root.joinpath("lib")}'
    )
    assert gap_root.joinpath("pkg").exists(), (
        "Folder with the GAP packages not found. "
        f'Expected it in {gap_root.joinpath("pkg")}'
    )
    return gap_root


# The semicolon-separated search path for GAP packages. It is passed
# directly to GAP via the -l flag.
# Using `dict.get(..., None) or f()` instead of `dict.get(..., f())` avoids
# calling `f` in case the entry exists in the dictionary, which in this case
# means avoiding the possibility of raising a misleading ValueError.
GAP_ROOT_PATHS = os.environ.get("GAP_ROOT_PATHS", None) or find_gap().as_posix()
