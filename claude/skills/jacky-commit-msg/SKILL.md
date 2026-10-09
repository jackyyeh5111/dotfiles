---
name: jacky-commit-msg
description: "Writes or rewrites a git commit message or PR description in simple, everyday words with an airy, easy-to-scan layout (Problem / Fix / Tests, each heading followed by a blank line and short indented sentences), adding a tiny pure-text diagram or a 1–3 line code example only when it explains the bug better than prose. Short, but long enough to carry the full meaning. Use whenever the user asks to write, reword, amend, or clean up a commit message or PR message/description, e.g. 'modify last commit msg', 'write the PR msg', 'make the commit message clearer', 'commit msg looks too crowded'."
user-invocable: true
argument-hint: "[commit ref or PR number; default: HEAD]"
---

# Commit / PR Message

Write a message anyone on the team can read once and understand, even if they don't know the code: what broke, why, what changed, and how it's proven.

## Process

1. **Read the real change.** Run `git show <ref>` (or `git diff dev...HEAD` / `gh pr view` for a PR) and the current message. Write from the diff, not from the old message alone. If the old message has facts the diff doesn't show (the trigger, the root cause), keep them.

2. **Write the message in this shape:**

   ```
   <Subject: imperative, specific, ≤ ~72 chars>

   Problem:

     <what the user sees going wrong, in one short sentence>
     <the trigger>
     <the root cause>

     <optional: why the existing mechanism didn't cover it>

   Fix:

     <what now happens, one short sentence per change>
     <what still works as before, if anyone might worry>

   Tests:

     <what the test does and that it passes>
   ```

   Layout rules:
   - Put a blank line after each heading, and between headings.
   - Indent every body line by 2 spaces under its heading.
   - One short, complete sentence per line. End it with a period.
   - Use a blank line inside a section to split a separate thought
     (e.g. the root cause vs. "send_input() already does this").
   - No `-` bullets and no `Component:` prefixes; they make it look busy.

   Drop any section that has nothing to say. For a trivial change, a subject plus 1–3 lines is enough.

3. **Diagram only when it beats prose.** It works well for a deadlock, a race, an ordering bug, or a data flow. Keep it 2–4 lines, plain ASCII, aligned, with one actor per line, indented like the rest of the section:

   ```
     manual_output_loop: pop() waits for a buffer -> never comes
     ~MxModel:           join(manual_output_loop) -> waits forever
   ```

   Never use markdown tables, box-drawing art, or anything wider than ~72 columns.

4. **Add a simple example when it makes things clearer.** If a reader
   would understand faster by seeing a call, add a 1–3 line snippet
   showing what failed or what now works. Put it right after the
   sentence it supports, indented 4 spaces, with a blank line above
   and below:

   ```
     Passing a list of arrays failed with a TypeError:

       outputs = accl.run([x1, x2], stream_id=0)   # TypeError
   ```

   Skip it when the sentences are already obvious. Use at most one
   example per section, and keep it short with simple names (`x1`, `x2`).

5. **Check the length.** Aim for about 6–12 sentences in the body (blank lines don't count). If you're over that, cut repetition and explanation of obvious code before you cut causes or caveats. If you're under, make sure the root cause and test intent are still stated, not just implied.

6. **Apply it.**
   - Commit: write the message to a file in the scratchpad, then `git commit --amend -F <file>` (or `-F` on a new commit). First check `git branch -r --contains HEAD`: if the commit is already pushed, say that amending needs a force-push, and ask before rewriting it.
   - PR: `gh pr edit <n> --body-file <file>`, or print the message for the user to paste.
   - No attribution line: leave out `Co-Authored-By: Claude ...` and the "Generated with Claude Code" footer.
   - Show the final message in the reply.

## Word choice

- Write for someone who knows what the API does but not how it's built.
  Describe what they would see ("run() only accepted one numpy array",
  "failed with a TypeError"), not the internals that cause it.
- Leave out internal types and plumbing (`py::array_t<float>`, "pybind
  lambda", "BindObjMT") unless the fix can't be understood without them.
- Keep public names a reader would grep for (`run()`, `send_input()`,
  test names), but don't narrate the code line by line.
- Use everyday words: "accepts", "fails", "waits forever", "still works".
- Wrap lines at ~72 columns.
- Don't use filler ("This commit…", "In order to…") or hedging, and don't repeat the subject in the body.

## Example

```
Let MxAcclMT.run() accept a list of inputs

Problem:

  run() only accepted one numpy array.
  Passing a list of arrays failed with a TypeError.
  So models with more than one input could not use run().

  send_input() already accepts both a list and a single array.

Fix:

  run() now accepts the same input types as send_input().
  Passing a single array still works as before.

Tests:

  test_pre_passthrough sends 5 inputs through run() and passes.
  All 25 TestAcclMT tests pass.
```
