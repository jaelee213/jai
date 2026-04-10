---
name: pr-management
description: >
  Pull request creation, feedback review, and comment resolution.
  Handles PR lifecycle with resilient fallbacks (MCP -> gh CLI -> gh API).
---

# PR Management

## Creating a PR

### Step 1: Gather Context
```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE=${BASE_BRANCH:-main}

# Get commit history for description
git log ${BASE}..HEAD --oneline --no-merges

# Get the full diff stat
git diff ${BASE}...HEAD --stat

# Get changed files for categorization
git diff ${BASE}...HEAD --name-only
```

### Step 2: Check for PR Template
```bash
# Check ALL common template locations
TEMPLATE=""
for f in \
  .github/pull_request_template.md \
  .github/PULL_REQUEST_TEMPLATE.md \
  .github/PULL_REQUEST_TEMPLATE/default.md \
  docs/pull_request_template.md \
  PULL_REQUEST_TEMPLATE.md; do
  if [ -f "$f" ]; then
    TEMPLATE="$f"
    echo "Found template: $f"
    cat "$f"
    break
  fi
done

if [ -z "$TEMPLATE" ]; then
  echo "No PR template found — using default format"
fi
```

**If a template exists, fill it out section by section.** Do not skip any section. If a section doesn't apply, write "N/A" with a reason.

### Step 3: Generate PR Title
Format: `<type>(<scope>): <short description>`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`

If the repo doesn't use conventional commits, match the style of recent PRs:
```bash
gh pr list --limit 10 --json title --jq '.[].title'
```

### Step 4: Generate PR Description

If no template exists, use this format:

```markdown
## Summary
<Concise description of what this PR does and why>

## Changes
<Categorized list of changes, grouped by area>

## Testing
- <How this was tested>
- <Test commands to verify>
- <Edge cases considered>

## Risk Assessment
- **Risk Level**: Low / Medium / High
- **Blast Radius**: <What could break>
- **Rollback Plan**: <How to undo if needed>
- **Feature Flag**: <yes/no, flag name if yes>

## Screenshots / Recordings
<If UI changes, include before/after>

## Related
- Ticket: <JIRA/Linear link if applicable>
- Related PRs: <if any>
- Docs: <if any docs need updating>
```

### Step 5: Create the PR

```bash
# Create the PR
gh pr create \
  --base "$BASE" \
  --title "<title>" \
  --body "<body>" \
  --assignee "@me"
```

If `gh` is not authenticated:
```bash
gh auth status
gh auth login
```

## Reviewing & Addressing PR Feedback

### Step 1: Fetch PR Info
```bash
# Get PR number for current branch
PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null)
if [ -z "$PR_NUMBER" ]; then
  echo "No PR found for current branch"
  exit 1
fi
echo "PR #$PR_NUMBER"
```

### Step 2: Fetch All Reviews and Comments

**Primary method (gh CLI):**
```bash
# Get review status
gh pr view "$PR_NUMBER" --json reviews --jq '.reviews[] | "\(.author.login): \(.state) - \(.body)"'

# Get PR-level comments
gh pr view "$PR_NUMBER" --json comments --jq '.comments[] | "\(.author.login): \(.body)"'

# Get inline code review comments (the important ones)
gh api "repos/{owner}/{repo}/pulls/${PR_NUMBER}/comments" \
  --jq '.[] | "[\(.path):\(.line // .original_line)] \(.user.login): \(.body)"'
```

**If the above fails** (MCP crash, auth issue, rate limit), fall back to:
```bash
# Fallback: get raw review data
gh pr diff "$PR_NUMBER" --name-only  # at least get what files were reviewed
gh pr checks "$PR_NUMBER"            # get CI status
```

### Step 3: Process Each Comment

Create a tracking list of every comment:

```markdown
| # | File:Line | Author | Comment | Status | Action |
|---|-----------|--------|---------|--------|--------|
| 1 | file.ts:42 | reviewer | "..." | pending | fix / reply / discuss |
```

For each comment:

1. **Read the full context** — Read the file, understand what the reviewer is pointing at
2. **Assess validity**:
   - ✅ **Valid, will fix** — Make the change. Err on the side of accepting feedback.
   - 🤔 **Debatable** — If you genuinely disagree, explain with code evidence. Never dismiss without reasoning.
   - ❌ **Incorrect** — The reviewer misread the code. Show them the context they missed. Be respectful.
   - ℹ️ **Question/Clarification** — Answer the question directly. Add a code comment if it would help future readers too.
3. **Make the fix** if applicable — edit the actual code
4. **Draft a reply** for each comment thread

### Step 4: Reply to Comments

```bash
# Reply to an inline review comment by comment ID
COMMENT_ID=<id>
gh api "repos/{owner}/{repo}/pulls/comments/${COMMENT_ID}/replies" \
  -f body="<your response>"

# Or reply to a PR-level comment
gh pr comment "$PR_NUMBER" --body "<summary of all changes made>"
```

### Step 5: Push and Summarize

```bash
# Stage and commit fixes
git add -A
git commit -m "Address PR review feedback

$(cat << COMMIT_BODY
Changes made:
- <summary of fix 1>
- <summary of fix 2>
- <summary of fix 3>

Threads addressed: <count>
COMMIT_BODY
)"

# Push
git push
```

After pushing, post a summary comment on the PR:
```bash
gh pr comment "$PR_NUMBER" --body "Addressed all review feedback. Summary of changes:
- <change 1>
- <change 2>

Please re-review when you get a chance."
```

## Rules
- Address EVERY comment — never skip any, even nits
- Actually edit the code files — don't just say what you'd change
- If you disagree with feedback, provide evidence (code, docs, benchmarks)
- Group related fixes into a single commit
- Always push after making changes
- Always leave a summary comment on the PR after addressing feedback
- If a comment requires a larger refactor beyond this PR's scope, say so and suggest a follow-up
