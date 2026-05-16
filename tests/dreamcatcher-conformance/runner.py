#!/usr/bin/env python3
"""
runner.py — Dreamcatcher conformance suite runner.

Executes every case under cases/ against an implementation passed in via
--engine, comparing the implementation's output to the canonical
expected.json. Reports pass/fail per case.

Currently a skeleton: cases/ is empty pending suite population. Runner
infrastructure is in place so that any populated case immediately runs
without further setup.

Usage:
    python3 runner.py --engine /path/to/dreamcatcher-binary
    python3 runner.py --engine /path/to/dreamcatcher-binary --case 001-empty-merge
    python3 runner.py --engine wildhaven   # if installed as a Python module
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True,
                        help="Path to merge-engine binary or 'wildhaven' for the canonical reference")
    parser.add_argument("--case", help="Run only the named case")
    parser.add_argument("--cases-dir", type=Path,
                        default=Path(__file__).parent / "cases")
    args = parser.parse_args()

    cases_dir = args.cases_dir
    if not cases_dir.exists() or not any(cases_dir.iterdir()):
        print(f"\n  ⚠️  No test cases found in {cases_dir}.")
        print(f"     The suite is currently a skeleton — see README.md.")
        print(f"     Contributions welcome via PR.\n")
        sys.exit(0)

    case_dirs = sorted([d for d in cases_dir.iterdir() if d.is_dir()])
    if args.case:
        case_dirs = [d for d in case_dirs if d.name == args.case]
        if not case_dirs:
            print(f"  ✗ No case named '{args.case}'")
            sys.exit(1)

    passes, fails = 0, 0
    for case_dir in case_dirs:
        result = run_case(case_dir, args.engine)
        if result:
            print(f"  ✓ {case_dir.name}")
            passes += 1
        else:
            print(f"  ✗ {case_dir.name}")
            fails += 1

    print(f"\n  {passes} passed, {fails} failed")
    sys.exit(0 if fails == 0 else 1)


def run_case(case_dir: Path, engine: str) -> bool:
    """Run a single case. Returns True if implementation output matches expected."""
    base_path = case_dir / "base.json"
    ours_path = case_dir / "ours.json"
    theirs_path = case_dir / "theirs.json"
    expected_path = case_dir / "expected.json"

    if not all(p.exists() for p in [base_path, ours_path, theirs_path, expected_path]):
        print(f"    (skipping {case_dir.name}: missing one of base/ours/theirs/expected.json)")
        return False

    # Convention: engine is invoked as `<engine> merge <base> <ours> <theirs>`,
    # writing JSON to stdout. Implementations may follow any convention they
    # choose; this runner can be extended with --invoke-style flags as the
    # conformance contract solidifies.
    try:
        result = subprocess.run(
            [engine, "merge", str(base_path), str(ours_path), str(theirs_path)],
            capture_output=True, text=True, check=True
        )
        actual = json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"    (engine error in {case_dir.name}: {e.stderr.strip()})")
        return False
    except json.JSONDecodeError as e:
        print(f"    (non-JSON output in {case_dir.name}: {e})")
        return False

    expected = json.loads(expected_path.read_text())
    return _canonical(actual) == _canonical(expected)


def _canonical(o):
    return json.dumps(o, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


if __name__ == "__main__":
    main()
