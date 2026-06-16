--- User-facing translation actions. These are the functions re-exported by
--- `translate.init` and bound in keymaps. Engine calls go through `engine.*`,
--- rendering through `render.*`, and wrapping/indent through `format.*`.
local config = require("translate.config")
local engine = require("translate.engine")
local render = require("translate.render")
local format = require("translate.format")
local cache = require("translate.cache")
local util = require("util")

local M = {}

-- In-buffer undo map for paragraph replace: bufnr -> { normalized_translation
-- -> original_lines }. The primary, always-reliable restore path (works even
-- when the SQLite cache is degraded). `cache.find_source` is the cross-session
-- fallback when no in-memory entry matches.
local undo_map = {}

--- Resolve the target display width for a buffer, falling back to the narrowest
--- line in `content` (capped at 78) when the buffer has no usable 'textwidth'.
---@param buf integer
---@param content string[]
---@return integer
local function fallback_textwidth(buf, content)
  local tw = vim.bo[buf].textwidth
  if tw and tw > 0 then
    return tw
  end
  local widths = vim.tbl_map(function(l)
    return vim.fn.strdisplaywidth(l)
  end, content)
  return math.min(math.min(unpack(widths)), 78)
end

--- Render a multi-paragraph translation as virtual lines anchored at the end of
--- each source paragraph. Shared by visual-selection and `:Translate <range>`.
---@param buf integer
---@param content string[] source lines (raw selection / range)
---@param srow integer 1-based start row of the source in the buffer
---@param opts {force?: boolean}
local function render_paragraphs(buf, content, srow, opts)
  local grouped_content, paragraph_range = util.join_strings_by_paragraph(content)
  table.insert(grouped_content, "")

  -- Buffer line (1-based) where each source paragraph ends.
  local paragraph_end = vim.tbl_map(function(range)
    return range.finish + srow - 1
  end, paragraph_range or {})

  local textwidth = fallback_textwidth(buf, content)
  local indent_num = vim.api.nvim_buf_call(buf, function()
    return vim.fn.indent(paragraph_end[#paragraph_end])
  end)

  engine.translate_paragraph(grouped_content, {
    textwidth = textwidth,
    indent = indent_num or 0,
    force = opts and opts.force,
    callback = function(lines)
      local para, para_id = {}, 1
      for _, line in ipairs(lines) do
        local trimmed_line = vim.trim(line or "")
        if #trimmed_line > 0 then
          table.insert(para, trimmed_line)
        else
          render.set_line_extmark(buf, paragraph_end[para_id] - 1, format.indent_para(paragraph_end[para_id], para))
          para_id = para_id + 1
          para = {}
        end
      end
      if #para > 0 then
        render.set_line_extmark(buf, paragraph_end[para_id] - 1, format.indent_para(paragraph_end[para_id], para))
      end
    end,
  })
end

--- Translate a single buffer line and show the result as virtual lines below it.
---@param buf? integer buffer number
---@param line? integer line number (1-based)
---@param opts? {force?: boolean}
function M.translate_line(buf, line, opts)
  buf = buf or vim.api.nvim_get_current_buf()
  line = line or vim.api.nvim_win_get_cursor(0)[1]

  local content_lines = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)
  if not content_lines or #content_lines == 0 then
    vim.notify("Error: Could not get content for line " .. line .. " in buffer " .. buf, vim.log.levels.ERROR)
    return
  end
  local content = content_lines[1]

  local indent_num = vim.api.nvim_buf_call(buf, function()
    local n = 0
    if line > 0 and line <= vim.api.nvim_buf_line_count(0) then
      n = math.max(vim.fn.indent(line), 0)
    end
    return n
  end)

  local textwidth = vim.bo[buf].textwidth
  if not textwidth or textwidth <= 0 then
    local display_width = math.max(vim.fn.strdisplaywidth(content or ""), 0)
    textwidth = math.min(display_width, 78)
  end

  engine.translate_paragraph({ content }, {
    textwidth = textwidth,
    indent = indent_num,
    force = opts and opts.force,
    callback = function(translated_lines)
      if not translated_lines or #translated_lines == 0 then
        return
      end
      local prepared_lines = vim.tbl_map(function(l)
        local trimmed_line = vim.trim(l or "")
        return string.rep(" ", indent_num) .. trimmed_line
      end, translated_lines)
      if #prepared_lines > 0 then
        render.set_line_extmark(buf, line - 1, prepared_lines)
      end
    end,
  })
end

--- Translate the current visual selection.
--- Charwise (`v`) => inline deepl translation; otherwise => fabric paragraphs.
---@param opts? {force?: boolean}
function M.translate_selection(opts)
  local winid = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(winid)
  local visual_coordiate = util.get_visual_coordinate()
  local content = util.get_visual_selection()
  local mode = vim.api.nvim_get_mode()
  if not visual_coordiate or not content or #content == 0 then
    return
  end
  local srow, _, erow, ecol = unpack(visual_coordiate)

  if mode == "v" then
    engine.translate_phrase(content[1], function(text)
      render.set_text_extmark(buf, erow - 1, ecol, text)
    end, { force = opts and opts.force })
  else
    render_paragraphs(buf, content, srow, opts or {})
  end
end

--- Translate an explicit line range (used by `:Translate <range>`).
---@param line1 integer 1-based start line
---@param line2 integer 1-based end line
---@param opts? {force?: boolean}
function M.translate_range(line1, line2, opts)
  local buf = vim.api.nvim_get_current_buf()
  if line1 == line2 then
    M.translate_line(buf, line1, opts)
    return
  end
  local content = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  if not content or #content == 0 then
    return
  end
  render_paragraphs(buf, content, line1, opts or {})
end

--- Translate arbitrary content. With a `callback`, returns raw (unwrapped)
--- lines to it; otherwise routes to word lookup (kd) or sentence preview.
---@param content? string|string[]
---@param callback? fun(lines: string[])
---@param opts? {force?: boolean}
function M.translate_content(content, callback, opts)
  opts = opts or {}
  content = content or util.get_visual_selection()
  if type(content) == "string" then
    if content:find("%S") then
      content = { content }
    end
  end
  if not content or #content == 0 then
    return
  end

  if callback then
    engine.translate_paragraph(content, { wrap = false, force = opts.force, callback = callback })
    return
  end

  local save_path = util.get_daily_filepath("md", "ReciteWords")
  if #content == 1 and #vim.split(content[1], "%s+") <= 3 then
    require("kd").translate_word(content[1], save_path)
  else
    M.translate_sentence(content, save_path, opts)
  end
end

--- Operator-pending translation. With no `type` arg, arms the operator;
--- otherwise selects the motion's text and translates it.
---@param type? string "line"|"char"|"block"
function M.trans_op(type)
  local commands = {
    line = "'[V']",
    char = "`[v`]",
    block = "`[\\<C-V>`]",
  }
  if not type or #type == 0 then
    vim.opt.opfunc = "v:lua.require'translate'.trans_op"
    vim.api.nvim_feedkeys("g@", "m", false)
  else
    vim.cmd.normal(commands[type])
    M.translate_content()
  end
end

--- Toggle the visibility of this module's translation extmarks.
---@return integer|nil 0 when nothing visible/hidden (caller should translate).
function M.toggle()
  return config.extmark:toggle_extmarks()
end

--- Translate `content` and show it in a floating markdown preview (anki-style),
--- optionally appending the rendered block to `output_file_path`.
---@param content string[]
---@param output_file_path? string
---@param opts? {force?: boolean}
function M.translate_sentence(content, output_file_path, opts)
  local grouped_content, _ = util.join_strings_by_paragraph(content)

  local textwidth = vim.bo.textwidth
  if not textwidth or textwidth == 0 then
    textwidth = math.min(
      math.min(unpack(vim.tbl_map(function(l)
        return vim.fn.strdisplaywidth(l)
      end, content))),
      78
    )
  end

  engine.translate_paragraph(grouped_content, {
    textwidth = textwidth,
    indent = 0,
    force = opts and opts.force,
    callback = function(lines)
      if not lines or #lines < 1 then
        return
      end
      local grouped_lines, _ = util.join_strings_by_paragraph(lines)

      local output_lines, extmarks = {}, {}
      vim.list_extend(output_lines, { "<!-- start_anki trans -->", "---", "" })
      vim.list_extend(output_lines, grouped_content)
      vim.list_extend(output_lines, { "", ". . .", "" })
      for i = 0, #output_lines - 1 do
        table.insert(extmarks, { line = i, col = 0, opts = { conceal_lines = "" } })
      end
      local start_line = #output_lines + 1
      vim.list_extend(output_lines, grouped_lines)
      vim.list_extend(output_lines, { "<!-- end_anki -->", "" })
      table.insert(extmarks, { line = #output_lines - 2, col = 0, opts = { conceal_lines = "" } })
      table.insert(extmarks, { line = #output_lines - 1, col = 0, opts = { conceal_lines = "" } })

      local win = render.create_float_win({
        win_height = math.min(15, #lines),
        win_width = math.min(70, math.ceil(0.75 * vim.fn.winwidth(0))),
      })
      if not win or not win.buf then
        return
      end

      vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, output_lines)
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = win.buf })
      vim.api.nvim_set_option_value("modified", false, { buf = win.buf })
      vim.api.nvim_set_option_value("modifiable", false, { buf = win.buf })

      local ns = "trans_sentence_highlight"
      local ns_id = vim.api.nvim_create_namespace(ns)
      vim.api.nvim_buf_clear_namespace(win.buf, ns_id, 0, -1)
      for _, e in ipairs(extmarks) do
        vim.api.nvim_buf_set_extmark(win.buf, ns_id, e.line, e.col, e.opts)
      end

      win:show()
      vim.api.nvim_win_set_cursor(win.win, { start_line, 0 })

      if output_file_path then
        render.save_translate_output(output_file_path, output_lines, true)
      end
    end,
  })
end

--- Insert-mode helper: translate the current line (or its `=...` suffix) and
--- replace it in place with the translation.
---@param opts? {force?: boolean}
function M.replace_line(opts)
  vim.cmd.stopinsert()
  local winnr = vim.api.nvim_get_current_win()
  local row = vim.api.nvim_win_get_cursor(winnr)[1]
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)

  if not current_line or #current_line == 0 or not current_line[1]:find("%S") then
    return
  end

  local match_s, _, match = current_line[1]:find("%=([^=]+)$")
  local pre_content = match_s and current_line[1]:sub(1, match_s - 1) or current_line[1]:match("^%s+")
  local content = match_s and match or current_line[1]

  if not content:find("%S") then
    return
  end
  content = content:gsub("%s+$", ""):gsub("^%s+", "")

  engine.translate_paragraph({ content }, {
    wrap = false,
    force = opts and opts.force,
    callback = function(results)
      if not results or #results == 0 then
        return
      end
      local translated_content = table.concat(results, " ")
      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { (pre_content or "") .. translated_content })
    end,
  })
end

--- Return the 1-based [srow, erow] of the (blank-line delimited) paragraph the
--- cursor sits in, or nil when the cursor is on a blank line.
---@param buf integer
---@param cursor_row integer 1-based
---@return integer|nil srow
---@return integer|nil erow
local function current_paragraph_range(buf, cursor_row)
  local total = vim.api.nvim_buf_line_count(buf)
  local function is_blank(n)
    local l = vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1]
    return not l or not l:find("%S")
  end
  if cursor_row < 1 or cursor_row > total or is_blank(cursor_row) then
    return nil
  end
  local s, e = cursor_row, cursor_row
  while s > 1 and not is_blank(s - 1) do
    s = s - 1
  end
  while e < total and not is_blank(e + 1) do
    e = e + 1
  end
  return s, e
end

--- Try to restore a paragraph that is itself a known translation back to its
--- original text. In-memory undo map first (exact), then the SQLite cache
--- reverse lookup (cross-session). Returns true if a restore happened.
---@param buf integer
---@param srow integer 1-based
---@param erow integer 1-based
---@param para_join string the paragraph joined with "\n"
---@return boolean restored
local function restore_paragraph(buf, srow, erow, para_join)
  local norm = cache.normalize(para_join)

  local m = undo_map[buf]
  if m and m[norm] then
    vim.api.nvim_buf_set_lines(buf, srow - 1, erow, false, m[norm])
    m[norm] = nil
    return true
  end

  local source = cache.find_source(para_join)
  if source then
    vim.api.nvim_buf_set_lines(buf, srow - 1, erow, false, vim.split(source, "\n"))
    return true
  end

  return false
end

--- Translate the paragraph under the cursor and replace it in place (CJK source
--- => English, otherwise => Chinese; direction is auto-detected by the engine).
--- If the paragraph is already a known translation, this restores the original
--- instead (toggle), so repeated presses flip between source and translation.
---@param opts? {force?: boolean}
function M.translate_paragraph_replace(opts)
  opts = opts or {}
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor_row = vim.api.nvim_win_get_cursor(win)[1]

  local srow, erow = current_paragraph_range(buf, cursor_row)
  if not srow then
    return
  end

  local original_lines = vim.api.nvim_buf_get_lines(buf, srow - 1, erow, false)
  if #original_lines == 0 then
    return
  end

  -- Toggle: if this paragraph is a translation we produced, restore it.
  local para_join = table.concat(vim.tbl_map(vim.trim, original_lines), "\n")
  if not opts.force and restore_paragraph(buf, srow, erow, para_join) then
    return
  end

  local indent_num = vim.api.nvim_buf_call(buf, function()
    return math.max(vim.fn.indent(srow), 0)
  end)
  local textwidth = vim.bo[buf].textwidth
  if not textwidth or textwidth <= 0 then
    textwidth = 80
  end

  local grouped_content = util.join_strings_by_paragraph(original_lines)

  engine.translate_paragraph(grouped_content, {
    textwidth = textwidth,
    indent = indent_num,
    wrap = true,
    force = opts.force,
    callback = function(translated_lines)
      if not translated_lines or #translated_lines == 0 then
        return
      end
      local prepared = vim.tbl_map(function(l)
        return string.rep(" ", indent_num) .. vim.trim(l or "")
      end, translated_lines)

      -- Record the undo mapping keyed by the normalized translation so the next
      -- press on this (now translated) paragraph restores the original lines.
      local norm = cache.normalize(table.concat(vim.tbl_map(vim.trim, prepared), "\n"))
      undo_map[buf] = undo_map[buf] or {}
      undo_map[buf][norm] = original_lines

      vim.api.nvim_buf_set_lines(buf, srow - 1, erow, false, prepared)
    end,
  })
end

return M
