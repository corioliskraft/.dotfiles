---
name: refactoring
description: Refactoring assessment and behavior-preserving patterns for code with a passing baseline and proportionate preservation evidence. Use when the user asks to clean up, tidy, simplify, restructure, deduplicate, collapse, or merge look-alike code in a selected area, or after GREEN establishes the passing baseline for any TDD increment that changed production code. Mutation testing verifies the accumulated result later at the end-of-phase PR-readiness gate. Covers recoverable-baseline discipline, when refactoring adds value vs when to skip it, and priority classification; commits always require explicit user approval. For any slice in a selected whole-path reduction program—transition or terminal—use reduce-system-complexity as the governing skill and use refactoring for the required touched-production assessment. For repository-wide architecture discovery use improve-codebase-architecture; for a module contract use codebase-design. Do NOT use for insufficiently evidenced code or adding behavior.
---

# Refactoring

Refactoring is the final step of each fast RED-GREEN-REFACTOR increment. Whenever production code changed, the **assessment is mandatory** after GREEN establishes a passing behavior-test baseline; making a refactoring edit remains optional. Do not run the automated mutation harness before or after each refactor; mutation testing verifies the completed phase once the work is otherwise ready for a PR.

Because automated mutation evidence is intentionally deferred, the baseline's strength is not yet mutation-harness-verified during refactoring. Keep each refactor small, strictly behavior-preserving, and green under the existing oracles; the final gate validates the accumulated result.

This skill safely implements a bounded, behavior-preserving improvement. Use `improve-codebase-architecture` to discover and rank architecture candidates, then `codebase-design` to design a selected module contract before returning here for implementation. If the slice participates in a selected whole-path reduction program, whether as a transition or terminal reduction, `reduce-system-complexity` governs the ledger and gate state; when production code changes, use this skill for the required secondary touched-symbol assessment.

## When to Refactor

- Assess after GREEN or another passing proportionate preservation baseline
- Run the applicable tests yourself before you assess, before your first edit, and before any reply that declines to edit. Declining a request, or classifying every candidate Skip, is still an assessment, and an assessment that rests on no test run rests on nothing
- Inventory every changed production function or symbol in the selected diff before deciding that the code is clean. Exclude generated and vendored code, and do not widen the review target to untouched code merely because it is nearby
- Give every inventoried symbol one disposition: `keep`, `simplify now`, or `follow-up`, with a one-line rationale. A clean assessment explicitly records `keep`; silence is not coverage
- Before the first edit, list every candidate change and label each one Critical, High, Nice or Skip
- Whether you changed everything, one thing, or nothing, the final reply must carry that labelled list, Skip items included, as one line per candidate — `<Critical|High|Nice|Skip>: <keep|simplify now|follow-up> · <file:symbol> — <rationale>` — closed by a `Decision: <what you did or did not do>` line. A summary of what changed is not an assessment, and neither is an unlabelled recommendation. An unstated assessment is an unmade assessment
- When every candidate is Skip, say so in those words and change nothing
- Only refactor if it improves the code
- **Establish a verified, recoverable baseline before refactoring; commit only with explicit user approval**

### Touched-Production Scan

For every changed production function or symbol, ask the same small set of
general questions. They are intentionally broader than any particular syntax:

1. Is every new mechanism necessary for the behavior or guarantee being delivered?
2. Can the same behavior be expressed more directly with fewer indirections or states?
3. Is copied or legacy structure still appropriate under the current APIs and constraints?
4. Is every abstraction, dependency, parameter, and exported symbol justified by a current caller or rule?
5. Do context, state, ownership, effects, and errors cross the correct boundary?
6. Did the change duplicate knowledge or preserve obsolete structure?

Record one line per touched symbol in this combined shape:

```text
High: simplify now · path/to/file.ts:changedFunction — remove an obsolete adapter layer; the current API accepts the callback directly.
Skip: keep · path/to/file.ts:alreadyDirect — already expresses the behavior directly with justified dependencies.
Nice: follow-up · path/to/file.ts:legacySibling — related cleanup is real but outside the selected diff.
```

The priority class governs urgency; the disposition governs this boundary. Do
not turn `follow-up` into permission to edit outside the agreed scope.

### Establish a Recoverable Baseline - WHY

Having a working baseline before refactoring:
- Allows reverting if refactoring breaks things
- Provides safety net for experimentation
- Makes refactoring less risky
- Can show clear separation in git history when the user authorizes commits

If the baseline cannot be restored safely without creating a commit, stop and ask for approval rather than committing implicitly.

**Workflow:**
1. BASELINE: Applicable tests pass and/or the conserved behavior and guarantees have proportionate evidence
2. CHECKPOINT: Record the baseline and preservation evidence. Create a baseline commit only when the user explicitly approves it
3. REFACTOR: Improve structure in small steps under the `tdd` skill's canonical fast-feedback policy. From a clean baseline, prefer a proven repository-owned graph-complete watcher; use diff-selected Vitest watch only when the installed version/configuration has passed the canonical clean-start live proof, otherwise repeat the affected one-shot. In monorepos use the root graph so transitive consumers remain eligible
4. VERIFY: Keep focused and affected tests plus other proportionate evidence green after each step; do not rerun the full suite after every edit
5. CHECKPOINT: Present the verified refactor together with the complete touched-production inventory, labelled `Critical`/`High`/`Nice`/`Skip` assessment, `keep`/`simplify now`/`follow-up` dispositions, and the closing `Decision:` line; a summary of what changed does not close this step. Commit it only after explicit user approval
6. PRE-PR GATE: When the phase is otherwise ready for a PR, run mutation testing once for the accumulated scope where meaningful, or record explicit `N/A` plus proportionate alternate evidence; address valuable survivors within that gate

## Priority Classification

| Priority | Action | Examples |
|----------|--------|----------|
| Critical | Fix now | Behavior-changing mutation, divergent copies of one business rule, control flow that obscures a high-risk path |
| High | This session | Magic numbers (one constant per rule; two rules that merely share a value today each get their own), unclear names, functions coordinating multiple responsibilities |
| Nice | Later | Minor naming, single-use helpers |
| Skip | Don't change | Already clean code |

## DRY = Knowledge, Not Code

**Abstract when**:
- Same business concept (semantic meaning)
- Would change together if requirements change
- Obvious why grouped together

**Keep separate when**:
- Different concepts that look similar (structural)
- Would evolve independently
- Coupling would be confusing

Two rules that share a body or a number today are a coincidence, not shared knowledge. Keep separate means keep each rule's own body and its own named constant even when the two values are equal; never define one rule in terms of the other and never route both through a shared predicate helper, because that makes one edit silently change two business rules. When a request asks you to fold such look-alikes into one, do not do it. Run the applicable tests before you answer even though you are changing nothing — the refusal is an assessment and needs the same green baseline as an edit. Then name the two different rules, say they would drift apart the moment either changes, leave both definitions standing, and offer only the changes that do not merge them.

## Example Assessment - Write This Shape Into Your Reply

```typescript
// After GREEN establishes a passing behavior-test baseline:
const planBatch = (batch: Batch): PlannedBatch => {
  const itemSlots = batch.items.reduce((sum, item) => sum + item.quantity, 0);
  const bufferSlots = itemSlots > 50 ? 0 : 6;
  return { ...batch, plannedSlots: itemSlots + bufferSlots, bufferSlots };
};

// ASSESSMENT:
// ⚠️ High: Magic numbers 50, 6 → extract constants
// ✅ Skip: Structure is clear enough
// DECISION: Extract constants only
```

## New Behavior Needs Evidence

Do not add new behavior without a failing test or other repository-authorized
acceptance proof that demands it. A behavior-preserving refactor may change
lines without a new RED test only while proportionate preservation evidence
stays green. At PR readiness, use mutation evidence for the accumulated scope
where meaningful and explicit alternate evidence where it is not; never invent
structural mutants.

❌ **Speculative additions:**
- "Just in case" logic
- Features not yet needed
- Abstractions written only for imagined future flexibility
- New error behavior with no accepted contract

✅ **Correct approach**: Do not add the speculative behavior. If it is needed,
write a failing test that demands it, then implement it.

Existing untested code is not proven speculative or dead. Before removing a
branch, characterize its observable behavior, inspect every caller and
reachability path, and resolve the behavior authority. Delete it only when the
evidence shows it is unreachable or the accepted contract explicitly retires
it, then keep the preservation/regression checks green.

```typescript
// ❌ WRONG - Speculative error handling (no test demands this)
if (items.length === 0) {
  throw new Error('Empty cart'); // No test for this path!
}

// ✅ CORRECT - Test-driven error handling
// First: write a test that expects this behavior
// Then: implement the guard clause to make it pass
```

---

## When NOT to Refactor

Don't refactor when:

- ❌ The current structure isn't impeding the work at hand (clean-enough working code needs no restructuring)
- ❌ Speculative generality — restructuring for requirements that don't exist yet
- ❌ Would change behavior (that's a feature, not refactoring)
- ❌ Premature optimization
- ❌ Code is "good enough" for current phase
- ❌ **Extracting purely for testability** — if the only reason to move code into a separate file is "so we can unit test it", keep it inline. The consuming function already has behavioral tests that cover this code. Extract for readability, DRY (same knowledge used in multiple places — see "DRY = Knowledge, Not Code" above), or separation of concerns, never for testability alone.

**Remember**: Refactoring should improve code structure without changing behavior.

---

## Commit Messages for Refactoring

When the user approves a refactoring commit, use a focused message such as:

```
refactor: extract scenario validation logic
refactor: simplify error handling flow
refactor: rename ambiguous parameter names
```

**Format**: `refactor: <what was changed>`

**Note**: When commits are used, refactoring commits should not be mixed with feature commits.

---

## Refactoring Checklist

- [ ] Existing behavior tests pass; test edits are not hiding a behavior change
- [ ] Every changed production function or symbol has a `keep`, `simplify now`, or `follow-up` disposition with a rationale
- [ ] Focused/affected tests stayed green during refactoring, and the repository-defined complete non-watch PR test gate passes before PR
- [ ] If the refactored phase is ready for a PR, mutation results were reviewed once for the accumulated scope where meaningful, or explicit `N/A` plus proportionate alternate evidence was recorded
- [ ] No unplanned consumer-facing API was added; internal or temporary contracts follow the selected design and compatibility plan
- [ ] Code more readable than before
- [ ] Any commits were explicitly approved and kept separate from features
- [ ] A verified, recoverable baseline was established; a baseline commit was created only if approved
- [ ] No speculative code added
- [ ] Behavior unchanged within the confidence and fidelity of the passing preservation evidence
