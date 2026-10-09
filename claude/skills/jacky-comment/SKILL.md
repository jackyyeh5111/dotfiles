---
name: jacky-comment
description: "Adds or rewrites code comments in Jacky's style: short, clear inline comments at the key steps, plus an overall comment above a function that says what it does, what it produces, and gives one concrete worked example. Use whenever the user asks to add, improve, or clean up comments, e.g. 'add comments for this place', 'comment this function', 'add overall comments above this function', 'explain this in a comment'."
user-invocable: true
argument-hint: "[file:line or function name]"
---

# Code Comments

Write comments a teammate can read once and understand what the code does and what it produces, without walking through the loop.

## Process

1. **Read the real code first.** Open the function and trace what it reads, what it writes, and which order the output comes out in. If the user's notes say something about behavior, check it against the code before you write it down.

2. **Add inline comments at the key steps only.** Put one at each non-obvious step, such as a matching loop, a fallback, or an ordering rule. Keep each one to 1–2 lines. Say what the step does or the one constraint that matters:

   ```cpp
   // Map each pre-model output to the DFP input with the same name
   ...
   // Unmatched DFP inputs are passthrough, kept in ascending DFP index order
   // (so passthrough inputs follow DFP order, not the original model's order)
   ```

3. **Add an overall comment above the function** when asked or when the function is not obvious:
   - **Line 1–2:** what it does, and what each output member/return value holds. Cover every branch (e.g. pre *and* post) in one sentence when they are symmetric.
   - **Then a worked example:** small made-up inputs and the exact outputs. Choose inputs that show the subtle part. For example, list items out of order so the reader can see which output keeps the input order and which output is sorted.

   ```cpp
   // Match pre-model outputs (or post-model inputs) to DFP ports by name: dfp_pattern holds the matched
   // DFP indices, passthrough_featuremaps holds the unmatched ones in ascending DFP order.
   // e.g. DFP inputs [a, b, c, d], pre-model outputs [c, a]
   //      -> dfp_pattern = [2, 0], passthrough_featuremaps = [1, 3] (b, d)
   ```

4. **Check the example by hand** against the code. A wrong example is worse than none.

5. **Apply with minimal edits.** Change only comments. Then show the `git diff` of the commented region in the reply. If the same pattern appears in a sibling branch or function, mention it and offer to comment it too, rather than doing it unasked.

## Style rules

- Use `//` comments that match the file's existing style and indentation. Don't add Doxygen blocks unless the file already uses them.
- Keep the overall comment to about 2–4 lines, including the example. Keep inline comments to 1–2 lines.
- Use real identifiers (`dfp_pattern`, `passthrough_featuremaps`) so readers can grep for them.
- Use tiny symbolic values (`[a, b, c, d]`, indices `[2, 0]`) in examples, not real model names.
- Indent the example's result line with `->` under the inputs.
- Don't narrate obvious code ("loop over i"), don't hedge, and don't write long rationale. Rationale belongs in the commit message.
