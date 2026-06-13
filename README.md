# TapRoot Studios — Claude Code Agents

Version-controlled home for the Claude Code subagents used across TapRoot Studios
work (currently the **Roamily** app). This repo is the **source of truth**; the
live agents Claude Code loads are symlinks back into here, so editing an agent
anywhere keeps git in sync.

Professional/product agents only — no personal agents live here.

## Layout

| Dir | Symlinked into | Agents |
|-----|----------------|--------|
| `generic/` | `~/.claude/agents/` (global, all projects) | `architect`, `feature-decomposer`, `grill-me-planner`, `implementer`, `request-refactor-plan`, `security`, `story-to-spec` |
| `roamily/` | `<roamily-app>/.claude/agents/` | `analytics-expert`, `ceo`, `grill-me`, `growth-monetization`, `legal-expert`, `marketing-executive`, `product-manager`, `project-manager`, `technical-expert`, `ux-expert` |
| `roamily/ios/` | `<roamily-app>/roamily-ios/.claude/agents/` | `content-curator` |

`generic/` agents ship a `.json` sidecar (registration metadata) alongside each
`.md`. Roamily agents are `.md` only.

## Install (new machine)

```bash
git clone git@github.com:lovelejess/taproot-agents.git ~/repos/taproot-agents
cd ~/repos/taproot-agents
./install.sh
```

If your Roamily checkout isn't at `~/roamily-app`:

```bash
ROAMILY_APP_DIR=~/path/to/roamily-app ./install.sh
```

`install.sh` is idempotent. Any real file already sitting at a target path is
moved to `.install-backups/` before being replaced with a symlink.

## Adding or editing an agent

1. Add/edit the `.md` (and `.json` for a generic agent) **in this repo**.
2. Run `./install.sh` to link any new file into the live dir.
3. Commit.

Because live agents are symlinks, edits you make through Claude Code's normal
agent locations land here automatically — just commit.

## The generic agents

Platform- and project-agnostic engineering agents that follow project-local
steering files. Drop a `.claude/steering/` dir in any project to tune them:

```
your-project/.claude/steering/
├── architecture.md     # your patterns (MVVM, Clean Architecture, …)
├── coding-standards.md # your style guide
└── testing.md          # your test conventions
```

Typical flow: `@feature-decomposer` → `@story-to-spec` → `@implementer`, with
`@grill-me-planner` to stress-test a design and `@request-refactor-plan` →
`@implementer` for refactors.
