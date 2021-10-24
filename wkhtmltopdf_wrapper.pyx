# cython: language_level=3, c_string_type=bytes

import logging
from multiprocessing import Queue, Process
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
    # TODO: Improve code by separating into specialized methods
    # TODO: Improve speed by removing unnecessary python calls
    def to_pdf(self, page, settings: dict, output=None):
        cdef wkhtmltopdf_converter *converter
        cdef wkhtmltopdf_object_settings *object_settings
        cdef unsigned char *pdf = NULL
        cdef unsigned char *pdf_copy = NULL
        cdef unsigned char *pos = pdf
        cdef char *c_output = NULL

        wkhtmltopdf_init(1)
        global_settings = wkhtmltopdf_create_global_settings()

        if output is not None:
            c_output = output
        wkhtmltopdf_set_global_setting(global_settings, 'out', c_output)

        converter = wkhtmltopdf_create_converter(global_settings)
        object_settings = wkhtmltopdf_create_object_settings()

        wkhtmltopdf_set_object_setting(object_settings, 'page', page)
        for k, v in settings.keys():
            wkhtmltopdf_set_object_setting(object_settings, k, v)

        # We set callbacks
        # wkhtmltopdf_set_progress_changed_callback(converter, progress_changed)
        # wkhtmltopdf_set_phase_changed_callback(converter, phase_changed)
        wkhtmltopdf_set_error_callback(converter, _error_callback)
        wkhtmltopdf_set_warning_callback(converter, _warning_callback)

        try:
            wkhtmltopdf_add_object(converter, object_settings, NULL)

            if not wkhtmltopdf_convert(converter):
                raise WkhtmltopdfError("There was an error converting to PDF")

            # wkhtmltopdf_http_error_code(converter)
            if output is None:
                length = wkhtmltopdf_get_output(converter, &pdf)

                # Does the appropriate conversion to bytes and returns a bytes string of the right length
                # by ignoring null characters
                return pdf[:length]
        finally:
            # TODO: free pdf pointer
            wkhtmltopdf_destroy_converter(converter)
            wkhtmltopdf_destroy_object_settings(object_settings)
            wkhtmltopdf_destroy_global_settings(global_settings)
            wkhtmltopdf_deinit()
        return None


def _pdf_process(page, settings, output, q: Queue):
    q.put(_PDF().to_pdf(page, settings, output))


def to_pdf(page: Union[str, bytes], settings: dict = None, output: str=None):
    # TODO: Add docstring
    q = Queue()
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


