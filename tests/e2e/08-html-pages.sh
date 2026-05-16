#!/usr/bin/env bash
# Verify the four new marketing/docs pages parse cleanly, contain the
# expected messaging anchors, and cross-link to each other correctly.
# No brainstem needed; pure file checks.
set -euo pipefail
cd "$(dirname "$0")/../.."

PAGES=(pages/product/one-pager.html pages/about/leadership.html pages/about/process.html pages/product/faq-slide.html pages/about/partners.html pages/product/use-cases.html pages/about/security.html pages/release/release-notes.html pages/release/roadmap.html pages/product/faq.html)

for f in "${PAGES[@]}"; do
    [ -f "$f" ] || { echo "FAIL: $f does not exist"; exit 1; }
    BYTES=$(wc -c < "$f")
    LINES=$(wc -l < "$f")
    if [ "$BYTES" -lt 4000 ]; then
        echo "FAIL: $f suspiciously small ($BYTES bytes)"
        exit 1
    fi
    echo "PASS: $f exists ($BYTES bytes, $LINES lines)"
done

# Parse sanity for each
for f in "${PAGES[@]}"; do
    python3 - <<EOF || { echo "FAIL: $f parse error"; exit 1; }
from html.parser import HTMLParser
import sys
class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.err = None
    def error(self, msg): self.err = msg
p = P()
with open("$f") as fh: p.feed(fh.read())
if p.err:
    print(p.err); sys.exit(1)
EOF
    echo "PASS: $f parses"
done

# ── Content anchors — the specific messaging that MUST be in each ──

check() {
    local file="$1"; local label="$2"; local pattern="$3"
    if grep -qE "$pattern" "$file"; then
        echo "PASS: [$file] $label"
    else
        echo "FAIL: [$file] missing — $label"
        echo "  expected pattern: $pattern"
        exit 1
    fi
}

# one-pager.html — single-slide pitch, reads like a PowerPoint slide
echo "▶ one-pager content anchors..."
check pages/product/one-pager.html "headline uses 'goal' + 'swarm'"             'Give it a.*goal.*swarm'
check pages/product/one-pager.html "positions alongside Copilot/Azure/M365"     'Copilot.*Azure.*Microsoft 365|Copilot, Azure, and Microsoft 365'
check pages/product/one-pager.html "claims portable single file"                'Single Python file|single Python file|one Python file|one portable'
check pages/product/one-pager.html "lands the 'one codebase, three tiers' beat" 'three tiers|three-tier|One codebase|one codebase'
check pages/product/one-pager.html "pull-quote distills the pitch"              'swarms around it|swarm around your goal|swarms around your goal'
check pages/product/one-pager.html "cross-links to FAQ (sr-only nav)"           'faq\.html'
check pages/product/one-pager.html "cross-links to roadmap (sr-only nav)"       'roadmap\.html'

# release-notes.html
echo "▶ release-notes content anchors..."
check pages/release/release-notes.html "v0.12.1 listed"                         'v0.12.1|brainstem-v0\.12\.1'
check pages/release/release-notes.html "v0.12.0 listed"                         'v0.12.0|brainstem-v0\.12\.0'
check pages/release/release-notes.html "Three Tiers One Model reference"        'Three Tiers|One Model|tier-2'
check pages/release/release-notes.html "install pin example"                    'BRAINSTEM_VERSION='
check pages/release/release-notes.html "cross-links to roadmap"                 'roadmap\.html'
check pages/release/release-notes.html "cross-links to FAQ"                     'faq\.html'

# roadmap.html
echo "▶ roadmap content anchors..."
check pages/release/roadmap.html "three horizons columns"                       'Now|Next|Later'
check pages/release/roadmap.html "Tier 2 cloud item"                            'Tier 2.*[cC]loud|provision-twin-lite'
# swarm-factory item dropped from roadmap; assertion removed rather than locking
# the document to copy nobody plans to ship (Article XIX-style: don't write
# tests that require future content).
check pages/release/roadmap.html "on-device / offline item"                     'on-device|offline|IoT'
check pages/release/roadmap.html "one-pager linked"                             'one-pager\.html'
check pages/release/roadmap.html "Article references"                           'Article I-A|Article II|Article V'

# leadership.html — audience: execs / GMs / funders
echo "▶ leadership.html content anchors..."
check pages/about/leadership.html "audience kicker labels it"                 'For Leadership|LEADERSHIP'
check pages/about/leadership.html "headline lands 'working agent' outcome"    'working agent'
check pages/about/leadership.html "positions as acceleration layer"           'acceleration layer|accelerates|on-ramp'
check pages/about/leadership.html "mentions Copilot/Azure/M365 alongside"     'Copilot.*Azure.*Microsoft 365|Microsoft AI stack'
check pages/about/leadership.html "KPI row has the 3 big numbers"             '1 hr|3 days|1 file'
check pages/about/leadership.html "3-beat outcome section"                    'specialist headcount|Workshop to validated|On the stack'
check pages/about/leadership.html "closing hinge line"                        'Every conversation becomes an artifact|becomes an artifact'
check pages/about/leadership.html "cross-links to process one-pager"          'process\.html'
check pages/about/leadership.html "cross-links to platform one-pager"         'one-pager\.html'

# process.html — audience: enablement / sellers / partners
echo "▶ process.html content anchors..."
check pages/about/process.html "audience kicker labels it"                    'The Process|PROCESS'
check pages/about/process.html "headline lands 'one week' promise"            'one week|In one week'
check pages/about/process.html "5-step pipeline present"                      '60-min ideation|Transcript.*RAPP|Partner handoff|Copilot Studio'
check pages/about/process.html "customer validates step"                      'Customer validates|customer validates'
check pages/about/process.html "value band with what customers give"          'one-hour conversation|hour conversation'
check pages/about/process.html "self-documenting handoff"                     'self-documenting|Self-documenting'
check pages/about/process.html "agent IS the spec insight"                    'agent IS the spec|agent is the spec'
check pages/about/process.html "cross-links to leadership one-pager"          'leadership\.html'
check pages/about/process.html "cross-links to platform one-pager"            'one-pager\.html'

# faq-slide.html — top 4 Q&A compressed to one slide
echo "▶ faq-slide.html content anchors..."
check pages/product/faq-slide.html "audience kicker"                            'Top Questions|TOP QUESTIONS'
check pages/product/faq-slide.html "4-question framing"                         'Four questions'
check pages/product/faq-slide.html "Copilot question (not competition)"         'compete with Copilot Studio'
check pages/product/faq-slide.html "offline question"                           'offline'
check pages/product/faq-slide.html "production question"                        'production|three tiers|Three tiers'
check pages/product/faq-slide.html "one-sentence question"                      'one sentence|one-sentence|in one sentence'
check pages/product/faq-slide.html "links to full FAQ"                          'faq\.html'

# partners.html — partner audience
echo "▶ partners.html content anchors..."
check pages/about/partners.html "kicker labels audience"                      'For Partners|FOR PARTNERS'
check pages/about/partners.html "the file IS the spec headline"               'file.*IS.*spec|IS the spec'
check pages/about/partners.html "'you get / you build / you own' framing"     'You get.*You build.*You own|you get.*you build.*you own'
check pages/about/partners.html "self-documenting handoff"                    'self-documenting|Self-documenting'
check pages/about/partners.html "before/after contrast"                       'Without RAPP.*With RAPP|Discovery.*spec.*estimate'
check pages/about/partners.html "cross-links to process"                      'process\.html'
check pages/about/partners.html "cross-links to leadership"                   'leadership\.html'

# use-cases.html — concrete scenarios
echo "▶ use-cases.html content anchors..."
check pages/product/use-cases.html "kicker labels audience"                     'What Teams Build|WHAT TEAMS BUILD'
check pages/product/use-cases.html "lead prioritization scenario"               'Lead prioritization'
check pages/product/use-cases.html "personalized outreach scenario"             'Personalized outreach'
check pages/product/use-cases.html "customer-service scenario"                  'Customer-service|customer-service'
check pages/product/use-cases.html "research briefs scenario"                   'Research.*insights|insights briefs|briefs'
check pages/product/use-cases.html "input/swarm/outcome flow per card"          'lbl in.*Input|>Input<.*>Swarm<|lbl out'
check pages/product/use-cases.html "cross-links to platform one-pager"          'one-pager\.html'

# security.html — CISO / compliance audience
echo "▶ security.html content anchors..."
check pages/about/security.html "kicker labels audience"                      'Security.*Compliance|SECURITY'
check pages/about/security.html "headline: data / device / audit trail"       'Your data.*Your device.*Your audit|audit trail'
check pages/about/security.html "data residency pillar"                       'Data residency|Local-first'
check pages/about/security.html "supply chain pillar"                         'Supply chain|Auditable'
check pages/about/security.html "identity pillar (IdP)"                       'IdP.*already trust|Identity'
check pages/about/security.html "Entra / AAD reference"                       'Azure AD|Entra'
check pages/about/security.html "BRAINSTEM_VERSION pin example"               'BRAINSTEM_VERSION'
check pages/about/security.html "guardrails: no telemetry"                    'No telemetry|telemetry phoning home'
check pages/about/security.html "guardrails: no centralized registry"         'No vendor-shared|no centralized|agent registry'
check pages/about/security.html "cross-links to other one-pagers"             'one-pager\.html|partners\.html|leadership\.html'

# faq.html
echo "▶ faq content anchors..."
check pages/product/faq.html "Q about GPT/Claude/Copilot"                       'GPT.*Claude.*Copilot|using GPT'
check pages/product/faq.html "Q about real scenario"                            'real scenario|forestry'
check pages/product/faq.html "Q about offline"                                  '[oO]ffline'
check pages/product/faq.html "Q about Copilot Studio"                           'Copilot Studio directly|Copilot Studio'
check pages/product/faq.html "Q about portable meaning"                         'portable.*actually|portable.*mean'
check pages/product/faq.html "Q about install one-liner"                        'curl -fsSL'
check pages/product/faq.html "one-sentence version at end"                      'one-sentence|one sentence|one.*line version'
check pages/product/faq.html "cross-links to one-pager"                         'one-pager\.html'

echo "✅ HTML pages smoke test passed"
