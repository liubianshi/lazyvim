--- Rendering helpers: virtual-text / virtual-line extmarks, the preview float
--- window, and writing translated output to a file. All buffer/namespace state
--- comes from `config` (ns_id, hl_group).
local config = require("translate.config")

local M = {}

--- Set an inline virtual-text extmark (the text is wrapped in `[]`).
---@param buf integer Buffer handle (0 for current buffer).
---@param row integer 0-based line index for the mark.
---@param col integer 0-based column index for the mark.
---@param text string The virtual text content to display.
---@param opts? table Additional `nvim_buf_set_extmark` options.
function M.set_text_extmark(buf, row, col, text, opts)
  opts = opts or {}

  local default = {
    virt_text_pos = "inline",
    virt_text_repeat_linebreak = true,
    hl_mode = "combine",
  }
  local merged_opts = vim.tbl_deep_extend("keep", opts, default)
  merged_opts.virt_text = { { string.format("[%s]", text), config.options.hl_group } }

  vim.api.nvim_buf_set_extmark(buf, config.ns_id, row, col, merged_opts)
end

--- Set a virtual-lines extmark below `row`.
---@param buf integer buffer number, 0 for current buffer
---@param row integer line where to place the mark, 0-based
---@param lines string[] virtual lines to add
---@param opts? vim.api.keyset.set_extmark
function M.set_line_extmark(buf, row, lines, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    virt_lines_leftcol = false,
  })
  opts.virt_lines = vim.tbl_map(function(line)
    return { { line, config.options.hl_group } }
  end, lines)
  vim.api.nvim_buf_set_extmark(buf, config.ns_id, row, 0, opts)
end

--- Save or append translated content to a file, checking writability first.
---@param output_file_path string
---@param content string|string[]
---@param append boolean true => append, false => overwrite.
function M.save_translate_output(output_file_path, content, append)
  local flag = append and "a" or "w"
  local can_write = false

  local stat = vim.uv.fs_stat(output_file_path)
  if stat then
    if vim.uv.fs_access(output_file_path, "W") then
      can_write = true
    else
      vim.notify("Output file exists but is not writable: " .. output_file_path, vim.log.levels.ERROR)
    end
  else
    local dir = vim.fn.fnamemodify(output_file_path, ":h")
    if dir == "" then
      dir = "."
    end
    if vim.uv.fs_access(dir, "W") then
      can_write = true
    else
      vim.notify("Cannot write to directory for output file: " .. dir, vim.log.levels.ERROR)
    end
  end

  if can_write then
    local success_code = vim.fn.writefile(content, output_file_path, flag)
    if success_code ~= 0 then
      vim.notify("Failed to write to output file: " .. output_file_path, vim.log.levels.ERROR)
    else
      local action = append and "Appended" or "Wrote"
      vim.notify(action .. " translation to " .. output_file_path, vim.log.levels.INFO)
    end
  end
end

--- Create a floating window positioned near the cursor / selection, used to
--- preview sentence translations.
---@param opts table|nil { win_height, win_width, buf }
---@return table|nil win a snacks.win instance, or nil if positioning failed.
function M.create_float_win(opts)
  opts = vim.tbl_extend("keep", opts or {}, { win_height = 15, win_width = 70 })

  local mode = vim.api.nvim_get_mode().mode
  local current_win_line = vim.fn.winline()
  local current_win_col = vim.fn.wincol()

  local start_line, start_col, end_line, end_col = current_win_line, current_win_col, current_win_line, current_win_col
  if mode == "v" or mode == "V" or mode == "\22" then
    local coord = require("util").get_visual_coordinate()
    if not coord then
      return
    end

    local current_line = vim.fn.line(".")
    local line_offset = current_line - current_win_line
    start_line, end_line = coord[1] - line_offset, coord[3] - line_offset

    local current_col = vim.fn.col(".")
    local col_offset = current_col - current_win_col
    start_col, end_col = coord[2] - col_offset, coord[4] - col_offset
  end

  local current_win_height = vim.api.nvim_win_get_height(0)

  local ln, col
  if current_win_height - end_line < opts.win_height then
    ln = math.max(start_line - opts.win_height - 1, 1)
    col = start_col
  else
    ln, col = end_line, end_col
  end

  local win = require("snacks.win").new({
    border = "rounded",
    backdrop = false,
    relative = "win",
    buf = opts.buf,
    row = ln,
    col = col,
    width = opts.win_width,
    height = opts.win_height,
    bo = {
      buftype = "nofile",
      swapfile = false,
    },
    wo = {
      signcolumn = "yes:1",
      wrap = true,
      linebreak = true,
    },
  })

  return win
end

return M
