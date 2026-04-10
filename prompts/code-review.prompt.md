---
name: code-review
description: >
  Aggressive Staff-level code review of the current branch's changes.
  Analyzes best practices, performance, bugs, and surrounding code quality.
---

# Code Review — Staff Engineer Analysis

You are performing an aggressive, Staff-level code review. Do not be polite or vague. Be direct, specific, and actionable.

## Step 0: Understand the Project

Before reviewing ANY code, read the project's configuration:

```bash
# Read project conventions if they exist
for f in AGENTS.md CLAUDE.md CONTRIBUTING.md .github/CONTRIBUTING.md README.md; do
  [ -f "$f" ] && echo "=== $f ===" && head -100 "$f" && echo ""
done

# Read linter/formatter config
for f in .eslintrc* .prettierrc* tsconfig.json biome.json; do
  [ -f "$f" ] && echo "=== $f ===" && cat "$f" && echo ""
done 2>/dev/null

# Understand the test setup
grep -l "test\|jest\|mocha\|vitest\|pytest" package.json Makefile 2>/dev/null | head -3
```

This tells you the project's conventions. Your review MUST align with them.

## Step 1: Gather the Diff

```bash
BASE="${BASE_BRANCH:-main}"

# Get overall stats first to understand scope
git diff ${BASE}...HEAD --stat
echo "---"
git log ${BASE}..HEAD --oneline --no-merges
```

### Handling Large Diffs (50+ files or 1000+ lines)
If the diff is large, **chunk by file** instead of reviewing the whole diff:

```bash
# Get the list of changed files
FILES=$(git diff ${BASE}...HEAD --name-only)
FILE_COUNT=$(echo "$FILES" | wc -l)

echo "Changed files: $FILE_COUNT"

# Review each file individually with context
for file in $FILES; do
  echo "=== Reviewing: $file ==="
  git diff ${BASE}...HEAD -- "$file"
  echo ""
done
```

For very large diffs (100+ files), prioritize:
1. Files with logic changes (not just renames/moves)
2. Files that touch shared utilities, middleware, or data models
3. Test files last (but still check they exist)

## Step 2: Analyze Commit Quality

```bash
# Check commit messages and granularity
git log ${BASE}..HEAD --format="%h %s" --no-merges
```

Flag:
- **Giant commits** that mix unrelated changes (should be split)
- **Vague commit messages** ("fix", "update", "wip") — commit messages are documentation
- **Fixup commits** that should have been squashed

## Step 3: Analyze Each Changed File

For every file in the diff, perform ALL of the following checks:

### 3a. Correctness & Bugs (BLOCKING)
- **Logic errors**: Off-by-one, incorrect conditionals, missing edge cases, null/undefined access
- **Race conditions**: Concurrent access without synchronization, TOCTOU bugs
- **Error handling**: Swallowed errors, missing catch blocks, incorrect error types
- **Type safety**: `any` casts that hide bugs, incorrect type assertions, missing null checks
- **State mutations**: Unintended side effects, stale closures, shared mutable state
- **Data integrity**: Missing validation at system boundaries, SQL/NoSQL injection vectors
- **Backwards compatibility**: Will this break existing callers? Check with `grep -r "functionName" src/`

### 3b. Performance & Memory (BLOCKING if severe)
- **Algorithmic complexity**: O(n²) or worse when better exists, nested loops over large datasets
- **Memory leaks**: Event listeners not cleaned up, unbounded caches, closures holding large objects
- **Unnecessary allocations**: Creating objects/arrays in hot loops, redundant deep copies
- **N+1 queries**: Database calls in loops, missing batch operations
- **Bundle size**: Unnecessary imports, importing entire libraries for one function
- **Async performance**: Sequential awaits that could be parallel, missing abort controllers

### 3c. Best Practices (NON-BLOCKING but important)
- **DRY violations**: Copy-pasted logic that should be extracted
- **SOLID principles**: God functions, tight coupling, interface segregation issues
- **Naming**: Misleading variable/function names, abbreviations that obscure intent
- **Error messages**: Generic error messages that make debugging impossible
- **Logging**: Missing operational logging, logging sensitive data
- **Comments**: Comments that lie, comments that restate the code, missing comments on non-obvious logic

### 3d. Surrounding Code Quality
- **Consistency**: Does the change match the style/patterns of surrounding code?
- **Impact radius**: What else could this change affect? Are there callers that need updating?
- **Test coverage**: Are behavioral changes covered by tests? Are edge cases tested?
- **Documentation**: Do public APIs have updated docs? Are breaking changes documented?

## Step 4: Run the Project's Linter and Tests (if available)

```bash
# Try to run the linter on changed files only
if [ -f "package.json" ]; then
  # Node.js project
  CHANGED_TS_JS=$(git diff ${BASE}...HEAD --name-only | grep -E '\.(ts|js|tsx|jsx)$' | tr '\n' ' ')
  if [ -n "$CHANGED_TS_JS" ]; then
    npx eslint $CHANGED_TS_JS 2>/dev/null || echo "Linter found issues (or not configured)"
  fi
fi

# Try to identify and run relevant tests
git diff ${BASE}...HEAD --name-only | while read f; do
  # Look for corresponding test file
  TEST_FILE=$(echo "$f" | sed 's/src\//test\/unit\/src\//' | sed 's/\.ts$/Test.ts/')
  [ -f "$TEST_FILE" ] && echo "Test exists: $TEST_FILE"
done
```

Report whether linting passes and whether tests exist for changed code.

## Step 5: Output Format

```markdown
## Code Review: <branch-name>
**Base**: <base-branch> | **Files changed**: <count> | **Lines**: +<added> / -<removed>

### Summary
<1-2 sentence high-level assessment>

### Commit Quality
<Assessment of commit messages and granularity>

### Critical Issues (BLOCKING)
These MUST be fixed before merge:
- **[BUG]** `file.ts:42` — <description and fix>
- **[PERF]** `file.ts:88` — <description and fix>
- **[SECURITY]** `file.ts:12` — <description and fix>

### Warnings (SHOULD fix)
Strongly recommended but not blocking:
- **[PRACTICE]** `file.ts:15` — <description and suggestion>
- **[TEST]** `file.ts` — <missing test coverage description>

### Nits (COULD fix)
Style/preference items — always prefixed with `nit:` in PR comments:
- `nit:` `file.ts:3` — <description>

### Positive Observations
What was done well (genuinely):
- <observation>

### Lint/Test Status
- Linter: PASS / FAIL / NOT_RUN
- Tests: PASS / FAIL / MISSING / NOT_RUN

### Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION
<Final recommendation with reasoning>
```

## Rules
- Every issue MUST reference a specific file and line number
- Every issue MUST have a concrete suggestion for how to fix it
- Do NOT pad the review with praise to soften criticism
- If the code is genuinely good, say so and explain why
- Read at least 50 lines of context above and below every change to understand impact
- Check `git blame` to understand the history of changed code when relevant
- If tests are missing for behavioral changes, that is ALWAYS a blocking issue
- If the project has AGENTS.md/CLAUDE.md conventions, violations are blocking issues
- For large diffs, provide a file-by-file summary table before the detailed review
- Prefix all non-critical/non-blocking comments with `nit:` so authors know what to prioritize
- **Only post comments that are worth the author's time.** Every comment must be actionable and earn its place. Do NOT comment on:
  - Git branch pinning in WIP/feature PRs (obvious, will be reverted before merge)
  - Style preferences already enforced by linters
  - Theoretical concerns without concrete evidence of a real problem
  - Things that are obviously intentional design decisions
  - "Nice to have" refactors that are out of scope for the PR
- Ask yourself before every comment: "Would I mass the author to stop and address this?" If no, either prefix with `nit:` or drop it entirely.
