---
name: jacky-commit-msg
description: "Writes or rewrites a git commit message or PR description in simple, everyday words with an airy, easy-to-scan layout (Problem / Fix, plus Tests only when a test matters, each heading followed by a blank line and short indented sentences), adding a tiny pure-text diagram or a 1–3 line code example only when prose can't explain it. The first draft must already be short and plain; the user should never need to ask to simplify it. Use whenever the user asks to write, reword, amend, or clean up a commit message or PR message/description, e.g. 'modify last commit msg', 'write the PR msg', 'make the commit message clearer', 'commit msg looks too crowded'."
user-invocable: true
argument-hint: "[commit ref or PR number; default: HEAD]"
---

# Commit / PR Message

Write a message anyone on the team can read once and understand, even if they don't know the code: what broke, why, and what changed.

**The first draft you show must already be the simple one.** The user should never have to say "make it simpler". If you're unsure, go shorter and plainer.

## Process

1. **Read the real change.** Run `git show <ref>` (or `git diff dev...HEAD` / `gh pr view` for a PR) and the current message. Write from the diff, not from the old message alone. If the old message has facts the diff doesn't show (the trigger, the root cause), keep them.

2. **Write the message in this shape:**

   ```
   <Subject: imperative, plain words, what the user gets, ≤ ~50 chars>

   Problem:

     <what the user sees going wrong, in one short sentence>
     <the root cause, in one or two short sentences>

     <optional: a second, separate problem>

   Fix:

     <what now happens, one short sentence per change>
   ```

   Layout rules:
   - Put a blank line after each heading, and between headings.
   - Indent every body line by 2 spaces under its heading.
   - One short, complete sentence per line. End it with a period.
   - Use a blank line inside a section to split a separate thought.
   - No `-` bullets and no `Component:` prefixes; they make it look busy.

   For a trivial change, a subject plus 1–3 lines is enough.

3. **Tests: leave the section out by default.** Add it only when a test is
   worth a reader's attention, for example a new regression test that
   reproduces this exact bug. Never add it just to say "builds", "all
   tests pass", or that you checked it by hand.

4. **Diagram or example: almost never.** Add a 2–4 line plain-ASCII diagram
   or a 1–3 line code snippet only when the sentences alone can't make the
   bug clear. If the Problem section already reads clearly, skip it.

   ```
     Passing a list of arrays failed with a TypeError:

       outputs = accl.run([x1, x2], stream_id=0)   # TypeError
   ```

   Never use markdown tables, box-drawing art, or anything wider than ~72 columns.

5. **Simplify before showing it.** The body should be about 3–7 sentences
   (blank lines don't count). Then go through it line by line:
   - Cut any line a teammate could skip and still get the point.
   - Replace mechanism words with what they mean: "blocks signals with
     pthread_sigmask and waits in sigwait()" becomes "the main thread
     waits for Ctrl+C".
   - Drop "what still works as before" unless someone would really worry.
   - Drop anything that already lives in a code comment.

6. **Apply it.**
   - Commit: write the message to a file in the scratchpad, then `git commit --amend -F <file>` (or `-F` on a new commit). First check `git branch -r --contains HEAD`: if the commit is already pushed, say that amending needs a force-push, and ask before rewriting it.
   - PR: `gh pr edit <n> --body-file <file>`, or print the message for the user to paste.
   - No attribution line: leave out `Co-Authored-By: Claude ...` and the "Generated with Claude Code" footer.
   - Show the final message in the reply, in a code block. Put one space on
     each blank line inside it: Claude Code's terminal drops truly empty
     lines from code blocks. Only the reply needs this; the commit file
     keeps real empty lines.

## Word choice

- Write for someone who knows what the tool or API does but not how it's
  built. Describe what they would see ("Ctrl+C could hang", "failed with
  a TypeError"), not the internals that cause it.
- Leave out internal types, system calls, and plumbing (`py::array_t`,
  `sigwait()`, "signal mask", "BindObjMT") unless the fix can't be
  understood without them.
- Keep public names a reader would grep for (`run()`, `send_input()`),
  but don't narrate the code line by line.
- Use everyday words: "accepts", "fails", "hangs", "waits forever", "still works".
- Wrap lines at ~72 columns.
- Don't use filler ("This commit…", "In order to…") or hedging, and don't repeat the subject in the body.

## Example: too detailed vs. right

Too detailed (the user had to ask twice to simplify this):

```
Stop mxa_manager on the main thread instead of in a signal handler

Problem:

  Pressing Ctrl+C could hang mxa_manager instead of stopping it.
  The SIGINT handler deleted the whole server inside the handler.
  The handler runs on whichever thread the signal interrupts.
  If that thread holds a lock, teardown waits on it forever:

    worker:   holds a lock -> interrupted by SIGINT, runs the handler
    handler:  delete server -> waits for that lock -> never released

  SIGTERM (plain kill, systemd stop) skipped cleanup entirely.

Fix:

  SIGINT and SIGTERM are blocked before the server starts.
  All worker threads inherit this, so no worker is ever interrupted.
  The main thread waits for either signal with sigwait().
  It then returns from main(), and the server shuts down normally.

Tests:

  main_linux.cpp builds on its own against the committed server code.
```

Right (write this the first time):

```
Stop mxa_manager safely on Ctrl+C

Problem:

  Ctrl+C could hang mxa_manager instead of stopping it.
  The Ctrl+C handler could run on a worker thread holding a lock.
  The handler then deleted the server, which waited on that lock forever.

  A plain kill (SIGTERM) did not clean up at all.

Fix:

  The main thread now waits for Ctrl+C or kill.
  Then it shuts the server down normally.
  Worker threads are never interrupted by these signals.
```
