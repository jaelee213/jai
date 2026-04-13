#!/usr/bin/env bash
set -euo pipefail

JAI_DIR="$(cd "$(dirname "$0")" && pwd)"
VSCODE_PROMPTS_DIR="${HOME}/Library/Application Support/Code/User/prompts"


# Color helpers for install output
_green() { printf "\033[0;32m%s\033[0m\n" "$*"; }
_dim()   { printf "\033[0;90m%s\033[0m\n" "$*"; }
_red()   { printf "\033[0;31m%s\033[0m\n" "$*"; }
echo "=== Jai Agent Installer ==="
echo ""

# Step 1: Symlink into VS Code user prompts directory
echo "[1/3] Setting up VS Code Copilot integration..."
mkdir -p "$VSCODE_PROMPTS_DIR"

for prompt in "$JAI_DIR"/prompts/*.prompt.md; do
  filename=$(basename "$prompt")
  target="$VSCODE_PROMPTS_DIR/$filename"
  [ -L "$target" ] || [ -f "$target" ] && rm -f "$target"
  ln -s "$prompt" "$target"
  echo "  → $filename"
done

AGENT_TARGET="$VSCODE_PROMPTS_DIR/jai.agent.md"
[ -L "$AGENT_TARGET" ] || [ -f "$AGENT_TARGET" ] && rm -f "$AGENT_TARGET"
ln -s "$JAI_DIR/jai.agent.md" "$AGENT_TARGET"
echo "  → jai.agent.md"

# Step 2: Install CLI
echo ""
echo "[2/3] Installing CLI..."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/jai" << 'CLI_INNER_EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
JAI_HOME="__JAI_DIR__"
BASE_BRANCH="${JAI_BASE:-main}"

# --- Helpers ---
red()   { printf "\033[0;31m%s\033[0m\n" "$*"; }
green() { printf "\033[0;32m%s\033[0m\n" "$*"; }
dim()   { printf "\033[0;90m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

ensure_git() {
  git rev-parse --is-inside-work-tree &>/dev/null || { red "Not in a git repo"; exit 1; }
}

ensure_gh() {
  command -v gh &>/dev/null || { red "gh CLI not installed. Run: brew install gh"; exit 1; }
  gh auth status &>/dev/null || { red "gh not authenticated. Run: gh auth login"; exit 1; }
}

# --- Commands ---

do_review() {
  ensure_git
  local base="${1:-$BASE_BRANCH}"

  bold "Code Review: $(git rev-parse --abbrev-ref HEAD) vs $base"
  echo ""

  # Stats
  local stat_output
  stat_output=$(git diff "$base"...HEAD --stat 2>/dev/null || git diff "$base"..HEAD --stat)
  echo "$stat_output"
  echo ""

  local file_count
  file_count=$(git diff "$base"...HEAD --name-only 2>/dev/null | wc -l | tr -d ' ')
  local line_summary
  line_summary=$(git diff "$base"...HEAD --shortstat 2>/dev/null || echo "unknown")

  dim "Files changed: $file_count | $line_summary"
  dim "Commits: $(git log "$base"..HEAD --oneline --no-merges 2>/dev/null | wc -l | tr -d ' ')"
  echo ""

  if [ "$file_count" -gt 50 ]; then
    red "⚠ Large diff ($file_count files). Review will be chunked by file."
  fi

  echo "Opening VS Code Copilot with review prompt..."
  echo ""

  # Open in VS Code and copy prompt
  local prompt="@jai review this branch against \`$base\`. Follow prompts/code-review.prompt.md exactly."
  if command -v code &>/dev/null; then
    echo "$prompt" | pbcopy 2>/dev/null || true
    green "Prompt copied to clipboard. Open Copilot Chat (Cmd+Shift+I) and paste."
    echo ""
    dim "Or ask @jai directly: 'review' or 'cr'"
  else
    echo "$prompt"
  fi
}

do_pr_create() {
  ensure_git
  ensure_gh
  local base="${1:-$BASE_BRANCH}"
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)

  bold "Creating PR: $branch → $base"
  echo ""

  # Check for existing PR
  if gh pr view &>/dev/null 2>&1; then
    local existing_url
    existing_url=$(gh pr view --json url -q '.url')
    red "PR already exists: $existing_url"
    echo "Use 'jai pr feedback' to address review comments."
    exit 1
  fi

  # Show what will be in the PR
  git log "$base"..HEAD --oneline --no-merges
  echo ""
  git diff "$base"...HEAD --stat 2>/dev/null || git diff "$base"..HEAD --stat
  echo ""

  # Check for PR template
  local template=""
  for f in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md \
           .github/PULL_REQUEST_TEMPLATE/default.md docs/pull_request_template.md; do
    if [ -f "$f" ]; then
      template="$f"
      green "Found PR template: $f"
      break
    fi
  done

  [ -z "$template" ] && dim "No PR template found — will use default format"
  echo ""

  local prompt="@jai Create a PR for branch \`$branch\` targeting \`$base\`. Follow prompts/pr-management.prompt.md exactly."
  if command -v code &>/dev/null; then
    echo "$prompt" | pbcopy 2>/dev/null || true
    green "Prompt copied to clipboard. Open Copilot Chat (Cmd+Shift+I) and paste."
  else
    echo "$prompt"
  fi
}

do_pr_feedback() {
  ensure_git
  ensure_gh

  local pr_number
  pr_number=$(gh pr view --json number -q '.number' 2>/dev/null || true)

  if [ -z "$pr_number" ]; then
    red "No PR found for current branch."
    exit 1
  fi

  bold "PR #$pr_number — Fetching feedback..."
  echo ""

  # Show review status
  echo "Reviews:"
  gh pr view "$pr_number" --json reviews --jq '.reviews[] | "  \(.author.login): \(.state)"' 2>/dev/null || dim "  (none)"
  echo ""

  # Show comment count
  local comment_count
  comment_count=$(gh api "repos/{owner}/{repo}/pulls/${pr_number}/comments" --jq 'length' 2>/dev/null || echo "?")
  echo "Inline review comments: $comment_count"

  local pr_comment_count
  pr_comment_count=$(gh pr view "$pr_number" --json comments --jq '.comments | length' 2>/dev/null || echo "?")
  echo "PR-level comments: $pr_comment_count"
  echo ""

  # Show CI status
  echo "CI Status:"
  gh pr checks "$pr_number" 2>/dev/null || dim "  (no checks)"
  echo ""

  local prompt="@jai Address all review feedback on PR #$pr_number. Follow prompts/pr-management.prompt.md exactly. Fetch comments, make code fixes, push, and reply to each thread."
  if command -v code &>/dev/null; then
    echo "$prompt" | pbcopy 2>/dev/null || true
    green "Prompt copied to clipboard. Open Copilot Chat (Cmd+Shift+I) and paste."
  else
    echo "$prompt"
  fi
}

do_cxe() {
  local subcmd="${1:-}"
  local ticket="${2:-}"

  case "$subcmd" in
    triage)
      [ -z "$ticket" ] && { red "Usage: jai cxe triage <TICKET-ID>"; exit 1; }
      bold "CXE Triage: $ticket"
      local prompt="@jai CXE mode. Triage ticket $ticket. Follow prompts/cxe-mode.prompt.md triage section exactly. Size as S/M/L, identify affected areas, risks, and open questions."
      ;;
    approach)
      [ -z "$ticket" ] && { red "Usage: jai cxe approach <TICKET-ID>"; exit 1; }
      bold "CXE Approach: $ticket"
      local prompt="@jai CXE mode. Generate full approach doc for $ticket. Follow prompts/cxe-mode.prompt.md approach section exactly. Include data model, API, UI changes, testing, and rollback."
      ;;
    plan)
      [ -z "$ticket" ] && { red "Usage: jai cxe plan <TICKET-ID>"; exit 1; }
      bold "CXE Build Plan: $ticket"
      local prompt="@jai CXE mode. Generate phased build and deployment plan for $ticket. Follow prompts/cxe-mode.prompt.md build plan section exactly. Include deployment sequence with gates and monitoring."
      ;;
    summary)
      [ -z "$ticket" ] && { red "Usage: jai cxe summary <TICKET-ID>"; exit 1; }
      bold "CXE Product Summary: $ticket"
      local prompt="@jai CXE mode. Generate product-friendly summary for $ticket. Follow prompts/product-summary.prompt.md exactly. Read implementation plan from ~/lever/cxe-triage-agent/implementation_plans/$ticket.md if it exists. Save to ~/lever/cxe-triage-agent/implementation_plans/$ticket-product-summary.md."
      ;;
    audit)
      [ -z "$ticket" ] && { red "Usage: jai cxe audit <TICKET-ID>"; exit 1; }
      bold "CXE Deep Analysis: $ticket"
      local prompt="@jai CXE mode. Run the 3-agent deep analysis audit on $ticket. Read skills/deep-analysis-skill.md and the implementation plan at ~/lever/cxe-triage-agent/implementation_plans/$ticket.md. Append findings to the plan."
      ;;
    *)
      red "Usage: jai cxe <triage|approach|plan> <TICKET-ID>"
      exit 1
      ;;
  esac

  if command -v code &>/dev/null; then
    echo "$prompt" | pbcopy 2>/dev/null || true
    green "Prompt copied to clipboard. Open Copilot Chat (Cmd+Shift+I) and paste."
  else
    echo "$prompt"
  fi
}

show_help() {
  cat << HELP
$(bold "jai — Staff Software Engineer AI Agent")

$(green "Usage:")
  jai review [--base <branch>]     Aggressive code review
  jai pr create [--base <branch>]  Create a PR with generated description
  jai pr feedback                  Fetch + address PR review comments
  jai cxe triage <ticket>          Triage a JIRA ticket (S/M/L)
  jai cxe approach <ticket>        Generate approach doc
  jai cxe plan <ticket>            Generate phased build + deployment plan
  jai cxe summary <ticket>         Generate product-friendly summary
  jai cxe audit <ticket>           Run 3-agent deep analysis audit
  jai help                         This help message

$(green "Options:")
  --base <branch>        Base branch (default: main, override with JAI_BASE env var)

$(green "Environment Variables:")
  JAI_BASE               Default base branch (default: main)

$(green "VS Code:")
  Type @jai in Copilot Chat for interactive use.

$(green "Examples:")
  jai review                       Review current branch vs main
  jai review --base develop        Review vs develop
  jai pr create                    Create PR for current branch
  jai pr feedback                  Address review comments on current PR
  jai cxe triage CXE-1234          Triage JIRA ticket
  jai cxe approach CXE-1234        Full approach doc
  jai cxe plan CXE-1234            Phased build plan
  jai cxe summary CXE-1234         Product-friendly summary
  jai cxe audit CXE-1234           3-agent deep analysis audit
HELP
}

# --- Main ---
case "${1:-help}" in
  review|cr)
    shift
    base="$BASE_BRANCH"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base) base="${2:?--base requires a branch name}"; shift 2 ;;
        *) base="$1"; shift ;;
      esac
    done
    do_review "$base"
    ;;
  pr)
    shift
    case "${1:-}" in
      create)
        shift
        base="$BASE_BRANCH"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --base) base="${2:?--base requires a branch name}"; shift 2 ;;
            *) shift ;;
          esac
        done
        do_pr_create "$base"
        ;;
      feedback) do_pr_feedback ;;
      *) red "Usage: jai pr <create|feedback>"; exit 1 ;;
    esac
    ;;
  cxe) shift; do_cxe "$@" ;;
  help|--help|-h) show_help ;;
  *) red "Unknown command: $1"; echo ""; show_help; exit 1 ;;
esac
CLI_INNER_EOF

# Replace placeholder with actual JAI_DIR
sed -i '' "s|__JAI_DIR__|$JAI_DIR|g" "$HOME/.local/bin/jai"
chmod +x "$HOME/.local/bin/jai"
echo "  → installed: ~/.local/bin/jai"

# Step 3: PATH check
echo ""
echo "[3/3] Checking PATH..."
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  SHELL_RC=""
  [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
  [ -z "$SHELL_RC" ] && [ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"

  if [ -n "$SHELL_RC" ]; then
    echo '# Jai agent CLI' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    _green "  Added ~/.local/bin to PATH in $SHELL_RC"
    _dim "  Run: source $SHELL_RC"
  else
    _red "  Add ~/.local/bin to your PATH manually"
  fi
else
  _green "  PATH includes ~/.local/bin ✓"
fi

echo ""
_green "=== Jai installed successfully ==="
echo ""
echo "  CLI:     jai help"
echo "  VS Code: @jai in Copilot Chat"
echo ""
