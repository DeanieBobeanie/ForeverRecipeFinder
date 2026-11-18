"""Exercise release scripts against isolated miniature repositories."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'repository'
        self.root.mkdir()
        (self.root / 'tools').mkdir()
        for name in ('package.py', 'check_tag.py'):
            shutil.copyfile(Path(__file__).with_name(name), self.root / 'tools' / name)
        self.addon = self.root / 'ForeverRecipeFinder'
        self.addon.mkdir()
        self.toc = self.addon / 'ForeverRecipeFinder.toc'
        self.toc.write_text('## Version: 1.0.1-beta.1\nCore.lua\n', encoding='utf-8')
        (self.addon / 'Core.lua').write_text('local name = ...\n', encoding='utf-8')
        self.files = ['ForeverRecipeFinder/Core.lua', 'ForeverRecipeFinder/ForeverRecipeFinder.toc']
        self.write_json('release-manifest.json', {'addon': 'ForeverRecipeFinder', 'files': self.files})
        self.write_json('package.json', {'version': '1.0.1-beta.1'})
        self.write_json('package-lock.json', {
            'version': '1.0.1-beta.1', 'packages': {'': {'version': '1.0.1-beta.1'}}})

    def write_json(self, name, value):
        (self.root / name).write_text(json.dumps(value), encoding='utf-8')

    def run_script(self, name='package.py', tag=None):
        environment = os.environ.copy()
        environment.pop('RELEASE_TAG', None)
        if tag is not None:
            environment['RELEASE_TAG'] = tag
        return subprocess.run([sys.executable, str(self.root / 'tools' / name)],
                              cwd=self.root.parent, env=environment, capture_output=True, text=True)

    def assert_rejected(self, text, name='package.py', tag=None):
        result = self.run_script(name, tag)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(text, result.stderr)
        self.assertFalse((self.root / 'dist').exists())

    def test_archive_bytes_checksum_and_reproducibility(self):
        (self.root / 'private-notes.txt').write_text('Do not ship this file.', encoding='utf-8')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = self.root / 'dist' / 'ForeverRecipeFinder-1.0.1-beta.1.zip'
        first = archive.read_bytes()
        with zipfile.ZipFile(archive) as package:
            self.assertEqual(package.namelist(), sorted(self.files))
            for name in self.files:
                self.assertEqual(package.read(name), (self.root / name).read_bytes())
        expected = hashlib.sha256(first).hexdigest() + '  ' + archive.name + '\n'
        self.assertEqual((archive.parent / 'SHA256SUMS.txt').read_text(), expected)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(archive.read_bytes(), first)

    def test_unlisted_runtime_file_stops_build(self):
        (self.addon / 'saved-data.lua').write_text('private = true', encoding='utf-8')
        self.assert_rejected('Manifest does not match runtime files')

    def test_missing_toc_source_stops_build(self):
        self.toc.write_text('## Version: 1.0.1-beta.1\nMissing.lua\n', encoding='utf-8')
        self.assert_rejected('Missing TOC file: Missing.lua')

    def test_duplicate_manifest_entry_stops_build(self):
        self.write_json('release-manifest.json', {'addon': 'ForeverRecipeFinder', 'files': self.files * 2})
        self.assert_rejected('Duplicate manifest entry')

    def test_addon_folder_cannot_escape_repository(self):
        self.write_json('release-manifest.json', {'addon': '..', 'files': self.files})
        self.assert_rejected('Invalid add-on folder')

    def test_manifest_paths_must_be_canonical(self):
        for path in ('ForeverRecipeFinder/../package.json', './ForeverRecipeFinder/Core.lua',
                     'ForeverRecipeFinder//Core.lua', 'ForeverRecipeFinder\\Core.lua'):
            with self.subTest(path=path):
                self.write_json('release-manifest.json', {
                    'addon': 'ForeverRecipeFinder', 'files': self.files + [path]})
                self.assert_rejected('Invalid package path')

    def test_missing_or_duplicate_version_stops_build(self):
        for value in ('Core.lua\n', '## Version: 1.0.1-beta.1\n## Version: 1.0.0\nCore.lua\n'):
            with self.subTest(value=value):
                self.toc.write_text(value, encoding='utf-8')
                self.assert_rejected('TOC must declare exactly one version')

    def test_version_drift_stops_build_and_tag_check(self):
        for filename, value in (
                ('package.json', {'version': '1.0.0-beta.1'}),
                ('package-lock.json', {'version': '1.0.0-beta.1',
                                       'packages': {'': {'version': '1.0.1-beta.1'}}}),
                ('package-lock.json', {'version': '1.0.1-beta.1',
                                       'packages': {'': {'version': '1.0.0-beta.1'}}})):
            with self.subTest(filename=filename, value=value):
                before = (self.root / filename).read_bytes()
                self.write_json(filename, value)
                self.assert_rejected('Package and lockfile versions must match the TOC version')
                self.assert_rejected('Package and lockfile versions must match the TOC version',
                                     'check_tag.py', 'v1.0.1-beta.1')
                (self.root / filename).write_bytes(before)

    def test_release_tag_check_works_outside_repository(self):
        result = self.run_script('check_tag.py', 'v1.0.1-beta.1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_rejected('Release tag does not match TOC version', 'check_tag.py', 'v1.0.0-beta.1')
        self.assert_rejected('Release tag does not match TOC version', 'check_tag.py')


if __name__ == '__main__':
    unittest.main()
