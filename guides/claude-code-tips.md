# Claude Code Tips from the Claude Code Team

*By Boris Cherny — January 31, 2026*

There's no one right way to use Claude Code — everyone's setup is different. These tips are sourced directly from the Claude Code team, whose workflows vary widely even among themselves. Experiment to see what works for you!

---

## 1. Do More in Parallel

Spin up 3–5 git worktrees at once, each running its own Claude session in parallel. This is the single biggest productivity unlock and the top tip from the team.

- Most of the team prefers worktrees, though multiple git checkouts work too.
- Some people name their worktrees and set up shell aliases (`za`, `zb`, `zc`) to hop between them in one keystroke.
- Others keep a dedicated "analysis" worktree solely for reading logs and running BigQuery.

> **Docs:** [Run parallel sessions with git worktrees](https://code.claude.com/docs/en/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees)

## 2. Start Every Complex Task in Plan Mode

Pour your energy into the plan so Claude can one-shot the implementation.

- Have one Claude write the plan, then spin up a second Claude to review it as a staff engineer.
- The moment something goes sideways, switch back to plan mode and re-plan — don't keep pushing.
- Explicitly tell Claude to enter plan mode for verification steps, not just for the build.

## 3. Invest in Your CLAUDE.md

After every correction, end with: *"Update your CLAUDE.md so you don't make that mistake again."* Claude is eerily good at writing rules for itself.

- Ruthlessly edit your `CLAUDE.md` over time. Keep iterating until Claude's mistake rate measurably drops.
- One engineer has Claude maintain a notes directory for every task/project, updated after every PR, then points `CLAUDE.md` at it.

## 4. Create Your Own Skills and Commit Them to Git

Reuse skills across every project. Tips from the team:

- If you do something more than once a day, turn it into a skill or command.
- Build a `/techdebt` slash command and run it at the end of every session to find and kill duplicated code.
- Set up a slash command that syncs 7 days of Slack, Google Drive, Asana, and GitHub into one context dump.
- Build analytics-engineer-style agents that write dbt models, review code, and test changes in dev.

## 5. Claude Fixes Most Bugs by Itself

- Enable the Slack MCP, paste a bug thread into Claude, and just say "fix." Zero context switching required.
- Say "Go fix the failing CI tests" — don't micromanage how.
- Point Claude at Docker logs to troubleshoot distributed systems. It's surprisingly capable at this.

## 6. Level Up Your Prompting

**Challenge Claude.** Say things like:

- *"Grill me on these changes and don't make a PR until I pass your test."* Make Claude your reviewer.
- *"Prove to me this works"* — have Claude diff behavior between `main` and your feature branch.

**Push for elegance.** After a mediocre fix, say: *"Knowing everything you know now, scrap this and implement the elegant solution."*

**Be specific.** Write detailed specs and reduce ambiguity before handing work off. The more specific you are, the better the output.

## 7. Terminal & Environment Setup

- The team loves [Ghostty](https://ghostty.org/) for its synchronized rendering, 24-bit color, and proper Unicode support.
- Use `/statusline` to customize your status bar to always show context usage and current git branch.
- Color-code and name your terminal tabs — some use tmux — one tab per task/worktree.
- **Use voice dictation.** You speak 3× faster than you type, and your prompts get way more detailed as a result. (Hit `fn` twice on macOS.)

> **Docs:** [Terminal configuration](https://code.claude.com/docs/en/terminal-config)

## 8. Use Subagents

- Append "use subagents" to any request where you want Claude to throw more compute at the problem.
- Offload individual tasks to subagents to keep your main agent's context window clean and focused.
- Route permission requests to Opus 4.5 via a hook — let it scan for attacks and auto-approve the safe ones.

> **Docs:** [Permission request hooks](https://code.claude.com/docs/en/hooks#permissionrequest)

## 9. Use Claude for Data & Analytics

Ask Claude Code to use the `bq` CLI to pull and analyze metrics on the fly. The team has a BigQuery skill checked into the codebase that everyone uses for analytics queries directly in Claude Code. This works for any database that has a CLI, MCP, or API.

## 10. Learning with Claude

- Enable the "Explanatory" or "Learning" output style in `/config` to have Claude explain the *why* behind its changes.
- Have Claude generate a visual HTML presentation explaining unfamiliar code — it makes surprisingly good slides.
- Ask Claude to draw ASCII diagrams of new protocols and codebases to help you understand them.
- Build a spaced-repetition learning skill: you explain your understanding, Claude asks follow-ups to fill gaps, and stores the result.
