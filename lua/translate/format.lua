--- Line-wrapping and indentation helpers for translated text.
---
--- Wrapping is delegated to mdwrap.nvim's synchronous `format_lines`, replacing
--- the previous out-of-process `mdwrap` CLI call. Wrap options (`wrap_sentence`,
--- `cjk_break_at_punct_only`) come from `config.options.wrap`; the caller only
--- needs to supply an explicit `width`.
local config = require("translate.config")

local M = {}

--- Wrap a list of lines.
---@param lines string[]
---@param opts table|nil mdwrap opts; `width` (display columns) is the important one.
---@return string[] wrapped lines (returns the input unchanged if mdwrap is missing)
function M.wrap(lines, opts)
  -- Wrap options from config (wrap_sentence etc.) are the base; the caller's
  -- explicit opts (width) take precedence.
  opts = vim.tbl_extend("keep", opts or {}, config.options and config.options.wrap or {})

  local ok, mdwrap = pcall(require, "mdwrap")
  if not ok then
    return lines
  end
  return mdwrap.format_lines(lines, opts)
end

--- Prepend the indentation of buffer line `linenr` to every line in `para`.
--- Returns `para` unchanged when there is no indentation or it is empty.
---@param linenr number 1-based line number to read the indent from.
---@param para table|nil lines of a paragraph.
---@return table
function M.indent_para(linenr, para)
  para = para or {}

  local indent_level = vim.fn.indent(linenr)
  if indent_level == 0 or #para == 0 then
    return para
  end

  local indent_str = string.rep(" ", indent_level)
  return vim.tbl_map(function(line)
    return indent_str .. line
  end, para)
end

return M
