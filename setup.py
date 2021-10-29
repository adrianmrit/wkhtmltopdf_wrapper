import os
import subprocess

from setuptools import Extension, setup
from Cython.Build import cythonize

_IS_WINDOWS = os.name == "nt"
"""Whether the operative system is Windows or not"""

_WKHTMLTOPDF_EXE = "wkhtmltopdf"
"""Executable for wkhtmltopdf. Used to get the right path of the dependencies"""

__all__ = []


def _get_wkhtmltopdf_path():
    """
    Resolves the parent folder of the wkhtmltopdf installation.

    :return: Parent path of the bin folder that contains the wkhtmltopdf executable
    """
    command = "where" if _IS_WINDOWS else "which"

    try:
        result = subprocess.check_output([command, _WKHTMLTOPDF_EXE])
    except subprocess.CalledProcessError:
        raise RuntimeError("This operative system is not supported.")

    if result is None:
        return []

    result = result.decode().splitlines()

    if not result:
        raise RuntimeError("Please install wkhtmltopdf before installing this package.")

    # Executable is contained in the bin directory, we need the parent directory
    bin_path = os.path.dirname(result[-1])
    return os.path.dirname(bin_path)


def _get_extension(name: str, sources: list):
    """
    Returns an instance of ``setuptools.Extension`` with the right
    ``library_dirs``, ``include_dirs`` and ``libraries`` parameters.

    :param name: Name of the library
    :param sources: Library sources
    :return: Extension instance
    """
    wkhtmltopdf_root_path = _get_wkhtmltopdf_path()
    kwargs = {
        "sources": sources,
        "libraries": ["wkhtmltox"],
    }
    library_dir_names = ["lib"]
    include_dir_names = ["bin", "include", "include/wkhtmltox"]

    kwargs["library_dirs"] = [
        os.path.join(wkhtmltopdf_root_path, dir_name) for dir_name in library_dir_names
    ]
    kwargs["include_dirs"] = [
        os.path.join(wkhtmltopdf_root_path, dir_name) for dir_name in include_dir_names
    ]
    return Extension(name, **kwargs)


_ext_modules = [_get_extension("wkhtmltopdf_wrapper", ["wkhtmltopdf_wrapper.pyx"])]

with open("requirements.txt") as f:
    _requirements = f.read().splitlines()

setup(
    name="wkhtmltopdf_wrapper",
    ext_modules=cythonize(_ext_modules),
    install_requires=_requirements,
)
