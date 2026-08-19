# Alis Build

Connect Cursor to Alis Build through the `alis` CLI and workspace-aware build and deploy operations.

## What You Get

- A standing Define → Build → Deploy primer rule (`alwaysApply`) that gives Cursor the Alis Build mental model, the skills contract, and the CLI-first execution contract every session
- Description-triggered `discover` and `capture` rules: `discover` finds and loads the right registry skill when a request touches the platform — local-first (`alis skills suggest --json` probe, distinctive-score gate, registry search only on explicit asks); `capture` saves work just completed in the session as a reusable team skill (`alis skills capture`)
- A `sessionStart` hook that, when a session opens inside an Alis Build service folder (`~/alis.build/<org>/build|define/…`), injects the package id and a pointer to the matching definitions ⇄ implementation counterpart
- A `sessionStart` hook that refreshes cached catalog metadata with `alis skills sync --cache-only`; it never installs or prunes native user skills
- A `beforeShellExecution` hook that auto-approves clean, single `alis …` commands so the agent can run the Alis Build CLI without a prompt on every call — chained/redirected commands defer to Cursor's normal permission flow, and `--confirm-production`, `--approve`, and `blocks uninstall --yes` always prompt (deliberate double-keying). Restrict with a space-separated `ALIS_ALLOWED_SUBCMDS` allowlist if desired. The hook also records the pending command at `~/.alis/agent-approval.json` for the CLI's approval gate (audit only on Cursor — Cursor exposes no permission-mode signal, so the CLI never treats it as a standing grant)

## Primer sync

The DBD primer rule body (`rules/dbd-primer.mdc`) is synced from the canonical primer in the
Alis Build Claude Code plugin v0.19.0
(`claude-plugin/plugins/alis-build/context/dbd-primer.md`) — whose "Skills — discovery is
native and quiet" section describes local-first, confidence-gated discovery and whose
Executing DBD section carries the "Diagnose before re-running" block and the `.playground`
hidden+gitignored gotcha. Local differences are limited to the rule frontmatter, the Skills
section naming the `discover` / `capture` rules (Claude names `alis-build:discover` /
`alis-build:capture` skills), and the Google documentation section omitting
`/connect-google` (Cursor has no such command). Sync the body on each claude-plugin primer
release.

## Before You Start

You need:

- Cursor with plugin support
- The `alis` CLI installed, on your `PATH`, and signed in (`alis login`)
- An Alis Build account with access to the organisations and products you want to use

## Use It

After installing, ask Cursor to use Alis Build — just describe what you want:

```text
Add a search endpoint to my orders service.
```

```text
Use Alis Build to list the organisations I can access.
```

```text
Use Alis Build to inspect the current workspace, product, active neurons, and recent build status.
```

```text
Use Alis Build to review the latest failed build or deploy logs and suggest the next action.
```

## Workflow Rules

This plugin includes description-triggered Cursor rules for Alis Build workflows:

- **`discover`** — finds and loads the right Alis Build skill for what you want to do — local-first: it probes the local catalog (`alis skills suggest --json`, ~40ms, no network), loads a registry skill only on a distinctive match, and stays quiet otherwise (`alis skills search` is reserved for explicit "find me a skill" asks). Cursor applies it when your request touches the platform — describe the goal in your own words; no wake word is needed. It does not fire on generic coding (Makefiles, ordinary bugs, tests, git) just because you are inside a workspace.
- **`capture`** — turns work just completed in the session into a reusable skill for your team. Say "capture this as a skill" (or "make this a skill" / "skillify this").
- **`getting-started`** — say "Use the getting-started skill to help me get started on Alis Build."

## Troubleshooting

If the rules or hooks do not take effect, confirm the plugin install completed and reload Cursor.

If `alis` commands fail with an auth error, run `alis login` (or `alis authorise <org>.<product>` for git/package credentials) and retry.
