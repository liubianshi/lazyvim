--- Shared configuration / state hub for the translate module.
---
--- This module is the single source of truth for the merged options, the
--- extmark namespace id and the extmark utility instance. Every sibling module
--- reads from here but this module never `require`s a sibling, which keeps the
--- dependency graph a tree (no circular `require`).
local M = {}

--- Default configuration. User overrides are merged with the "keep" strategy
--- (user values win, defaults fill the gaps).
local default_opts = {
  ns_name = "LBS_Translate", -- Namespace name used for extmarks.
  hl_group = "Comment", -- Highlight group applied to virtual text/lines.

  -- Wrapping behaviour forwarded to mdwrap.nvim's `format_lines`.
  -- `wrap_sentence = true` => greedily fill each line up to `width`
  -- (a sentence may be broken anywhere). `cjk_break_at_punct_only` is left
  -- unset so mdwrap's own default (true) applies; set it to false to also
  -- allow breaking Chinese text at arbitrary positions.
  wrap = {
    wrap_sentence = true,
  },

  -- Translation cache (SQLite, never expires; manual force refresh only).
  cache = {
    enabled = true,
    path = vim.fn.stdpath("data") .. "/translate/cache.db",
  },

  -- Engine commands (the base argv; per-call arguments are appended).
  engines = {
    deepl = { "deepl" },
    fabric = { "fabric", "--pattern", "translate" },
  },
}

--- Populated by `setup`. Nil until then.
M.options = nil ---@type table|nil
M.ns_id = nil ---@type integer|nil
M.extmark = nil ---@type table|nil

--- Merge user options with defaults and (re)initialise the shared state.
--- Idempotent: safe to call again to re-resolve options.
---@param opts table|nil
---@return table self
function M.setup(opts)
  M.options = vim.tbl_deep_extend("keep", opts or {}, default_opts)
  -- Namespace creation is idempotent: returns the existing id if present.
  M.ns_id = vim.api.nvim_create_namespace(M.options.ns_name)
  M.extmark = require("util.extmark").new(M.options.ns_name)
  return M
end

return M
