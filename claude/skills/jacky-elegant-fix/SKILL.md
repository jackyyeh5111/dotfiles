---
name: jacky-elegant-fix
description: "Modify code with the most elegant approach: find the layer that actually owns the behavior and fix it there, instead of patching symptoms downstream with flags, special cases, or state pushed across layers. Use whenever you are about to fix a bug, change behavior, or improve an error message, and especially when the user says 'most elegant', 'clean fix', 'root cause', 'not a hack', 'not a weird patch', 'fix it properly', or pushes back on a fix as patchy. Also use when your own draft fix adds a new flag/field to carry information between components, mutates another component's internal state, or copies the same few lines into several call sites."
user-invocable: true
argument-hint: "[bug, symptom, or change to make]"
---

# Elegant Fix

Most bugs show up far from where they're caused. Patching where the symptom appears is fast, but it usually means sending information across layers that were never meant to carry it. The result is harder to follow, and the next person has to rediscover the real cause anyway. The goal here is the fix that someone who knows the whole system would call obviously right, which is often a small change in a different place than you expected.

## Process

### 1. Trace the symptom to the decision that caused it

Keep asking "why is this state what it is?" until you reach the code that *decided* it, not code that just passes it along. Read the real code at every step and don't infer from names. An earlier trace can be wrong: if a test fails in a way your trace doesn't explain, re-trace instead of adding a workaround.

Things to identify:
- the value or state that is wrong from the caller's point of view
- the component that sets it, and the component that decided it should be set that way
- whether that decision is intentional, and what it protects

Example: an error message came out generic because a "discovered device count" was still at its "not discovered yet" value. The cause wasn't the error-message code or the discovery code. The server refused the connection before discovery could run, and fixing that one place made the existing discovery path produce the right state by itself.

### 2. Recognize a downstream patch before you write it

Your draft is probably a patch if it:
- **adds a flag or field whose only job is to carry a failure reason** from the component that knows it to one that doesn't
- **writes another component's internal state** from outside (e.g. `other->count = 0`) instead of letting that component set it through its own logic
- **copies the same few lines into several call sites**
- **guards against a situation that can't happen**, "just in case"
- **special-cases after the fact**, deciding what went wrong by inspecting leftover state
- needs a comment to explain why it's reaching across a boundary

Any one of these is a signal to go back to step 1.

### 3. Prefer the fix that removes code or reuses an existing path

At the layer that owns the behavior, check what's already there. Often the existing flow already handles the case correctly and just never gets reached (e.g. a handler that already supports zero items, blocked by an earlier early-return). The best fix is often deleting that early exit rather than adding anything new.

In order of preference:
1. Delete or relax the thing that stops the correct existing path from running.
2. Change behavior at the component that owns it, using that component's own logic.
3. Add a small, well-named capability at the owning layer.
4. Only then consider changes at the caller.

Don't add new state, locking, or configuration layers when an existing mechanism can express the change.

### 4. Check the blast radius of fixing it at the owner

Fixing at the source changes behavior for every consumer of that layer, not just the one you were looking at. Before committing to it:
- **Find every caller** of the changed behavior across the repo, including tools, CLIs, bindings and tests, and describe how each one changes.
- **Check safety**: does the new path let callers reach code that assumed the old guard? Read the handlers or functions that are now reachable and confirm they validate inputs.
- **Consider version skew**: old client with new server and new client with old server, if the change crosses a process or API boundary.
- **Consider external consumers** outside the repo that might depend on the old behavior. Call these out; you can't verify them.

If the blast radius is worse than a local patch, say so and let the user choose. Elegance isn't worth a risky protocol change for a cosmetic gain.

### 5. Clean up, then explain the reasoning

- Revert any patch-style changes from earlier attempts completely. Check `git diff` to confirm those files are back to their original state.
- Keep code comments to a line or two. Put the full reasoning in the commit message or the reply.
- In your reply to the user:
  - **root cause:** why the state was wrong
  - **the owning layer and the change**
  - **why it's better than the patch:** what the patch would have had to do
  - **blast radius:** every affected caller and how it changes
  - **what you didn't verify**

## When the downstream fix *is* the right one

Sometimes the owning layer is off-limits: it's a third-party library, a frozen protocol, another team's component, or the user has said not to touch it. Then a caller-side fix is correct. Make it explicit and contained: one helper, one place, with a short comment naming the upstream behavior it compensates for. Tell the user it's a workaround and where the real fix would go.
