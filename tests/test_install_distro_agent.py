"""Tests for install_distro_agent.py.

Stdlib unittest, no network unless RAPPTER_TEST_NETWORK=1.

The agent now does a two-phase hatch:
  1. Discover the kernel under source_home and copy it into target_home.
  2. Lay the distro at target_home from a manifest.

Tests check both phases independently and end-to-end. install_distro()
accepts source_dir/manifest/fetcher overrides so the distro-lay phase
stays hermetic.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(_REPO_ROOT, "agents"))

import install_distro_agent as agent  # noqa: E402


# ── Fixtures ─────────────────────────────────────────────────────────────

def _make_flat_kernel(home: str, version: str = "0.12.2") -> None:
    """A kernel src laid out flat: brainstem.py, VERSION, agents/basic_agent.py
    all directly under `home`. (One of the two layouts the agent supports.)"""
    os.makedirs(home, exist_ok=True)
    with open(os.path.join(home, "brainstem.py"), "w") as f:
        f.write("# stub kernel for tests\n")
    with open(os.path.join(home, "VERSION"), "w") as f:
        f.write(version + "\n")
    os.makedirs(os.path.join(home, "agents"), exist_ok=True)
    with open(os.path.join(home, "agents", "basic_agent.py"), "w") as f:
        f.write("class BasicAgent: pass\n")
    with open(os.path.join(home, "soul.md"), "w") as f:
        f.write("# Stub soul\n")


def _make_nested_kernel(home: str, version: str = "0.6.0") -> str:
    """A kernel src laid out the way rapp-installer actually produces it:
    src/rapp_brainstem/brainstem.py under `home`. Returns the kernel src dir."""
    kernel_src = os.path.join(home, "src", "rapp_brainstem")
    os.makedirs(kernel_src, exist_ok=True)
    with open(os.path.join(kernel_src, "brainstem.py"), "w") as f:
        f.write("# nested stub kernel\n")
    with open(os.path.join(kernel_src, "VERSION"), "w") as f:
        f.write(version + "\n")
    os.makedirs(os.path.join(kernel_src, "agents"), exist_ok=True)
    with open(os.path.join(kernel_src, "agents", "basic_agent.py"), "w") as f:
        f.write("class BasicAgent: pass\n")
    # Also put some runtime junk at the install root to confirm we don't copy it.
    with open(os.path.join(home, "brainstem.log"), "w") as f:
        f.write("runtime garbage\n")
    return kernel_src


def _checkout_fetcher(src_root: str):
    def fetch(src: str) -> bytes:
        with open(os.path.join(src_root, src), "rb") as f:
            return f.read()
    return fetch


# ── Tests ────────────────────────────────────────────────────────────────

class AgentMetadataTests(unittest.TestCase):
    def test_class_metadata_shape(self):
        self.assertEqual(agent.InstallDistroAgent.name, "install_rappter_distro")
        meta = agent.InstallDistroAgent.metadata
        self.assertEqual(meta["name"], "install_rappter_distro")
        self.assertIn("description", meta)
        props = meta["parameters"]["properties"]
        self.assertEqual(
            set(props["action"]["enum"]),
            {"check", "status", "dry-run", "hatch"},
        )
        # New fields the hatch model exposes
        self.assertIn("source_home", props)
        self.assertIn("target_home", props)

    def test_rar_manifest_shape(self):
        m = agent.__manifest__
        self.assertEqual(m["schema"], "rapp-agent/1.0")
        self.assertEqual(m["name"], "@kody/install_rappter_distro")
        # No dashes anywhere in the slug — RAR enforces snake_case.
        self.assertNotIn("-", m["name"])
        self.assertEqual(m["category"], "pipeline")
        self.assertIn("@rapp/basic_agent", m["dependencies"])

    def test_perform_unknown_action(self):
        a = agent.InstallDistroAgent()
        result = json.loads(a.perform(action="nonsense"))
        self.assertFalse(result["ok"])
        self.assertIn("nonsense", result["error"])

    def test_perform_hatch_without_confirm_returns_preview(self):
        a = agent.InstallDistroAgent()
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            result = json.loads(a.perform(
                action="hatch", confirm=False,
                source_home=src_home, target_home=tgt_home,
            ))
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "confirmation required")
        self.assertIn("preview", result)


class KernelDiscoveryTests(unittest.TestCase):
    def test_discover_flat_layout(self):
        with tempfile.TemporaryDirectory() as home:
            _make_flat_kernel(home)
            self.assertEqual(agent._discover_kernel_src(home), home)

    def test_discover_nested_layout(self):
        with tempfile.TemporaryDirectory() as home:
            kernel_src = _make_nested_kernel(home)
            found = agent._discover_kernel_src(home)
            self.assertEqual(found, kernel_src)
            self.assertNotEqual(found, home)

    def test_discover_missing(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertIsNone(agent._discover_kernel_src(home))


class CheckTests(unittest.TestCase):
    def test_check_with_no_kernel(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            os.environ["BRAINSTEM_HOME"] = src_home
            os.environ["RAPPTER_HOME"] = tgt_home
            try:
                result = agent.check()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
                os.environ.pop("RAPPTER_HOME", None)
        self.assertFalse(result["ok"])
        self.assertIn("no grail brainstem", result["note"])
        self.assertIsNone(result["kernel_src"])

    def test_check_with_flat_kernel(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home, version="0.12.2")
            os.environ["BRAINSTEM_HOME"] = src_home
            os.environ["RAPPTER_HOME"] = tgt_home
            try:
                result = agent.check()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
                os.environ.pop("RAPPTER_HOME", None)
        self.assertTrue(result["ok"])
        self.assertEqual(result["kernel_version"], "0.12.2")
        self.assertEqual(result["kernel_src"], src_home)
        self.assertEqual(result["target_home"], tgt_home)


class KernelCopyTests(unittest.TestCase):
    def test_copy_flat_layout_to_target(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent._copy_kernel_to_target(src_home, tgt_home, dry_run=False)
            # Every file in the source tree (minus skipped) lands in target.
            self.assertGreater(len(result), 0)
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "brainstem.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "VERSION")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "agents", "basic_agent.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "soul.md")))

    def test_copy_skips_runtime_and_caches(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            # Add things that MUST NOT be copied
            os.makedirs(os.path.join(src_home, "__pycache__"))
            with open(os.path.join(src_home, "__pycache__", "x.pyc"), "w") as f:
                f.write("BYTECODE")
            with open(os.path.join(src_home, ".copilot_token"), "w") as f:
                f.write("SECRET")
            with open(os.path.join(src_home, "brainstem.py.pyc"), "w") as f:
                f.write("BAD")
            with open(os.path.join(src_home, "rappid.json"), "w") as f:
                f.write('{"rappid": "DO-NOT-COPY"}')
            agent._copy_kernel_to_target(src_home, tgt_home, dry_run=False)
            self.assertFalse(os.path.exists(os.path.join(tgt_home, "__pycache__")))
            self.assertFalse(os.path.exists(os.path.join(tgt_home, ".copilot_token")))
            self.assertFalse(os.path.exists(os.path.join(tgt_home, "brainstem.py.pyc")))
            self.assertFalse(os.path.exists(os.path.join(tgt_home, "rappid.json")),
                             "must not carry the source's identity into the new organism")

    def test_dry_run_copies_nothing(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent._copy_kernel_to_target(src_home, tgt_home, dry_run=True)
            self.assertGreater(len(result), 0)
            for e in result:
                self.assertEqual(e["action"], "would-copy")
            self.assertFalse(os.path.exists(os.path.join(tgt_home, "brainstem.py")))


class InstallNoKernelTests(unittest.TestCase):
    def test_refuses_hatch_when_no_brainstem(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            # No stub kernel at src_home
            result = agent.install_distro(
                source_home=src_home,
                target_home=tgt_home,
                source_dir=_REPO_ROOT,
                dry_run=False,
            )
        self.assertFalse(result["ok"])
        self.assertIn("no grail brainstem", result["error"])


class HatchFromDirTests(unittest.TestCase):
    """End-to-end hatch via source_dir override. Both phases run."""

    def test_dry_run_writes_nothing_at_target(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent.install_distro(
                source_home=src_home,
                target_home=tgt_home,
                source_dir=_REPO_ROOT,
                dry_run=True,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["action"], "dry-run")
            self.assertGreater(result["distro_files_installed"], 0)
            self.assertGreater(result["kernel_files_copied"], 0)
            # Nothing physically landed at target_home
            self.assertFalse(os.path.isfile(os.path.join(tgt_home, "brainstem.py")))
            self.assertFalse(os.path.isfile(os.path.join(tgt_home, "utils", "boot.py")))
            for e in result["distro_manifest"]:
                self.assertEqual(e["action"], "would-install")
            for e in result["kernel_copy_manifest"]:
                self.assertEqual(e["action"], "would-copy")

    def test_hatch_lays_kernel_and_distro_at_target(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home, version="0.12.2")
            result = agent.install_distro(
                source_home=src_home,
                target_home=tgt_home,
                source_dir=_REPO_ROOT,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["action"], "hatch")
            self.assertEqual(result["kernel_version"], "0.12.2")
            # Kernel files copied to target
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "brainstem.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "VERSION")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "agents", "basic_agent.py")))
            # Distro files laid at target
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "utils", "boot.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "utils", "bond.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "utils", "organs", "estate_organ.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "utils", "senses", "voice_sense.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "index.html")))
            self.assertTrue(os.path.isdir(os.path.join(tgt_home, "agents", "@rappter")))
            # post_install hint points into target
            self.assertIn(tgt_home, result["post_install"])

    def test_hatch_does_not_mutate_source(self):
        """The whole point of side-by-side: source_home must be identical
        before and after hatch."""
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home, version="0.12.2")

            def _snapshot(root: str) -> dict:
                snap = {}
                for dp, _, fns in os.walk(root):
                    for f in fns:
                        p = os.path.join(dp, f)
                        with open(p, "rb") as fh:
                            snap[os.path.relpath(p, root)] = fh.read()
                return snap

            before = _snapshot(src_home)
            agent.install_distro(
                source_home=src_home, target_home=tgt_home,
                source_dir=_REPO_ROOT, dry_run=False,
            )
            after = _snapshot(src_home)
            self.assertEqual(before, after, "source_home was modified")

    def test_hatch_idempotent(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            r1 = agent.install_distro(source_home=src_home, target_home=tgt_home,
                                      source_dir=_REPO_ROOT, dry_run=False)
            r2 = agent.install_distro(source_home=src_home, target_home=tgt_home,
                                      source_dir=_REPO_ROOT, dry_run=False)
            self.assertTrue(r1["ok"] and r2["ok"])
            self.assertEqual(r1["distro_files_installed"], r2["distro_files_installed"])
            # Re-hatch should report every distro file as overwritten now.
            distro_actions = {e["action"] for e in r2["distro_manifest"]}
            self.assertEqual(distro_actions, {"overwrote"})

    def test_hatch_works_against_nested_kernel(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            kernel_src = _make_nested_kernel(src_home, version="0.6.0")
            result = agent.install_distro(
                source_home=src_home, target_home=tgt_home,
                source_dir=_REPO_ROOT, dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["kernel_src"], kernel_src)
            self.assertEqual(result["kernel_version"], "0.6.0")
            # The nested kernel's files land at target's TOP LEVEL (boot.py
            # expects flat layout).
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "brainstem.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "agents", "basic_agent.py")))
            # Runtime junk at the install root is NOT copied.
            self.assertFalse(os.path.exists(os.path.join(tgt_home, "brainstem.log")))


class StatusTests(unittest.TestCase):
    def test_status_reports_both_homes(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            # Run a real hatch first
            agent.install_distro(source_home=src_home, target_home=tgt_home,
                                 source_dir=_REPO_ROOT, dry_run=False)

            os.environ["BRAINSTEM_HOME"] = src_home
            os.environ["RAPPTER_HOME"] = tgt_home
            try:
                s = agent.status()
            finally:
                os.environ.pop("BRAINSTEM_HOME", None)
                os.environ.pop("RAPPTER_HOME", None)

        # Source has a kernel but NO distro (pristine).
        self.assertTrue(s["source_checks"]["kernel_present"])
        self.assertFalse(s["source_checks"]["distro_installed"])
        # Target has both.
        self.assertTrue(s["target_checks"]["kernel_present"])
        self.assertTrue(s["target_checks"]["distro_installed"])
        self.assertTrue(s["target_checks"]["rich_ui"])
        self.assertGreater(s["target_checks"]["organ_count"], 0)


class HatchViaManifestPipelineTests(unittest.TestCase):
    """Exercise the manifest pipeline (production network path) with a
    test-supplied fetcher rather than real network calls."""

    def setUp(self):
        self.manifest = agent.build_manifest(_REPO_ROOT)
        self.fetcher = _checkout_fetcher(_REPO_ROOT)

    def test_hatch_via_injected_manifest_and_fetcher(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent.install_distro(
                source_home=src_home, target_home=tgt_home,
                manifest=self.manifest, fetcher=self.fetcher,
                dry_run=False,
            )
            self.assertTrue(result["ok"], result.get("error"))
            self.assertEqual(result["source"], "injected")
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "utils", "boot.py")))
            self.assertTrue(os.path.isfile(os.path.join(tgt_home, "brainstem.py")))

    def test_sha_mismatch_aborts_that_file(self):
        bad_manifest = json.loads(json.dumps(self.manifest))
        bad_manifest["files"][0]["sha256"] = "00" * 32

        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent.install_distro(
                source_home=src_home, target_home=tgt_home,
                manifest=bad_manifest, fetcher=self.fetcher,
                dry_run=False,
            )
            self.assertFalse(result["ok"])
            mismatches = [e for e in result["distro_manifest"] if e["action"] == "sha-mismatch"]
            self.assertEqual(len(mismatches), 1)


class ManifestBuilderTests(unittest.TestCase):
    def test_build_manifest_against_repo_checkout(self):
        m = agent.build_manifest(_REPO_ROOT, branch="main")
        self.assertEqual(m["schema"], agent.MANIFEST_SCHEMA)
        self.assertGreater(len(m["files"]), 5)
        dsts = {e["dst"] for e in m["files"]}
        self.assertIn("utils/bond.py", dsts)
        self.assertIn("utils/boot.py", dsts)
        self.assertIn("utils/organs/estate_organ.py", dsts)
        self.assertIn("utils/senses/voice_sense.py", dsts)
        self.assertIn("index.html", dsts)
        for e in m["files"]:
            self.assertEqual(len(e["sha256"]), 64)
            int(e["sha256"], 16)

    def test_built_manifest_is_stable_when_recomputed(self):
        self.assertEqual(agent.build_manifest(_REPO_ROOT),
                         agent.build_manifest(_REPO_ROOT))


class ManifestValidatorTests(unittest.TestCase):
    def _good(self):
        return {
            "schema": agent.MANIFEST_SCHEMA,
            "repo": "x/y",
            "branch": "main",
            "files": [{"src": "a.py", "dst": "utils/a.py", "sha256": "00" * 32}],
        }

    def test_accepts_good_manifest(self):
        agent._validate_manifest(self._good())

    def test_rejects_traversal_dst(self):
        m = self._good(); m["files"][0]["dst"] = "../etc/passwd"
        with self.assertRaises(ValueError):
            agent._validate_manifest(m)

    def test_refuses_sacred_dst(self):
        m = self._good(); m["files"][0]["dst"] = "brainstem.py"
        with self.assertRaises(PermissionError):
            agent._validate_manifest(m)


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
class NetworkHatchTest(unittest.TestCase):
    def test_network_dry_run(self):
        with tempfile.TemporaryDirectory() as src_home, \
             tempfile.TemporaryDirectory() as tgt_home:
            _make_flat_kernel(src_home)
            result = agent.install_distro(
                source_home=src_home, target_home=tgt_home,
                branch="main", dry_run=True,
            )
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(result["source"], "network")
        self.assertGreater(result["distro_files_installed"], 0)


if __name__ == "__main__":
    unittest.main()
