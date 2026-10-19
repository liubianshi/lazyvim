local M = {}

local delimiters = vim.regex("[「」『』“”‘’]")
local closing_quotes = { ["「"] = "」", ["『"] = "』", ["“"] = "”", ["‘"] = "’" }
local literal_nodes = {
  code_span = true,
  latex_block = true,
  link_destination = true,
  link_title = true,
  uri_autolink = true,
  email_autolink = true,
  html_tag = true,
  image = true,
}

local function exclusions(root)
  local ranges = {}
  local function visit(node)
    if literal_nodes[node:type()] then
      local first_row, first_col, last_row, last_col = node:range()
      for row = first_row, last_row do
        ranges[row] = ranges[row] or {}
        table.insert(ranges[row], {
          row == first_row and first_col or 0,
          row == last_row and last_col or math.huge,
        })
      end
      return
    end
    for child in node:iter_children() do
      visit(child)
    end
  end
  visit(root)
  return ranges
end

local function add_mark(marks, row, first, last, conceal)
  if first >= last then
    return
  end
  table.insert(marks, {
    conceal = conceal,
    start_row = row,
    start_col = first,
    opts = {
      end_row = row,
      end_col = last,
      conceal = conceal and "" or nil,
      hl_group = not conceal and "RenderMarkdownChineseQuote" or nil,
      priority = 120,
    },
  })
end

function M.parse(ctx)
  local marks, stack = {}, {}
  local ignored = exclusions(ctx.root)
  local first_row, first_col, last_row, last_col = ctx.root:range()
  local lines = vim.api.nvim_buf_get_lines(ctx.buf, first_row, last_row + 1, false)
  for index, line in ipairs(lines) do
    local row = first_row + index - 1
    local offset = row == first_row and first_col or 0
    local limit = row == last_row and last_col or #line
    while offset < limit do
      local first, last = delimiters:match_str(line:sub(offset + 1, limit))
      if not first then
        break
      end
      first, last = first + offset, last + offset
      offset = last
      local literal = false
      for _, range in ipairs(ignored[row] or {}) do
        if first >= range[1] and first < range[2] then
          literal = true
          break
        end
      end
      if not literal then
        local quote = line:sub(first + 1, last)
        if closing_quotes[quote] then
          table.insert(stack, { row = row, first = first, last = last, closing = closing_quotes[quote] })
        elseif stack[#stack] and stack[#stack].closing == quote then
          local opening = table.remove(stack)
          add_mark(marks, opening.row, opening.first, opening.last, true)
          add_mark(marks, row, first, last, true)
          for content_row = opening.row, row do
            local start_col = content_row == opening.row and opening.last or 0
            local end_col = content_row == row and first or #lines[content_row - first_row + 1]
            for _, range in ipairs(ignored[content_row] or {}) do
              add_mark(marks, content_row, start_col, math.min(end_col, range[1]), false)
              start_col = math.max(start_col, range[2])
            end
            add_mark(marks, content_row, start_col, end_col, false)
          end
        end
      end
    end
  end
  return marks
end

function M.setup()
  local function highlight()
    vim.api.nvim_set_hl(0, "RenderMarkdownChineseQuote", { default = true, link = "Special" })
  end
  highlight()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("lbs_markdown_chinese_quotes", { clear = true }),
    callback = highlight,
  })
end

return M
