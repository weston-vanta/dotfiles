# Onboarding

Builds or rebuilds the guide from the user's own writing, tests it in blind evals, and throws the raw samples away. Paths below are relative to the guide directory (`$MY_VOICE_DIR`, default `~/.config/agents/my-voice/`) unless they start with `$WORK`.

Ask the user one question at a time, with AskUserQuestion where the harness has it, and wait for each answer before asking the next.

Against every source, run only read commands (search, list, view, read a thread). Many of these tools can also post, react, edit and comment; never use those commands here.

## 1. Set up

1. On a rebuild, replace `previous/` with the current guide files, so one prior version survives.
2. Create a scratch directory `$WORK` with `mktemp -d`, outside the guide directory. Raw samples live only there.

## 2. Choose contexts

Ask which contexts the guide should cover, offering: Slack messages, PR bodies, commit messages, code review comments, docs, email. Done when the user has named a list.

## 3. Choose sources

1. Look for the tools that can reach each source: CLIs on `PATH` (`gh` for GitHub; Google Workspace, Atlassian or Slack CLIs, found by name and confirmed with `--help`) and any MCP connectors in this session. Check each one is logged in with its auth-status command.
2. Ask, as separate questions: which sources to use (each option naming its tool and whether it is logged in), how far back to go, and which files or pastes cover sources with no tool. Ask the user to point only at text they wrote themselves.

Done when every chosen context has at least one source.

## 4. Collect

For each context, fetch all of the user's own text in the chosen window, then sample it evenly across that window (by month, say) down to about 15k words, so no single stretch of time sets the voice. Learn each tool's query syntax from its `--help`.

- Write fetched items straight to files under `$WORK/<context>/`, one per item, rather than printing them into your context. Each file holds the user's text plus its **prompt context**, what the text responded to: a PR's diff summary and title, the Slack thread above a reply, the ticket under a comment, a one-line topic for a doc.
- Keep only text the user authored. Strip quoted text from others, templates and boilerplate (a PR template's headings, an email signature).
- Drop every item carrying an agent marker: a `Co-Authored-By:` trailer naming an AI agent, "Generated with ..." lines, a bot author.

Report the word count per context and source. Done when each context has about 10k words or the user accepts what there is.

## 5. Hold out

Using file names and metadata only, before reading any item's text, set aside one fresh set per possible eval round: 1 or 2 items per context (5 to 8 per set) into `$WORK/heldout/round-1/` through `round-3/`. Every round tests unseen items, because once the user has seen a real text they can no longer judge it blind. Pick items whose prompt context is clear enough for someone else to write the same piece. Never read held-out text while writing the guide.

## 6. Distill

Read the remaining items and write the guide.

- `core.md` opens with one line on scope: the guide owns voice, and the task's own instructions own structure and content. Then come the rules, under about 60 lines.
- A rule names an observable habit, not an adjective: "Slack messages are lowercase with no trailing period", not "casual". Cover vocabulary used and avoided, sentence length and rhythm, openers and sign-offs, hedging, formality, humour, punctuation, capitalisation and emoji, prose versus lists, density, and how the user disagrees and asks.
- Keep only rules that change behaviour against how a model writes by default.
- Phrase each rule as the behaviour to produce. Pair a rule with a verbatim excerpt (two lines at most) where the excerpt teaches more than the rule alone. Show the user the candidate excerpts and keep only those they approve.
- Each context file holds only what that context changes from `core.md`: length, structure habits, formatting.
- `index.md` lists each context, its file, and what writing it covers.

Done when every chosen context has a file and every rule passes the tests above.

## 7. Evaluate

Run up to 3 rounds, each on its own held-out set (`round-<n>/`).

1. Dispatch one subagent to write a **content brief** per item in the round's set: the points the real text makes, paraphrased neutrally with no wording, tone or length cues. Without it, candidates make different points from the real text, and the user spots it by content rather than voice.
2. For each item, dispatch two fresh subagents in parallel. Each gets only the item's prompt context, its content brief, and the task ("write the PR body for this change"). The **guided** one is also told to read `index.md`, `core.md` and the matching context file first. The **unguided** one gets nothing else. Never write candidates yourself: you have read the samples, so your writing is not a fair baseline.
3. Present one item per message, in plain chat rather than AskUserQuestion: the item's prompt context, then the real text and both candidates, shuffled as A, B and C. Ask which they think is real, which sounds most like them, and what is off, and wait for the answer before the next item. Keep the shuffle key in a file and out of your messages until the round ends.
4. Reveal the key, and report how many real texts the user picked out and how often the guided candidate beat the unguided one.
5. Revise the guide from the user's notes. Turn each note into a rule or a fix to one, and copy no phrasing from the held-out texts into the guide.
6. Unless this was round 3, ask whether to run another round on the next fresh set. Good results are a fine reason to stop.

Done when the user declines another round or round 3 ends.

## 8. Finish

1. Delete `$WORK`.
2. Offer to add this line to the user's user-level agent instructions (whichever of `~/.claude/CLAUDE.md`, `~/AGENTS.md` and `~/.codex/AGENTS.md` exist): "When writing prose on my behalf, use the my-voice skill." Write it only if the user agrees.
3. Report the contexts covered, the per-round eval results, and the guide's path.
