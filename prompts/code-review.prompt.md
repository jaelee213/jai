---
name: code-review
description: >
  Aggressive Staff-level code review of the current branch's changes.
  Analyzes best practices, performance, bugs, and surrounding code quality.
---

# Code Review — Staff Engineer Analysis

You are performing an aggressive, Staff-level code review. Do not be polite or vague. Be direct, specific, and actionable.

## Step 1: Gather the Diff

Run the following to get the changes on the current branch relative to the base:

```
git diff main...HEAD
```

If a different base branch was specified, use that instead. Also gather context:

```
git log main..HEAD --oneline
git diff main...HEAD --stat
```

## Step 2: Analyze Each Changed File

For every file in the diff, perform ALL of the following checks:

### 2a. Correctness & Bugs (BLOCKING)
- **Logic errors**: Off-by-one, incorrect conditionals, missing edge cases, null/undefined access
- **Race conditions**: Concurrent access without synchronization, TOCTOU bugs
- **Error handling**: Swallowed errors, missing catch blocks, incorrect error types
- **Type safety**: `any` casts that hide bugs, incorrect type assertions, missing null checks
- **State mutations**: Unintended side effects, stale closures, shared mutable state
- **Data integrity**: Missing validation at system boundaries, SQL/NoSQL injection vectors

### 2b. Performance & Memory (BLOCKING if severe)
- **Algorithmic complexity**: O(n²) or worse when better exists, nested loops over large datasets
- **Memory leaks**: Event listeners not cleaned up, unbounded caches, closures holding large objects
- **Unnecessary allocations**: Creating objects/arrays in hot loops, redundant deep copies
- **N+1 queries**: Database calls in loops, missing batch operations
- **Bundle size**: Unnecessary imports, importing entire libraries for one function
- **Async performance**: Sequential awaits that could be parallel, missing abort controllers

### 2c. Best Practices (NON-BLOCKING but important)
- **DRY violations**: Copy-pasted logic that should be extracted
- **SOLID principles**: God functions, tight coupling, interface segregation issues
- **Naming**: Misleading variable/function names, abbreviations that obscure intent
- **Error messages**: Generic error messages that make debugging impossible
- **Logging**: Missing operational logging, logging sensitive data
- **Comments**: Comments that lie, comments that restate the code, missing comments on non-obvious logic

### 2d. Surrounding Code Quality
- **Consistency**: Does the change match the style/patterns of surrounding code?
- **Impact radius**: What else could this change affect? Are there callers that need updating?
- **Test coverage**: Are behavioral changes covered by tests? Are edge cases tested?
- **Documentation**: Do public APIs have updated docs? Are breaking changes documented?

## Step 3: Output Format

Structure your review as:

```
## Code Review: <branch-name>

### Summary
<1-2 sentence high-level assessment>

### Critical Issues (BLOCKING)
These MUST be fixed before merge:
- **[BUG]** `file.ts:42` — <description and fix>
- **[PERF]** `file.ts:88` — <description and fix>

### Warnings (SHOULD fix)
Strongly recommended but not blocking:
- **[PRACTICE]** `file.ts:15` — <description and suggestion>

### Nits (COULD fix)
Style/preference items:
- `file.ts:3` — <description>

### Positive Observations
What was done well (genuinely):
- <observation>

### Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION
<Final recommendation with reasoning>
```

## Rules
- Every issue MUST reference a specific file and line number
- Every issue MUST have a concrete suggestion for how to fix it
- Do NOT pad the review with praise to soften criticism
- If the code is genuinely good, say so and explain why
- Read at least 50 lines of context above and below every change to understand impact
- Check git blame to understand the history of changed code when relevant
- If tests are missing for behavioral changes, that is ALWAYS a blocking issue
