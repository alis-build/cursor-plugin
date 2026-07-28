# Alis Build

Connect Cursor to Alis Build through hosted MCP tools, OAuth authentication, and workspace-aware build and deploy operations.

## What You Get

- A preconfigured Cursor MCP server for `https://mcp.alis.build`
- A preconfigured static Alis Build OAuth client and scopes for MCP sign-in
- OAuth/OIDC sign-in through `https://identity.alisx.com`
- Alis Build tools for inspecting organisations, products, neurons, builds, and deploys
- A standing Define → Build → Deploy primer rule (`alwaysApply`) that gives Cursor the Alis Build mental model, the skill-routing contract, and the CLI-first execution contract every session
- Skill-routing rules for `build it` / `fix it` (discover via `alis skills search` / `alis skills load`; MCP `SearchSkills` only without a terminal) and `spec it` (call `SpecIt` directly)
- A `sessionStart` hook that, when a session opens inside an Alis Build service folder (`~/alis.build/<org>/build|define/…`), injects the package id and a pointer to the matching definitions ⇄ implementation counterpart, plus an instruction to pass the session id to the session-aware Alis Build MCP tools
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
- An Alis Build account with access to the organisations and products you want to use
- Network access to `https://mcp.alis.build` and `https://identity.alisx.com`
- The Alis Build OAuth client must allow Cursor's MCP redirect URI: `cursor://anysphere.cursor-mcp/oauth/callback`

## Use It

After installing and signing in, ask Cursor to use Alis Build:

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
spec it
Use the getting-started skill to help me get started on Alis Build.
```

`build it` discovers the right Alis Build skill for the thing you want to build (via `alis skills search` when a terminal is available). `fix it` is an alias for the same discovery flow when the goal is framed as a fix. `spec it` turns the current session into an Alis Build build specification via `SpecIt`.

## Troubleshooting

If `alis-build` does not appear as an MCP server, confirm the plugin install completed and that `plugins/tools/mcp.json` is present in this plugin.

If sign-in fails with `Incompatible auth server: does not support dynamic client registration`, confirm the installed plugin's MCP config contains `auth.CLIENT_ID`. Cursor uses that static OAuth client for Alis Build because the auth server does not support Dynamic Client Registration.

If sign-in fails with `invalid redirect`, confirm the Alis Build OAuth client allows the exact redirect URI `cursor://anysphere.cursor-mcp/oauth/callback`.

If sign-in still fails, confirm that you can reach both `https://mcp.alis.build` and `https://identity.alisx.com`, then retry the MCP login flow in Cursor.
