# Deep Analysis Skill — Multi-Agent Adversarial Audit

Use this skill when asked to do a "deep analysis", "thorough audit", "final review", or "adversarial review" of an implementation plan. This runs 3 parallel subagents, each examining a different risk dimension, then synthesizes findings.

## When to Use

- After an implementation plan is complete and before committing to build
- When a plan touches 3+ repos or involves data model changes
- When asked: "are we missing anything?", "final check", "deep dive"
- As the last step before marking a ticket "ready to build"

## How to Run

Launch **exactly 3 subagents in parallel** using `runSubagent`. Each gets the full implementation plan as context, plus specific instructions for their dimension.

### Agent 1: Code Completeness Audit

Focus: Ensure EVERY code reference is accounted for.

Prompt template:
```
THOROUGH analysis. You are auditing an implementation plan for [FEATURE].
Your job is to EXHAUSTIVELY find every reference to [KEY_TERMS] across ALL repos.

1. Grep for all related patterns across all repos in the local repo paths
2. For each match, note file, line, and what it does
3. Cross-reference against the plan's file inventory
4. For every grep hit NOT in the plan, evaluate whether it needs changes
5. Check test files — are they listed? Do they need updates?
6. Verify any libraries marked "no changes needed" actually need no changes

Return: Complete grep summary, missing-from-plan files, test file inventory,
library verdicts, hidden dependencies, risk assessment (HIGH/MEDIUM/LOW)
```

### Agent 2: Migration & Rollback Safety Audit

Focus: Every intermediate deploy state must be safe.

Prompt template:
```
THOROUGH analysis. Auditing [FEATURE] for MIGRATION SAFETY, FEATURE FLAG
ROLLBACK, and DATA INTEGRITY.

1. Study existing migration patterns in the codebase (naming, execution model, rollback)
2. Analyze the data model changes in detail
3. Enumerate ALL intermediate states during rollout:
   - State A: Migration NOT run, new code deployed, flag OFF
   - State B: Migration run, new code deployed, flag OFF
   - State C: Migration run, new code deployed, flag ON (normal)
   - State D: Flag ON → turned OFF (rollback)
   - State E: Flag ON, code rolled back to old version
   - State F: Partial deploy — backend updated, frontend old
   - State G: Partial deploy — frontend updated, backend old
4. For each state, trace critical code paths
5. Identify data integrity risks ranked by severity
6. Check for database-specific concerns (indexes, atomic ops, doc size)

Return: Migration pattern analysis, state machine verdicts (A-G),
data integrity risks, recommended strategy, flag rollback safety, confidence
```

### Agent 3: Concurrency & Integration Edge Cases

Focus: Race conditions, feature interactions, lifecycle edge cases.

Prompt template:
```
THOROUGH analysis. Auditing [FEATURE] for CONCURRENCY, RACE CONDITIONS,
INTEGRATION EDGE CASES, and INTERACTION WITH OTHER FEATURES.

1. Deep-dive on concurrent operations (token refresh, parallel writes, etc.)
2. Trace the complete lifecycle of affected entities (e.g., offer lifecycle)
3. Analyze bulk operation implications
4. Check every feature that might interact with this change
5. Examine rate limits, error handling, retry logic
6. UI concurrency (simultaneous admin actions, stale state)
7. Session/subscription model — what's exposed to the client? Security concerns?

Return: Concurrency verdict, lifecycle trace, bulk ops risk,
feature interaction matrix, rate limit implications, UI concurrency risks,
security findings, top 5 risks not in plan, confidence
```

## Synthesis

After all 3 agents return, synthesize into a single section appended to the plan:

### Structure

```markdown
## Final Deep Analysis (3-Agent Audit)

### Analysis Scope
| Agent | Focus Area | Confidence |
|-------|-----------|------------|
| 1 | Code Completeness | [level] |
| 2 | Migration & Rollback Safety | [level] |
| 3 | Concurrency & Integration | [level] |

### [CRITICAL/HIGH findings — one section each]

### Deploy Order Requirement
[If partial deploy states revealed issues]

### Feature Flag Rollback Safety
[State machine summary table]

### Code Completeness Findings
[Missing files, test files, library verdicts]

### Feature Interaction Matrix
[Table of every feature that could interact]

### Offer/Entity Lifecycle Edge Cases
[Table of every lifecycle event and propagation status]

### Summary of All Action Items
| # | Item | Severity | Ticket | Effort |
[Ranked list with clear ownership]

### Overall Verdict
[Architecture assessment, blocking gaps, estimate impact, readiness status]
```

## Key Principles

1. **Every grep hit must be accounted for** — if it's not in the plan, evaluate it
2. **Every intermediate state must be safe** — partial deploys, rollbacks, flag toggles
3. **Pre-existing issues are noted but not blocking** — distinguish new risks from inherited ones
4. **Security findings are always CRITICAL** — token exposure, auth bypasses, etc.
5. **Actionable over theoretical** — every finding must have a concrete resolution or be explicitly accepted as a known risk
