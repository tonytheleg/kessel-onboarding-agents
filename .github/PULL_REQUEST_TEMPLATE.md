## What changed
<!-- Brief description. Use bullet points for multi-part changes. -->

## Why
<!-- Context and motivation. -->

## Plugin version checklist

> Skills, agents, commands, and context files are distributed as a versioned plugin cache.
> Changes to these files **do not reach users until the version is bumped**.
> See [CONTRIBUTING.md](../CONTRIBUTING.md) for full guidance on what requires a bump and which version to choose.

- [ ] My changes **do not** touch `skills/`, `agents/`, `commands/`, `context/`, or `examples/` → no version bump needed
- [ ] My changes **do** touch one or more of those directories → I have bumped the version in **both** files below:
  - [ ] `.claude-plugin/plugin.json`
  - [ ] `.claude-plugin/marketplace.json`

**If bumping, which version was incremented?**
- [ ] Patch (`x.x.N`) — bug fix or wording correction, no behavior change
- [ ] Minor (`x.N.0`) — new skill/command/flag, or meaningful behavior change that is backward-compatible
- [ ] Major (`N.0.0`) — breaking change to outputs, artifact format, or workflow

Jira: <!-- RHCLOUD-XXXXX or N/A -->

<!-- Note any dependencies on other PRs or breaking changes here. -->
