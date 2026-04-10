---
name: pr-management
description: >
  Pull request creation, feedback review, and comment resolution.
  Handles PR lifecycle with resilient fallbacks (MCP -> gh CLI).
---

# PR Management

## Creating a PR

### Step 1: Gather Context
```bash
# Get branch info
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
Look for PR templates in the repo:
```bash
# Check common locations for PR templates
for f in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md \
         .github/PULL_REQUEST_TEMPLATE/*.md docs/pull_request_template.md; do
  if [ -f "$f" ]; then
    echo "Found template: $f"
    cat "$f"
    break
  fi
done
```

If a template exists, fill it out. If not, use the default format below.

### Step 3: Generate PR Description

Default format (use repo template if available):

```markdown
## Summary
<Concise description of what this PR does and why>

## Changes
- <Categorized list of changes>

## Testing
- <How this was tested>
- <Test commands to verify>

## Risk Assessment
- **Risk Level**: Low/Medium/High
- **Rollback Plan**: <How to revert if needed>

## Related
- Ticket: <JIRA/Linear link if applicable>
- Related PRs: <if any>
```

### Step 4: Create the PR
Try MCP GitHub tools first, fall back to `gh` CLI:

```bash
gh pr create --base "$BASE" --title "<title>" --body "<body>"
```

## Reviewing PR Feedback

### Step 1: Fetch Comments and Reviews
Try MCP tools first. If they fail/crash, fall back immediately:

```bash
# Get PR number
PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null)

# Get all reviews and comments
gh pr view "$PR_NUMBER" --json reviews,comments --jq '.'

# Get review comments (inline code comments)
gh api "repos/{owner}/{repo}/pulls/${PR_NUMBER}/comments" | head -200
```

### Step 2: Process Each Comment
For each review comment:

1. **Read the comment** — Understand what the reviewer is asking
2. **Check validity** — Is the feedback correct? Does it apply to the current code?
3. **Categorize**:
   - ✅ **Valid and actionable** — Make the fix
   - 🤔 **Valid but debatable** — Present your reasoning, ask what they'd prefer
   - ❌ **Incorrect or outdated** — Explain why respectfully with evidence
4. **Address it** — Either fix the code or reply with a clear explanation

### Step 3: After Addressing All Comments
```bash
# Stage and commit the fixes
git add -A
git commit -m "Address PR feedback

- <summary of changes made>
"

# Push the changes
git push
```

### Feedback Response Rules
- Address EVERY comment — do not skip any
- If you disagree, provide code evidence or documentation links
- Group related fixes into a single commit when possible
- Reply to each comment thread with what action was taken
- If a comment requires a larger refactor, note it and create a follow-up ticket suggestion
