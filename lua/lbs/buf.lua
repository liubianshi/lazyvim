-- 缓冲区文本操作：visual 选区取值与坐标、按段落合并行。
local M = {}

--- Gets the start and end coordinates (line and column) of the last visual selection.
--- Ensures that the start position always comes before the end position,
--- regardless of the direction the visual selection was made.
---@return VisualCoordinate|nil A table containing the start and end coordinates: { start_line, start_col, end_line, end_col }
function M.get_visual_coordinate()
  -- Get the start and end positions of the last visual selection
  -- getpos("'<") returns the start marker
  -- getpos("'>") returns the end marker
  -- The format is [bufnum, lnum, col, off]
  local start_pos, end_pos
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  else
    start_pos = vim.fn.getpos(".")
    end_pos = vim.fn.getpos("v")
  end
  if not start_pos or not end_pos then
    return
  end

  local srow, scol, erow, ecol = start_pos[2], start_pos[3], end_pos[2], end_pos[3]

  -- Ensure start_pos represents the position that comes first in the buffer
  -- Compare line numbers first, then column numbers if lines are the same
  if srow > erow or (srow == erow and scol > ecol and mode ~= "V") then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end

  if mode == "V" then
    scol = 1
    ecol = -1
  end

  -- ecol 指向最后一个选中字符的首字节，推到它的末字节，否则按字节切会截断多字节序列。
  -- 用 str_utf_end 而不是手写首字节范围表：旧实现给 4 字节序列（emoji、CJK 扩展 B
  -- 的汉字）只补 2 而非 3，少一个字节，切出来是残缺的 UTF-8。中文是 3 字节，恰好
  -- 落在写对了的那一档，所以这个错误一直没显形。
  if srow == erow and mode ~= "V" then
    local line = vim.fn.getline(srow)
    if ecol >= 1 and ecol <= #line then
      ecol = ecol + vim.str_utf_end(line, ecol)
    end
  end

  -- Return the relevant coordinates: start line, start col, end line, end col
  return { srow, scol, erow, ecol }
end

-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/utils.lua
---@return string[]|nil A table containing the start and end coordinates: { start_line, start_col, end_line, end_col }
function M.get_visual_selection()
  -- this will exit visual mode
  -- use 'gv' to reselect the text
  local visual_coordiate = M.get_visual_coordinate()
  if not visual_coordiate then
    return
  end
  local csrow, cscol, cerow, cecol = unpack(visual_coordiate)
  local lines = vim.api.nvim_buf_get_lines(0, csrow - 1, cerow, false)
  local n = #lines
  if n <= 0 then
    return
  end
  if cecol then
    lines[n] = string.sub(lines[n], 1, cecol)
  end
  if cscol then
    lines[1] = string.sub(lines[1], cscol)
  end

  return lines
end

---Joins lines within paragraphs in a list of strings.
---Paragraphs are defined as sequences of non-blank lines separated by one or more blank lines.
---@param lines? string[] A list of strings, where each string represents a line.
---@return string[], Paragraphs.Position[]|nil A new list of strings with lines within each paragraph joined together. Returns an empty table if the input is nil or empty.
function M.join_strings_by_paragraph(lines)
  if not lines or #lines == 0 then
    return {}
  end

  -- 创建临时缓冲区
  local temp_bufnr = vim.api.nvim_create_buf(false, true)
  if temp_bufnr <= 0 then
    vim.notify("Error: Could not create temporary buffer.", vim.log.levels.ERROR)
    return lines -- Return original lines on error
  end

  -- 销毁临时缓冲区
  local cleanup = function()
    if vim.api.nvim_buf_is_valid(temp_bufnr) then
      vim.api.nvim_buf_delete(temp_bufnr, { force = true })
    end
  end

  -- 将 list 写入缓冲区。临时 buffer 只是为了借 `:join`，段落扫描直接用入参 lines，
  -- 不必写进去再读回来。
  vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, lines)

  -- 扫描内容，读取每段的起始和结束行
  local paragraph_ranges = {}
  local current_paragraph_start = 0
  local line_count = #lines

  for i = 1, line_count do
    local trimmed_line = vim.trim(lines[i] or "") -- Handle potential nil

    if #trimmed_line > 0 then -- Non-blank line
      if current_paragraph_start == 0 then
        current_paragraph_start = i
      end
    else -- Blank line
      if current_paragraph_start > 0 then
        -- Paragraph ended before this blank line
        table.insert(paragraph_ranges, { start = current_paragraph_start, finish = i - 1 })
        current_paragraph_start = 0
      end
      -- Ignore consecutive blank lines for range finding
    end
  end

  -- Check for paragraph ending at the last line
  if current_paragraph_start > 0 then
    table.insert(paragraph_ranges, { start = current_paragraph_start, finish = line_count })
  end

  -- Join paragraphs in reverse order to avoid messing up line numbers
  vim.api.nvim_buf_call(temp_bufnr, function()
    for i = #paragraph_ranges, 1, -1 do
      local range = paragraph_ranges[i]
      if range.finish > range.start then -- Only join if paragraph has more than 1 line
        vim.cmd(string.format("%d,%djoin", range.start, range.finish))
      end
    end
  end)

  local final_lines = vim.api.nvim_buf_get_lines(temp_bufnr, 0, -1, false)
  cleanup()
  return final_lines, paragraph_ranges
end

--- 把选中的 markdown 渲染成 html 交给 mdviewer。
--- 唯一调用点在 autoload/utils.vim 的 utils#MdPreview()（surf 可用时的分支）。
---@param input? string[] 不传则取当前 visual 选区
function M.md_preview(input)
  -- 用本文件既有的 get_visual_selection：它经 get_visual_coordinate 处理了反向选区、
  -- 块选与多字节结尾，且退出 visual 模式后仍能靠 '< '> 取到选区——而 vimscript 侧
  -- 的 utils#MdPreview() 正是在退出 visual 之后才被调用的。
  input = input or M.get_visual_selection()
  if not input or #input == 0 then
    return
  end

  local outfile = vim.fn.stdpath("cache") .. "/vim_markdown_preview.html"
  vim.system({ "mdviewer", "--to", "html", "--outfile", outfile }, { text = true, stdin = input }, function() end)
end

return M
