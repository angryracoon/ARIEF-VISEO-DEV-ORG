# A New Way of Working: AI-Powered Salesforce Delivery

**The Question:** What if your delivery pipeline ran itself — from requirement to deployed feature — with best practices enforced at every step?

**The Experiment:** A real Salesforce org. Real requirements. Six specialized AI agents. See what happens.

---

## The Idea

Most teams use AI like a smart autocomplete — ask it to write a field, paste the XML, deploy. Useful, but the human is still the glue between every step.

This experiment tries something different: **what if the pipeline itself was automated?**

Paste a requirement. An AI agent reads it, designs the solution, hands it to the next agent who builds it, then the next who reviews it, then the next who deploys it. Humans approve gates — not do the work.

The key insight is **agent specialization**. Not one AI doing everything, but multiple AIs each owning their lane — with the right rules, constraints, and best practices baked into each one.

---

## The Team: Six Specialized Agents

Each agent is a configuration file (`.md`) that defines its role, tools, memory, and non-negotiable rules. The main Claude session (the orchestrator) reads a master rulebook and decides which agents to call and when.

```
.claude/agents/
  salesforce-design.md         ← the architect
  salesforce-admin.md          ← the declarative specialist
  salesforce-developer.md      ← the Apex/LWC/Flow engineer
  salesforce-code-review.md    ← the senior reviewer
  salesforce-documentation.md  ← the PR writer
  salesforce-devops.md         ← the release manager
  CLAUDE.md                    ← the delivery process rulebook
```

| Agent | Model | Owns |
|-------|-------|------|
| `salesforce-design` | Opus | Requirements analysis, solution architecture, feature branch creation |
| `salesforce-admin` | Sonnet | Custom objects, fields, validation rules, layouts, permission sets |
| `salesforce-developer` | Opus | Apex, LWC, Flows, test classes, and deployment validation |
| `salesforce-code-review` | Sonnet | PMD analysis, ESLint analysis, manual best-practice review |
| `salesforce-documentation` | Sonnet | PR overview draft — no git, no commits |
| `salesforce-devops` | Opus | PR creation, post-merge deployment (scratch org → target org) |

---

## Skills: The Expertise Each Agent Draws On

Agents define *who does what*. Skills define *how well they do it*.

A Salesforce skill is a specialized AI capability with deep knowledge of one specific task — Apex generation, LWC components, Flow creation, test classes, debug log analysis. When an agent needs to perform one of these tasks, it loads the relevant skill, which brings a structured workflow, platform-specific guardrails, and output validation into that session.

Salesforce ships an official library of 60+ skills (`forcedotcom/sf-skills`) covering the full stack. The developer agent in this pipeline draws on several of them: `generating-apex`, `generating-lwc-components`, `generating-apex-test`, `generating-flow`, and others depending on what the requirement needs.

### What Happens Inside a Skill

A skill isn't just a list of instructions. It follows a structured four-stage workflow:

```
Stage 1 — Analyze
  Read the requirement. Match it to the right skill.
  "LWC" → generating-lwc-components
  "Apex class" → generating-apex
  "test class" → generating-apex-test
         ↓
Stage 2 — Discover
  Read the project's existing conventions.
  Identify naming patterns, architectural layers, existing classes.
  Choose the right pattern: Service, Controller, Batch, Selector.
         ↓
Stage 3 — Generate with guardrails
  Produce the code with built-in constraints enforced automatically:
  - Rejects SOQL or DML inside loops
  - Forces with sharing on all classes
  - Will not complete without generating test classes
  - Creates all required metadata files (.cls-meta.xml, etc.)
         ↓
Stage 4 — Validate before reporting done
  Runs sf code-analyzer to catch security violations and antipatterns
  Executes test suite to verify functionality
  Confirms 75%+ code coverage
  Only then marks the task complete.
```

The critical detail is Stage 4: **skills validate their own output before reporting success**. The developer agent doesn't just generate code and hand it off — the skill confirms the code actually passes static analysis and test coverage before the agent moves on.

### Skills vs Agent System Prompts

The agent's system prompt defines roles, boundaries, and project-specific conventions (naming patterns, architecture decisions, team standards). Skills provide deep platform expertise for a specific technical task.

| | Agent system prompt | Skill |
|---|---|---|
| Scope | Full role definition | One specific task |
| Content | Project standards, rules, team conventions | Platform patterns, guardrails, validation steps |
| Loaded | Always in context for that agent | On demand, for the specific task |
| Maintained by | This project's configuration | Salesforce (`forcedotcom/sf-skills`) |

Together they cover both dimensions: your team's standards (agent) + platform expertise with quality enforcement (skill).

### Skills Are Customizable

The `forcedotcom/sf-skills` library is open source. You can fork it and add your team's specific naming conventions to templates, create org-specific skills for patterns your team uses repeatedly, and override defaults to match your project's architecture.

This means the expertise layer isn't fixed — it can be extended to reflect how your specific team builds. The more you invest in it, the more precisely the agents generate code that matches your standards without correction.

---

## Why Specialized Agents — Not One AI for Everything?

This is the first question most people ask. Here's the honest answer.

### What one agent gives you

Simplicity. One system prompt. One conversation. You ask, it does.

This works fine for a one-off task. It breaks down when:
- The task spans multiple domains (design + code + tests + deployment)
- You want consistent quality across sessions and team members
- You need different model tiers for different steps (expensive model for complex reasoning, cheaper model for structured output)
- You want to know *which part* of the pipeline failed, not just *that something failed*

### What specialized agents give you

**1. Context efficiency**

Each agent loads only what it needs. The admin agent doesn't need Apex testing standards. The code review agent doesn't need deployment commands. A single agent doing everything holds all of that in context simultaneously — which means more tokens, more confusion, more drift.

**2. Model matching**

Design and development need deep reasoning — Opus. Metadata generation, review, and documentation follow patterns — Sonnet. Running everything on Opus costs 3–5x more per token. Specialized agents let you use the right model for the right job.

**3. Role clarity prevents agentic drift**

When an agent is explicitly told "you are the reviewer, you never modify code," it won't start fixing what it's supposed to be reviewing. Role boundaries in the system prompt act as guardrails. The more capable the model, the more important those guardrails become — because a powerful model will confidently improvise when it thinks it's helping.

**4. Failure isolation**

If code review fails or produces wrong output, you re-run only code review. A monolithic agent that fails mid-pipeline leaves you untangling one long session to figure out where things went wrong.

**5. Memory stays organized**

Each agent accumulates domain-specific memory across sessions. DevOps remembers org-specific CLI quirks. Admin remembers permission set naming conventions. Developer remembers architectural patterns. One agent would have one undifferentiated memory pile that grows harder to manage over time.

### This Is an Industry Pattern — Not Just a Claude Thing

If this sounds familiar, it's because the same architecture is appearing across all major AI coding tools.

GitHub Copilot recently introduced the same concept under the name "Subagents" in Visual Studio Code. The description from their documentation:

> *"A GitHub Copilot subagent is a helper that operates in a dedicated context window, separate from your main Copilot chat session. When you delegate a task to a subagent, it spins up an isolated environment to perform its work and returns only the final result to your main conversation."*

That is exactly what happens here — just built in Claude Code instead of VS Code, and applied to Salesforce delivery instead of general software development.

The key concepts map directly across both platforms:

| Concept | GitHub Copilot | This Project (Claude) |
|---------|---------------|----------------------|
| Orchestrator | `manager.agent.md` with `tools: ['agent']` | `CLAUDE.md` + orchestrator session |
| Specialized workers | `.agent.md` files per role | `.claude/agents/*.md` files per role |
| Context isolation | Each subagent runs in its own context window | Each Claude subagent runs in its own context window |
| Only final result returns | Intermediate work discarded, summary returned | Output budget policy + shared artifact files |
| Internal-only agents | `user-invokable: false` | Agents only called by orchestrator, not directly |

The one deliberate difference: Copilot highlights parallel execution as a feature — running multiple subagents simultaneously. We run sequentially. In Salesforce delivery, the steps have hard dependencies (admin metadata must exist before developer can build on it, tests must exist before code review runs) so parallel execution would cause coordination failures, not speed gains.

The broader point: **this is where AI-assisted development is heading across the industry.** Specialized agents with isolated context, baked-in rules, and structured handoffs. The tools differ; the architecture is converging.

---

## The Pipeline: From Requirement to Deployed Feature

This is what happens when you paste a requirement.

```
You type: "Add a picklist field to Opportunity to track Loss Reason"
                              ↓
┌─────────────────────────────────────────┐
│  salesforce-design (Opus)               │
│  • Reads requirement                    │
│  • Determines: declarative-only         │
│  • Writes solution spec                 │
│  • Creates Git feature branch           │
│  • Writes agent-output/design-req.md   │
└───────────────┬─────────────────────────┘
                │
    ── GATE 1: User reviews design ──
    "Approve this? [Y] Yes [N] No [C] Changes"
                │ Y
                ↓
┌─────────────────────────────────────────┐
│  salesforce-admin (Sonnet)              │
│  • Creates Loss_Reason__c field XML     │
│  • Updates permission sets (RO/RW/DEL) │
│  • Commits to feature branch            │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  salesforce-code-review (Sonnet)        │
│  • Runs PMD (no Apex here — skipped)   │
│  • Checks field label ≤ 40 chars        │
│  • Checks fullName matches filename     │
│  • Checks permission sets exist         │
│  • Issues verdict: APPROVED             │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  salesforce-documentation (Sonnet)      │
│  • Drafts PR overview                   │
│  • Writes agent-output/pr-draft.md     │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│  salesforce-devops (Opus)               │
│  • Reads agent-output/pr-draft.md      │
│  • Creates GitHub PR                    │
│  • Shows PR URL to user                 │
└───────────────┬─────────────────────────┘
                │
    ── GATE 2: User merges PR on GitHub ──
                │
                ↓
┌─────────────────────────────────────────┐
│  salesforce-devops Phase 2              │
│  • Pulls latest main                    │
│  • Deploys to target org via MCP        │
└─────────────────────────────────────────┘
                ↓
        Feature is live in Salesforce.
```

For requests that include Apex, triggers, or LWC, the Developer agent is added between Admin and Code Review:

```
design → admin → developer → code-review → documentation → devops
```

The pipeline routes itself based on what the requirement actually needs — no manual configuration per request.

### How Agents Talk to Each Other

Agents don't pass work through conversation. They write to and read from shared files:

```
agent-output/
  design-requirements.md    ← design writes once; everyone else reads
  components-created.md     ← admin and developer append their output
  review-findings.md        ← code-review writes; developer reads if fixing
  pr-draft.md               ← documentation writes; devops reads for PR body
  current-branch.md         ← design writes the branch name; all agents read
```

This is important: **the human is never the relay between agents**. You approve gates. Agents move the work.

---

## What's Baked In: Expertise Without Repetition

This is where agent specialization becomes a delivery quality story, not just a productivity story.

Each agent carries two distinct layers of knowledge:

**Layer 1 — Universal Salesforce platform rules.** Things that apply to every Salesforce project, every org, every team. These aren't team decisions — they're platform constraints or widely accepted best practices that any good Salesforce developer should know.

**Layer 2 — This project's specific standards.** Team conventions, architecture decisions, naming patterns, and quality thresholds that are specific to how *this* project is run. These are configured — they can be different for another project, another client, another team.

The agents enforce both layers automatically. The team doesn't have to remember either one.

---

### Admin Agent

**Platform rules the agent knows:**
- `fullName` in a field XML file must exactly match the filename — Salesforce rejects a mismatch at deploy time with a non-obvious error
- Field API names cannot exceed 40 characters (excluding the `__c` suffix) — enforced by the platform
- Forbidden attributes differ per field type — Master-Detail fields cannot have `<required>`, `<deleteConstraint>`, or `<lookupFilter>`; Roll-up Summary fields cannot have `<precision>` or `<scale>`

**Project-specific standards configured for this project:**
- Permission sets are created in triples for every object: `[Object]_RO_PS` (read), `[Object]_RW_PS` (read-write), `[Object]_DELETE_PS` — no field is created without updating all three
- Flows are not admin's responsibility — automation logic belongs to the developer agent

A different project might use a different permission set convention, or a different ownership model. These are configurations, not universal rules.

---

### Developer Agent

**Platform rules the agent knows:**
- No SOQL or DML inside loops — governor limit violations in bulk execution
- `with sharing` on handler and service classes — enforced by Salesforce platform security model
- 75% code coverage required for Apex before any production deployment — platform requirement
- Flows cannot use `CASE()` to return Boolean in formula contexts — Salesforce formula engine limitation

**Project-specific standards configured for this project:**
- Trigger architecture: one trigger per object → handler → service → selector chain. No business logic in the trigger body.
- Constants class required — no hardcoded strings or IDs in implementation classes
- Javadoc required on every class and method (class name, description, author, date, params)
- Test classes written in the same session as implementation — not deferred to a later step. Mandatory scenarios: positive, negative, and bulk (200+ records for trigger tests)
- Record-triggered flows must have no entry criteria at the start element — all conditional logic goes inside the canvas via a Decision element
- Every flow action that can fail must have a fault path wired. Screen flows route to a shared error screen built from a formula resource; auto-launched flows route to a notification or Apex logger.

**How skills reinforce these rules:**

The developer agent doesn't operate on rules alone. When generating Apex or Flows, it loads the relevant skill (`generating-apex`, `generating-flow`, `generating-lwc-components`) which enforces its own guardrails on top of the agent's project standards. The skill rejects SOQL in loops before the code is even committed. For Flows, the `generating-flow` skill enforces a mandatory pipeline: query org schema first → select elements from real data → generate XML. This prevents a class of deploy failures that comes from referencing fields that don't exist in the org.

The skill also validates its own output — runs static analysis and confirms test coverage — before reporting the task complete. By the time the developer agent hands off to code review, the code has already passed one layer of automated quality checks.

Again — a different project could have a different trigger architecture, different Javadoc requirements, or different test scenario expectations. These are team standards, not Salesforce rules.

---

**Why this distinction matters:**

Most AI tools give you Layer 1 for free — they've seen enough Salesforce code to know about governor limits and `with sharing`. What they don't have is Layer 2, because that's specific to your team and your project.

This system lets you configure both layers. You get universal platform knowledge built in, plus your team's specific quality bar enforced the same way on every PR — regardless of who (or what) wrote the code.

### Code Review Agent — Automated + Manual Quality Gates

Before any human even sees a verdict, two automated checks run:

```bash
sf scanner run --engine pmd   # checks Apex for governor limit violations,
                               # security issues, design antipatterns
sf scanner run --engine eslint # checks LWC for JavaScript violations
```

**PMD error = CHANGES REQUIRED. No override.**
**ESLint error = CHANGES REQUIRED. No override.**

These are not warnings. They are blocks. The developer fixes and re-submits. Only after zero PMD errors and zero ESLint errors does the manual review checklist run.

The manual checklist then covers: recursion guards, null checks, error handling on DML, missing `WITH USER_MODE`, hardcoded IDs, missing permission sets, test class quality.

Verdicts:
- `APPROVED` — zero PMD, zero ESLint, zero critical manual findings
- `APPROVED WITH WARNINGS` — zero PMD, zero ESLint, warnings only
- `CHANGES REQUIRED` — any PMD error, ESLint error, or critical manual finding

### Developer Agent — Deployment Validation

Before handing off to code review, the developer runs deployment validation against the delta — the exact files changed in this feature branch, not the entire org:

```bash
git diff origin/main...HEAD --name-only | grep "^force-app/"
# → generates delta-package.xml from those files only
sf project deploy validate --manifest delta-package.xml --wait 60
```

This means: by the time code review runs, the code is already confirmed deployable by Salesforce. By the time documentation runs, both deployment validation and code review have passed. DevOps just creates the PR — it doesn't need to re-validate anything.

If validation fails, the developer fixes, re-commits, and re-validates before handing off. Nothing moves forward until `VALIDATION_STATUS: PASS` is emitted.

### DevOps Agent — Deployment Safety

DevOps Phase 1 is clean and simple: read `agent-output/pr-draft.md`, create the GitHub PR, show the URL. No validation step here — that already happened.

DevOps Phase 2 (post-merge) deploys only the delta — the files that changed in the merged PR, identified via GitHub MCP:

```bash
mcp: arief-github/get_pull_request_files(owner, repo, pull_number)
```

A PR with 5 changed files deploys 5 files. It never redeploys stable, unchanged metadata. Before touching the target org, it spins up a scratch org, deploys the delta there first, runs all tests, and only proceeds if everything passes.

---

## The Productivity Question

What does this actually change for a human on the team?

**Without this system, what the human does:**
```
Consultant receives requirement
  → Creates metadata manually (Setup UI or hand-crafted XML)
  → Creates and updates permission sets manually
  → Writes Apex and test classes (if needed)
  → Runs code review — separate meeting or async PR comment cycle
  → Runs deployment validation manually
  → Writes PR description
  → Deploys
```

**With this system, what the human does:**
```
Consultant pastes requirement
  → Reviews design output — approves, rejects, or requests changes
  → Agents execute the pipeline
  → Reviews the PR before merging
  → Merges PR
  → Agents deploy
```

The honest difference is not about how many minutes it takes. We don't have controlled benchmarks, and the pipeline itself takes real time to run — agent invocations, validation, MCP calls all add up. For a single simple field, an experienced admin using Setup UI might be faster.

What actually changes is **what the human is doing**. Instead of executing each step, the human is reviewing output at two gates. The execution work — metadata creation, code, tests, validation, PR description — is handled by the agents. Whether that saves 30 minutes or 3 hours depends on the task complexity, the team's experience level, and how many back-and-forth cycles a normal delivery requires.

The more meaningful case for speed is on tasks where the bottleneck isn't the individual execution time but the **coordination cost**: waiting for a developer to be available, waiting for a code review, waiting for someone to write the PR description. Agents eliminate the waiting.

### Routing by Complexity

Not every request needs every agent. The pipeline self-routes based on what the requirement actually contains:

| Scope | Agents Used |
|-------|-------------|
| Declarative only (field, VR, layout, permission set) | 4 agents |
| Code scope (Apex, LWC, Flow) | 6 agents |

Simple requests skip the developer agent entirely. Code review won't run PMD/ESLint if there's no Apex or LWC in scope. The pipeline is lean by default — it does what the work requires, nothing more.

---

## The Quality Question

The natural concern: if AI is writing the code, is the quality lower?

The argument is the opposite — for the categories where quality is measurable, quality should be **higher** because:

1. **Best practices are always enforced** — the agents don't skip the Javadoc because they're tired. They don't forget the permission sets because they were distracted. The rules are embedded.

2. **Static analysis runs on every PR** — in many manual workflows, PMD is something developers "should" run but often don't. Here, a PR cannot be approved if PMD has errors. It's not optional.

3. **Test coverage is mandatory** — the developer agent cannot hand off without writing the test class. There's no "we'll add tests later."

4. **Review happens on every PR** — not just "big" ones. Every change goes through the same review process regardless of size.

5. **Memory accumulates lessons** — every time an agent hits a new org-specific quirk, gets a deployment error, or discovers a wrong assumption, that gets written to its memory directory. Future runs don't repeat the same mistakes.

**Where quality can still slip:**

- **Subtle business logic errors** — the agents implement what was written in the requirement, not necessarily what was meant. Unclear requirements produce technically correct but wrong solutions.
- **Platform-specific edge cases** — new Salesforce behavior, API version differences, org-specific configuration that hasn't been encountered before. These need memory to accumulate.
- **Complex cross-object flows** — multi-object automation with many conditions. The agents can build it, but the logic needs human validation.

---

## The Honest Scorecard

| Capability | Verdict |
|-----------|---------|
| Custom objects, fields, validation rules | Works well — format errors are rare now |
| Apex triggers, handlers, service classes | Works well — follows patterns consistently |
| Salesforce Flows (with fault paths + no-start-condition rules) | Works well for standard patterns |
| Apex test classes (bundled with developer, not a separate step) | Works well — 90%+ coverage by default |
| Code review with PMD + ESLint + manual checklist | Strong — static analysis blocks delivery, not just flags it |
| Git, branching, PR creation | Works well — uses GitHub MCP for HTTPS, no SSH dependency |
| Delta deployment with pre-validation | Works well — deploys only changed files |
| PR descriptions | Structured — documentation agent drafts, devops publishes |
| **Understanding ambiguous requirements** | Does not work — garbage in, garbage out |
| **Catching new platform-specific gotchas** | Partial — needs memory to accumulate them first |
| **Architecture trade-off decisions** | Still human — agents follow rules, not judgment |
| **Supervision and final approval** | Still required — and intentionally so |

---

## The Future: Gets Smarter Over Time

This is the compounding advantage that doesn't exist with manual delivery.

Every session adds to agent memory. Every org-specific quirk discovered becomes a rule for next time. Every deployment failure that gets fixed gets written down so the next deployment doesn't repeat it.

Examples from this experiment that are now permanent memory:

- `sf project deploy validate --test-level NoTestRun` fails on this org — agent now uses `deploy start --dry-run` automatically
- `CASE()` cannot return Boolean in validation rule formulas — code review now catches this before deployment
- CustomNotificationType metadata goes in `notificationtypes/` with `.notiftype-meta.xml` extension — agent knows the correct format without being told again
- The CLI "Finalizing" error is cosmetic — agent checks the deploy report instead of panicking on the exit code

Six months from now, an agent that has worked in this org will know the org's quirks, patterns, and conventions better than a new consultant joining the project. That institutional knowledge doesn't leave when someone is assigned to a different project.

---

## What This Means

Can AI-powered agent specialization increase productivity without reducing delivery quality?

Based on this experiment: **yes — with conditions.**

**Productivity increases because:**
- The execution of repetitive delivery work (creating fields, writing permission sets, structuring Apex, running reviews) is automated
- Best practices are enforced without requiring the human to remember them
- Every PR goes through the same quality process regardless of who initiated the request

**Quality holds (or improves) because:**
- Rules are embedded, not assumed
- Static analysis is mandatory, not optional
- Memory accumulates lessons, so the same mistake doesn't happen twice

**The conditions:**
- Requirements must be clear — the agents are very good at implementation, not at guessing intent
- Human approval at key gates is still necessary — and that's by design, not a limitation
- The agent configurations need to reflect your team's actual standards, not generic defaults

The shift is not "AI replaces the team." The shift is: **the team stops spending time on execution and starts spending it on decisions.** Architecture, requirements, stakeholder alignment, trade-offs — the work that actually requires judgment.

That's the new way of working.

---

*Project: ARIEF-VISEO-DEV-ORG (github.com/angryracoon)*
*Stack: Claude Code + claude-opus-4-6 / claude-sonnet-4-6 + @salesforce/mcp@0.30.13 + @modelcontextprotocol/server-github*
*Experiment period: June 17 – June 24, 2026*
