#### WARNING: Still in development

This is a wrapper of the wkhtmltopdf shared library.
Written with Cython

Although wkhtmltopdf is not thread-safe, this library
(the `to_pdf` method to be more specific) achieves thread
safety by doing each conversion in a separate process.

Unlike other libraries, this wrapper is written in
<b>Cython</b> and does not call a command line process,
which should make it more efficient and handle errors better.