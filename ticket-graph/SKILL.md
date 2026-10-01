---
name: ticket-graph
description: Take one Linear ticket from pickup to a merged PR as an explicit graph. Clarify with Kevin (grilling) or execute; commit, /simplify, commit, /code-review, the paid Greptile CLI only when review confidence isn't high, commit; PR to staging; fix CI until green; agree merge order with sibling sessions; merge. Use when a session is handed a ticket to ship end to end, when Kevin fans tickets out to Herdr tabs, and when resuming such a session after /clear or compaction.
---

# Ticket graph

A ticket moves through the named nodes below. Each node does one job, then takes exactly one edge from its row. The only cycles are the ones drawn, and each has a cap. When a cap is hit, go to BLOCKED; don't try harder.

The graph is thin on purpose. EXECUTE, REVIEW and CLARIFY are where you work freely as an agent. Everything around them is a fixed step whose gate is evidence from the environment (tests, CI, PR state), never your own sense that it's done.

Lost? Read the checkpoint and resume from its node.

## Checkpoint
- **Where:** one JSON file per worktree, at `$(git rev-parse --git-path ticket-graph.json)`. Update it on every edge.
- **Contents:** `{ticket, branch, node, pr, plan, counts: {verify_same_failure, ci_fix, greptile}, decisions: [], history: [{from, to, why}], blocked_on, blocked_by: [ticket ids]}`.
  - Log every edge in `history` with its reason. That trace is how you, and Kevin, see why the graph went where it did.
- **Tab name:** mirror the node in the Herdr tab (`~/.claude/hooks/herdr-tab name "<emoji> eng-NNNN <gist>"`), so Kevin can see where every ticket stands.
- **Every node must be safe to re-run**, because a resume replays the node it stopped in. Check before acting:
  - Is there already a PR for the branch (`gh pr list --head <branch>`)?
  - Is there anything to commit?
  - Is the PR already merged?

## Nodes

| Node | Tab | Job | Edges |
|---|---|---|---|
| START | 🔍 | Read the ticket, its comments, related tickets, linked PRs, and the code and logs it names. Create the worktree with `git worktree add ../ampersand-eng-NNNN -b feature/eng-NNNN origin/staging` (Linear's `gitBranchName`), then run every command as `cd ../ampersand-eng-NNNN && …` or with `git -C`. **Don't use `EnterWorktree`:** its isolation blocks the checkpoint in the main repo's `.git/worktrees/` and refuses compound git commands. Write the ticket's Linear "blocked by" relations, plus any hard edges in your brief, to `blocked_by`. | a blocker not yet merged or Done → WAITING · clear → EXECUTE · unclear → CLARIFY |
| CLARIFY | 🔍 | Run the `grilling` skill. `/grill-me` only calls it, and the model can't invoke `/grill-me`. Post the answers as a `Decisions` comment on the ticket. | decided → EXECUTE · Kevin defers → PARKED |
| EXECUTE | 🛠️ | Plan first: write 3–5 lines in the checkpoint's `plan`, covering the acceptance check, the files, and the test that will prove it. Then make the change. Write API and integration tests as you go (real handlers, real Postgres). Add unit tests only for pure logic worth pinning; don't pile them on. Use subagents only for independent exploration or pieces of work. | → VERIFY |
| VERIFY | 🧪 | Typecheck, lint and test each touched package, one at a time, through `slot.sh`. Never delete, skip or weaken a test to get green. | green → COMMIT · red → EXECUTE · the same failure 3 times in a row → BLOCKED |
| COMMIT | 🛠️ | Commit. The subject is lower-case and ends `(eng-nnnn)`. The first pass goes on to SIMPLIFY. | 1st → SIMPLIFY · 2nd → REVIEW · 3rd → PR |
| SIMPLIFY | 👀 | Run `/simplify`, then re-run VERIFY's checks on whatever it touched. | → COMMIT (2nd) |
| REVIEW | 👀 | Run `/code-review medium` with your branch as the target. It can take about an hour, so start it and do other work while it runs. Fix the real findings and re-verify. Then rate your confidence as **high** or **not high**; see the routing rules. | high → COMMIT (3rd) · not high → GREPTILE |
| GREPTILE | 👀 | Costs money, so only here. Push first. Then run `greptile review --json --agent --branch $(git merge-base HEAD origin/staging) --instructions "<context, ≤ 2000 chars>"` (see `~/.claude/skills/greptile/cli-review`). Fix what's real. **The target is 5/5.** Settle for 4/5 only when the change it still asks for would be harmful or isn't worth it, and give the reason in the PR body. Naming the invariant the finding would break, in the code and in `--instructions`, often turns a declined finding into 5/5. | → COMMIT (3rd); a second run only if you fixed something it found or named an invariant it missed (`greptile` ≤ 2) |
| PR | 🚀 | Push, then open a PR to `staging`. The body needs `Fixes ENG-NNNN`, what changed, why, and how it was verified. | → CI |
| CI | 🚀 | Wait on `gh pr checks <n> --watch`, run in the background. | all green → COORDINATE · any red → FIX_CI |
| FIX_CI | 💥 | Read the failing job's log (`gh run view --log-failed`) and fix the cause. Never skip, retry blindly or disable a check. Push. | → CI (`ci_fix` ≤ 3, then BLOCKED) |
| COORDINATE | 🚀 | Settle your place in the merge order with sibling sessions (see Fleet). If `origin/staging` has moved, rebase. `git range-diff` all `=` means CI and review both still hold. | your turn → MERGE · rebased with changed patches → VERIFY |
| MERGE | 🚀 | Merge with `gh pr merge <n> --merge` only when: all checks are green, it's your turn, and no staging deploy is running (`gh run list --workflow staging-deploy-orchestrator.yml -L 1`). Then tell the sibling sessions and the orchestrator. Then watch your merge commit's staging deploys finish (`gh run list --commit <merge sha>`): `staging-deploy-orchestrator.yml`, and `solera-deploy.yml` if it ran. A failed deploy is yours: read its log, re-dispatch a transient or infrastructure failure once as the `staging-pr-greptile-and-terraform-guard` memory describes, and tell the orchestrator about anything else or a second failure. | deploys green, or a failure handed to the orchestrator → END |
| END | 🎉 | Enter only on evidence: `gh pr view <n> --json state` reads `MERGED`, or you came from PARKED with its reason written down. Linear closes the ticket through the branch name and `Fixes`. Run `~/.claude/hooks/herdr-orchestrator next` to start the next queued ticket in a fresh session (exit 3 means low memory; say so). Report to Kevin in a few lines, and SendMessage the same to `orchestrator` with any follow-ups you didn't do. Then stop, and **leave this chat open**. Clearing or closing needs Kevin's explicit approval of this exact tab and session (see the `herdr` skill). Never take the next ticket in this session: new work always gets a fresh one. | done |
| PARKED | 💤 | Comment on the ticket why it stops here and what would restart it. | → END |
| BLOCKED | 🚧 | Only Kevin can unblock this. Flag the tab (`herdr-tab ask "<question>"` or `request "<what he must do>"`), write `blocked_on` into the checkpoint, tell the orchestrator, and stop. | → the node you left, once he answers |
| WAITING | 💤 | A blocker isn't merged yet. This isn't BLOCKED, so don't flag Kevin. Tell the orchestrator and each running blocker session (`eng-NNNN`) that you wait on it, then stop. On a sibling's post-merge note, recheck every blocker. | all merged → rebase on `origin/staging`, then START · still open → stop again |

## Routing rules (the two decision points)
- **Clear enough to execute** means you can name the acceptance check and the files you'll change, and none of the decisions belong to Kevin. Kevin's decisions include deleting data, product behavior, spend, anything irreversible, and anything in production.
- **Review confidence is high** means /code-review left nothing unfixed, and the change is proven by a test that failed before and passes now (or it's trivially safe), and you'd merge it without anyone else looking.
- **Jev as a second opinion:** `~/.claude/skills/ticket-graph/jev "<question>" "<true when…>" "<false when…>" < text` asks Jev, TypeSafe's classifier. Exit 2 means there's no key, so decide yourself. If Jev disagrees with you, take the safer edge: CLARIFY or GREPTILE.

## Fleet (the graph around the graphs)
- Sibling tickets run in parallel, one Herdr tab and Claude session each. Their briefs wait in `~/.cache/herdr-fleet/queue/`, and `herdr-orchestrator next` starts the next one in a fresh session: a `⚪ ready` tab, or a new tab when memory allows. A session that reaches END refills the pool, and leaves its chat open. Clearing needs Kevin's approval.
- **The orchestrator** (👑, the Claude session named `orchestrator`; see the `herdr` skill) keeps the fleet's notes and the queue, and relays Kevin's decisions. It leaves finished sessions open and clears one only after Kevin explicitly approves that exact tab and session (see the `herdr` skill). Tell it when you merge, get blocked, or finish.
- **Merge order is a DAG.** Hard edges in your brief ("after #3818") come first. Otherwise the first green PR goes first. When two PRs touch the same files, the smaller or more foundational one goes first.
- **Coordinating:**
  - Find your siblings with `ListAgents`; their names are `eng-NNNN`.
  - Message each one whose PR touches your files with your PR number, the files you changed, your hard edges and your proposed position. Wait for anyone ahead of you.
  - After you merge, send a one-line note so they rebase. Include any session WAITING on your ticket; the note is what wakes it.
  - If a sibling is silent for 30 minutes, say so in its ticket and carry on by the rules above.
- **Shared resources:** run every heavy command through `~/.claude/skills/ticket-graph/slot.sh` (3 machine-wide slots). For Postgres integration tests, start your own server on a free port (`ss -ltn`), per the `local-postgres-integration-tests` memory.

## House rules
- **PR rules:** PRs target `staging`. The branch is Linear's `gitBranchName`, one ticket per PR.
- **Production is off-limits** without Kevin: no writes, deploys or billable calls on private data.
- **Never use `git stash`:** the stash is shared by every worktree of the repo, so two sessions' stashes can swap (eng-2539 and eng-2542 on 2026-09-29). Park work in a WIP commit on your own branch instead.
- **Keep the diff small:** the shortest working diff wins. Name any smells you find in files you touch (CLAUDE.md, "Remove Overhead").
- **One-time checks:** read `CLAUDE.md` once. Load the `herdr` skill once, to name your tab.

## Why this shape
"Graph engineering" is a new name (July 2026) for an old idea: workflows, state machines with conditional edges, and durable execution. Each choice here comes from what the sources agree on.

- **Fixed steps in the skill, judgment in the agent nodes.** EXECUTE, REVIEW and CLARIFY carry the judgment; git, CI and merges are fixed [1][3][6].
- **One ticket per session.** Agents do best on one feature at a time in small steps [6][8].
- **State lives outside the transcript:** the checkpoint, git, the PR and Linear. So a /clear, a compaction or a new window resumes from the right node [5][8].
- **Routing is an explicit edge with a written reason.** CLARIFY vs EXECUTE and Greptile vs not are rules, with an optional classifier (Jev) as a second opinion [3][5].
- **Gates are environment evidence,** not self-report. Never edit tests to pass [3][8].
- **Cycles exist, but each is capped,** and a cap escalates to a human. The CI cap is 3 [1][6].
- **Human interrupts are named nodes:** CLARIFY and BLOCKED. There's no plan-approval interrupt: Kevin chose "if it's clear, just execute" [7].
- **Dependencies wait in their own tab.** A ticket with an open blocker parks in WAITING, an idle session (about 0.4 GB, no heavy work), rather than being skipped by `herdr-orchestrator next`. A queue skip would need the script to read Linear, and a skipped brief has no session for the post-merge note to wake; `next` already refuses to start one when memory is short.
- **Fan-out covers independent tickets only,** bounded by memory. Merge order is a deterministic DAG, because coding has less truly parallel work than research [4].
- **Terminal states need proof** (merged or parked), guarding against a premature "done" [5][7][8].
- **Keep it thin.** Don't turn the agentic core into a flowchart; the graph only wraps it [1][3].

Sources:
1. LangChain, "3 Years of Graph Engineering with LangGraph" (2026): https://www.langchain.com/blog/3-years-of-graph-engineering-with-langgraph
2. Feng et al., "Graph Engineering in the Era of LLM Agents" (2026): https://arxiv.org/abs/2608.21156
3. Anthropic, "Building effective agents" (2024): https://www.anthropic.com/engineering/building-effective-agents
4. Anthropic, "How we built our multi-agent research system" (2025): https://www.anthropic.com/engineering/multi-agent-research-system
5. LangChain, "Building LangGraph" (2025): https://www.langchain.com/blog/building-langgraph
6. HumanLayer, "12-Factor Agents": https://github.com/humanlayer/12-factor-agents
7. LangChain, "Introducing Open SWE" (2025): https://www.langchain.com/blog/introducing-open-swe-an-open-source-asynchronous-coding-agent
8. Anthropic, "Effective harnesses for long-running agents" (2025): https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
