# Alis Build

Connect Cursor to Alis Build through the `alis` CLI and workspace-aware build and deploy operations.

## What You Get

- A standing Define → Build → Deploy primer rule (`alwaysApply`) that gives Cursor the Alis Build mental model, the skill-routing contract, and the CLI-first execution contract every session
- Skill-routing rules for `build it` / `fix it` (discover via `alis skills search` / `alis skills load`)
- A `sessionStart` hook that, when a session opens inside an Alis Build service folder (`~/alis.build/<org>/build|define/…`), injects the package id and a pointer to the matching definitions ⇄ implementation counterpart
- A `beforeShellExecution` hook that auto-approves clean, single `alis …` commands so the agent can run the Alis Build CLI without a prompt on every call — chained/redirected commands defer to Cursor's normal permission flow, and `--confirm-production`, `--approve`, and `blocks uninstall --yes` always prompt (deliberate double-keying). Restrict with a space-separated `ALIS_ALLOWED_SUBCMDS` allowlist if desired. The hook also records the pending command at `~/.alis/agent-approval.json` for the CLI's approval gate (audit only on Cursor — Cursor exposes no permission-mode signal, so the CLI never treats it as a standing grant)

## Primer sync

The DBD primer rule body (`rules/dbd-primer.mdc`) is synced from the canonical primer in the
Alis Build Claude Code plugin (`claude-plugin/plugins/alis-build/context/dbd-primer.md`).
Local differences are limited to the rule frontmatter, "primer"→"rule" and "shell"→"terminal"
wording, and the closing sentence of the Google documentation section (Cursor has no
`/connect-google` command). Sync the body on each claude-plugin primer release.

## Before You Start

You need:

- Cursor with plugin support
- The `alis` CLI installed, on your `PATH`, and signed in (`alis login`)
- An Alis Build account with access to the organisations and products you want to use

## Use It

After installing, ask Cursor to use Alis Build:

```text
build it
```

```text
fix it
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

## Workflow Prompts

This plugin includes Cursor rules for Alis Build workflow prompts:

```text
build it
fix it
Use the getting-started skill to help me get started on Alis Build.
```

`build it` discovers the right Alis Build skill for the thing you want to build (via `alis skills search`). `fix it` is an alias for the same discovery flow when the goal is framed as a fix.

## Troubleshooting

If the rules or hooks do not take effect, confirm the plugin install completed and reload Cursor.

If `alis` commands fail with an auth error, run `alis login` (or `alis authorise <org>.<product>` for git/package credentials) and retry.
