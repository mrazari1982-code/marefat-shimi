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
                    self.assertEqual(p.parent, asset_root, 'Internal directories must not be published')
                    self.assertTrue(p.suffix == '.html' or p.name in {'auto-link.js', 'student-auth.js'}, p.name)
    def test_required_routes_exist(self):
        for name in ('index.html', 'exam-access.html', 'exam.html', 'student-result.html',
                     'student-login.html', 'admin-student-password.html',
                     'admin-login-v2.html', 'admin-panel.html', 'admin-question-bank.html'):
            self.assertTrue((ROOT / 'public' / name).is_file(), name)

if __name__ == '__main__':
    unittest.main()
