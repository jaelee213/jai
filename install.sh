#!/usr/bin/env bash
set -euo pipefail

JAI_DIR="$(cd "$(dirname "$0")" && pwd)"
VSCODE_PROMPTS_DIR="${HOME}/Library/Application Support/Code/User/prompts"
COPILOT_INSTRUCTIONS_DIR="${HOME}/Library/Application Support/Code/User"

echo "=== Jai Agent Installer ==="
echo ""

# Step 1: Symlink prompts into VS Code user prompts directory
echo "[1/3] Setting up VS Code Copilot integration..."
mkdir -p "$VSCODE_PROMPTS_DIR"

# Symlink each prompt file
for prompt in "$JAI_DIR"/prompts/*.prompt.md; do
  filename=$(basename "$prompt")
  target="$VSCODE_PROMPTS_DIR/$filename"
  if [ -L "$target" ] || [ -f "$target" ]; then
    echo "  Updating: $filename"
    rm -f "$target"
  else
    echo "  Installing: $filename"
  fi
  ln -s "$prompt" "$target"
done

# Symlink the agent file
AGENT_TARGET="$VSCODE_PROMPTS_DIR/jai.agent.md"
if [ -L "$AGENT_TARGET" ] || [ -f "$AGENT_TARGET" ]; then
  rm -f "$AGENT_TARGET"
fi
ln -s "$JAI_DIR/jai.agent.md" "$AGENT_TARGET"
echo "  Installing: jai.agent.md"

# Step 2: Install CLI wrapper
echo ""
echo "[2/3] Installing CLI command..."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/jai" << 'CLI_EOF'
#!/usr/bin/env bash
set -euo pipefail

JAI_HOME="$(dirname "$(readlink -f "$0")")/../jai"
# Fallback: if installed via symlink to repo
if [ ! -d "$JAI_HOME" ]; then
  JAI_HOME="PLACEHOLDER_JAI_DIR"
fi

show_help() {
  cat << HELP
jai — Staff Software Engineer AI Agent

Usage:
  jai review [--base <branch>]     Run aggressive code review
  jai pr create [--base <branch>]  Create a PR with auto-generated description
  jai pr feedback                  Pull and address PR review comments
  jai cxe triage <ticket>          Triage a JIRA ticket (CXE mode)
  jai cxe approach <ticket>        Generate approach doc
  jai cxe plan <ticket>            Generate phased build + deployment plan
  jai help                         Show this help

Options:
  --base <branch>  Base branch for comparison (default: main)

Examples:
  jai review                       Review current branch changes vs main
  jai review --base develop        Review current branch changes vs develop
  jai pr create                    Create a PR from current branch
  jai pr feedback                  Address PR review comments
  jai cxe triage PROJ-1234         Triage a JIRA ticket

Note: Most commands open VS Code Copilot Chat with the appropriate prompt.
      For terminal-only usage, the prompts are in: $JAI_HOME/prompts/
HELP
}

open_copilot_chat() {
  local prompt_text="$1"
  # Open VS Code and trigger Copilot chat with the prompt
  if command -v code &>/dev/null; then
    code --goto . && echo "$prompt_text" | pbcopy
    echo "Prompt copied to clipboard. Open Copilot Chat (Cmd+Shift+I) and paste."
  else
    echo "VS Code 'code' command not found. Prompt:"
    echo ""
    echo "$prompt_text"
  fi
}

case "${1:-help}" in
  review|cr)
    BASE="${3:-main}"
    if [ "${2:-}" = "--base" ] && [ -n "${3:-}" ]; then
      BASE="$3"
    fi
    PROMPT="@jai Run a full code review of this branch's changes relative to \`$BASE\`. Use the code-review prompt. Be aggressive."
    echo "Running code review (base: $BASE)..."
    echo ""
    echo "Quick diff stats:"
    git diff "$BASE"...HEAD --stat 2>/dev/null || git diff "$BASE"..HEAD --stat
    echo ""
    open_copilot_chat "$PROMPT"
    ;;
  pr)
    case "${2:-}" in
      create)
        BASE="${4:-main}"
        if [ "${3:-}" = "--base" ] && [ -n "${4:-}" ]; then
          BASE="$4"
        fi
        PROMPT="@jai Create a PR for this branch targeting \`$BASE\`. Use the pr-management prompt. Check for a PR template in the repo."
        open_copilot_chat "$PROMPT"
        ;;
      feedback)
        PROMPT="@jai Pull the latest PR review comments and address each one. Use the pr-management prompt. Fall back to gh CLI if MCP crashes."
        open_copilot_chat "$PROMPT"
        ;;
      *)
        echo "Usage: jai pr <create|feedback>"
        exit 1
        ;;
    esac
    ;;
  cxe)
    case "${2:-}" in
      triage)
        TICKET="${3:?Usage: jai cxe triage <ticket-id>}"
        PROMPT="@jai CXE mode. Triage JIRA ticket $TICKET. Assess size (S/M/L), identify affected areas, and list risks. Use the cxe-mode prompt."
        open_copilot_chat "$PROMPT"
        ;;
      approach)
        TICKET="${3:?Usage: jai cxe approach <ticket-id>}"
        PROMPT="@jai CXE mode. Generate an approach doc for JIRA ticket $TICKET. Include data model changes, API changes, UI changes, testing strategy, and rollback plan. Use the cxe-mode prompt."
        open_copilot_chat "$PROMPT"
        ;;
      plan)
        TICKET="${3:?Usage: jai cxe plan <ticket-id>}"
        PROMPT="@jai CXE mode. Generate a phased build and deployment plan for JIRA ticket $TICKET. Include deployment sequence and monitoring. Use the cxe-mode prompt."
        open_copilot_chat "$PROMPT"
        ;;
      *)
        echo "Usage: jai cxe <triage|approach|plan> <ticket-id>"
        exit 1
        ;;
    esac
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac
CLI_EOF

# Replace placeholder with actual path
sed -i '' "s|PLACEHOLDER_JAI_DIR|$JAI_DIR|g" "$HOME/.local/bin/jai"
chmod +x "$HOME/.local/bin/jai"

# Step 3: Ensure PATH includes ~/.local/bin
echo ""
echo "[3/3] Checking PATH..."
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  SHELL_RC=""
  if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  fi
  
  if [ -n "$SHELL_RC" ]; then
    echo '' >> "$SHELL_RC"
    echo '# Jai agent CLI' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo "  Added ~/.local/bin to PATH in $SHELL_RC"
    echo "  Run: source $SHELL_RC"
  else
    echo "  WARNING: Add ~/.local/bin to your PATH manually"
  fi
else
  echo "  PATH already includes ~/.local/bin ✓"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  jai review          — Code review current branch"
echo "  jai pr create       — Create a PR"
echo "  jai pr feedback     — Address PR comments"
echo "  jai cxe triage X    — Triage a JIRA ticket"
echo "  jai help            — Full help"
echo ""
echo "In VS Code Copilot Chat, type @jai to use the agent directly."
