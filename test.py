import threading
from unittest import TestCase

from wkhtmltopdf_wrapper import to_pdf


class TestToPDF(TestCase):
    def test_multiple_calls(self):
        """
        Ensures to_pdf can be called multiple times
        """
        pdf_1 = to_pdf("https://google.com", None, None)
        pdf_2 = to_pdf("https://google.com", None, None)

        self.assertIsNotNone(pdf_1)
        self.assertIsNotNone(pdf_2)

    def test_thread_calls(self):
        """
        Ensures to_pdf can be called in threads
        """
        result = []

        def func1():
            result.append(to_pdf("https://google.com", None, None))

        def func2():
            result.append(to_pdf("https://google.com", None, None))

        thread1 = threading.Thread(target=func1)
        thread2 = threading.Thread(target=func2)
        thread1.start()
        thread2.start()
        # No timeout as it fails in some systems
        # Like when running in wsl with `xvfb-run python -m unittest test`
        thread1.join()
        thread2.join()
        self.assertEqual(len(result), 2)

    def test_raw_html(self):
        data = """
        <!DOCTYPE html>
        <html>
            <body>
            <h1>Sample PDF</h1>
            <p>Sample content</p>
            </body>
        </html>
        """
        pdf = to_pdf(data, None, None)

        self.assertIsNotNone(pdf)
