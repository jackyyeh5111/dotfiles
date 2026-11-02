---
name: jacky-test
description: "Writes new tests, or checks existing tests, against Jacky's test rules: every test names the bug it catches, expected values are worked out by hand, and tests exercise the real code instead of mocks. Use whenever you write, change, or review tests, add a mock, stub, fake, or test helper, or are tempted to add a method to production code that only tests call. Also use when the user says 'write tests', 'add a test', 'check my tests', 'are these tests good', 'review the tests', 'this test is useless', or asks whether a test is testing a mock."
user-invocable: true
argument-hint: "[write | check] [file, function, or test path]"
---

# Tests

A test exists to catch a specific break. Two rules drive everything below:

```
1. Every test names the break it catches
2. Every test exercises the real thing
```

Writing the test first and watching it fail against real code proves both: the test can fail, and a mock only shows up once the real dependency proves slow or external.

## Modes

- **write**: write tests for new or changed behavior. Follow the rules, then run the mutation check.
- **check**: audit existing tests (a file, a directory, or the tests in the current diff). Report each problem, then fix only if the user asked for fixes.

If the user doesn't say, pick from context: new code with no tests → write; existing tests named → check.

## Rule 1: Name the break

Before writing the test body, answer: **what production change should make this test fail, and is that change a bug or a decision?** A test earns its place by catching a wrong branch, missing side effect, wrong argument, boundary case, or broken contract.

**Work out expected values by hand.** Use literals and hand-checked fixtures. Table-driven tests with literal `want` values are the preferred shape. An expected value computed by the code under test, or its helpers, passes no matter what that code does:

```typescript
// ❌ Mirror: the same builder computes both sides, always true
expect(buildQuery({ tag: 'urgent' })).toBe(buildQuery({ tag: 'urgent' }));

// ✅ Hand-derived literal
expect(buildQuery({ tag: 'urgent' })).toBe('tag:"urgent"');
```

**No change detectors.** If only intentional decisions can fail a test (a constant's value, exact message wording, private structure), it fires on redesign and sleeps through bugs. Test the behavior that depends on the decision: not `expect(MAX_RETRIES).toBe(5)`, but "a failing call is retried 5 times and a 6th attempt never happens."

**Behavior, not text.** Asserting that a script, skill, or config contains an exact line proves only that the source is the source. Run scripts against controlled inputs and assert outputs, side effects, or exit codes. Prose for humans earns no test.

**Your code, not the framework.** Test the contract your code makes at its edges: the route you register, the query you emit, the payload you produce. Don't test that the router calls a registered handler; that's the framework's job. If upstream behavior surprised you, write one narrow test that names the assumption. Same inside your code: constructors, getters, constants, and plain forwarding earn tests only when they validate, normalize, default, derive, enforce, or cause side effects. Otherwise assert the first result a caller can see that depends on them.

### Gate

```
BEFORE writing the test body:
  Name the production change that would make this test fail.

  Can't name one            → redesign around observable behavior
  "The source text changed" → run the artifact, assert its effects
  Only intentional decisions → change detector; test the behavior
                               that depends on the decision

  Is the expected value derived without the code under test?
    No → replace it with a literal or hand-checked fixture
```

## Rule 2: Exercise the real thing

**Never assert on a mock.** A mock assertion passes when the mock is there and fails when it isn't. It says nothing about the real component. Assert real behavior; if the mock is what you're checking, unmock it or delete the assertion.

```typescript
// ❌ Mock existence
expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();

// ✅ Real behavior
expect(screen.getByRole('navigation')).toBeInTheDocument();
```

**Understand a method before mocking it.** List every side effect of the real method. Keep the ones the test depends on real, and mock the slow or external layer below them. When unsure, run the test against the real code first and watch what actually needs to happen.

```typescript
// ❌ The mock swallows the config write that duplicate detection reads
vi.mock('ToolCatalog', () => ({ discoverAndCacheTools: vi.fn() }));

// ✅ Mock only the slow server startup; the config write stays real
vi.mock('MCPServerManager');
```

**Make doubles specific.** When arguments, call counts, or order are part of the contract, assert them. A fake that accepts anything verifies nothing. Give each branch (success, error, malformed) its own fixture, so the wrong branch can't satisfy the test.

**Mirror real data completely.** A mock response has every field the real one has, not just the ones this test reads. Partial mocks fail silently when downstream code reads a missing field: the test passes while the real integration breaks. Check the real schema, docs, or a captured response.

**No test-only methods in production code.** Cleanup that only tests need lives in test utilities, never as a `destroy()` on the production class. Ask: is this method called only from tests? Does this class own this resource's lifecycle? Wrong answer to either → test utility.

**Prefer real components over complex mocks.** Switch to an integration test with real components when mock setup is longer than the test logic, mocks lack methods the real thing has, or tests break when the mock changes. Ask: "Do we need a mock here at all?"

### Gate

```
BEFORE adding a mock or test helper:
  List the real method's side effects. Keep the ones the test
  depends on real; mock the slow/external layer below them.

  Mock responses mirror the complete real structure.
  A method only tests call lives in test utilities.

  About to assert on the mock itself?
    Unmock it or delete the assertion.

  Red flags: "mock it to be safe", "might be slow, better mock",
  can't explain why the mock is needed.
```

## Tests ship with the code

Failing test, minimal code, refactor: that's what "done" means. Don't call work finished with tests still to write. Ship the tests the behavior needs and only those. Trivial code earns none, and a test written to satisfy process costs maintenance forever.

## Mutation check

Before finishing, mutate the production code in your head. At least one test should fail for each realistic mutation:

- Wrong constant or argument
- Wrong branch handler
- Missing state change or side effect
- Empty or default return
- Missing check for zero, empty, nil, unauthorized, or malformed input

A mutation nothing catches means the behavior is unprotected, or a test is a tautology. When it's cheap, actually make the mutation, run the test, watch it fail, and revert.

## Warning signs

Use this list as the checklist in **check** mode.

| Sign | Fix |
|------|-----|
| Setup and assertion share the same object, so equality is guaranteed | Hand-derived literal |
| Expected value hidden behind loops, builders, or helpers | Inline literal `want` values |
| Fails on every intentional change, never on a bug | Test the behavior behind the decision |
| Can only fail by crash, panic, or missing selector | Assert a real outcome |
| Greps source text, or asserts a removed symbol stays removed | Run it and assert effects |
| Would still matter if only the framework remained | Delete; test your own contract |
| Exists for coverage, checks no outcome or side effect | Delete, or assert the outcome |
| Asserts a `*-mock` test ID, or fails if the mock is removed | Unmock or delete the assertion |
| Mock replaces a method whose side effect the test needs | Mock one layer lower |
| Mock response missing fields the real one has | Copy the full real shape |
| Fake accepts any args; branches share one fixture | Assert args; one fixture per branch |
| Production method called only from test files | Move to test utilities |
| Mock setup is over half the test | Integration test with real parts |

## Output in check mode

Group findings by test. For each one:

- `path:line` and the test name
- which warning sign or rule it breaks, in one line
- the concrete fix (or "delete" when the test catches nothing)

Then list behaviors that have no test but should, from the mutation check. End with a count: tests checked, tests fine, tests to fix, tests to delete.

## Finishing in write mode

1. Run the new tests and confirm they pass.
2. Confirm each one can fail: mutate the code or recall it failing before the fix.
3. Tell the user, for each test, the break it catches in one line.
