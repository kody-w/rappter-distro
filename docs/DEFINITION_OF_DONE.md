# Definition of Done

> A done thing is verified, not assumed. This file is the contract I commit to before declaring anything finished.

## For a planted neighborhood / repo to be "done"

1. **The repo exists at the canonical URL.**
   `gh api repos/<owner>/<name>` returns metadata (not 404).
2. **The seed content is committed.**
   `gh api repos/<owner>/<name>/contents` returns the expected file set.
3. **If the repo has `index.html` and is public:** GitHub Pages is enabled AND `https://<owner>.github.io/<name>/` returns **HTTP 200** AND the served body is the seed's actual page (verified by grepping for a known title string, not just a status code).
4. **If the repo is in the metropolis index:** the entry's `gate_repo` and `gate_url` strings exactly match the actual planted URLs (no drift).
5. **Links from the metropolis directory page resolve.** A scripted check fetches each entry's gate URL and confirms 200 (or auth-required for private).

## For a code change to be "done"

1. **All automated tests pass after the change.**
   Not "the new tests pass" — *all* tests, including pre-existing ones. Ran and observed.
2. **All affected scenarios pass with the intended outcome.**
   Exit code 0 is necessary but not sufficient — the scenario's `step_pass` count must match the expected count, and the `step_fail` count must be zero.
3. **The change is committed AND pushed.** `git push` exit 0, `git rev-parse origin/main` == `git rev-parse HEAD`.
4. **If the change touches a deployed URL:** that URL returns the correct response NOW, verified by curl after deploy time has elapsed.

## For a feature to be "done"

1. **All user-named requirements are met.** Not partial. If the user said "build the application," the application exists and runs end-to-end, not just a scaffolded shell.
2. **Edge cases the user explicitly mentioned are handled.** Adapt-to-whats-home, offline survival, removed-collaborator, empty-library — if the user named it, there's a test that exercises it.
3. **Documentation reflects the actual state.** No "Phase 2" labels on things that should work today. No URLs that 404. No "✓ done" comments on broken builds.
4. **Nothing returns a placeholder where functionality was promised.** No `phase_1_stub` returns when the user expects real behavior. (Phase-1 stubs are fine *only* if explicitly scoped + named in the user's brief.)
5. **I have personally verified the working behavior.** Not assumed. Not "should work." Ran the thing, observed the result.

## What "verified" means concretely

| Claim | Required verification |
|---|---|
| "Pushed" | `git push` exit code 0 AND `git rev-parse origin/main == git rev-parse HEAD` |
| "Repo created" | `gh api repos/<o>/<n>` returns 200 with `.name == <n>` |
| "Pages enabled" | `gh api repos/<o>/<n>/pages` returns the pages object AND `curl -I https://<o>.github.io/<n>/` returns 200 AND the body contains a known string from the seed |
| "Test passes" | Re-ran the test command after the change; observed `0 failing` in the output |
| "All scenarios green" | Ran the loop; counted N×green, 0×red |
| "URL resolves" | `curl -sI <url> -o /dev/null -w '%{http_code}'` returned 200 (or auth-required for private) |
| "Tracker entry correct" | The JSON entry's gate URL was just curl'd and resolved |

## What I will NOT do anymore

- Declare "✓ pushed" when piped output swallowed the exit code.
- Claim "Pages enabled" without confirming the URL serves the seed.
- Say "done" when one assertion is broken because "the rest passed."
- Write `phase_1_stub` and call it shipped.
- Tell the user to test something I haven't verified myself.
- Give URLs I haven't curl'd.

## When I CANNOT verify (escalate, don't ship)

- If GitHub Pages takes longer than my probe window: wait + re-probe before claiming.
- If a step needs human auth I don't have: stop and tell the user, don't pretend.
- If a verification fails after retries: report the failure honestly with the curl output + ask for direction.

## Why this exists

I was shipping facades and calling them done — pushing without verifying, claiming Pages was up before checking, declaring repos planted that didn't exist. The user named the pattern: *"you have been telling me stuff is done when its not done."* This file is the corrective. I check it before saying done.
