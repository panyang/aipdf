"""Installer behavior tests use isolated synthetic app bundles, never /Applications."""
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import install


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="aipdf-install-test-")
        self.root = Path(self.temp.name)
        self.applications = self.root / "Applications with spaces"
        self.applications.mkdir()
        self.target = self.applications / "AIPDF.app"
        self.source = self.root / "source with spaces/AIPDF.app"
        self.make_app(self.source, "new")

    def tearDown(self):
        self.temp.cleanup()

    def make_app(self, path, text, identifier=install.APP_ID):
        (path / "Contents").mkdir(parents=True)
        (path / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identifier, "AIPDFRuntimeID": "py3-14-test"}))
        (path / "Contents/data").write_text(text)

    def test_new_install(self):
        self.assertIsNone(install.deploy_app(self.source, self.target))
        self.assertEqual((self.target / "Contents/data").read_text(), "new")
        self.assertTrue(self.source.exists())

    def test_upgrade_keeps_backup(self):
        self.make_app(self.target, "old")
        backup = install.deploy_app(self.source, self.target)
        self.assertEqual((backup / "Contents/data").read_text(), "old")
        self.assertEqual((self.target / "Contents/data").read_text(), "new")

    def test_failed_verification_preserves_old_app(self):
        self.make_app(self.target, "old")
        def reject(_):
            raise RuntimeError("Invalid signature")
        with self.assertRaisesRegex(RuntimeError, "Invalid signature"):
            install.deploy_app(self.source, self.target, reject)
        self.assertEqual((self.target / "Contents/data").read_text(), "old")

    def test_failed_replacement_rolls_back(self):
        self.make_app(self.target, "old")
        rename = Path.rename
        def fail_staged_move(path, destination):
            if path.parent.name.startswith(".aipdf-install-"):
                raise OSError("Simulated disk error")
            return rename(path, destination)
        with patch.object(Path, "rename", fail_staged_move):
            with self.assertRaisesRegex(OSError, "Simulated disk error"):
                install.deploy_app(self.source, self.target)
        self.assertEqual((self.target / "Contents/data").read_text(), "old")

    def test_unrelated_app_is_not_overwritten(self):
        self.make_app(self.target, "unrelated", "other.application")
        with self.assertRaisesRegex(RuntimeError, "其他应用"):
            install.deploy_app(self.source, self.target)
        self.assertEqual((self.target / "Contents/data").read_text(), "unrelated")

    def test_symlink_target_is_not_followed(self):
        self.target.symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "符号链接"):
            install.deploy_app(self.source, self.target)
        self.assertEqual((self.source / "Contents/data").read_text(), "new")

    def test_runtime_changes_when_python_or_lock_changes(self):
        a = install.runtime_identity(b"lock1", "/python/old", "3.14.6", "arm64")
        self.assertEqual(a, install.runtime_identity(b"lock1", "/python/old", "3.14.6", "arm64"))
        self.assertNotEqual(a, install.runtime_identity(b"lock2", "/python/old", "3.14.6", "arm64"))
        self.assertNotEqual(a, install.runtime_identity(b"lock1", "/python/new", "3.14.7", "arm64"))
        self.assertNotIn("/", a)

    def test_incomplete_runtime_is_not_reused(self):
        runtime = self.root / "runtime"
        runtime.mkdir()
        self.assertFalse(install.runtime_is_ready(runtime, {"version": 1}))
        (runtime / "aipdf-runtime.json").write_text(json.dumps({"version": 1}))
        self.assertFalse(install.runtime_is_ready(runtime, {"version": 1}))

    def test_bundle_cannot_reference_source_or_escape_runtime(self):
        with patch.object(install, "run"):
            install.verify_bundle(self.source)
            for value in [{"AIPDFRuntimeID": "../escape"}, {"AIPDFRuntimeID": "py3", "AIPDFProjectPath": "/source"}]:
                value["CFBundleIdentifier"] = install.APP_ID
                (self.source / "Contents/Info.plist").write_bytes(plistlib.dumps(value))
                with self.assertRaises(RuntimeError):
                    install.verify_bundle(self.source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
