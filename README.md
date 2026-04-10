# Jai — Staff Software Engineer AI Agent

An AI agent that operates as a Staff Software Engineer. Aggressive code reviews, PR management, and CXE-mode ATS engineering.

## Features

### 1. Code Review (`jai review`)
Performs a Staff-level code review on your current branch's changes:
- Checks for **bugs** (logic errors, race conditions, null access, type safety)
- Checks for **performance** issues (O(n²), memory leaks, N+1 queries, unnecessary allocations)
- Checks for **best practices** (DRY, SOLID, naming, error handling)
- Evaluates **surrounding code quality** (consistency, impact radius, test coverage)
- Outputs a structured review with severity levels and actionable suggestions

### 2. PR Management (`jai pr`)
- **`jai pr create`** — Auto-generates a PR with a descriptive body that conforms to the repo's PR template
- **`jai pr feedback`** — Fetches PR review comments (via MCP or `gh` CLI fallback), evaluates each one, and iteratively addresses them

### 3. CXE Mode (`jai cxe`)
Specialized mode for Staff Engineers working on ATS platforms (Lever, Jobvite, JazzHR, Talemetry/RM):
- **`jai cxe triage <ticket>`** — Sizes a JIRA ticket (S/M/L) with affected areas and risks
- **`jai cxe approach <ticket>`** — Generates a full approach doc with data model, API, UI changes, testing strategy, and rollback plan
- **`jai cxe plan <ticket>`** — Creates a phased build and deployment plan

CXE mode automatically analyzes unfamiliar ATS repos on first encounter and stores domain knowledge for future use.

## Installation

```bash
git clone https://github.com/jaelee213/jai.git ~/jai
cd ~/jai
./install.sh
```

This will:
1. Symlink agent/prompt files into VS Code's user prompts directory
2. Install the `jai` CLI command to `~/.local/bin/`
3. Add `~/.local/bin` to your PATH if needed

## Usage

### CLI
```bash
jai review                    # Review current branch vs main
jai review --base develop     # Review vs a different branch
jai pr create                 # Create a PR
jai pr feedback               # Address PR review comments
jai cxe triage PROJ-1234      # Triage a ticket
jai cxe approach PROJ-1234    # Generate approach doc
jai cxe plan PROJ-1234        # Generate build plan
```

### VS Code Copilot Chat
Type `@jai` in the Copilot Chat panel, then use natural language:
- `@jai review my code`
- `@jai create a PR`
- `@jai cxe triage PROJ-1234`

## Structure

```
jai/
├── jai.agent.md              # Main agent definition
├── prompts/
│   ├── code-review.prompt.md # Code review instructions
│   ├── pr-management.prompt.md # PR creation & feedback
│   └── cxe-mode.prompt.md    # CXE mode (ATS engineering)
├── skills/
│   └── code-review-skill.md  # Code review patterns & checklist
├── memory/                   # Local memory (gitignored)
├── install.sh                # Installer script
└── README.md
```

## Requirements

- [VS Code](https://code.visualstudio.com/) with [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)
- [GitHub CLI](https://cli.github.com/) (`gh`) — for PR operations
- Git

## Works Everywhere

Jai is repo-agnostic. The prompts and agent definition are installed at the user level in VS Code, so they work in any workspace/repository. The CLI works from any directory with a git repo.
