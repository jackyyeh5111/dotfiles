---
name: jacky-review
description: "Guides a human reviewer through a change: states what it is for, groups the changed files into layers, and gives a step-by-step reading order with what to check at each step, written in simple, natural words. Use whenever the user asks for help reviewing a commit, branch, diff, or PR themselves, e.g. 'guide me through this review', 'what order should I read these files', 'act as my code review guide', 'walk me through the last commit'. Not for running an automated review (use review / code-review for that)."
user-invocable: true
argument-hint: "[commit ref, branch, or PR number; default: latest change]"
---

# Review Guide

Help a person review a change themselves. Tell them what the change is for,
where to start reading, and what could go wrong at each step. Don't fix or
edit anything.

## Process

1. **Find the real change.** Don't trust a pasted file list. Templates often
   come with the list left empty.
   - Default: `git show --stat HEAD`, then the full diff
   - If HEAD looks wrong (session snapshot differs, recent `reset` in
     `git reflog`, uncommitted diff matching a commit on the remote), work
     out what "latest change" means and say so in one line at the top
   - PR: `gh pr diff <n>`, branch: `git diff dev...<branch>`
   - Ask only if two candidates are equally likely

2. **Read beyond the diff.** For each changed function, read the code around
   it: callers, other users of the same queue/lock/flag, shutdown and error
   paths, and the matching path in other modes (auto vs manual, local vs
   shared). Most real risks sit next to the diff, not inside it.

3. **Check each risk before you write it down.** Each one needs a
   `file:line` and a short reason. Write it as a fact only when you've
   read the code that proves it. If you haven't proven it, write it as a
   question for the reviewer ("make sure X can't happen").

4. **Write the guide in this shape:**

   ```
   One line: which change this covers (ref + subject)

   ## What this change is for
   2–4 lines: what went wrong, the trigger, the cause, the fix idea
     <optional 2–4 line text diagram>

   ## Files, grouped
   - **<Layer>:** `file` — what changed, in a few words
   - Note any unrelated file in the diff (e.g. submodule bump)

   ## Reading order
   ### Step N: <plain title> (`file:line`)
   One or two lines: what it does and why read it now
   Check that:
   - <thing that must stay true, or a way it could break>

   ## The things that matter before merge
   1. <top risks, most serious first, one line each>

   One line: what you read vs. what you built or ran
   ```

   Order the steps so each one builds on the last. Start with the lowest
   piece the rest depends on (a helper, data type, or primitive), then the
   logic that uses it, then lifecycle and cleanup, then tests.

5. **For tests, check that they prove the fix.** Would the test fail
   without the fix? Does a regression fail the test, or just hang it? Do the
   assertions check the outcome or only that the code ran?

## Style rules

- Use plain words: "holds a buffer", "runs dry", "waits forever". Don't
  write "invariant", "lifecycle semantics", or "ownership model" when a
  short phrase says it
- Use real identifiers (`receive_output()`, `~MxModel`) so the reader can
  grep for them, but don't walk through the code line by line
- Write one idea per bullet. Keep bullets as short phrases without a
  trailing period
- Add a diagram only when it explains the problem better than words (a
  deadlock, race, or ordering bug). Keep it to 2–4 lines of plain ASCII,
  with no markdown tables and no box-drawing characters
- Use bold labels only for the two or three risks that matter most, not on
  every bullet
- Don't use filler or hedging. Say what you didn't verify once, at the end
