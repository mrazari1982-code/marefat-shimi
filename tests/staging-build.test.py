import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('staging_build', ROOT / 'staging/build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)

class StagingBuildTests(unittest.TestCase):
    def test_every_page_is_isolated_and_source_is_unchanged(self):
        original = {p.name: p.read_bytes() for p in ROOT.glob('*.html')}
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / 'site'
            build.build(ROOT, out)
            self.assertEqual(set(original), {p.name for p in out.glob('*.html')})
            for p in out.glob('*.html'):
                text = p.read_text()
                self.assertNotIn(build.PRODUCTION_REF, text)
                self.assertNotIn(build.PRODUCTION_KEY, text)
                self.assertIn('Content-Security-Policy', text)
                self.assertIn('محیط آزمایشی', text)
            self.assertFalse((out / 'schema-baseline.sql').exists())
            self.assertFalse((out / 'tests').exists())
        self.assertEqual(original, {p.name: p.read_bytes() for p in ROOT.glob('*.html')})

    def test_rejects_unknown_backend_before_writing(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / 'src'
            root.mkdir()
            (root / 'index.html').write_text('<head></head><body>https://unexpected.supabase.co</body>')
            out = Path(d) / 'out'
            with self.assertRaises(ValueError):
                build.build(root, out)
            self.assertFalse(out.exists())

    def test_rejects_source_as_output(self):
        with self.assertRaises(ValueError):
            build.build(ROOT, ROOT)

if __name__ == '__main__':
    unittest.main()
