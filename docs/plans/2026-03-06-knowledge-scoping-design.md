# Knowledge Scoping and Research Design

## Problem

Knowledge extraction writes all insights into a single `knowledge.md` per directory. This causes two issues:
1. General knowledge gets trapped at the wrong directory level (scope leakage)
2. Files grow large with disparate information, wasting agent context on irrelevant content

## Design

### File Structure

Each `.ai-dev/` directory contains an index file and topic-based detail files:

```
.ai-dev/
  knowledge.md          # Index — one-line summaries linking to detail files
  architecture.md       # Detail file (name chosen by extraction agent)
  gotchas.md            # Detail file
  testing.md            # Detail file
```

Index format:

```markdown
# Knowledge Index

- [Architecture](architecture.md) — Component relationships and data flow
- [Gotchas](gotchas.md) — Non-obvious behaviors around connection pooling
- [Testing](testing.md) — Factory patterns, test database setup conventions
```

Detail files use markdown with topic headings. Entries are concise (1-3 sentences each). File names are chosen by the extraction agent based on content — no fixed taxonomy.

### Three Agents

**1. Extraction agent** (updated `ai update`)

Processes transcripts and writes scoped knowledge into index + detail files. Updated flow:

1. Triage — skip trivial sessions
2. Extract insights — list individual pieces of knowledge
3. Scope each insight — determine the most specific directory it applies to, based on where the knowledge is *useful*, not where work happened. General methodology goes to parent/root; specific findings stay local.
4. Write knowledge files — for each directory with scoped insights:
   - Group insights by topic
   - Read the `.ai-dev/knowledge.md` index to match topic groups to existing detail files or decide to create new ones
   - Read and update only matched detail files; create new ones for unmatched topics
   - Update the index with one-line summaries for new or changed detail files

**2. Research subagent** (new, invoked via `research` skill)

Queries the `.ai-dev` knowledge layer across the repo. Flow:

1. Receive a natural language query from the main agent
2. Glob for `**/.ai-dev/knowledge.md` to find all index files
3. Read index files (small — just summaries and links)
4. Identify which detail files across which directories are relevant to the query
5. Read only those detail files
6. Return a synthesized answer — focused response, not raw file contents

For large monorepos, the subagent reads indices starting with directories whose paths seem most relevant to the query, then expands if needed.

**3. Main agent** (Claude Code)

Does the work. Invokes the `research` skill when it needs codebase knowledge — when working in unfamiliar areas, when a task spans multiple components, or when it needs to understand patterns before making changes.

### Scoping Rules

- If knowledge would be useful working on *any* file in a directory and its children, it belongs in that directory.
- If useful across *sibling* directories, it belongs in the parent.
- Project-wide knowledge (debugging approaches, architecture overview, cross-cutting conventions) belongs at root.
- Separate general methodology (how to investigate X) from specific findings (Y causes Z in this service).
- When in doubt, prefer the parent directory.

## Deliverables

1. Update `.claude/prompts/knowledge-extraction.md` — index + detail file structure, updated process steps
2. Create `research` skill — dispatches research subagent with `.ai-dev` convention knowledge
