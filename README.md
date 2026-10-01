# Skills

Agent skills I use with Claude Code.

| Skill | What it does |
| --- | --- |
| [ticket-graph](ticket-graph/SKILL.md) | Takes one Linear ticket from pickup to a merged PR as an explicit graph of nodes, with a checkpoint, capped retry loops, and a fleet of parallel sessions run by an orchestrator. |

`ticket-graph` pairs with the Herdr tab and orchestrator setup in
[herdr-customizations](https://github.com/kevinmanase/herdr-customizations).
It is written for my own repo and workflow; adapt the house rules, paths and
deploy checks to yours.

## Install

```sh
mkdir -p ~/.claude/skills
cp -R ticket-graph ~/.claude/skills/
```
