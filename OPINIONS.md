# OPINIONS.md

This file is a working map of Brytton's preferences, defaults, and values.
It is meant to help agents make better decisions when Brytton has not specified every detail explicitly.
Treat these as strong defaults, not as rules that override direct instructions.

## How to use this file

When a task is ambiguous, prefer the option that best matches the principles below.
When tradeoffs are real, surface them briefly and recommend the path that best protects quality and long term maintainability.
When Brytton gives a direct instruction that conflicts with this file, follow Brytton.

## Engineering standards

Brytton prefers quality over speed when the tradeoff is meaningful.
He would rather take a little longer and end up with something clean, understandable, and durable than land a fast messy patch.
He values correctness, maintainability, and robustness more than cleverness.
He prefers solutions that fit the existing codebase rather than forcing a new abstraction or pattern.
He likes changes that are scoped, deliberate, and easy to reason about later.
He expects bugs to be reproduced as close to the real user experience as practical before they are fixed.
He wants fixes validated, not merely argued for.
He has a low tolerance for flaky tests, broken lint, and unfinished edge cases.
If something adjacent is obviously broken and easy to repair safely, he would rather clean it up than step around it.

## Tooling and workflow

Brytton likes terminal-centered workflows.
He is comfortable with tmux, modern terminal tooling, and keyboard-driven navigation.
He prefers tools that are composable, scriptable, and easy to inspect.
He generally favors plain files, explicit configuration, and reproducible setup over opaque state hidden inside apps.
He appreciates automation that is idempotent and safe to rerun.
He wants installers and setup scripts to back up existing user state before replacing it.
He prefers agent workflows that gather evidence through search, tests, and direct inspection instead of guessing.
He values concise output, but not at the expense of missing important context or verification.

## Code style and change shape

Brytton prefers code that is boring in the best way.
He likes straightforward control flow, clear naming, and small local reasoning steps.
He is usually happier with one solid simple approach than with several layers of indirection.
He prefers comments that explain non-obvious intent, not commentary that narrates the obvious.
He wants Markdown to stay readable and well structured.
For substantial Markdown editing, he prefers each sentence on its own line when practical.
He does not want agent names auto-added as commit co-authors.
He does not want auto-generated files hand-edited unless the task explicitly calls for regenerating or updating them through the right mechanism.

## UX and product taste

Brytton cares about polish.
He notices when interfaces feel cluttered, inconsistent, cramped, or visually careless.
He prefers interfaces that feel intentional and usable over ones that are flashy for their own sake.
He values strong defaults, low friction, and controls that behave the way experienced users expect.
He likes products that respect attention and reduce noise.
He is willing to spend effort on details when those details improve the actual experience.

## Aesthetic preferences

Brytton appears to like terminal environments that feel calm, immersive, and personal rather than sterile.
He seems to prefer tasteful visual identity over default settings.
He likes setups that feel crafted, with consistent keybindings, good typography, and considered theming.
He does not want aesthetics to overpower usability, but he does think visual quality matters.

## Platforms and environment

Brytton works across Windows and Linux.
He wants user-level configuration that behaves predictably across both where practical.
He prefers avoiding machine-specific paths, usernames, secrets, and one-off assumptions in committed config.
He likes shared configuration when it reduces duplication without making either platform awkward.

## Collaboration and communication

Brytton wants agents to be proactive, honest, and calm.
He prefers clear explanations over performative certainty.
He appreciates collaborators who surface risks early, verify their work, and keep momentum without being pushy.
He does not need a wall of explanation for every small change.
He does want enough context to trust the result and understand the important tradeoffs.
He would rather an agent ask a focused question than silently make a risky personal or product assumption.

## AI and agents

Brytton is interested in agentic workflows that produce real work, not just polished demos.
He prefers agents that use tools well, inspect the codebase, and verify outcomes.
He sees AI as leverage for execution and iteration, not as a substitute for judgment.
He expects humans to remain accountable for the final result.
He is open to automation, but he wants it to stay legible, controllable, and grounded in evidence.

## Startup and builder mindset

Brytton seems builder-oriented.
He values shipping useful things, improving his environment, and investing in tools that compound over time.
He likely prefers practical leverage over ceremony.
He respects systems that reduce repeated effort and turn good habits into defaults.

## In case of doubt

Prefer the path that is simpler, safer, and easier to maintain.
Prefer the solution that keeps user state safe.
Prefer evidence over assumption.
Prefer durable quality over hurried output.
