# Generic Agents

Platform-agnostic, project-agnostic agents for personal projects.

## Agents

| Agent | Type | Description |
|-------|------|-------------|
| `@architect` | Architecture | Software architecture advisor. Reviews designs, enforces patterns (DI, separation of concerns), reviews module boundaries. Follows project-local steering. |
| `@feature-decomposer` | Planning | Decomposes features/epics into phased vertical slices with parallelization analysis, dependency graphs, and dev allocation. |
| `@story-to-spec` | Spec Generation | Generates complete specs from stories or ACs — requirements, design with Mermaid diagrams, use case matrix, task list, and handoff summary. |
| `@implementer` | Autonomous | Semi-autonomous task executor. Reads spec task lists, implements each task with build/test gates, self-review, and atomic commits. Stops on failure. |
| `@grill-me-planner` | Skill | Stress-tests a plan or design through relentless questioning until reaching shared understanding. |
| `@request-refactor-plan` | Skill | Creates detailed refactor plans with tiny incremental commits via user interview. |

## Workflow

```
@feature-decomposer → @story-to-spec → @implementer
(Decompose Epic)      (Spec per Slice)  (Implement Tasks)
```

For refactors: `@request-refactor-plan` → `@implementer`

Use `@grill-me-planner` at any point to stress-test a design before committing to it.

## Installation

Copy the `.md` and `.json` files to `~/.claude/agents/`:

```bash
cp Generic/*.md Generic/*.json ~/.claude/agents/
```

## Customization

These agents follow project-local steering files. Drop a `.claude/steering/` directory in any project with your conventions:

```
your-project/
├── .claude/
│   └── steering/
│       ├── architecture.md    # Your patterns (e.g., Clean Architecture, MVVM, etc.)
│       ├── coding-standards.md # Your style guide
│       └── testing.md         # Your test conventions
```

The `@architect` agent reads these on every invocation and adapts its guidance accordingly.
