# How Roamily gets built: an AI-native development workflow

_Last updated 2026-07-29. Source of truth for the "how I work with AI" story — the raw
material for a LinkedIn post or blog._

Roamily is a Denver-area iOS app that helps parents of toddlers find something to do today.
It's built solo, nights-and-weekends, by an iOS engineer with a day job. Everything below is
the actual machinery that exists on disk — not a proposal.

The short version: **AI doesn't write Roamily. AI runs the parts of the process that a solo
founder would otherwise skip** — the design review, the second opinion, the code review, the
"did you think about legal" conversation. The interesting work isn't prompting; it's building
a system where an LLM has enough context to be useful and enough guardrails to be trusted.

---

## 1. The pipeline, end to end

```
  idea ──▶ grill ──▶ spec ──▶ approve ──▶ implement ──▶ review ──▶ draft PR ──▶ ship ──▶ measure
   │        │         │         │            │            │           │           │        │
 human   @grill-me  @story-   HUMAN       workflow     ios-        gh pr      human    PostHog
 (or a   8-persona  to-spec    GATE       (.mjs, 3     reviewer   --draft    merges    events
 briefing  panel    →specs/            design lenses  ≤3 fix                          + spec
  agent)                                + architect     rounds                        →Shipped
                                          judge)
```

Four repos, each with a job:

| Repo | Role |
|---|---|
| `roamily-specs` | **What & why.** Requirements → design → tasks. No code. Plus `steering/` — the product/tech/structure context every spec inherits. |
| `roamily-ios` | SwiftUI + MVVM app (`@Observable`, protocol-injected repositories, Swift 6 strict concurrency, no TCA). |
| `roamily-pipeline` | Python. Hand-authored YAML → validated `places.json` / `activities.json`, published to Firebase Hosting. |
| `taproot-agents` | **The AI tooling itself, version-controlled.** 20 subagent definitions. |

---

## 2. Layer one: context is the product

An agent is only as good as what it knows. Three tiers of durable context feed every session,
and building them was most of the actual work:

**Steering files** (`roamily-specs/steering/`) — `product.md` (who we build for, and the *kill
criteria*), `tech.md` (stack + conventions), `structure.md` (repo topology, where ADRs live),
`strategy.md`. Every spec and every agent inherits these. They change when the product changes,
not per-feature.

**Per-repo `CLAUDE.md`** — orientation for whichever repo the session is in. The iOS one spells
out the MVVM+`@Observable` pattern, the JSON envelope format, the "no TCA, no force-unwraps"
rules. The pipeline one explains that publishing is a *whole-site replace* and that two
hand-maintained allow-lists must agree or files silently vanish from an environment.

**Persistent memory** — 43 memory files, one fact each, indexed. Not code structure (git already
records that) but the things that aren't derivable: *why* GeoIP is deliberately off, that phone
photos leak GPS EXIF and `sips` does not strip it, that the App Store rejection was 4.2.2
("too web-like") and not "too thin" — which flipped a native map from scope creep into *the fix*.

There's also **agent-scoped memory**: the `voice-content-curator` carries its own four-file
memory of brand voice principles, banned phrases, per-surface length conventions, and
ground-truth app facts it may never embellish past.

**ADRs** close the loop — 20 in the pipeline, 8 in iOS. Specs link to ADRs instead of restating
decisions, so there's exactly one copy of every "why."

---

## 3. Layer two: a versioned roster of specialists

`taproot-agents` is the source of truth; the live agents Claude Code loads are **symlinks back
into the repo**. Edit an agent anywhere — including through the tool's own UI — and git stays in
sync. `install.sh` is idempotent, backs up any real file it replaces, and re-links a new machine
in one command.

**7 generic engineering agents** (global, any project): `architect`, `feature-decomposer`,
`story-to-spec`, `implementer`, `grill-me-planner`, `request-refactor-plan`, `security`. These
are project-agnostic and read project-local steering files, so they port to any codebase.

**10 Roamily "executive team" agents**: `ceo`, `product-manager`, `project-manager`,
`technical-expert`, `ux-expert`, `analytics-expert`, `marketing-executive`, `legal-expert`,
`growth-monetization`, and `grill-me` — a facilitator that channels all eight perspectives at
once and refuses to stop until every branch of the decision tree is resolved.

**3 iOS delivery agents**: `ios-implementer`, `ios-reviewer`, `content-curator` /
`voice-content-curator`.

This is the part that most directly substitutes for a team. A solo builder does not get a UX
critique, a legal read, and an analytics plan for a feature — the calendar doesn't allow it.
`@grill-me` asks the questions those people would have asked, and the output lands in the spec
before any code exists. Three grill sessions are archived as artifacts in their own right
(the Firebase-Hosting backend decision, the beta scope call, the Places filter design).

---

## 4. Layer three: orchestration in code, not in a prompt

The `.js` file: **`.claude/workflows/implement-spec.mjs`** — 380 lines that take an Approved spec
from a task list to a reviewed draft PR. Invoked as `/implement-spec <slug>`.

```
Read spec ──▶ Design (3 lenses ∥) ──▶ Judge ──▶ Implement ──▶ Review ⇄ Fix (≤3) ──▶ PR
  sonnet          sonnet ×3            OPUS       sonnet          sonnet          sonnet
```

The design decisions inside it are the interesting part:

**Control flow is deterministic; only judgment is delegated.** Loops, caps, early-exit, and gate
conditions are JavaScript. The model decides *what's true*, never *what happens next*.

**A judge panel instead of one opinion.** Three agents propose a design in parallel through
fixed lenses — YAGNI ("three similar lines beat a premature abstraction"), extensibility ("build
for the *next* expected change, not five steps out"), and testability. An architect scores them
and may synthesize, grafting the best of the runners-up onto the strongest base.

**Model routing as an explicit cost knob.** A `MODELS` table at the top of the file sets model +
reasoning effort per stage, with a comment explaining the policy: spend Opus only where decision
quality compounds (the judge), Sonnet for the workhorse stages, minimum effort for the PR
mechanics — whose body is built deterministically in JS precisely so no tokens go to formatting.
One table, one line changed, and the whole run gets more expensive or cheaper.

**Structured outputs, not parsed prose.** Six JSON schemas (brief, proposal, judge, impl, review,
PR) validated at the tool boundary, so a malformed response is retried by the harness rather than
silently misread downstream.

**Incremental re-review.** Round 1 reviews the full diff; later rounds review *only* the files
touched by the previous fix, and are told not to re-litigate accepted code. The loop exits early
when a review comes back clean, and hard-stops at 3 rounds rather than looping forever.

**It ends at a draft PR.** Never a merge.

The `implement-spec` **skill** wraps the workflow with the cheap preflight: resolve the slug,
confirm the spec is `Approved`, name the worktree work will land in, state the cost and the
side-effects, *then* spend the tokens. It also documents its own tuning knobs — a nice property
for something you'll come back to in three months.

---

## 5. Layer four: guardrails, because autonomy without rails is just risk

The goal is hands-off autonomy on safe work and hard stops on the rest.

**Permissions as an allow-list.** ~45 read-only and build commands pre-approved so routine work
never prompts. A deny list on the catastrophic — `rm -r`, `git reset --hard`, any force-push,
`git clean`, `filter-branch`, `gh repo delete`, `gh secret`, plus reads of `.env`, `*.pem`,
`*.key`, `.ssh/**`. An `ask` tier for the genuinely consequential: `make deploy-prod`, any push
to `main`, `npm publish`.

**Git hooks in all three repos** — `pre-commit`, `pre-push`, and a `post-checkout` hook that
seeds gitignored secrets into new worktrees (a real bug: a fresh worktree missing
`Secrets.xcconfig` silently no-ops analytics in debug builds). A specs-repo hook blocks commits
on `main` — added *after* work got stranded exactly that way.

**Branch-per-worktree, always.** Never an in-place `git switch`. Worktrees live in a sibling
`<project>-worktree/<branch>` dir, so parallel agent work can't collide.

**CI gates on every repo** — tests, types, lint.

**Human gates that AI cannot open:**
- Only a spec marked `Approved` runs. The workflow's skill explicitly forbids bumping the status
  itself to make a run go through.
- PRs open as drafts. A human opens them for real merge.
- `promote_candidates.py` deliberately emits *incomplete* stubs — it never writes a `description`
  or `tagline`, so the build **fails** until a human writes them. The description must be ours
  (ADR-0012, no verbatim third-party text), and the tagline is the product's inclusion bar: a
  place that can't finish "go here because ___" doesn't ship. A machine-written placeholder would
  sail through validation and quietly become filler.

---

## 6. Layer five: the ops loop

**Nightly prod refresh** — a launchd job on a Mac mini runs the pipeline behind validation
(ADR-0013) and publishes to Firebase Hosting. Because the app reads its data remotely, content
and even display vocabulary ship *without an App Store release*.

**The morning briefing — built, then killed.** A chief-of-staff agent ran at 6:03am: a pure-Python
`collect.py` (no LLM, no secrets, unit-tested) walked all three repos and emitted a snapshot of
worktrees, *loose branches with no worktree and no PR* — "where work goes to die" — orphan dirs,
open PRs with CI status. One Claude call then reconciled that against Todoist and Calendar and
wrote a Notion page: e.g. an open task whose code is already written on a stranded branch.

It was disabled on 2026-07-26, and the disabling is the better story. It had been quietly firing
daily — a full Opus call on a 35KB snapshot — to write a page nobody was reading. The code is
kept intact with revival instructions and a one-line "run it by hand when you actually want it."
The design lesson is in the architecture, though: **the deterministic stage runs first so it
fails cheap, before any LLM spend.**

**Analytics close the loop.** PostHog events are defined by the analytics agent *before* a feature
ships, so there's a baseline to compare against. Privacy is deliberately narrow: no Location or
Contact Info in the App Store label, GeoIP off on purpose with a dated decision to revisit.

---

## 7. Receipts (as of 2026-07-29)

| | |
|---|---|
| Repos | 4 (specs, iOS, pipeline, agents) |
| Agent definitions, version-controlled | 20 |
| Orchestration workflows | 1 (`implement-spec.mjs`, 5 phases) |
| Specs written | 14 — **9 shipped** |
| PRs merged | ~91 across the three product repos (highest: iOS #64, pipeline #63) |
| Commits | 143 iOS / 131 pipeline / 56 specs, since 2026-03-14 |
| ADRs | 28 |
| Persistent memory facts | 43 |
| Team size | 1 |

---

## 8. What actually went wrong (the honest part)

These are the most publishable lessons, because everyone shows the happy path.

**Custom agents + forced structured output can deadlock.** Three stages — judge, implement,
review — were originally routed to purpose-built agents (`architect`, `ios-implementer`,
`ios-reviewer`). All three failed the same way: the custom agent repeatedly emitted a
`StructuredOutput` call missing required fields and blew the retry cap. Fix: run the default
subagent with a *model* override, and supply the specialist knowledge in the prompt plus the
steering docs. The comment explaining this is in the file, next to the code, so future-me doesn't
"clean it up."

**Agents will report before they work.** The implementer once returned a beautiful structured
result — status, branch, files changed — after four events and *zero tool calls*. Pure
hallucinated completion. The fix is a blunt prompt clause: `DO THE WORK FIRST, THEN REPORT.
Actually create the worktree, write the code, run the build and tests, and commit — BEFORE you
call StructuredOutput.` Structured output makes a fabricated result *look* exactly like a real
one. That's the trap.

**Agents over-flag blockers to avoid doing work.** The spec-reader kept halting on non-blockers:
"the worktree doesn't exist," "the ADR isn't written," "a dependency isn't merged" (it was —
it had checked the working branch instead of `origin/main`). The prompt now carries an explicit
negative list of what is *not* a blocker, and a required verification procedure for the
"depends on X" case. Defining the negative space took more iterations than defining the task.

**Resume corrupted its own input.** A resumed run re-stringified the args object, producing a
path like `roamily-specs/specs/{"slug":…}`. The workflow now accepts a plain string slug and
defensively unwraps a JSON-object-shaped one.

**Relative paths break subagents.** Agents don't share a working directory. Everything the
workflow hands off is absolute — a lesson learned from an implementer reporting `blocked`
because it couldn't resolve a sibling repo.

**Unknown is not false.** In the Notion triage database, amenities are yes/no/**unknown**, not
checkboxes — and a blank is *omitted* from the generated stub, never written as `false`.
Collapsing them would launder "we didn't look" into "we checked and there isn't one." For an app
parents use to decide whether a place has a changing table, that distinction is the whole product.

**The cheapest optimization was deleting an agent.** See §6.

---

## 9. Angles worth writing up

1. **"I gave my solo project an executive team."** Ten persona agents, one grill-me facilitator,
   and what a UX/legal/analytics critique does to a feature *before* code exists. Most relatable
   hook; least technical.
2. **"Your AI agent will lie about finishing. Here's the prompt clause that fixed it."** The
   zero-tool-calls structured result. Strong, specific, and useful to anyone building agents.
3. **"Orchestration belongs in code, not in a prompt."** The judge panel, the `MODELS` cost table,
   deterministic loops and caps — the case that the model should decide what's *true*, never what
   happens *next*.
4. **"Context is the product."** Steering files, per-repo `CLAUDE.md`, 43 memory facts, agent-scoped
   brand memory. The unglamorous work that makes everything else possible.
5. **"The best thing I did with AI was turn one off."** A 6am Opus call writing a page nobody read
   — and the architecture lesson (deterministic stage first, fail cheap before spend).
6. **"The gates a machine can't open."** Approved-only specs, draft-only PRs, and a build that
   *fails* until a human writes the description. Where judgment stays human, on purpose.

---

## 10. The thesis, if you only keep one paragraph

AI didn't make me a faster typist. It gave a one-person project the *process* of a team: a design
reviewed from three angles before anyone commits, a spec that survives a hostile eight-persona
grilling, a code review that runs every time instead of when someone has a spare hour. The
engineering wasn't in the prompts — it was in the context layer that makes agents competent, the
schemas and caps that make them predictable, and the hard-coded gates that keep the judgment calls
human. 9 specs shipped, ~91 PRs, one person.
