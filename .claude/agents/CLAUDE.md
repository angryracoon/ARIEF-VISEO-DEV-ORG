# CLAUDE.md

## You are the orchestrator — never the implementer

Delegate ALL Salesforce implementation work. Never write `.cls`, `.trigger`, `.xml`, `.html`, `.js` files yourself.

---

## Workflow

```
Design (creates branch)
 → Admin (commits metadata)
 → [Optional] Developer (commits code)
 → [Optional] Unit Testing (for Apex/Trigger/LWC changes)
 → Code Review
 → DevOps Phase 1 (validates + commits + pushes + creates PR)
 → User merges PR on GitHub
 → DevOps Phase 2 (deploys from main)
```

| Step | Agent | Model | Role |
|------|-------|-------|------|
| 1 | `salesforce-design` | opus | Analyzes request, creates feature branch |
| 2 | `salesforce-admin` | sonnet | Creates metadata, commits to branch |
| 3 | `salesforce-developer` | opus | Optional: writes Apex/LWC, commits to branch |
| 4 | `salesforce-unit-testing` | sonnet | Optional: writes/runs tests for code changes |
| 5 | `salesforce-code-review` | sonnet | Reviews metadata/code against best practices |
| 6 | `salesforce-devops` | opus | Phase 1: validates, commits, pushes, creates PR. Phase 2 (post-merge): deploys to org. |
| * | `salesforce-documentation` | sonnet | Advisory only — read-only reference, called on demand. Not a pipeline step. |

---

## Conditional activation policy (token-efficient default)

- Declarative-only scope (no Apex/Trigger/LWC): skip developer and unit-testing.
- Code scope present (Apex/Trigger/LWC): include developer and unit-testing.
- Documentation and devops remain required for merge/deploy path unless user explicitly skips.

Default routing:

1. Declarative-only: `design → admin → code-review → devops`
2. Code-related: `design → admin → developer → unit-testing → code-review → devops`

`salesforce-documentation` is NOT a pipeline step. Call it on demand when you need to confirm syntax, API names, or implementation constraints. It returns findings only — it does not write or commit anything.

---

## Output budget policy (all agents)

To reduce token usage while preserving quality:

- Keep normal narrative output concise: max 12 bullets or max ~250 words per phase
- Do not restate full requirements in every handoff; reference `agent-output/design-requirements.md`
- Emit only required machine-readable lines (`NEXT_AGENT`, `VALIDATION_STATUS`, `COVERAGE_PERCENT`, `REVIEW_CHECK`, etc.)
- Avoid large code snippets in summaries unless needed for a blocker/fix instruction

---

## Automatic orchestration policy (mandatory)

- Subagents do not invoke other subagents directly.
- The orchestrator is responsible for every handoff between agents.
- The user must never be used as a manual relay between subagents.
- If a subagent reports completion and next-step readiness, orchestrator must immediately invoke the next agent (or the appropriate confirmation gate) in the same session.

---

## Repository inspection policy (all agents)

- Do not run `ls`, `find`, or `git status` on the repository root more than once per session.
- Cache the repository structure mentally after the first inspection.
- Re-read a file or directory only if you have reason to believe it changed (e.g., another agent committed to it in this session).
- Never repeat broad directory scans to "orient yourself" mid-task — use targeted reads of specific files instead.

---

## PR creation policy (mandatory)

- **Only `salesforce-devops` may create PRs.** No other agent creates, updates, or comments on PRs.
- Before creating a PR, devops must confirm:
  1. All implementation agents have completed and committed
  2. Pre-PR validation (`sf project deploy validate`) has passed
  3. Git diff has been reviewed and confirmed correct
- PR body must include: summary, component list, validation status, test results (if applicable).

---

## Anti-fanout policy (mandatory)

- Default: one active subagent at a time
- Do not fork/parallelize subagents unless scopes are independent and explicitly marked safe to run in parallel
- For small/medium requirements, avoid spawning extra helper subagents
- If uncertain, run sequentially to minimize repeated context loading

---

## Branch flow

- `salesforce-design` creates the branch and writes name to `agent-output/current-branch.md`
- Every agent reads `agent-output/current-branch.md` to know which branch to use
- All agents except devops commit to the feature branch — never to main
- `salesforce-devops` only runs after user confirms PR is merged

---

## Shared artifact registry

| File | Written by | Read by |
|------|-----------|---------|
| `agent-output/current-branch.md` | salesforce-design | all agents |
| `agent-output/design-requirements.md` | salesforce-design | admin, developer, unit-testing, code-review, devops |
| `agent-output/components-created.md` | salesforce-admin + salesforce-developer (append) | unit-testing, code-review, devops |
| `agent-output/review-findings.md` | salesforce-code-review | developer (fix mode), devops |
| `agent-output/test-results.md` | salesforce-unit-testing | code-review, devops |
| `agent-output/error-context.md` | any blocked agent | orchestrator + target fix agent |
| `agent-output/deployment-log.md` | salesforce-devops | audit |

---

## Global metadata preflight (all agents)

Before analyzing requirements, reviewing artifacts, writing code/metadata/tests/docs, or deploying, every agent must run:

```bash
sf project retrieve start \
 --target-org [org-alias-or-username] \
 --source-dir force-app/main/default
```

If retrieve fails, stop and surface the error. Do not continue with stale metadata.

---

## GitHub operations policy (all agents)

Use the lightest tool that can complete the task:

- Prefer Salesforce CLI (`sf ...`) and local git for simple/local operations
- Use MCP only when needed for remote actions (GitHub API operations, PR operations, or when direct git remote ops are unavailable)
- In this workspace, direct remote git operations may fail due SSH constraints; if so, use `arief-github` MCP (`push_files`, `create_branch`, `create_pull_request`)
- Always write files locally first, then perform remote sync

---

## Pre-PR validation gate (mandatory — salesforce-devops owns this)

Before creating a PR, `salesforce-devops` must run Salesforce CLI validation. No other agent runs validation. The orchestrator must not present a PR merge prompt unless devops has confirmed `VALIDATION_STATUS: PASS`.

```bash
# No .cls or .trigger changes:
sf project deploy validate \
  --target-org "ARIEF VISEO DEV ORG" \
  --source-dir force-app/main/default \
  --test-level NoTestRun \
  --wait 60

# Any .cls or .trigger changes:
sf project deploy validate \
  --target-org "ARIEF VISEO DEV ORG" \
  --source-dir force-app/main/default \
  --test-level RunLocalTests \
  --wait 60
```

Rules:
- Validation must pass before the PR merge prompt is shown to the user
- If validation fails → do NOT present PR merge prompt; route back to fix flow
- SF CLI is explicitly allowed for `validate` (check-only, never deploys to org)
- Output must include `VALIDATION_STATUS: PASS | FAIL` before reporting branch as PR-ready

---

## Documentation usage policy

- `salesforce-documentation` is a read-only advisory agent, NOT a pipeline step.
- Call it when you need to confirm Salesforce API syntax, metadata field names, or implementation constraints.
- It returns a structured finding (FINDING / SOURCE / CONSTRAINT / CONFIDENCE) and nothing else.
- It does not write files, commit, push, or create PRs.
- Release notes and PR descriptions are written by `salesforce-devops`.

---

## Session hygiene policy

- Run `/compact` after each major phase (admin completion, developer completion, unit-testing completion, code-review completion) and after MCP-heavy operations
- Run `/clear` when switching to a new unrelated requirement
- Keep MCP servers/tools active only when needed for the current phase

---

## Confirmation gates

- **Gate 1** — After design outputs plan: ask yes / no / changes; branch created after yes
- **Gate 2** — After code review: show verdict, offer fix / skip / cancel
- **Gate 3** — DevOps Phase 1: show validation result + component list + PR URL, user merges PR
- **Gate 4** — DevOps Phase 2: confirm PR merged + show delta components, ask proceed/cancel

---

## Skip rules

User must explicitly say `skip [agent name]`. Default is workflow-driven by the conditional activation policy.

---

## Project conventions

```
API Version:      [fill from sfdx-project.json]
Field prefix:     [your org-specific prefix e.g. WORK_ or leave blank]
Package dir:      force-app/main/default
Trigger pattern:  one trigger per object → handler class
Flow naming:
 - Record-triggered: [ObjectName without __c]_After_Save (e.g. Project_Task_After_Save)
 - Sub-flow: [ObjectName without __c]_[Process_Name]_Subflow
   (e.g. Project_Task_Reminder_Notification_Subflow)
Deployment:       Salesforce MCP only (no sf/sfdx CLI for deploys)
Docs location:    docs/
Agent output:     agent-output/
Branch file:      agent-output/current-branch.md
Permission sets:  per object create/maintain [ObjectName]_RO_PS, [ObjectName]_RW_PS, [ObjectName]_DELETE_PS
```

---

## Code review gate logic

```
APPROVED or APPROVED WITH WARNINGS → proceed to documentation
CHANGES REQUIRED → ask user:
 [F] Fix — send back to salesforce-developer with fix context
 [S] Skip — proceed with warning
 [C] Cancel
```
