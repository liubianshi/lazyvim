---
name: new-plugin-spec
description: Scaffold a new lazy.nvim plugin spec under lua/plugins/ following this repo's AGENTS.md conventions (opts pattern, keys table, lazy trigger, explicit dependencies). Use when the user runs `/new-plugin-spec <author/repo>` or says "add a plugin", "new plugin spec", "scaffold plugin", "新建插件配置".
disable-model-invocation: true
---

# new-plugin-spec

Scaffold a new lazy.nvim plugin spec file at `lua/plugins/<name>.lua` that conforms to **every rule** the `lazyvim-conventions-reviewer` checks.

## Invocation

The user invokes you with one of:
- `/new-plugin-spec <author/repo>` — minimum form
- `/new-plugin-spec <author/repo> <lazy-trigger>` — e.g. `/new-plugin-spec folke/snacks.nvim VeryLazy`
- `/new-plugin-spec` — no args, you ask interactively

## Steps

### 1. Gather required information

You need these five fields. Parse from arguments first; for anything missing, ask the user **in one batched question** (use AskUserQuestion when available):

| Field | Example | Notes |
|---|---|---|
| `<author>/<repo>` | `folke/snacks.nvim` | GitHub path |
| `module_name` | `snacks` | The `require("...")` name. Default: repo stem with `.nvim`/`.lua` suffix stripped. |
| `file_name` | `snacks.lua` | Path inside `lua/plugins/`. Default: same as `module_name`. |
| `lazy_trigger` | `event = "VeryLazy"` OR `ft = { "lua" }` OR `cmd = { "Snacks" }` OR `keys = {...}` | Required (R5). If unclear, ask. |
| `category_check` | one of: coding, ui, lsp, editor, ai, lang, util | Determines if this should be merged into an existing file (R7). |

### 2. Decide: new file vs. merge into existing

Before writing, **Glob** `lua/plugins/*.lua` and check if a file matching the category already exists (e.g., `coding.lua`, `ui.lua`, `lsp.lua`). If yes, ask the user:
- "Existing `lua/plugins/<category>.lua` covers similar concerns — append the spec there, or create a new file?"

Default: separate file when the plugin is large/standalone (LSP server, full-feature plugin like CodeCompanion); merge when small (a single-purpose UI tweak alongside other UI tweaks).

### 3. Render the template

Read `templates/plugin.lua` (sibling of this SKILL.md). The template is **valid Lua** (so the workspace LSP doesn't error on it); replace these sentinels:

| Sentinel in template | Replace with |
|---|---|
| `"PLACEHOLDER_AUTHOR_REPO"` (string) | `"folke/snacks.nvim"` |
| `"PLACEHOLDER_MODULE_NAME"` (string, appears twice) | `"snacks"` |
| the line `event = "VeryLazy",` (entire line) | user's chosen lazy trigger, e.g. `ft = { "lua" },` or `cmd = { "Snacks" },`. Keep `event = "VeryLazy",` as-is if the user wants that default. |

Also **strip the top 5 comment lines** (the `-- Template consumed by …` block) — they are scaffold-internal docs, not part of the rendered output.

If creating a **new file**, write the rendered template directly.

If **appending** to an existing file:
- Read the file
- The file should already return `{ {...}, {...} }` (multi-spec form). Insert your new spec as a new table entry inside that list.
- If the file currently returns a single spec (no outer list), refactor to a list and add yours — confirm with user first.

### 4. Validate against AGENTS.md rules

After writing, mentally verify (do not invoke another agent for this — these are tractable):
- **R3**: no `config = function` with a trivial body — use `opts =`.
- **R4**: plugin keymaps live in `keys = { ... }`, not in `config`.
- **R5**: at least one of `event`/`ft`/`cmd`/`keys`/`lazy = false` present.
- **R6**: `dependencies` block exists (can be empty `{}` if truly standalone).

If the user gave you info that would violate a rule (e.g., "set it up with a config function that just calls setup"), gently redirect: "AGENTS.md prefers `opts =` for trivial setup — I'll use that. Tell me if you actually need the function form."

### 5. Report back

Show the user:
- The file path written
- A summary of what was scaffolded (1-3 lines)
- A suggested next step: `:Lazy sync` to fetch the plugin, then customize `opts`

## Constraints

- **Never** invent plugin features. The `opts = { ... }` should be empty `{}` unless the user told you concrete options.
- **Never** add a hardcoded keymap. The `keys = { ... }` should be empty `{}` unless the user told you concrete bindings.
- **Never** write outside `lua/plugins/`. If the user asks to scaffold a global keymap or autocmd, redirect to `lua/config/keymaps.lua` or `lua/config/autocmds.lua`.
- **Stylua will run** on the new file via the PostToolUse hook — don't fuss over column width manually.

## Failure modes

- User gives a repo that doesn't exist on GitHub — you can't verify (no network), so trust them and write the spec. They'll find out at `:Lazy sync`.
- User gives a lazy trigger that doesn't make sense for the plugin type — flag your doubt but proceed.
- User wants to scaffold for a plugin already in `lazy-lock.json` — Glob `lua/plugins/` first; if the spec already exists, refuse and point to the existing file.
