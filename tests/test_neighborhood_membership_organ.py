"""tests/test_neighborhood_membership_organ.py — stdlib unittest for the membership organ.

Pure-logic tests only — no GitHub API hit, no real subscription writes.
Patches network + filesystem boundaries so the organ's routing,
slug parsing, and dispatch table are exercised in isolation.

    python3 -m unittest tests.test_neighborhood_membership_organ -v
    # or
    python3 tests/test_neighborhood_membership_organ.py
"""

import importlib.util
import os
import sys
import tempfile
import unittest


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORGAN_PATH = os.path.join(
    ROOT, "rapp_brainstem", "utils", "organs", "neighborhood_membership_organ.py"
)


def _load_organ():
    spec = importlib.util.spec_from_file_location("neighborhood_membership_organ", ORGAN_PATH)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["neighborhood_membership_organ"] = mod
    spec.loader.exec_module(mod)
    return mod


class _OrganTestCase(unittest.TestCase):
    """Base case that sandboxes ~/.brainstem/* into a tmpdir per test."""

    def setUp(self):
        self.organ = _load_organ()
        self.tmp = tempfile.TemporaryDirectory()
        fake_home = os.path.join(self.tmp.name, "brainstem")
        os.makedirs(fake_home, exist_ok=True)
        self._original = {
            "HOME_BRAINSTEM": self.organ.HOME_BRAINSTEM,
            "SUBS_FILE": self.organ.SUBS_FILE,
            "CACHE_DIR": self.organ.CACHE_DIR,
        }
        self.organ.HOME_BRAINSTEM = fake_home
        self.organ.SUBS_FILE = os.path.join(fake_home, "neighborhoods.json")
        self.organ.CACHE_DIR = os.path.join(fake_home, "neighborhoods")

    def tearDown(self):
        for key, value in self._original.items():
            setattr(self.organ, key, value)
        self.tmp.cleanup()

    def patch(self, attr, value):
        """Monkeypatch a module-level attribute for the duration of one test."""
        original = getattr(self.organ, attr)
        setattr(self.organ, attr, value)
        self.addCleanup(setattr, self.organ, attr, original)


class SlugParsing(_OrganTestCase):
    def test_basic(self):
        s = self.organ._slug_from_url
        self.assertEqual(s("https://github.com/kody-w/microsoft-se-team-neighborhood"),
                         "kody-w/microsoft-se-team-neighborhood")
        self.assertEqual(s("http://github.com/owner/repo"), "owner/repo")
        self.assertEqual(s("https://github.com/owner/repo.git"), "owner/repo")
        self.assertEqual(s("https://github.com/owner/repo/tree/main"), "owner/repo")

    def test_rejects_bad(self):
        s = self.organ._slug_from_url
        self.assertIsNone(s(None))
        self.assertIsNone(s(""))
        self.assertIsNone(s("not a url"))
        self.assertIsNone(s("https://gitlab.com/owner/repo"))


class Dispatch(_OrganTestCase):
    def test_name_is_plural(self):
        """Routes dispatch at /api/neighborhoods/* — the existing local-peer
        organ at /api/neighborhood/* must not be shadowed."""
        self.assertEqual(self.organ.name, "neighborhoods")

    def test_unknown_route_returns_404_with_table(self):
        body, status = self.organ.handle("PATCH", "frobnicate", {})
        self.assertEqual(status, 404)
        self.assertIn("valid_routes", body)


class ListSubscriptions(_OrganTestCase):
    def test_starts_empty(self):
        body, status = self.organ.handle("GET", "", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["schema"], "rapp-neighborhoods-cache/1.0")
        self.assertEqual(body["subscriptions"], [])


class Join(_OrganTestCase):
    GATE_URL = "https://github.com/kody-w/microsoft-se-team-neighborhood"
    PRIVATE_URL = "https://github.com/kody-w/microsoft-se-team-neighborhood-private"

    def test_requires_gate_url(self):
        body, status = self.organ.handle("POST", "join", {})
        self.assertEqual(status, 400)
        self.assertIn("missing gate_url", body["error"])

    def test_unparseable_url(self):
        body, status = self.organ.handle("POST", "join", {"gate_url": "https://gitlab.com/x/y"})
        self.assertEqual(status, 400)
        self.assertIn("could not parse repo slug", body["error"])

    def test_unreachable_gate(self):
        self.patch("_fetch_neighborhood_json", lambda slug: (None, 404))
        body, status = self.organ.handle("POST", "join", {"gate_url": self.GATE_URL})
        self.assertEqual(status, 404)
        self.assertIn("could not read neighborhood.json", body["error"])
        self.assertIn("hint", body)

    def test_blocks_when_not_collaborator_and_offers_join_issue(self):
        gate = {
            "neighborhood_rappid": "test-rappid",
            "name": "se-team",
            "display_name": "Microsoft SE Team",
            "private_companion": {"repo": self.PRIVATE_URL},
        }
        self.patch("_fetch_neighborhood_json", lambda slug: (gate, 200))
        self.patch(
            "_verify_membership",
            lambda slug: {"is_member": False, "reason": "not a collaborator (404)"},
        )
        body, status = self.organ.handle("POST", "join", {"gate_url": self.GATE_URL})
        self.assertEqual(status, 403)
        self.assertFalse(body["joined"])
        self.assertEqual(body["next_step"]["action"], "open_join_issue")
        self.assertIn("issues/new", body["next_step"]["url"])

    def test_records_subscription_when_member(self):
        gate = {
            "neighborhood_rappid": "test-rappid",
            "name": "se-team",
            "display_name": "Microsoft SE Team",
            "private_companion": {"repo": self.PRIVATE_URL},
        }
        self.patch("_fetch_neighborhood_json", lambda slug: (gate, 200))
        self.patch(
            "_verify_membership",
            lambda slug: {"is_member": True, "is_pusher": True, "is_admin": False, "private": True},
        )
        self.patch("_cache_seed", lambda slug, paths: ("/tmp/fake", {}))

        body, status = self.organ.handle("POST", "join", {"gate_url": self.GATE_URL})
        self.assertEqual(status, 200)
        self.assertTrue(body["joined"])
        self.assertEqual(body["subscription"]["role_inferred"], "member")

        list_body, list_status = self.organ.handle("GET", "", None)
        self.assertEqual(list_status, 200)
        self.assertEqual(len(list_body["subscriptions"]), 1)
        self.assertEqual(list_body["subscriptions"][0]["gate_repo"], "kody-w/microsoft-se-team-neighborhood")

    def test_admin_collaborator_resolves_to_founder(self):
        gate = {"neighborhood_rappid": "x", "name": "y", "private_companion": {"repo": "https://github.com/o/r"}}
        self.patch("_fetch_neighborhood_json", lambda slug: (gate, 200))
        self.patch(
            "_verify_membership",
            lambda slug: {"is_member": True, "is_pusher": True, "is_admin": True},
        )
        self.patch("_cache_seed", lambda slug, paths: ("/tmp/fake", {}))
        body, status = self.organ.handle("POST", "join", {"gate_url": "https://github.com/o/r"})
        self.assertEqual(body["subscription"]["role_inferred"], "founder")


class Leave(_OrganTestCase):
    def test_idempotent(self):
        body, status = self.organ.handle("POST", "kody-w/microsoft-se-team-neighborhood/leave", None)
        self.assertEqual(status, 200)
        self.assertFalse(body["left"])
        self.assertEqual(body["removed_count"], 0)


class Members(_OrganTestCase):
    def test_404s_when_not_subscribed(self):
        body, status = self.organ.handle("GET", "kody-w/microsoft-se-team-neighborhood/members", None)
        self.assertEqual(status, 404)
        self.assertIn("not subscribed", body["error"])


class LocalMode(_OrganTestCase):
    """The file:// local-path subscription mode (Scenario 1: on-device, no
    GitHub round trip). Every test writes its own seed dir into a tmpdir to
    keep the cases independent."""

    def _stage_seed(self, rappid="aaaa1111-2222-3333-4444-555566667777"):
        seed = os.path.join(self.tmp.name, "seed")
        os.makedirs(seed, exist_ok=True)
        with open(os.path.join(seed, "neighborhood.json"), "w") as f:
            f.write(
                '{"schema":"rapp-neighborhood/1.0","neighborhood_rappid":"' + rappid +
                '","kind":"neighborhood","name":"local-fixture","display_name":"Local Fixture",'
                '"github":null,"visibility":"public","purpose":"Test fixture",'
                '"private_companion":null,"gate_repo":null,"kernel_version":"0.6.0"}'
            )
        return seed

    def test_local_path_parser_handles_three_shapes(self):
        f = self.organ._local_path_from_url
        self.assertEqual(f("file:///abs/path"), "/abs/path")
        self.assertEqual(f("file://localhost/abs/path"), "/abs/path")
        self.assertIsNone(f("https://github.com/x/y"))
        self.assertIsNone(f(None))

    def test_local_slug_is_derived_from_dirname(self):
        s = self.organ._local_slug_from_path("/Users/me/seeds/my-fixture")
        self.assertEqual(s, "local/my-fixture")

    def test_join_local_records_subscription_with_founder_role(self):
        seed = self._stage_seed()
        body, status = self.organ.handle("POST", "join", {"gate_url": f"file://{seed}"})
        self.assertEqual(status, 200, f"unexpected: {body}")
        self.assertTrue(body["joined"])
        self.assertEqual(body["mode"], "local")
        self.assertEqual(body["subscription"]["role_inferred"], "founder")
        self.assertEqual(body["subscription"]["membership_check"]["reason"], "local-mode (filesystem access)")

    def test_join_local_404s_when_seed_dir_missing(self):
        body, status = self.organ.handle(
            "POST", "join", {"gate_url": "file:///definitely/not/a/real/path-xyz123"}
        )
        self.assertEqual(status, 404)
        self.assertIn("could not read neighborhood.json", body["error"])

    def test_local_subscription_appears_in_estate_view(self):
        seed = self._stage_seed()
        self.organ.handle("POST", "join", {"gate_url": f"file://{seed}"})
        body, status = self.organ.handle("GET", "estate", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["subscription_count"], 1)
        names = [n["name"] for n in body["neighborhoods"]]
        self.assertIn("local-fixture", names)


class ByRappid(_OrganTestCase):
    """The rappid-as-global-passport lookup: given an operator's rappid, find
    every neighborhood in the local subscription set where they appear as a
    member. The rappid is the AI's identity primitive — it travels with the
    operator and is the spine of the global estate view."""

    def _stage_with_two_neighborhoods(self):
        # Stage two neighborhood caches with overlapping members
        cache_a = os.path.join(self.organ.CACHE_DIR, "kody-w__se-team")
        cache_b = os.path.join(self.organ.CACHE_DIR, "kody-w__home-photos")
        os.makedirs(cache_a, exist_ok=True)
        os.makedirs(cache_b, exist_ok=True)
        with open(os.path.join(cache_a, "members.json"), "w") as f:
            f.write('{"members": [{"github_login": "kody-w", "rappid": "AAAA-1111", "role": "founder"}, {"github_login": "rappter1", "rappid": "BBBB-2222", "role": "member"}]}')
        with open(os.path.join(cache_b, "members.json"), "w") as f:
            f.write('{"members": [{"github_login": "kody-w", "rappid": "AAAA-1111", "role": "founder"}, {"github_login": "alex", "rappid": "CCCC-3333", "role": "member"}]}')

        self.organ._save_subs({
            "schema": "rapp-neighborhoods-cache/1.0",
            "subscriptions": [
                {"name": "se-team", "kind": "neighborhood", "gate_repo": "kody-w/se-team", "cache_dir": cache_a, "visibility": "private-workspace"},
                {"name": "home-photos", "kind": "neighborhood", "gate_repo": "kody-w/home-photos", "cache_dir": cache_b, "visibility": "private-workspace"},
            ],
        })

    def test_by_rappid_finds_operator_across_neighborhoods(self):
        self._stage_with_two_neighborhoods()
        body, status = self.organ.handle("GET", "by-rappid/aaaa-1111", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["rappid"], "aaaa-1111")
        self.assertEqual(body["appears_in_count"], 2)
        names = sorted(a["neighborhood_name"] for a in body["appearances"])
        self.assertEqual(names, ["home-photos", "se-team"])

    def test_by_rappid_returns_zero_for_unknown(self):
        self._stage_with_two_neighborhoods()
        body, status = self.organ.handle("GET", "by-rappid/unknown-rappid-999", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["appears_in_count"], 0)
        self.assertEqual(body["appearances"], [])

    def test_by_rappid_finds_only_neighborhoods_where_rappid_appears(self):
        self._stage_with_two_neighborhoods()
        body, status = self.organ.handle("GET", "by-rappid/bbbb-2222", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["appears_in_count"], 1)
        self.assertEqual(body["appearances"][0]["neighborhood_name"], "se-team")
        self.assertEqual(body["appearances"][0]["github_login_in_this_neighborhood"], "rappter1")


class Estate(_OrganTestCase):
    """The estate view is the metropolis lens: multi-neighborhood, multi-zone,
    operator-identity-preserved synthesized view. Tests the empty case and the
    multi-subscription bridges case."""

    def test_estate_empty_when_no_subscriptions(self):
        body, status = self.organ.handle("GET", "estate", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["schema"], "rapp-estate/1.0")
        self.assertEqual(body["subscription_count"], 0)
        self.assertEqual(body["zones"], {})
        self.assertEqual(body["bridges"], [])

    def test_estate_surfaces_bridges_across_neighborhoods(self):
        # Stage two subscriptions with overlapping member rosters.
        cache_a = os.path.join(self.organ.CACHE_DIR, "kody-w__se-team")
        cache_b = os.path.join(self.organ.CACHE_DIR, "kody-w__home-photos")
        os.makedirs(cache_a, exist_ok=True)
        os.makedirs(cache_b, exist_ok=True)
        with open(os.path.join(cache_a, "members.json"), "w") as f:
            f.write('{"members": [{"github_login": "kody-w"}, {"github_login": "rappter1"}]}')
        with open(os.path.join(cache_b, "members.json"), "w") as f:
            f.write('{"members": [{"github_login": "kody-w"}, {"github_login": "alex"}]}')

        self.organ._save_subs({
            "schema": "rapp-neighborhoods-cache/1.0",
            "subscriptions": [
                {"name": "se-team", "kind": "neighborhood", "gate_repo": "kody-w/se-team", "cache_dir": cache_a},
                {"name": "home-photos", "kind": "neighborhood", "gate_repo": "kody-w/home-photos", "cache_dir": cache_b},
            ],
        })

        body, status = self.organ.handle("GET", "estate", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["subscription_count"], 2)
        bridges = {b["login"]: b["spans"] for b in body["bridges"]}
        self.assertIn("kody-w", bridges, "kody-w should bridge both neighborhoods (operator identity)")
        self.assertEqual(sorted(bridges["kody-w"]), ["home-photos", "se-team"])
        self.assertNotIn("rappter1", bridges, "rappter1 only in se-team — not a bridge")
        self.assertNotIn("alex", bridges, "alex only in home-photos — not a bridge")


class Federation(_OrganTestCase):
    """Real brainstem-to-brainstem federation: POST /api/.../contribute persists
    a receipt; GET /api/.../contributions lists them. No GitHub round-trip; no
    stubs; the receiver's filesystem holds the proof."""

    def _stage_subscription(self, slug="local/test", cache_subdir="local__test"):
        cache = os.path.join(self.organ.CACHE_DIR, cache_subdir)
        os.makedirs(cache, exist_ok=True)
        with open(os.path.join(cache, "neighborhood.json"), "w") as f:
            f.write('{"schema":"rapp-neighborhood/1.0","name":"test","display_name":"Test"}')
        self.organ._save_subs({
            "schema": "rapp-neighborhoods-cache/1.0",
            "subscriptions": [{
                "name": "test",
                "kind": "neighborhood",
                "gate_repo": slug,
                "cache_dir": cache,
                "neighborhood_rappid": "test-r",
            }],
        })
        return slug, cache

    def test_contribute_persists_receipt_with_provenance(self):
        slug, cache = self._stage_subscription()
        contribution = {
            "request_id": "abc123",
            "contributor": {"github_login": "rappter1", "rappid": "fake-rappid"},
            "findings": [{"snippet": "x", "source": {"kind": "files", "ref": "/x"}}],
        }
        body, status = self.organ.handle(
            "POST", f"{slug}/contribute",
            {"request_id": "abc123", "contribution": contribution, "from_peer": "rappter1@laptop"},
        )
        self.assertEqual(status, 200)
        self.assertTrue(body["received"])
        self.assertTrue(os.path.exists(body["stored_at"]))

    def test_contribute_rejects_missing_request_id(self):
        slug, _ = self._stage_subscription()
        body, status = self.organ.handle("POST", f"{slug}/contribute", {"no": "request_id"})
        self.assertEqual(status, 400)
        self.assertIn("request_id", body["error"])

    def test_contribute_rejects_unsubscribed_neighborhood(self):
        body, status = self.organ.handle("POST", "unknown/repo/contribute", {"request_id": "x"})
        self.assertEqual(status, 404)

    def test_list_contributions_returns_persisted_receipts(self):
        slug, _ = self._stage_subscription()
        for login in ["alice", "bob", "carol"]:
            self.organ.handle("POST", f"{slug}/contribute", {
                "request_id": "shared-req",
                "contribution": {
                    "request_id": "shared-req",
                    "contributor": {"github_login": login},
                    "findings": [],
                },
            })
        body, status = self.organ.handle("GET", f"{slug}/contributions", None)
        self.assertEqual(status, 200)
        self.assertEqual(body["count"], 3)
        logins = {c["contribution"]["contributor"]["github_login"] for c in body["contributions"]}
        self.assertEqual(logins, {"alice", "bob", "carol"})

    def test_list_contributions_filters_by_request_id(self):
        slug, _ = self._stage_subscription()
        self.organ.handle("POST", f"{slug}/contribute", {
            "request_id": "req-A",
            "contribution": {"request_id": "req-A", "contributor": {"github_login": "alice"}},
        })
        self.organ.handle("POST", f"{slug}/contribute", {
            "request_id": "req-B",
            "contribution": {"request_id": "req-B", "contributor": {"github_login": "bob"}},
        })
        body, _ = self.organ.handle("GET", f"{slug}/contributions", {"request_id": "req-A"})
        self.assertEqual(body["count"], 1)
        self.assertEqual(body["contributions"][0]["contribution"]["contributor"]["github_login"], "alice")


if __name__ == "__main__":
    unittest.main(verbosity=2)
