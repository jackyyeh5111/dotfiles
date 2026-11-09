---
name: jacky-commit-msg
description: "Writes or rewrites a git commit message or PR description in simple, everyday words with an airy, easy-to-scan layout (Problem / Fix, plus Tests only when a test matters, each heading followed by a blank line and short indented sentences), adding a short usage example whenever the change adds something people run or call (a command, option, or API), and a tiny pure-text diagram or code snippet for a bug only when prose can't explain it. Always write two drafts: follow the guide, then rewrite for clarity with plain words and a small ASCII diagram when helpful. Use whenever the user asks to write, reword, amend, or clean up a commit message or PR message/description, e.g. 'modify last commit msg', 'write the PR msg', 'make the commit message clearer', 'commit msg looks too crowded'."
user-invocable: true
argument-hint: "[commit ref or PR number; default: HEAD]"
---

# Commit / PR Message

Write a message anyone on the team can read once and understand, even if they don't know the code: what broke, why, and what changed.

**Write every commit or PR message twice before showing or applying it.**
First, draft the complete message using this guide. Then rewrite the whole
message for readability in step 6, even if the first draft seems good.
Keep both passes internal and show only the second draft unless the user
asks to see both.

## Process

1. **Read the real change.** Run `git show <ref>` (or `git diff dev...HEAD` / `gh pr view` for a PR) and the current message. Write from the diff, not from the old message alone. If the old message has facts the diff doesn't show (the trigger, the root cause), keep them.

2. **First pass: draft the complete message in this shape.** Follow
   the layout below and the rules in steps 3–5:

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

4. **Usage example: include it for anything new people run or call.** When
   the change adds or changes a command, option, flag, or API, show 1–3
   lines of how to use it in the Fix section, with a short `#` comment on
   each saying when to use it. This beats describing the options in prose.

   ```
       bash run_test.sh                # everything
       bash run_test.sh quick          # after each change
   ```

5. **Use a small text visual when it makes the explanation easier.**
   A 2–4 line ASCII diagram can show cause and effect, a sequence, or
   before/after behavior. A 1–3 line code snippet can show a failing call.
   Use the visual in place of the prose it explains; otherwise keep prose.

   ```
     Passing a list of arrays failed with a TypeError:

       outputs = accl.run([x1, x2], stream_id=0)   # TypeError
   ```

   Never use markdown tables, box-drawing art, or anything wider than ~72 columns.

6. **Second pass: rewrite the entire message for clarity.** Write a new
   version of the subject and body, rather than just checking the first
   draft or swapping a few words. Read it as a teammate seeing this change
   for the first time:
   - Lead with what the reader sees, why it happens, and what changes.
   - Use everyday words and short sentences. Keep jargon only when needed
     for accuracy or to name something the reader needs to find in code.
   - Cut repetition, side details, and sentences that add no useful meaning.
   - Consider the ASCII visual from step 5 if it makes the explanation
     easier to understand than prose alone.
   - Preserve the facts, important limits, required usage example, and layout.
   - Aim for 3–7 body sentences; trivial changes may stay shorter.

   Compare both drafts against the diff. Finish only when the second draft
   accurately explains the change and is as easy to read as you can make it.

7. **Apply only the second draft.**
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

After the second pass (show this version):

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

## Example: a new option, too detailed vs. right

Too detailed (lists every side change, explains options in prose):

```
Add a quick mode to run_test.sh

Problem:

  Checking a change meant running every suite in every mode.
  Most tests give the same result in shared, local and shm mode,
  so the repeats only cost time.

  A pytest run that was cut short left its manager running.

Fix:

  run_test.sh quick runs the shared suite without slow tests,
  plus a short smoke run in local and shm mode.
  --prepost, --py and --bench add the area you touched.
  With no arguments the script still runs everything.

  Each run first stops a leftover test manager.
  Messages print real line breaks, and crashes leave a core dump.
  The test README explains how to use the script.
```

After the second pass (show this version):

```
Add a quick mode to run_test.sh

Problem:

  run_test.sh runs every test in every mode, which is slow.
  Many tests give the same result in every mode.

Fix:

  Add a quick mode that skips those repeats.
  Running with no arguments still runs everything.

    bash run_test.sh                # everything
    bash run_test.sh quick          # after each change
    bash run_test.sh quick --py     # also the Python tests

  Use --prepost, --py or --bench for the area you changed.
  The README explains each option.
```
