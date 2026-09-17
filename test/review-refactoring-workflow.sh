#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS="$REPO_ROOT/claude/.claude/skills"

require_match() {
  local label="$1" pattern="$2"
  shift 2
  grep -ERq -- "$pattern" "$@" || { echo "FAIL: $label"; exit 1; }
  echo "PASS: $label"
}

REFACTORING="$SKILLS/refactoring/SKILL.md"
PLANNING="$SKILLS/planning/SKILL.md"
PANEL="$SKILLS/panel-review/SKILL.md"
LENSES="$SKILLS/panel-review/references/lenses.md"
WORKFLOW="$SKILLS/panel-review/references/workflow-template.md"
DOUBLE_CHECK="$SKILLS/double-check/SKILL.md"
BRIEF="$SKILLS/double-check/resources/brief-template.md"
BRIEF_VALIDATOR="$SKILLS/double-check/scripts/validate-brief.mjs"
REVIEWER_PREFERENCES="$SKILLS/double-check/resources/reviewer-preferences.json"
PANEL_COVERAGE_CHECKER="$SKILLS/panel-review/scripts/check-production-coverage.mjs"

require_match "refactoring inventories every touched production symbol" \
  'every (changed|touched) production (function|symbol)' "$REFACTORING"
require_match "refactoring records keep, simplify-now, or follow-up disposition" \
  'keep.*simplify now.*follow-up|keep.*follow-up.*simplify now' "$REFACTORING"
require_match "refactoring asks whether each mechanism is necessary" \
  'every new mechanism necessary' "$REFACTORING"
require_match "refactoring revalidates copied or legacy code against current APIs" \
  'copied or legacy.*current APIs' "$REFACTORING"

require_match "planning makes the production-code refactoring assessment mandatory" \
  'Whenever production code changed.*assessment is mandatory' "$PLANNING"
require_match "planning records a clean no-change assessment" \
  'no valuable refactoring found' "$PLANNING"

require_match "panel review inventories touched production symbols during scouting" \
  'inventory.*touched production (function|symbol)' "$PANEL" "$LENSES"
require_match "panel review runs refactoring lens for production changes" \
  'refactoring.*production code changes|production code changes.*refactoring' "$LENSES"
require_match "panel workflow carries the production symbol inventory" \
  'productionSymbols' "$WORKFLOW"
require_match "panel workflow runs the deterministic production coverage check" \
  'check-production-coverage\.mjs' "$WORKFLOW"
require_match "panel refactoring lens independently audits the scout inventory" \
  'independently inspect the diff|independent inventory audit' "$LENSES" "$PANEL"

require_match "double-check forbids removing mandatory brief sections" \
  'must not remove.*mandatory section|mandatory sections.*must not be removed' "$DOUBLE_CHECK"
require_match "double-check validates the materialized brief" \
  'validate-brief\.mjs' "$DOUBLE_CHECK"
require_match "double-check reads persistent reviewer preferences" \
  'reviewer-preferences\.json' "$DOUBLE_CHECK"
require_match "canonical brief has a distinct touched-production simplification section" \
  '^## Touched-production-code simplification' "$BRIEF"

if [[ ! -x "$BRIEF_VALIDATOR" ]]; then
  echo "FAIL: double-check brief validator is missing or not executable"
  exit 1
fi
if [[ ! -x "$PANEL_COVERAGE_CHECKER" ]]; then
  echo "FAIL: panel production coverage checker is missing or not executable"
  exit 1
fi

valid_brief="$(mktemp)"
invalid_brief="$(mktemp)"
shortened_brief="$(mktemp)"
scope_shortened_brief="$(mktemp)"
trap 'rm -f "$valid_brief" "$invalid_brief" "$shortened_brief" "$scope_shortened_brief"' EXIT

sed \
  -e 's/{{REVIEW_MODE}}/cross-provider independent review/' \
  -e 's/{{TASK}}/Preserve behavior while simplifying the touched production code./' \
  -e 's/{{ORIGINAL_SCOPE}}/Issue 2228 and its accepted test design./' \
  -e 's/{{CLAIM}}/The implementation satisfies the issue without unnecessary mechanism./' \
  -e 's/{{WORK_LOCATION}}/Review the current working-tree diff./' \
  -e 's/{{CONTEXT}}/Production behavior must remain unchanged./' \
  -e 's/{{VALIDATION}}/Focused and complete tests passed./' \
  -e 's/{{RISKS}}/Controller wiring and concurrency./' \
  -e 's#{{PRODUCTION_SYMBOLS}}#controllers/example.go:reconcile#' \
  "$BRIEF" > "$valid_brief"

node "$BRIEF_VALIDATOR" "$valid_brief"

sed '/^## Touched-production-code simplification/,/^## How to respond/d' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted a brief with a mandatory section removed"
  exit 1
fi

echo "PASS: brief validator rejects omitted mandatory sections"

sed 's/current APIs and constraints/current dependencies/' "$valid_brief" > "$shortened_brief"
if node "$BRIEF_VALIDATOR" "$shortened_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted a mandatory check that was shortened away"
  exit 1
fi

echo "PASS: brief validator rejects shortened-away mandatory checks"

sed \
  -e 's/diff the test files yourself/review the tests/' \
  -e 's/unrequested behavior change pass silently as a `blocker`/behavior change pass silently/' \
  "$valid_brief" > "$scope_shortened_brief"
if node "$BRIEF_VALIDATOR" "$scope_shortened_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted shortened-away scope-fidelity checks"
  exit 1
fi
echo "PASS: brief validator rejects shortened-away scope-fidelity checks"

sed 's/cross-provider independent review/unsupported review mode/' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted an unsupported review mode"
  exit 1
fi

echo "PASS: brief validator rejects unsupported review modes"

sed '/^## The task$/,/^## The original scope$/{ /Preserve behavior while simplifying the touched production code\./d; }' \
  "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted an empty required section"
  exit 1
fi

echo "PASS: brief validator rejects empty required sections"

sed 's/Issue 2228 and its accepted test design\./{{ORIGINAL_SCOPE}}/' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted an unresolved template field"
  exit 1
fi
echo "PASS: brief validator rejects unresolved template fields"

sed '/^## The task$/a\
## The task' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted a duplicated mandatory heading"
  exit 1
fi
echo "PASS: brief validator rejects duplicated mandatory headings"

sed 's#controllers/example.go:reconcile#production code was changed#' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted an unstructured production inventory"
  exit 1
fi
echo "PASS: brief validator rejects unstructured production inventories"

sed 's#controllers/example.go:reconcile#N/A — no production code changed\
controllers/example.go:reconcile#' "$valid_brief" > "$invalid_brief"
if node "$BRIEF_VALIDATOR" "$invalid_brief" >/dev/null 2>&1; then
  echo "FAIL: brief validator accepted mixed N/A and production identifiers"
  exit 1
fi
echo "PASS: brief validator rejects mixed production inventory states"

node -e '
  const fs = require("node:fs");
  const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (value.provider !== "anthropic" || value.reviewer !== "Claude Sonnet 5" ||
      value.model !== "sonnet" || value.effort !== "high" ||
      value.surface !== "claude-desktop" || value.permission_mode !== "plan" ||
      value.fallback_surface !== "sdk-cli" || value.max_rounds !== 4) {
    process.exit(1);
  }
' "$REVIEWER_PREFERENCES"
echo "PASS: persistent reviewer preferences select visible Claude Desktop, Sonnet 5, high effort, Plan mode, and four rounds"

inventory="$(mktemp)"
report="$(mktemp)"
trap 'rm -f "$valid_brief" "$invalid_brief" "$shortened_brief" "$scope_shortened_brief" "$inventory" "$report"' EXIT
printf '%s\n' '[{"id":"controllers/a.go:first"},{"id":"controllers/a.go:second"}]' > "$inventory"
printf '%s\n' '{"production_assessment":[{"symbol":"controllers/a.go:first","disposition":"keep","priority":"Skip","rationale":"already direct"}],"inventory_omissions":[]}' > "$report"
if node "$PANEL_COVERAGE_CHECKER" "$inventory" "$report" >/dev/null 2>&1; then
  echo "FAIL: panel coverage checker accepted an omitted production symbol"
  exit 1
fi
echo "PASS: panel coverage checker rejects omitted production symbols"

printf '%s\n' '{"production_assessment":[{"symbol":"controllers/a.go:first","disposition":"keep","priority":"Skip","rationale":"already direct"},{"symbol":"controllers/a.go:second","disposition":"simplify now","priority":"High","rationale":"obsolete adapter"}],"inventory_omissions":[]}' > "$report"
node "$PANEL_COVERAGE_CHECKER" "$inventory" "$report" >/dev/null
echo "PASS: panel coverage checker accepts a complete production assessment"

printf '%s\n' '{"production_assessment":[{"symbol":"controllers/a.go:first","disposition":"keep","priority":"Skip","rationale":"already direct"},{"symbol":"controllers/a.go:second","disposition":"keep","priority":"Skip","rationale":"already direct"}],"inventory_omissions":["controllers/b.go:missed"]}' > "$report"
if node "$PANEL_COVERAGE_CHECKER" "$inventory" "$report" >/dev/null 2>&1; then
  echo "FAIL: panel coverage checker accepted a scout inventory omission"
  exit 1
fi
echo "PASS: panel coverage checker rejects scout inventory omissions"

printf '%s\n' '{"production_assessment":[{"symbol":"controllers/a.go:first"},{"symbol":"controllers/a.go:second","disposition":"keep","priority":"Skip","rationale":"already direct"}],"inventory_omissions":[]}' > "$report"
if node "$PANEL_COVERAGE_CHECKER" "$inventory" "$report" >/dev/null 2>&1; then
  echo "FAIL: panel coverage checker accepted a hollow production assessment"
  exit 1
fi
echo "PASS: panel coverage checker rejects hollow production assessments"

printf '%s\n' '[]' > "$inventory"
printf '%s\n' '{"production_assessment":[],"inventory_omissions":[]}' > "$report"
node "$PANEL_COVERAGE_CHECKER" "$inventory" "$report" >/dev/null
echo "PASS: panel coverage checker accepts an explicit no-production-code result"
