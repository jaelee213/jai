# Code Review Skill

## Pre-Review Checklist
Before reviewing, always gather:
1. The full diff: `git diff <base>...HEAD`
2. The diff stats: `git diff <base>...HEAD --stat`
3. Commit messages: `git log <base>..HEAD --oneline`
4. Any CI/CD status if available

## Severity Levels
- **P0 (Critical)**: Security vulnerability, data loss, crash. MUST block merge.
- **P1 (High)**: Bug that affects functionality, performance regression. SHOULD block merge.
- **P2 (Medium)**: Code smell, missing test, unclear logic. Should be addressed.
- **P3 (Low)**: Style nit, naming preference, optional improvement.

## Common Patterns to Flag

### TypeScript/JavaScript
- `any` type that should be specific
- Missing `await` on async calls
- `==` instead of `===`
- Mutable default parameters
- Missing error boundaries in React
- `useEffect` with missing or wrong dependencies
- Unbounded `.map()` / `.filter()` chains on large arrays
- `JSON.parse()` without try/catch
- Template literals with user input (XSS risk)
- `dangerouslySetInnerHTML` usage

### Database/ORM
- N+1 query patterns
- Missing indexes for new query patterns
- Unbounded queries (no limit)
- Schema changes without migration plan

### General
- Commented-out code being committed
- Console.log / debug statements
- Hardcoded secrets or credentials
- Missing input validation at system boundaries
- Overly broad catch blocks
