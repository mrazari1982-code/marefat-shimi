"""Run: python3 tests/deployment-safety.py. No network or database writes."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class DeploymentSafety(unittest.TestCase):
    def test_both_configs_deploy_only_public_files(self):
        for name in ('wrangler.jsonc', 'wrangler-cloudflare.jsonc'):
            with self.subTest(config=name):
                config = json.loads((ROOT / name).read_text())
                self.assertIn('assets', config, 'Workers asset configuration is required')
                asset_root = (ROOT / config['assets']['directory']).resolve()
                self.assertEqual(asset_root, ROOT / 'public', 'Never publish repository root')
                self.assertNotIn('pages_build_output_dir', config)
                self.assertTrue((asset_root / 'index.html').is_file())
                files = [p for p in asset_root.rglob('*') if p.is_file()]
                self.assertTrue(files)
                for p in files:
                    self.assertFalse(p.is_symlink())
                    relative = p.relative_to(asset_root).as_posix()
                    if p.parent == asset_root:
                        self.assertTrue(p.suffix == '.html' or p.name in {
                            'admin-nav.js', 'auto-link.js', 'student-auth.js', 'student-dashboard.js', 'student-import.js',
                            'admin-school-structure.js', 'admin-curriculum-question-bank.js',
                            'admin-curriculum-exam-builder.js', 'curriculum-ui.js', 'admin-curriculum.css'
                        }, relative)
                    else:
                        self.assertIn(relative, {
                            'vendor/exceljs-4.4.0.min.js', 'vendor/EXCELJS-LICENSE.txt',
                            'assets/curriculum-structure.svg'
                        }, relative)
    def test_required_routes_exist(self):
        for name in ('index.html', 'exam-access.html', 'exam.html', 'student-dashboard.html', 'student-result.html',
                     'student-login.html', 'admin-student-password.html',
                     'admin-student-import.html',
                     'admin-login-v2.html', 'admin-panel.html', 'admin-question-bank.html'):
            self.assertTrue((ROOT / 'public' / name).is_file(), name)

    def test_student_management_links_to_bulk_import(self):
        html = (ROOT / 'public' / 'students.html').read_text()
        self.assertIn('href="admin-student-import.html"', html)

if __name__ == '__main__':
    unittest.main()
