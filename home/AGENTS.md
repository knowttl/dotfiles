# Baseline Agent Guidelines

You MUST follow these rules.

### 1. Think Before Coding

- State assumptions. If uncertain, STOP and ask.
- Present all interpretations - NEVER pick one silently.
- Propose simpler alternatives when they exist.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- Before using "dynamic workflows", "ultra code" or any harness feature that immediately spawns a large swarm of subagents, always explain the tradeoffs and ask the user for explicit approval.

### 2. Write the Minimum

- NEVER add unrequested features, abstractions, flexibility, or configurability.
- NEVER handle impossible scenarios.
- If 200 lines could be 50, rewrite to 50.

### 3. Touch Only What You Must

- NEVER "improve" adjacent code, comments, or formatting.
- ALWAYS match existing style.
- Notice dead code? Mention it. NEVER delete it.
- Remove only imports, variables, and functions YOUR changes orphaned.
- Fix unrelated lint failures, test failures, and flakiness when spotted.
- Read third-party source only when docs and types are not enough. NEVER edit it.

### 4. Define Success, Then Verify

- Turn tasks into verifiable E2E goals. Loop until they pass.
- Test E2E as a real user would. Be picky about UI and pixel perfection - fix obvious issues even if unrelated.
- When doing bug fixes, always start by reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
- For multi-step work, state a plan: `1. [Step] -> verify: [check]`.

### 5. Write for Local Reasoning

- Precise names. One term per concept.
- Small, focused functions.
- Keep the happy path readable. Isolate error handling and cleanup.
- Comments ONLY for rationale, constraints, warnings, or contracts.

### 6. Earn Every Abstraction

- Every interface, wrapper, and layer MUST hide more complexity than it adds.
- Design interfaces around caller needs, not implementation details.
- Make invalid states impossible. Never make callers repeat defensive checks.
- Keep domain logic local. Extract shared code only at 2+ callers.

### 7. Refactor Safely

- Refactoring preserves behavior. NEVER rewrite or slip in features.
- Work in small, reversible, buildable steps.
- Refactor ONLY the blocking smell. NEVER everything in sight.

### 8. Engineering Habits

- ONE source of truth per piece of system knowledge.
- Debug from facts. Never guess.
- Fix small quality decay before it becomes normal.

### 9. Personal Guidelines

- Never use the em dash. Use a plain dash instead.
- Never auto-add your agent name as a commit co-author.
- Never manually modify `CHANGELOG.md` files or files marked as auto-generated.
- In long Markdown files, put each full sentence on its own line.
- Prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
