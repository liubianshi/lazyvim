--- Public entry point for the translate module.
---
--- Requiring "translate" initialises the shared config with defaults (so the
--- module is usable without an explicit setup, matching the old `M = init()`
--- behaviour), re-exports the public actions, and registers the `:Translate`
--- command.
require("translate.config").setup()

local actions = require("translate.actions")

local M = {}

-- Public contract relied on by lua/config/keymaps.lua and the
-- `v:lua.require'translate'.trans_op` opfunc string. These six must stay.
M.toggle = actions.toggle
M.translate_line = actions.translate_line
M.translate_selection = actions.translate_selection
M.trans_op = actions.trans_op
M.replace_line = actions.replace_line
M.translate_content = actions.translate_content
-- Also exposed for completeness (used internally by translate_content).
M.translate_sentence = actions.translate_sentence

-- :Translate          translate current line (or range) using the cache.
-- :Translate!         force a refresh: bypass the cache and overwrite it.
vim.api.nvim_create_user_command("Translate", function(cmd_opts)
  local force = cmd_opts.bang
  if cmd_opts.range > 0 then
    actions.translate_range(cmd_opts.line1, cmd_opts.line2, { force = force })
  else
    actions.translate_line(nil, nil, { force = force })
  end
end, {
  range = true,
  bang = true,
  desc = "Translate current line/range (! forces a cache refresh)",
})

return M
