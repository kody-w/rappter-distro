"""observe.py — meta-loop observer.

Reads the simulation state (purely from filesystem — no LLM call), compares
to expected.json (the "what we are trying to do"), produces a
rapp-simulation-observation/1.0 envelope, and surfaces concrete adjustment
suggestions for the operator. Optionally calls BondRhythm.pulse_once() to
fold in ecosystem-scope drift detection.

Operator-mediated by design: this script SUGGESTS adjustments; it does
not auto-apply anything beyond writing its own observation file.

Usage:
    python3 observe.py [--with-ecosystem-pulse] [--out-dir <dir>] [--quiet]

Output:
    ~/RAPP-sim/observations/<utc>.json (always)
    ~/RAPP-sim/observations/latest.json (symlinked / overwritten pointer)
    Stdout: human-readable summary
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

SIM_ROOT = os.path.expanduser("~/RAPP-sim")


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _read_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def _seconds_since(ts_iso: str) -> int | None:
    if not ts_iso:
        return None
    try:
        import calendar
        return int(time.time() - calendar.timegm(time.strptime(ts_iso[:19], "%Y-%m-%dT%H:%M:%S")))
    except ValueError:
        return None


def discover_twins() -> list[dict]:
    twins = []
    for entry in sorted(os.listdir(SIM_ROOT)):
        path = os.path.join(SIM_ROOT, entry)
        rappid_path = os.path.join(path, "rappid.json")
        if os.path.isdir(path) and os.path.isfile(rappid_path):
            try:
                rj = _read_json(rappid_path)
                if rj.get("kind") == "twin" or rj.get("kind") == "personal":
                    twins.append({"name": rj.get("name", entry), "dir": path,
                                  "display_name": rj.get("display_name"),
                                  "rappid": rj["rappid"]})
            except (OSError, ValueError):
                pass
    return twins


def discover_neighborhoods() -> list[dict]:
    nbs = []
    for entry in sorted(os.listdir(SIM_ROOT)):
        path = os.path.join(SIM_ROOT, entry)
        nb_path = os.path.join(path, "neighborhood.json")
        if os.path.isdir(path) and os.path.isfile(nb_path):
            try:
                nb = _read_json(nb_path)
                nbs.append({"name": nb.get("name", entry), "dir": path,
                            "display_name": nb.get("display_name"),
                            "rappid": nb["neighborhood_rappid"]})
            except (OSError, ValueError):
                pass
    return nbs


def scan_neighborhood(nb: dict) -> dict:
    sub_dir = os.path.join(nb["dir"], "submissions")
    vote_dir = os.path.join(nb["dir"], "votes")
    submissions, votes = [], []
    if os.path.isdir(sub_dir):
        for slug in sorted(os.listdir(sub_dir)):
            slug_path = os.path.join(sub_dir, slug)
            if os.path.isdir(slug_path):
                meta_p = os.path.join(slug_path, "meta.json")
                if os.path.exists(meta_p):
                    submissions.append(_read_json(meta_p))
    if os.path.isdir(vote_dir):
        for vote_file in sorted(os.listdir(vote_dir)):
            if vote_file.endswith(".json"):
                votes.append(_read_json(os.path.join(vote_dir, vote_file)))
    return {"name": nb["name"], "submissions": submissions, "votes": votes}


def measure_twin(twin: dict) -> dict:
    bonds_path = os.path.join(twin["dir"], "bonds.json")
    bonds = _read_json(bonds_path) if os.path.exists(bonds_path) else {"events": []}
    events = bonds.get("events", [])
    last_event_at = events[-1]["at"] if events else None
    idle_s = _seconds_since(last_event_at)

    # Voice distinctiveness signal: just count unique words in soul (cheap proxy)
    soul_path = os.path.join(twin["dir"], "soul.md")
    soul_words = set()
    if os.path.exists(soul_path):
        soul_words = set(open(soul_path).read().lower().split())

    # Grail compliance check
    required = ["card.json", "holo.md", "holo.svg", "holo-qr.svg", "rappid.json", "soul.md", "bonds.json"]
    required_specs = ["specs/HOLOCARD_SPEC.md", "specs/RAPPID_SPEC.md", "specs/ANTIPATTERNS.md",
                      "specs/SOUL_IDENTITY.md", "specs/PARTICIPATION.md", "specs/README.md", "specs/TWIN_PROTOCOL.md"]
    missing = [f for f in required + required_specs
               if not os.path.exists(os.path.join(twin["dir"], f))]
    grail_files_present = len(required) + len(required_specs) - len(missing)

    return {
        "name": twin["name"], "display_name": twin["display_name"],
        "rappid": twin["rappid"], "event_count": len(events),
        "last_event_at": last_event_at, "idle_seconds": idle_s,
        "grail_files_present": grail_files_present, "grail_missing": missing,
        "soul_unique_words": len(soul_words),
    }


def voice_distinctiveness(twins: list[dict]) -> float:
    """Jaccard-style — fraction of unique words across all souls."""
    if len(twins) < 2:
        return 1.0
    word_sets = []
    for t in twins:
        soul_path = os.path.join(t["dir"], "soul.md")
        if os.path.exists(soul_path):
            word_sets.append(set(open(soul_path).read().lower().split()))
    if not word_sets:
        return 1.0
    union = set().union(*word_sets)
    intersection = set.intersection(*word_sets) if word_sets else set()
    if not union:
        return 1.0
    return 1.0 - (len(intersection) / len(union))


def check_antipatterns(twins: list[dict], neighborhoods: list[dict],
                       nb_state: list[dict]) -> list[str]:
    violations = []
    fallback_phrases = ["i am an ai assistant", "i am rapp", "i am claude", "i am gpt"]

    for t in twins:
        soul_path = os.path.join(t["dir"], "soul.md")
        if os.path.exists(soul_path):
            soul = open(soul_path).read().lower()
            for phrase in fallback_phrases:
                if phrase in soul:
                    violations.append(f"twin {t['name']!r}: soul.md contains forbidden fallback {phrase!r}")
        rj = _read_json(os.path.join(t["dir"], "rappid.json"))
        if rj.get("schema") not in ("rapp/1", None):
            violations.append(f"twin {t['name']!r}: rappid.json schema {rj.get('schema')!r} not 'rapp/1' (§12; the rapp-rappid/* labels were migrated out)")
        # Card schema
        card_path = os.path.join(t["dir"], "card.json")
        if os.path.exists(card_path):
            card = _read_json(card_path)
            if card.get("schema") != "rappcards/1.1.2":
                violations.append(f"twin {t['name']!r}: card.json schema is {card.get('schema')!r} (should be rappcards/1.1.2)")

    for ns in nb_state:
        existing_slugs = {s["slug"] for s in ns["submissions"]}
        for s in ns["submissions"]:
            if not s.get("contributor"):
                violations.append(f"neighborhood {ns['name']!r}: submission {s.get('slug')!r} has empty contributor")
            if s.get("license") != "CC0-1.0":
                violations.append(f"neighborhood {ns['name']!r}: submission {s.get('slug')!r} license is {s.get('license')!r} (should be CC0-1.0)")
        for v in ns["votes"]:
            if v["slug"] not in existing_slugs:
                violations.append(f"neighborhood {ns['name']!r}: vote references missing slug {v['slug']!r}")

    return violations


def call_bond_rhythm() -> dict | None:
    """Optional: invoke BondRhythm.pulse_once() to fold ecosystem-scope drift into the observation."""
    try:
        repo_root = "/Users/kodywildfeuer/Documents/GitHub/RAPP"
        sys.path.insert(0, os.path.join(repo_root, "rapp_brainstem", "agents"))
        sys.modules.setdefault("agents.basic_agent", type(sys)("agents.basic_agent"))
        sys.modules["agents.basic_agent"].BasicAgent = type("B", (), {"__init__": lambda self: None})
        import importlib.util
        spec = importlib.util.spec_from_file_location("br",
            os.path.join(repo_root, "rapp_brainstem", "agents", "bond_rhythm_agent.py"))
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        out = json.loads(m.BondRhythmAgent().perform(
            repo_root=repo_root,
            _bonds_file=os.path.join(SIM_ROOT, "_bonds-rhythm-from-observer.json"),
        ))
        return {
            "drift_count":   out["drift_count"],
            "by_direction":  out["by_direction"],
            "next_step":     out["next_step"],
            "degraded":      out["degraded"],
        }
    except Exception as e:
        return {"_error": f"bond rhythm call failed: {e}"}


def compute_adjustments(observation: dict, expected: dict) -> list[dict]:
    """For each measured drift, propose a concrete next step."""
    adjustments = []
    metrics = observation["measured"]
    expected_metrics = expected["north_star_metrics"]

    if metrics["contributor_count"] < expected_metrics["minimum_contributors_after_first_tick"]:
        adjustments.append({
            "kind": "low-participation",
            "severity": "high",
            "next_step": (f"only {metrics['contributor_count']} contributor(s) — expected ≥{expected_metrics['minimum_contributors_after_first_tick']}. "
                          f"Run another tick: `python3 ~/RAPP-sim/tick_twin.py --twin <missing-twin>`"),
        })
    if metrics["total_submissions"] < expected_metrics["minimum_total_submissions_after_2_ticks"]:
        adjustments.append({
            "kind": "low-canvas",
            "severity": "medium",
            "next_step": "run more ticks; canvas should grow over time",
        })
    for tw in metrics["per_twin"]:
        if tw["idle_seconds"] is not None and tw["idle_seconds"] > expected_metrics["maximum_idle_seconds_per_twin"]:
            adjustments.append({
                "kind": "twin-idle",
                "severity": "medium",
                "next_step": f"twin {tw['name']!r} idle for {tw['idle_seconds']}s — run `python3 ~/RAPP-sim/tick_twin.py --twin {tw['name']}`",
            })
        if tw["grail_missing"]:
            adjustments.append({
                "kind": "grail-incomplete",
                "severity": "high",
                "next_step": f"twin {tw['name']!r} missing grail files: {tw['grail_missing'][:3]}{'...' if len(tw['grail_missing']) > 3 else ''} — re-run the planter",
            })
    if metrics["voice_distinctiveness"] < expected_metrics["minimum_voice_distinctiveness"]:
        adjustments.append({
            "kind": "voices-too-similar",
            "severity": "low",
            "next_step": (f"voice distinctiveness {metrics['voice_distinctiveness']:.2f} < {expected_metrics['minimum_voice_distinctiveness']}. "
                          "Operator should diverge soul.md content for the twins."),
        })
    if metrics["antipattern_violations"]:
        adjustments.append({
            "kind": "antipattern-violation",
            "severity": "critical",
            "next_step": f"{len(metrics['antipattern_violations'])} antipattern violation(s) — review observation.measured.antipattern_violations[]",
        })
    if (metrics.get("ecosystem_pulse") or {}).get("drift_count", 0) > 0:
        adjustments.append({
            "kind": "ecosystem-drift",
            "severity": "high",
            "next_step": f"ecosystem drift_count={metrics['ecosystem_pulse']['drift_count']} — run `python3 ~/Documents/GitHub/RAPP/tools/ecosystem_audit.py --offline` for details",
        })

    return adjustments


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-ecosystem-pulse", action="store_true",
                    help="also call BondRhythm.pulse_once() for ecosystem-scope drift")
    ap.add_argument("--out-dir", default=os.path.join(SIM_ROOT, "observations"))
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    expected_path = os.path.join(SIM_ROOT, "expected.json")
    if not os.path.exists(expected_path):
        print(f"ERROR: {expected_path} missing — define what we're trying to do first", file=sys.stderr)
        sys.exit(2)
    expected = _read_json(expected_path)

    twins = discover_twins()
    neighborhoods = discover_neighborhoods()
    nb_state = [scan_neighborhood(nb) for nb in neighborhoods]

    twin_metrics = [measure_twin(t) for t in twins]
    contributors = set()
    total_subs = 0
    total_votes = 0
    remix_count = 0
    for ns in nb_state:
        contributors.update(s["contributor"] for s in ns["submissions"])
        total_subs += len(ns["submissions"])
        total_votes += len(ns["votes"])
        remix_count += sum(1 for s in ns["submissions"] if s.get("remix_of"))

    ecosystem_pulse = call_bond_rhythm() if args.with_ecosystem_pulse else None

    measured = {
        "twin_count":                len(twins),
        "neighborhood_count":        len(neighborhoods),
        "contributor_count":         len(contributors),
        "contributors":              sorted(contributors),
        "total_submissions":         total_subs,
        "total_votes":               total_votes,
        "remix_count":               remix_count,
        "voice_distinctiveness":     round(voice_distinctiveness(twins), 3),
        "per_twin":                  twin_metrics,
        "antipattern_violations":    check_antipatterns(twins, neighborhoods, nb_state),
        "ecosystem_pulse":           ecosystem_pulse,
    }

    observation = {
        "schema":         "rapp-simulation-observation/1.0",
        "observed_at":    _now_iso(),
        "sim_root":       SIM_ROOT,
        "measured":       measured,
        "expected":       expected["north_star_metrics"],
        "north_star":     expected["what_we_are_trying_to_do"],
    }
    observation["adjustments"] = compute_adjustments(observation, expected)

    out_dir = args.out_dir
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, observation["observed_at"].replace(":", "-") + ".json")
    with open(out_path, "w") as f:
        json.dump(observation, f, indent=2)
    latest = os.path.join(out_dir, "latest.json")
    with open(latest, "w") as f:
        json.dump(observation, f, indent=2)

    if not args.quiet:
        print(f"\n📊 OBSERVATION at {observation['observed_at']}")
        print(f"   Twins: {measured['twin_count']}    Neighborhoods: {measured['neighborhood_count']}")
        print(f"   Submissions: {measured['total_submissions']}   Votes: {measured['total_votes']}   Remixes: {measured['remix_count']}")
        print(f"   Contributors: {measured['contributors']}")
        print(f"   Voice distinctiveness: {measured['voice_distinctiveness']}")
        if ecosystem_pulse:
            print(f"   Ecosystem pulse: drift={ecosystem_pulse.get('drift_count','?')} {ecosystem_pulse.get('by_direction','')}")
        if measured["antipattern_violations"]:
            print(f"\n⚠️  ANTIPATTERN VIOLATIONS ({len(measured['antipattern_violations'])}):")
            for v in measured["antipattern_violations"]:
                print(f"   - {v}")
        if observation["adjustments"]:
            print(f"\n🔧 SUGGESTED ADJUSTMENTS ({len(observation['adjustments'])}):")
            for a in observation["adjustments"]:
                print(f"   [{a['severity']:8s}] {a['kind']:24s} → {a['next_step']}")
        else:
            print(f"\n✓ NO DRIFT — simulation is in line with expected state")
        print(f"\nWritten to: {out_path}")


if __name__ == "__main__":
    main()
