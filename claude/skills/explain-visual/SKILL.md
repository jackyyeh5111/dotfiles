---
name: explain-visual
description: "Explains a piece of code, a test, or a logic flow in plain language plus a pure-text (ASCII) diagram — no markdown tables, no generated images. Use whenever the user asks to explain, walk through, trace, or visualize how a function, test, protocol exchange, or control/data flow works, especially phrases like 'explain this logic', 'walk me through', 'visualize with text', 'what does this test do', or 'draw this out'."
user-invocable: true
argument-hint: "[file:line, function/test name, or pasted code]"
---

# Explain Visual

Explain the target simply, then show it as a text diagram. The diagram is what makes this different from a normal explanation — don't skip it, and don't let it replace the plain-language framing either.

## Process

1. **Read enough code to be sure.** Don't explain from the name or a guess. Read the target and any function/struct/enum it directly depends on for its meaning (e.g. an enum whose values are checked, a helper it calls). Use search tools or a fork if the target spans multiple files and would cost a lot of context to read inline — the point is to explain what the code actually does, not what it plausibly does.

2. **Give a short plain-language summary first.** One to three sentences: what this does and *why it exists* (what problem or bug it guards against, what invariant it protects). Skip jargon the reader hasn't used themselves in this conversation. If the logic is genuinely trivial (a one-line getter, a straightforward loop), say so briefly and don't force a diagram on it — over-explaining trivial code is worse than under-explaining it.

3. **Then show a pure-text diagram of the flow.** Pick whichever shape fits what the code actually does:
   - **Sequential steps / protocol exchange** (client↔server, caller↔callee): numbered steps with `──▶` / `◀──` arrows between named actors.
   - **Branching logic** (if/else, switch, state check): an indented decision tree or `if / else` blocks showing which path is taken under which condition.
   - **State machine**: boxes for states, arrows labeled with the transition/event.
   - **Data transformation pipeline**: boxes connected by `──▶` showing what shape the data is at each stage.

   Keep it in a single fenced plain-text block (no syntax highlighting language tag needed), sized to fit a terminal (~70-80 cols wide). Use only plain ASCII/box-drawing characters (`─│▶◀┌┐└┘├┤`, or plain `->`/`|` if you want to stay ultra-plain) — never a markdown table, never an actual image.

4. **Close with why it matters, only if non-obvious.** If the summary in step 2 already covered the "why," don't repeat it. If there's a specific failure this code prevents (a race, a stale read, a crash), name it concretely with the exact trigger — don't gesture vaguely at "safety."

## Example shape (protocol exchange)

```
Client                                   Manager
  │                                         │
  ├──try_local_lock(0)────────────────────▶│
  │                                         │  lock_table[0] = client_id
  │◀────────────────────────────── OK ──────┤
  │                                         │
  ├──get_device_statuses()────────────────▶│
  │                                         │  owner_id = lock_table.check_lock(0)
  │                                         │  owner_id != 0 → skip hardware poll
  │◀── [{mode=LOCAL, valid_fields=0}] ──────┤
```

## Boundaries

- Don't produce the diagram without the plain-language summary, or vice versa — they answer different questions (what/why vs. how the pieces move).
- Don't pad trivial code with an elaborate diagram just to satisfy the format.
- If the target is genuinely too large to trace faithfully without guessing, say which part you traced and which you didn't, rather than inventing plausible-looking steps.
