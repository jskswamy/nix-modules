"""Exercise the actual Home Manager hook and wrapper, never the live gateway."""

import concurrent.futures
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SessionKeyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "-f", "tests/agentgateway-runtime.nix"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        cls.runtime = json.loads(result.stdout)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.state = self.root / ".local/state/agentgateway"

    def run_key(self, directory=None, dry_run=False):
        env = os.environ.copy()
        env.pop("DRY_RUN", None)
        if dry_run:
            env["DRY_RUN"] = ""
        script = self.runtime["data"].replace("/home/t", str(self.root))
        if directory:
            script = script.replace(str(self.state), str(directory))
        return subprocess.run(
            ["bash", "-e", "-c", script], env=env,
            capture_output=True,
            text=True,
        )

    def launch(self):
        script = self.runtime["wrapper"].replace("/home/t", str(self.root))
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True)

    def test_hook_is_ordered_before_launchd(self):
        self.assertIn("writeBoundary", self.runtime["after"])
        self.assertIn("setupLaunchAgents", self.runtime["before"])

    def test_dry_run_creates_no_state(self):
        result = self.run_key(dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.state.exists())

    def test_wrapper_requires_activation_and_never_generates_state(self):
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertFalse(self.state.exists())

    def test_creates_private_key_and_reuses_it(self):
        first = self.run_key()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(first.stdout, "")
        key = self.state / "session.key"
        self.assertTrue(key.exists(), "activation must create the machine-local key")
        original = key.read_text()
        self.assertRegex(original, r"^[0-9a-f]{64}\n$")
        self.assertEqual(self.run_key().returncode, 0)
        self.assertEqual(key.read_text(), original)
        launched = self.launch()
        self.assertEqual(launched.returncode, 0, launched.stderr)
        self.assertEqual(launched.stdout, "gateway-started\n")
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.state / "session.key").stat().st_mode), 0o600)

    def test_different_machines_get_different_keys(self):
        first = self.run_key()
        other = self.run_key(self.root / "other-machine")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(other.returncode, 0, other.stderr)
        self.assertTrue((self.state / "session.key").exists())
        self.assertNotEqual((self.state / "session.key").read_text(), (self.root / "other-machine/session.key").read_text())

    def test_corrupt_key_fails_without_replacing_or_printing_it(self):
        self.state.mkdir(parents=True)
        key = self.state / "session.key"
        key.write_text("invalid-private-state")
        result = self.run_key()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("invalid-private-state", result.stderr)
        self.assertEqual(key.read_text(), "invalid-private-state")
        self.assertNotEqual(self.launch().returncode, 0)

    def test_symlink_key_is_rejected_without_changing_target(self):
        self.state.mkdir(parents=True)
        target = self.root / "target"
        target.write_text("a" * 64 + "\n")
        os.chmod(target, 0o644)
        (self.state / "session.key").symlink_to(target)
        result = self.run_key()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o644)

    def test_symlink_directory_is_rejected(self):
        target = self.root / "target"
        target.mkdir()
        self.state.parent.mkdir(parents=True)
        self.state.symlink_to(target, target_is_directory=True)
        result = self.run_key()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(target.iterdir()), [])

    def test_concurrent_activations_use_one_complete_key(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.run_key(), range(8)))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.state / "session.key").exists())
        self.assertRegex((self.state / "session.key").read_text(), r"^[0-9a-f]{64}\n$")
        self.assertEqual(sorted(p.name for p in self.state.iterdir()), ["session.key"])


if __name__ == "__main__":
    unittest.main()
