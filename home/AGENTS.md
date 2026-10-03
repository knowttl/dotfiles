# Baseline Agent Guidelines

### 1. Think Before Coding

- State assumptions. When a request has more than one reading, present them all and ask. Never pick one silently.
- Propose simpler alternatives when they exist.
- Give little weight to development cost in technical decisions. Prefer quality, simplicity, robustness, scalability, and long-term maintainability.

### 2. Write the Minimum

- Never add unrequested features, abstractions, flexibility, or configurability.
- Never handle impossible scenarios.
- If 200 lines could be 50, rewrite to 50.
- For one-off operational work, take the simplest direct path. No wrappers or automation until a repeated need appears.

### 3. Touch Only What You Must

- Leave adjacent code, comments, and formatting alone. Match existing style.
- Exceptions: fix unrelated lint failures, test failures, flaky tests, and UI defects you encounter. Be picky about UI and aim for pixel perfection. Never walk past them.
- Remove what your changes orphaned. Mention other dead code but never delete it.
- Never edit third-party source.
- Refactoring preserves behavior and targets only the blocking smell. Never slip in features or refactor everything in sight.

### 4. Define Success, Then Verify

- Turn the task into verifiable E2E goals and loop until they pass, testing as a real user would.
- Start every bug fix by reproducing it end to end, as close to the user's experience as possible.
- For multi-step work, state a plan: `1. [Step] -> verify: [check]`.

### 5. Write for Local Reasoning

- Precise names. One term per concept.
- Split a function only when the piece stands on its own. A reader should follow one concept without bouncing between files.
- Comments only for rationale, constraints, warnings, or contracts.

### 6. Prefer Deep Modules

- Every interface, wrapper, and layer must hide more complexity than it adds. A module whose interface is nearly as complex as its implementation is shallow: inline it or merge it into its neighbor.
- Deletion test: if removing a module would concentrate its complexity in one place, it is shallow and should go. If removal would spread complexity across callers, it is deep and earns its keep.
- Design interfaces around caller needs, not implementation details.
- Make invalid states impossible. Never make callers repeat defensive checks.
- One source of truth per piece of system knowledge.
- Flag shallow modules you encounter and propose deepening refactors. Do not apply them unasked.

### 7. Tool Selection for File Edits

- Edit files through the harness's dedicated file-editing tool (apply-patch, str-replace, edit, write, or similar).
- Never shell out to edit files: no `python -c`, `sed`, `awk`, `perl`, `tee`, here-docs, or `echo`/`cat` redirection, even for one line.
- Sole exception: a mechanical change across so many files that individual edits would exhaust context. Say so before scripting it.

### 8. Long-Running Operations

- Never poll: no `sleep X && check`, retry loops, or repeated status checks. Each turn burns context.
- Wait once instead: run slow work as one foreground command with a generous timeout, or block on the PID, tail the log until the event appears, or run one health check after the expected completion time.
- Start processes that must outlive the command (servers, daemons) detached, with output redirected to a log file.

### 9. Testing

- Reuse the repo's test conventions, fixtures, and builders. Never add a parallel setup or mock layer.
- Test through the module's real interface, at the lowest level that sees the behavior. Never extract code just for testability. Mock only true boundaries (network, clock, randomness, external services), preferring our own fakes. Keep E2E tests in the suite only for critical journeys lower levels miss.
- Add a test only if a plausible production change would fail it. Skip what types or existing tests cover, private helpers, and framework defaults. Ignore coverage.
- One behavior per test, named for it. Cover boundaries and failures. Use table-driven cases. No logic in tests.
- Assert outcomes, not internals. Assert interactions only when they are the requirement.
- Isolated and deterministic: no shared state, order dependence, leaks, or sleeps. Fake time, seed randomness.
- Run new tests before finishing, repeatedly if they touch time, async, or I/O.
- Delete low-value tests you wrote. Flag existing ones, never delete unasked.

### 10. Personal Guidelines

- Never use the em dash. Use a plain dash instead.
- Never auto-add your agent name as a commit co-author.
- Never manually modify `CHANGELOG.md` files or files marked as auto-generated.
- Before using dynamic workflows, ultracode, or any feature that spawns a large swarm of subagents, explain the tradeoffs and get explicit user approval.
- In long Markdown files, put each full sentence on its own line.
