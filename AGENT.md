# Project Rules & Guidelines

This project is a **LazyVim** configuration for Neovim. You are an expert Neovim Lua developer and LazyVim specialist.

## Project Structure

- `lua/config/`: Core configuration.
  - `options.lua`: Vim options (`vim.opt`, `vim.g`).
  - `keymaps.lua`: General keymaps (`vim.keymap.set`).
  - `autocmds.lua`: Autocommands (`vim.api.nvim_create_autocmd`).
  - `lazy.lua`: Lazy.nvim bootstrap and configuration.
- `lua/plugins/`: Plugin specifications. Each file returns a table (or list of tables) of plugin specs.
- `prompts/`: Markdown-based prompts for CodeCompanion.
- `lua/global_functions.lua`: Global utility functions.

## Coding Standards

### Lua & Neovim API
- **Prefer `vim.api`**: Use `vim.api.nvim_*` functions over `vim.cmd` wrappers when possible for better performance and safety.
- **Locals**: Always use `local` for variables and functions unless they are intended to be global (e.g., in `_G` for specific reasons).
- **String Format**: Use `string.format` for complex string interpolations.
- **Formatting**: Code should be formatted with StyLua (implied by LazyVim defaults).

### LazyVim Plugin Specs
- **Structure**: Return a table of plugin specifications.
  ```lua
  return {
    {
      "author/plugin-name",
      event = "VeryLazy", -- Use lazy loading events
      opts = { ... },     -- Use opts for setup() configuration
      config = function(_, opts) -- Only if custom config logic is needed
        require("plugin").setup(opts)
      end,
    }
  }
  ```
- **Configuration**: Prefer `opts` table over `config` function when possible. LazyVim automatically calls `setup(opts)` if `opts` is present.
- **Keymaps**: Use the `keys` table in plugin specs for plugin-specific keymaps.

### CodeCompanion Prompts
- **Location**: Store new prompts in `./prompts/`.
- **Format**: Use Markdown frontmatter for configuration and standard Markdown for content.
- **Helpers**: Use external Lua files for complex logic (e.g., `prompts/helper.lua`) and reference them via `${helper.func}`.

## Behavior Guidelines
- **Idempotency**: Ensure configuration changes are safe to reload.
- **Modularity**: Keep plugin configurations separated by concern (e.g., `lua/plugins/coding.lua`, `lua/plugins/ui.lua`, `lua/plugins/lsp.lua`).
- **Dependencies**: Explicitly state dependencies in plugin specs using `dependencies`.
- **Global Pollution**: Avoid polluting the global namespace `_G` unless absolutely necessary (like debugging tools).

## Common Tasks
- **Adding a Plugin**: Create a new file in `lua/plugins/` or add to an existing relevant file.
- **Adding a Keymap**:
  - Global: Add to `lua/config/keymaps.lua`.
  - Plugin: Add to `keys` in the plugin spec.
- **Modifying Options**: Edit `lua/config/options.lua`.
