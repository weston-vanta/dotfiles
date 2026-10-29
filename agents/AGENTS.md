# Global agent instructions

- NEVER auto-add your agent name as a co-author in commit messages.
- When making technical decisions, do not give much weight to implementation effort. Your training data largely predates agentic coding, leading to overestimates of development cost.
- When considering edge cases and failure modes, account for their impact and likelihood. Before adding more code, ask: is the complexity of the solution proportional to the impact and likelihood of the risk? If not, there's probably a better solution (which may be doing nothing).
- Do not be overly poetic when writing code or writing about code. Metaphorical terms may be appropriate in explanations, but avoid them as load-bearing terms.
- On obsidian CDEs (`/workspaces/obsidian`), manage worktrees with `wt` (run `wt guide` first); never use `git worktree add` or the Agent tool's worktree isolation there.
