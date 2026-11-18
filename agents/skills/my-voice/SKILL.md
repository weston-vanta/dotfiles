---
name: my-voice
description: The user's writing voice. Use when writing prose the user will send or publish as their own (PR bodies, commit messages, review comments, Slack messages, docs), and when the user asks to set up, update or correct their voice guide.
---

# My voice

The **guide** lives in `$MY_VOICE_DIR`, default `~/.config/agents/my-voice/`:

- `index.md` lists the guide's **contexts** (Slack, PR bodies, ...) and which file covers each.
- `core.md` is the voice shared by every context.
- One file per context holds what that context changes.

The guide owns **voice**: word choice, tone, rhythm, density, what the user never says. Structure and required content belong to the skill or instructions for the task at hand (a PR skill decides a PR body's sections); where the two conflict, the task's instructions win.

Pick the branch that matches the request:

## Write

1. If `index.md` is missing, write as you otherwise would, then tell the user once that no voice guide exists yet and offer to set one up (the Onboard branch). Stop here.
2. Read `index.md`, `core.md`, and the context file matching what you are writing. With no matching context, use `core.md` alone.
3. Draft, then check the draft against every rule in `core.md` and the context file, and revise until each holds.

When the user rewrites a draft you wrote with the guide, offer to file the difference as a correction.

## Correct

The user states a one-off correction ("I'd never say 'leverage'", "shorter Slack messages").

1. File it in `core.md` if it holds across contexts, otherwise in the context file. Phrase it as the behaviour to produce ("say 'use'"), adding the banned form only beside that target.
2. Merge it with any rule it overlaps rather than appending, keeping `core.md` under about 60 lines.
3. Show the user the diff.

## Onboard

The user asks to set up their voice guide, accepts the offer from Write, or asks to update (rebuild) an existing guide. Follow [`ONBOARDING.md`](ONBOARDING.md).
