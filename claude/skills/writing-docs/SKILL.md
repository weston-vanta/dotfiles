---
name: writing-docs
description: Use when a skill needs to produce a markdown document with iterative human review, or when you need to write any document that requires human feedback before finalizing
---

# Writing Docs

Iterative human-in-the-loop document review. Write a markdown doc into the sibling `ai-artifacts/` repo, wait for human feedback, incorporate changes, repeat until approved.

See `~/.claude/resources/ai-artifacts.md` for the full layout. Docs are never written into the host repo's working tree.

## Resolve the path before drafting

1. **Find the host repo**: `git rev-parse --show-toplevel`. If the current directory isn't a git repo, ask the user where the work lives — don't guess.

2. **Find the sibling artifacts repo**: look for `<workspace>/ai-artifacts/.git`, where `<workspace>` is the parent dir of the host repo. If it's missing, tell the user to run `/setup-ai-artifacts` first, then stop.

3. **Determine the feature slug** (once per session, then reuse):
   - Look at the current git branch name, the conversation context, and existing subdirs under `ai-artifacts/<host-repo>/`.
   - Propose a kebab-case slug and confirm with the user. If the user is already working on a feature that has artifacts, prefer that slug — don't create a duplicate.
   - Cache the confirmed slug for the rest of the session.

4. **Determine the topic**: `research`, `design`, `plan`, etc. — whatever the calling skill (or user) is asking for. One file per topic, flat inside the feature dir.

5. **Final path**: `<workspace>/ai-artifacts/<host-repo-slug>/<feature-slug>/<topic>.md`.

## The Review Loop

1. **Check gsync availability**: `npx gsync auth status`. Authenticated if the first line says "Authenticated" (ignore token expiry warnings — gsync auto-refreshes). If it fails or is not found, skip all gsync behavior silently for the session.

2. **Write the draft**
   - Immediately after the `# Title`, include `*Created: YYYY-MM-DD | Last revised: YYYY-MM-DD*` (both set to today on first draft).

3. **Announce:**
   - gsync available: you will see a Drive link in PostToolUse hook output. Say: "Draft written to `<path>` and synced to Google Drive: `<link>`. You can review and comment in either place."
   - gsync unavailable: "Draft written to `<path>`. Add `//** <comment>` annotations or edit directly, then let me know."

4. **Wait** for user response. If approved/done, return to calling skill.

5. **Re-read the file from disk** — never rely on cached content.

6. **Fetch and merge from Drive** if gsync is available.
   - `npx gsync view <path> --format markdown` — get Drive content.
   - `npx gsync comments <path> --json` — get comments.
   - **Merge**: use whichever side changed as base. If both changed the same section with contradictions, ask the user which to keep.

7. **Diff against your previous version** and categorize changes:
   - `//** <comment>` annotations and Drive comments: incorporate feedback then remove.
   - Direct edits: intentional changes — **preserve as-is, never revert**.

8. **If comments or edits contradict each other or existing content**, ask the user to resolve before proceeding. If any comments are ambiguous, ask for clarification.

9. **Apply changes**: if gsync is available, run `npx gsync comments resolve-all <path> -y` first (before writing), then incorporate feedback, preserve direct edits, remove `//**` annotations.
   - Update the "Last revised" date if it differs from the "Created" date.
   - Include a changelog entry at the bottom of the document: `- YYYY-MM-DD: <one-line summary of changes>`. Create the `## Changelog` section on first revision if it doesn't exist.

11. **Summarize** what changed. Go to step 3.

## Comment convention

Users may provide feedback in three ways:

- **Drive comments** — feedback provided directly in Google Drive.
- **`//**` comments** — inline annotations: `Some text. //** comment here`
- **Direct edits** — changes the user made themselves. Intentional; never revert.

## Session end

You don't need to commit or push the artifacts repo — the SessionEnd hook handles that automatically. Just leave the file in its final state on disk.
