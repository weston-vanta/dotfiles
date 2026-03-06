---
name: research
description: Use when working in an unfamiliar part of the codebase, when a task spans multiple components, or when you need to understand patterns and conventions before making changes
---

# Research Codebase Knowledge

## Overview

Query the `.ai-dev` knowledge layer across the repository. Dispatches a subagent that finds, reads, and synthesizes relevant knowledge from `.ai-dev/` directories.

## When to Use

- Starting work in an unfamiliar area of the codebase
- Task spans multiple components or directories
- Need to understand existing patterns, conventions, or gotchas before making changes
- Looking for prior knowledge about a specific topic (debugging approaches, architecture decisions, etc.)

## How It Works

Dispatch a subagent (Agent tool) with the following instructions and the user's query:

### Subagent Instructions

You are a research agent. Answer the following query using knowledge stored in `.ai-dev/` directories throughout this repository.

**Process:**

1. Glob for `**/.ai-dev/knowledge.md` to find all index files.
2. Read the index files. Each contains one-line summaries linking to detail files.
3. Identify which detail files are relevant to the query — use both the summaries and the directory paths to judge relevance.
4. Read only the relevant detail files.
5. Synthesize a focused answer to the query. Do not dump raw file contents — summarize and connect the relevant knowledge.

**If there are many index files**, prioritize by directory path relevance to the query. Expand to less-obvious directories only if initial results are insufficient.

**Always cite** which `.ai-dev/` directories your answer draws from, so the caller knows where to look for more detail.
