# Agent Configuration — ntnx-nkp-tpl-gitops

This directory contains agent definitions that preserve project context across OpenCode sessions.

## Files

| File | Purpose |
|---|---|
| `AGENTS.md` | Master agent config — all agents, their roles, and how to invoke them |
| `context.md` | Full project context — structure, patterns, decisions, conventions |
| `planning.md` | Planning framework — how to break down work, track progress |
| `agents/` | Individual agent definitions |

## How It Works

When you open a new OpenCode session in this repo, the agents at the top of `AGENTS.md` are
automatically loaded. They provide:

1. **Project context** — directory structure, patterns, conventions
2. **Planning framework** — how to break down tasks, track progress
3. **Agent roles** — which agent to use for which type of work

## Loading Agents

Agents are loaded via the `skill` tool. Each agent has a unique name:

```
# Load the project architect agent
skill: "ntnx-nkp-architect"

# Load the deployment specialist agent
skill: "ntnx-nkp-deploy"
```

## Customizing

To add a new agent, create a file in `agents/` and add an entry to `AGENTS.md`.
To update context, edit `context.md`.

