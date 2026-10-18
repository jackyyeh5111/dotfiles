---
name: jacky-plan
description: "Plans a new feature before any code changes, in four phases: explore the codebase, grill the user one question at a time on requirements and trade-offs, write a detailed implementation plan, then critically review it and present it for approval. Use whenever the user says 'I want to implement X', 'plan this feature', 'jacky-plan', or asks for a plan they will approve before coding starts."
user-invocable: true
argument-hint: "[feature to implement]"
---

# Feature Plan

The user wants to implement: **$ARGUMENTS**

If no feature was given, ask what it is before doing anything else.

Stay in Plan Mode for the whole workflow. If not already in it, enter it
with EnterPlanMode. Do not modify code until the user explicitly approves
the plan.

## Phase 1 — Explore

- Examine the existing codebase around the feature.
- Understand the relevant architecture: who owns the behavior, how data
  and control flow through it, which paths (modes, error, shutdown) touch it.
- Identify constraints and dependencies: APIs that must stay compatible,
  threading/locking, build and test setup.
- Briefly summarize what you found before moving on.

## Phase 2 — Grill Me

- Use the grilling skill to challenge the requirements and assumptions.
- Ask **one question at a time** (this overrides grilling's round format),
  with your recommended answer.
- Focus on architecture, trade-offs, edge cases, and potential failure modes.
- Don't make major design decisions without discussing them with the user.
- Continue until the important ambiguities are resolved.

## Phase 3 — Plan

Produce a detailed implementation plan that covers:

- **Affected files** and what changes in each
- **Architecture decisions**, with the trade-offs behind each major one
- **Implementation steps**, in order
- **Tests**: what to add or update, and how to run them

## Phase 4 — Review

- Critically review the plan for missing cases (error paths, other modes,
  cleanup, compatibility) and unnecessary complexity (new flags, state, or
  layers that an existing path could handle).
- Fix what you find, then present the final plan for approval with
  ExitPlanMode.

Do not modify code until the user explicitly approves the plan.
