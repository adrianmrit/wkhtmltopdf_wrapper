from setuptools import Extension, setup
from Cython.Build import cythonize


# TODO: Improve setup so it works in more platforms and scenarios
# TODO: Add requirements

ext_modules = [
    Extension("wkhtmltopdf_wrapper",
              sources=["wkhtmltopdf_wrapper.pyx"],
              library_dirs=["C:/Program Files/wkhtmltopdf/lib"],
              include_dirs=[
                  "C:/Program Files/wkhtmltopdf/bin",
                  "C:/Program Files/wkhtmltopdf/include",
                  "C:/Program Files/wkhtmltopdf/include/wkhtmltox"
              ],
              libraries=["wkhtmltox"],
              )
]

setup(name="wkhtmltopdf_wrapper", ext_modules=cythonize(ext_modules))