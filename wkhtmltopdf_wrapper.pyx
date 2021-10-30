# cython: language_level=3, c_string_type=bytes
import logging
from multiprocessing import SimpleQueue, Process
from typing import Union

cdef extern from "pdf.h":
    ctypedef struct wkhtmltopdf_global_settings:
        pass
    ctypedef struct wkhtmltopdf_object_settings:
        pass
    ctypedef struct wkhtmltopdf_converter:
        pass

    ctypedef void (*wkhtmltopdf_str_callback)(wkhtmltopdf_converter * converter, const char * _str)
    ctypedef void (*wkhtmltopdf_int_callback)(wkhtmltopdf_converter * converter, const int val)
    ctypedef void (*wkhtmltopdf_void_callback)(wkhtmltopdf_converter * converter)

    int wkhtmltopdf_init(int use_graphics)
    int wkhtmltopdf_deinit()
    int wkhtmltopdf_extended_qt()

    wkhtmltopdf_global_settings * wkhtmltopdf_create_global_settings()
    void wkhtmltopdf_destroy_global_settings(wkhtmltopdf_global_settings *)
    wkhtmltopdf_object_settings * wkhtmltopdf_create_object_settings()
    void wkhtmltopdf_destroy_object_settings(wkhtmltopdf_object_settings *)

    int wkhtmltopdf_set_global_setting(wkhtmltopdf_global_settings * settings, const char * name, const char * value)
    int wkhtmltopdf_get_global_setting(wkhtmltopdf_global_settings * settings, const char * name, char * value, int vs)
    int wkhtmltopdf_set_object_setting(wkhtmltopdf_object_settings * settings, const char * name, const char * value)
    int wkhtmltopdf_get_object_setting(wkhtmltopdf_object_settings * settings, const char * name, char * value, int vs)

    wkhtmltopdf_converter * wkhtmltopdf_create_converter(wkhtmltopdf_global_settings * settings)
    void wkhtmltopdf_destroy_converter(wkhtmltopdf_converter * converter)

    wkhtmltopdf_converter * wkhtmltopdf_create_converter(wkhtmltopdf_global_settings * settings)
    void wkhtmltopdf_destroy_converter(wkhtmltopdf_converter * converter)

    void wkhtmltopdf_set_warning_callback(wkhtmltopdf_converter * converter, wkhtmltopdf_str_callback cb)
    void wkhtmltopdf_set_error_callback(wkhtmltopdf_converter * converter, wkhtmltopdf_str_callback cb)
    void wkhtmltopdf_set_phase_changed_callback(wkhtmltopdf_converter * converter, wkhtmltopdf_void_callback cb)
    void wkhtmltopdf_set_progress_changed_callback(wkhtmltopdf_converter * converter, wkhtmltopdf_int_callback cb)
    void wkhtmltopdf_set_finished_callback(wkhtmltopdf_converter * converter, wkhtmltopdf_int_callback cb)
    # void wkhtmltopdf_begin_conversion(wkhtmltopdf_converter * converter)
    # void wkhtmltopdf_cancel(wkhtmltopdf_converter * converter)
    int wkhtmltopdf_convert(wkhtmltopdf_converter * converter)
    void wkhtmltopdf_add_object(
	wkhtmltopdf_converter * converter, wkhtmltopdf_object_settings * setting, const char * data)

    int wkhtmltopdf_current_phase(wkhtmltopdf_converter * converter)
    int wkhtmltopdf_phase_count(wkhtmltopdf_converter * converter)
    const char * wkhtmltopdf_phase_description(wkhtmltopdf_converter * converter, int phase)
    const char * wkhtmltopdf_progress_string(wkhtmltopdf_converter * converter)
    int wkhtmltopdf_http_error_code(wkhtmltopdf_converter * converter)
    long wkhtmltopdf_get_output(wkhtmltopdf_converter * converter, const unsigned char **)


class WkhtmltopdfError(Exception):
    """Wraps wkhtmltopdf errors"""
    pass

# We don't really need these methods, only here for reference
# # /* Print out loading progress information */
# cdef void progress_changed(wkhtmltopdf_converter * c, int p):
#     print(p)
#
# # /* Print loading phase information */
# cdef void phase_changed(wkhtmltopdf_converter * c):
#     cdef int phase = wkhtmltopdf_current_phase(c)
#     print(wkhtmltopdf_phase_description(c, phase))


cdef void _error_callback(wkhtmltopdf_converter * c, const char * msg):
    """Handles wkhtmltopdf_converter errors"""
    raise WkhtmltopdfError(msg)


cdef void _warning_callback(wkhtmltopdf_converter * c, const char * msg):
    """Handles wkhtmltopdf_converter warnings"""
    logging.WARNING(msg)


cdef class _PDF:
    """Wraps the c library"""
    cdef wkhtmltopdf_converter *converter
    cdef wkhtmltopdf_global_settings *global_settings
    cdef wkhtmltopdf_object_settings *object_settings


    def __cinit__(self, global_settings=None, object_settings=None):
        wkhtmltopdf_init(1)
        self.global_settings = wkhtmltopdf_create_global_settings()
        self.object_settings = wkhtmltopdf_create_object_settings()

        if global_settings:
            self.set_global_settings(global_settings)
        if object_settings:
            self.set_object_settings(object_settings)

        self.converter = wkhtmltopdf_create_converter(self.global_settings)

        wkhtmltopdf_set_error_callback(self.converter, _error_callback)
        wkhtmltopdf_set_warning_callback(self.converter, _warning_callback)

    def set_global_setting(self, key, val):
        if isinstance(key, str):
            key = <unicode> key.encode("utf-8")
        if isinstance(val, str):
            val = <unicode> val.encode("utf-8")

        wkhtmltopdf_set_global_setting(self.global_settings, key, val)

    def set_object_setting(self, key, val):
        if isinstance(key, str):
            key = <unicode> key.encode("utf-8")
        if isinstance(val, str):
            val = <unicode> val.encode("utf-8")

        wkhtmltopdf_set_object_setting(self.object_settings, key, val)

    def set_global_settings(self, settings: dict):
        for k, v in settings.items():
            self.set_global_setting(k, v)

    def set_object_settings(self, settings: dict):
        for k, v in settings.items():
            self.set_object_setting(k, v)

    def clean(self):
        # TODO: free pdf pointer
        wkhtmltopdf_destroy_converter(self.converter)
        wkhtmltopdf_destroy_object_settings(self.object_settings)
        wkhtmltopdf_destroy_global_settings(self.global_settings)
        wkhtmltopdf_deinit()

    def from_url(self, page, settings: dict, output=None):
        cdef unsigned char *pdf = NULL

        if output is not None:
            self.set_global_setting('out', output)

        self.set_object_setting('page', page)
        wkhtmltopdf_add_object(self.converter, self.object_settings, NULL)
        if not wkhtmltopdf_convert(self.converter):
            raise WkhtmltopdfError("There was an error converting to PDF")

        # wkhtmltopdf_http_error_code(converter)
        if output is None:
            length = wkhtmltopdf_get_output(self.converter, &pdf)

            # Does the appropriate conversion to bytes and returns a bytes string of the right length
            # by ignoring null characters
            return pdf[:length]

    def from_string(self, data, settings: dict, output=None):
        cdef unsigned char *pdf = NULL

        if output is not None:
            self.set_global_setting('out', output)

        wkhtmltopdf_add_object(self.converter, self.object_settings, data)
        if not wkhtmltopdf_convert(self.converter):
            raise WkhtmltopdfError("There was an error converting to PDF")

            # wkhtmltopdf_http_error_code(converter)
        if output is None:
            length = wkhtmltopdf_get_output(self.converter, &pdf)

            # Does the appropriate conversion to bytes and returns a bytes string of the right length
            # by ignoring null characters
            return pdf[:length]

    def __dealloc__(self):
        self.clean()


def _pdf_process(page, settings, output, q: SimpleQueue):
    if page.startswith(b"http"):
        q.put(_PDF().from_url(page, settings, output))
    else:
        q.put(_PDF().from_string(page, settings, output))

def to_pdf(page: Union[str, bytes], settings: dict = None, output: str=None):
    # TODO: Add docstring
    q = SimpleQueue()
    if isinstance(page, str):
        page = <unicode> page.encode("utf-8")

        if isinstance(output, str):
            output = <unicode> output.encode("utf-8")

        if settings is not None:
            settings = settings.copy()
            for k, v in settings.items():
                if isinstance(v, str):
                    settings[k] = <unicode> v.encode("utf-8")
        else:
            settings = {}

        # We run the PDF generation in a subprocess so it is thread safe
        process = Process(target=_pdf_process, args=(page, settings, output, q))
        process.start()
        result = q.get()
        process.join()
        return result


