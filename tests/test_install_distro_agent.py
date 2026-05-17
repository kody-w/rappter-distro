"""Tests for install_distro_agent.py.

Stdlib unittest, no network unless RAPPTER_TEST_NETWORK=1.

The agent's install_distro() accepts three test override paths:
  - source_dir         → walk a local checkout (skips manifest+fetch).
  - manifest + fetcher → exercise the manifest pipeline with no network.
  - fetcher only       → fetcher gets called for MANIFEST.json too.
We use all three to cover the production code paths hermetically.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
import unittest

# Make the agent importable.
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(_REPO_ROOT, "agents"))

import install_distro_agent as agent  # noqa: E402


# ── Fixtures ─────────────────────────────────────────────────────────────

def _make_stub_brainstem(home: str, version: str = "0.12.2") -> None:
    """Create the minimum file set the kernel-present check needs."""
    os.makedirs(home, exist_ok=True)
    with open(os.path.join(home, "brainstem.py"), "w") as f:
        f.write("# stub kernel for tests\n")
    with open(os.path.join(home, "VERSION"), "w") as f:
        f.write(version + "\n")
    os.makedirs(os.path.join(home, "agents"), exist_ok=True)
    with open(os.path.join(home, "agents", "basic_agent.py"), "w") as f:
        f.write("class BasicAgent: pass\n")


def _checkout_fetcher(src_root: str):
    """Returns a fetcher callable that reads `src` from a local checkout
    (also handles MANIFEST.json if present)."""
    def fetch(src: str) -> bytes:
        with open(os.path.join(src_root, src), "rb") as f:
            return f.read()
    return fetch


# ── Tests ────────────────────────────────────────────────────────────────

class AgentMetadataTests(unittest.TestCase):
    def test_class_metadata_shape(self):
        # The kernel reads class-level attrs (the BasicAgent shim's __init__
        # clobbers instance.name with the literal "BasicAgent"; the real
        # kernel BasicAgent doesn't do that). Test what the kernel sees.
        self.assertEqual(agent.InstallDistroAgent.name, "install_rappter_distro")
        meta = agent.InstallDistroAgent.metadata
        self.assertEqual(meta["name"], "install_rappter_distro")
        self.assertIn("description", meta)
        props = meta["parameters"]["properties"]
        self.assertEqual(
            set(props["action"]["enum"]),
            {"check", "status", "dry-run", "install"},
        )

    def test_perform_unknown_action(self):
        a = agent.InstallDistroAgent()
        result = json.loads(a.perform(action="nonsense"))
        self.assertFalse(result["ok"])
        self.assertIn("nonsense", result["error"])

    def test_perform_install_without_confirm_returns_preview(self):
        # Without confirm, install refuses and returns a dry-run preview.
        # We don't care that the preview itself fails (no network) — we
        # care that the confirm gate caught the request first.
        a = agent.InstallDistroAgent()
        with tempfile.TemporaryDirectory() as home:
            os.environ["BRAINSTEM_HOME"] = home
            try:
                result = json.loads(a.perform(action="install", confirm=False))
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "confirmation required")
        self.assertIn("preview", result)


class CheckAndStatusTests(unittest.TestCase):
    def test_check_with_no_kernel(self):
        with tempfile.TemporaryDirectory() as home:
            os.environ["BRAINSTEM_HOME"] = home
            try:
                result = agent.check()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
        self.assertFalse(result["ok"])
        self.assertIn("no grail brainstem", result["note"])
        self.assertIn("raw.githubusercontent.com", result["manifest_url"])
        self.assertTrue(result["manifest_url"].endswith("/MANIFEST.json"))

    def test_check_with_kernel(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home, version="0.12.2")
            os.environ["BRAINSTEM_HOME"] = home
            try:
                result = agent.check()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
        self.assertTrue(result["ok"])
        self.assertEqual(result["kernel_version"], "0.12.2")

    def test_status_reports_uninstalled(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            os.environ["BRAINSTEM_HOME"] = home
            try:
                result = agent.status()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
        self.assertTrue(result["checks"]["kernel_present"])
        self.assertFalse(result["checks"]["distro_installed"])
        self.assertFalse(result["checks"]["boot_py"])


class ManifestBuilderTests(unittest.TestCase):
    def test_build_manifest_against_repo_checkout(self):
        m = agent.build_manifest(_REPO_ROOT, branch="main")
        self.assertEqual(m["schema"], agent.MANIFEST_SCHEMA)
        self.assertEqual(m["repo"], agent.DISTRO_REPO)
        self.assertEqual(m["branch"], "main")
        self.assertIsInstance(m["files"], list)
        self.assertGreater(len(m["files"]), 5)
        # Spot-check expected entries: bond, organs/estate, ui/index, etc.
        dsts = {e["dst"] for e in m["files"]}
        self.assertIn("utils/bond.py", dsts)
        self.assertIn("utils/boot.py", dsts)
        self.assertIn("utils/organs/estate_organ.py", dsts)
        self.assertIn("utils/senses/voice_sense.py", dsts)
        self.assertIn("index.html", dsts)
        # sha256 fields look like sha256 hex
        for e in m["files"]:
            self.assertEqual(len(e["sha256"]), 64)
            int(e["sha256"], 16)  # raises if not hex

    def test_built_manifest_is_stable_when_recomputed(self):
        m1 = agent.build_manifest(_REPO_ROOT)
        m2 = agent.build_manifest(_REPO_ROOT)
        self.assertEqual(m1, m2)


class ManifestValidatorTests(unittest.TestCase):
    def _good(self):
        return {
            "schema": agent.MANIFEST_SCHEMA,
            "repo": "x/y",
            "branch": "main",
            "files": [{"src": "a.py", "dst": "utils/a.py", "sha256": "00" * 32}],
        }

    def test_accepts_good_manifest(self):
        agent._validate_manifest(self._good())  # no raise

    def test_rejects_bad_schema(self):
        m = self._good()
        m["schema"] = "wrong"
        with self.assertRaises(ValueError):
            agent._validate_manifest(m)

    def test_rejects_empty_files(self):
        m = self._good()
        m["files"] = []
        with self.assertRaises(ValueError):
            agent._validate_manifest(m)

    def test_rejects_traversal_dst(self):
        m = self._good()
        m["files"][0]["dst"] = "../etc/passwd"
        with self.assertRaises(ValueError):
            agent._validate_manifest(m)

    def test_rejects_absolute_dst(self):
        m = self._good()
        m["files"][0]["dst"] = "/etc/passwd"
        with self.assertRaises(ValueError):
            agent._validate_manifest(m)

    def test_refuses_sacred_dst(self):
        m = self._good()
        m["files"][0]["dst"] = "brainstem.py"
        with self.assertRaises(PermissionError):
            agent._validate_manifest(m)


class InstallNoKernelTests(unittest.TestCase):
    def test_refuses_install_when_no_brainstem(self):
        with tempfile.TemporaryDirectory() as home:
            # No stub kernel
            result = agent.install_distro(
                brainstem_home=home,
                source_dir=_REPO_ROOT,
                dry_run=False,
            )
        self.assertFalse(result["ok"])
        self.assertIn("no grail brainstem", result["error"])


class InstallFromDirTests(unittest.TestCase):
    """Exercise the source_dir path — fast, hermetic."""

    def test_dry_run_writes_nothing_but_returns_manifest(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                source_dir=_REPO_ROOT,
                dry_run=True,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["action"], "dry-run")
            self.assertEqual(result["source"], "dir")
            self.assertGreater(result["files_installed"], 0)
            for entry in result["manifest"]:
                self.assertEqual(entry["action"], "would-install")
                self.assertFalse(
                    os.path.exists(os.path.join(home, entry["dst"])),
                    f"dry-run wrote {entry['dst']}",
                )
            self.assertFalse(os.path.isfile(os.path.join(home, "utils", "boot.py")))

    def test_install_lays_down_expected_files(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                source_dir=_REPO_ROOT,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["action"], "install")
            self.assertGreater(result["files_installed"], 0)

            # Spot-check destinations the LAYOUT promises.
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "boot.py")))
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "bond.py")))
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "organs", "estate_organ.py")))
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "senses", "voice_sense.py")))
            self.assertTrue(os.path.isfile(os.path.join(home, "index.html")))
            self.assertTrue(os.path.isdir(os.path.join(home, "agents", "@rappter")))

            # Summary has the right shape
            self.assertEqual(result["summary"].get("installed", 0), result["files_installed"])

    def test_install_idempotent(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            r1 = agent.install_distro(brainstem_home=home, source_dir=_REPO_ROOT, dry_run=False)
            r2 = agent.install_distro(brainstem_home=home, source_dir=_REPO_ROOT, dry_run=False)
            self.assertTrue(r1["ok"] and r2["ok"])
            self.assertEqual(r1["files_installed"], r2["files_installed"])
            actions2 = {e["action"] for e in r2["manifest"]}
            self.assertEqual(actions2, {"overwrote"})

    def test_install_never_touches_sacred_files(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home, version="sentinel-0.0.0")
            ba_path = os.path.join(home, "agents", "basic_agent.py")
            sentinel = "# SENTINEL — must not be overwritten\nclass BasicAgent: pass\n"
            with open(ba_path, "w") as f:
                f.write(sentinel)

            result = agent.install_distro(
                brainstem_home=home,
                source_dir=_REPO_ROOT,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))

            with open(os.path.join(home, "brainstem.py")) as f:
                self.assertIn("stub kernel for tests", f.read())
            with open(os.path.join(home, "VERSION")) as f:
                self.assertEqual(f.read().strip(), "sentinel-0.0.0")
            with open(ba_path) as f:
                self.assertEqual(f.read(), sentinel)

            for entry in result["manifest"]:
                self.assertNotIn(entry["dst"], agent.SACRED_PATHS)

    def test_install_then_status_flips_to_installed(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            agent.install_distro(brainstem_home=home, source_dir=_REPO_ROOT, dry_run=False)
            os.environ["BRAINSTEM_HOME"] = home
            try:
                s = agent.status()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
        checks = s["checks"]
        self.assertTrue(checks["boot_py"])
        self.assertTrue(checks["organs_dir"])
        self.assertTrue(checks["senses_dir"])
        self.assertTrue(checks["rich_ui"])
        self.assertGreater(checks["organ_count"], 0)
        self.assertGreater(checks["sense_count"], 0)
        self.assertTrue(checks["distro_installed"])


class InstallViaManifestPipelineTests(unittest.TestCase):
    """Exercise the manifest-driven pipeline with an injected fetcher.
    This is the path the production network code takes; we just substitute
    a checkout-local fetcher for raw.githubusercontent.com."""

    def setUp(self):
        # Build the manifest once against the live checkout — represents
        # what would normally live as MANIFEST.json in the repo.
        self.manifest = agent.build_manifest(_REPO_ROOT)
        self.fetcher = _checkout_fetcher(_REPO_ROOT)

    def test_apply_via_manifest_and_fetcher(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                manifest=self.manifest,
                fetcher=self.fetcher,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["source"], "injected")
            # Spot-check
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "boot.py")))
            self.assertTrue(os.path.isfile(os.path.join(home, "index.html")))

    def test_fetcher_path_pulls_manifest_when_not_provided(self):
        """When only a fetcher is given, the agent fetches MANIFEST.json
        through it. Simulates the network path 1:1."""
        manifest_bytes = json.dumps(self.manifest).encode("utf-8")

        def fetch(src: str) -> bytes:
            if src == "MANIFEST.json":
                return manifest_bytes
            return self.fetcher(src)

        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                fetcher=fetch,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["source"], "injected")
            self.assertTrue(os.path.isfile(os.path.join(home, "utils", "boot.py")))

    def test_sha_mismatch_aborts_that_file(self):
        """If the fetched bytes don't match the manifest sha, that entry is
        flagged 'sha-mismatch' and overall result is not ok."""
        bad_manifest = json.loads(json.dumps(self.manifest))  # deep copy
        # Corrupt the recorded sha of one entry.
        bad_manifest["files"][0]["sha256"] = "00" * 32

        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                manifest=bad_manifest,
                fetcher=self.fetcher,
                dry_run=False,
            )
            self.assertFalse(result["ok"])
            mismatches = [e for e in result["manifest"] if e["action"] == "sha-mismatch"]
            self.assertEqual(len(mismatches), 1)

    def test_fetch_failure_is_reported_per_entry(self):
        def broken_fetcher(src: str) -> bytes:
            raise RuntimeError(f"simulated fetch failure for {src}")

        # We pass the manifest directly so MANIFEST.json itself isn't fetched.
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                manifest=self.manifest,
                fetcher=broken_fetcher,
                dry_run=False,
            )
            self.assertFalse(result["ok"])
            failures = [e for e in result["manifest"] if e["action"] == "fetch-failed"]
            self.assertEqual(len(failures), len(self.manifest["files"]))

    def test_invalid_manifest_json_via_fetcher(self):
        def fetch(src: str) -> bytes:
            if src == "MANIFEST.json":
                return b"not valid json {{{"
            raise AssertionError("shouldn't fetch any other path")

        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                fetcher=fetch,
                dry_run=False,
            )
        self.assertFalse(result["ok"])
        self.assertIn("MANIFEST.json", result["error"])


class RawUrlShapeTests(unittest.TestCase):
    def test_raw_url_shape(self):
        u = agent._raw_url("kody-w/rappter-distro", "main", "lib/bond.py")
        self.assertEqual(
            u,
            "https://raw.githubusercontent.com/kody-w/rappter-distro/main/lib/bond.py",
        )


@unittest.skipUnless(
    os.environ.get("RAPPTER_TEST_NETWORK") == "1",
    "set RAPPTER_TEST_NETWORK=1 to run the network-dependent test",
)
class NetworkInstallTest(unittest.TestCase):
    """Optional: exercises the actual raw.githubusercontent.com fetch path.
    Requires MANIFEST.json to already be committed at the branch HEAD."""

    def test_network_dry_run(self):
        with tempfile.TemporaryDirectory() as home:
            _make_stub_brainstem(home)
            result = agent.install_distro(
                brainstem_home=home,
                branch="main",
                dry_run=True,
            )
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(result["source"], "network")
        self.assertGreater(result["files_installed"], 0)


if __name__ == "__main__":
    unittest.main()
