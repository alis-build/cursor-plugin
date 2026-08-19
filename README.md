# Alis Build Cursor Plugin

<p align="center">
  <img src="plugins/tools/assets/connectivity.svg" alt="Cursor connected to Alis Build" width="760">
</p>

<p align="center">
  <strong>Connect Cursor to Alis Build.</strong>
</p>

Use this plugin to let Cursor work with Alis Build organisations, products, neurons, builds, and deploys through the `alis` CLI, with workspace-aware context injected into every session.

## What You Get

- A standing Define → Build → Deploy primer rule with quiet, local-first skill discovery — description-triggered `discover` and `capture` rules fire on your own words (`alis skills suggest|load|capture`), never on generic coding just because you are inside a workspace
- Catalog metadata refreshed quietly at session start; the plugin never installs or prunes native user skills
- Auto-approval of clean `alis …` CLI commands via a `beforeShellExecution` hook, with `--confirm-production` / `--approve` / `blocks uninstall --yes` always prompting (double-keyed)

## Before You Start

You need:

- Cursor with plugin support
- The `alis` CLI installed, on your `PATH`, and signed in (`alis login`)
- An Alis Build account with access to the organisations and products you want to use

## Install

Install this repository as a Cursor plugin marketplace, then install the `tools` plugin from that marketplace.

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

## Validate

```sh
node scripts/validate-template.mjs
```

## Troubleshooting

If the rules or hooks do not take effect, confirm the plugin install completed and reload Cursor.

If `alis` commands fail with an auth error, run `alis login` (or `alis authorise <org>.<product>` for git/package credentials) and retry.
