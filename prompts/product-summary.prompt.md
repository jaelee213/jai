---
name: product-summary
description: >
  Generate a product-friendly summary of a ticket triage or implementation plan.
  Use when asked for "product summary", "stakeholder summary", "non-technical summary",
  or "executive summary" of a triaged ticket.
---

# Product Summary — Non-Technical Stakeholder View

Generate a clear, jargon-free summary that a product manager, customer success manager, or non-technical stakeholder can read and understand. This should be a single document they can forward to a customer or bring to a planning meeting.

## Input

Read the implementation plan and/or clarifying questions for the ticket. If both exist, use both. If given a ticket ID, look for files in `implementation_plans/` and `clarifying_questions/` directories.

## Output Format

Produce a single document with exactly three sections:

```markdown
# [TICKET-ID]: [Title in Plain Language]

## What We're Building

[2-4 sentences in plain language. Describe the problem the customer has today,
what the solution looks like from a user's perspective, and the key user-facing behaviors.
No mention of repos, files, functions, arrays, schemas, or technical internals.
Focus on: what the user sees, what admins configure, and what changes in their workflow.]

## Assumptions We're Working With

[Numbered list. Each assumption in one sentence. Written as "We assume that..."
These are decisions already made — either confirmed by stakeholders or decided by the team.
Mark each with who confirmed it or that it was a team decision:]

1. **[Source]** — [Assumption in plain language]
2. **[Source]** — [Assumption in plain language]
...

## Open Questions

[Numbered list. If no open questions remain, say "All questions have been resolved."
For each open question:]

1. **[Who needs to answer: Customer / Team / Product]** — [Question in plain language. No technical jargon. Frame it in terms of user experience or business rules, not implementation details.]
...

---
**Estimate:** [T-shirt size] ([day range])
**Status:** [e.g., "Ready to build — no blockers" or "Blocked on Q2 — needs customer input"]
```

## Rules

1. **No technical language.** No repos, APIs, schemas, migrations, flags, functions, array lookups, MongoDB, Racer, Derby, etc. If a technical concept is essential, translate it: "database update" not "migration script", "setting" not "feature flag", "behind-the-scenes plumbing" not "backend services".
2. **Assumptions are facts, not questions.** If something is still open, it goes in Open Questions. Assumptions are things we've decided or that have been confirmed.
3. **Questions must be actionable.** Each question should make it clear what decision is needed and who needs to make it.
4. **Keep it short.** The whole document should fit on one screen. If the plan is complex, summarize — don't enumerate every detail.
5. **Include the estimate and status** at the bottom so the reader knows where things stand.
