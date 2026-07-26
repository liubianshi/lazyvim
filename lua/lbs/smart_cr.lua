-- 智能回车：markdown 类 buffer 的悬挂缩进
--
-- 在插入模式按 <cr> 时，根据当前行「前导符（缩进 + 引用标记 + 列表标记及其后空白）」
-- 的列宽，为新行生成等宽的纯空格缩进，使续行与正文对齐，且不重复任何标记。
--
-- 冲突优先级：blink 补全菜单 > nvim-autopairs 成对括号/代码块 > 智能缩进。

local M = {}

-- filetype 白名单：内容为 markdown 但 filetype 不一定是 markdown 的 buffer 也兜底覆盖
-- （含空 filetype 的 scratch buffer 与 CodeCompanion 输入框）
local FILETYPE_ALLOWLIST = {
  markdown = true,
  quarto = true,
  [""] = true,
  codecompanion = true,
  codecompanion_input = true,
}

-- nvim-autopairs 关注的成对括号：left → right
local PAIRS = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

-- 从行首逐段消费，提取整段前导符：
--   缩进 `^[ \t]*` → 零或多个 blockquote 标记 `>[ \t]*`（支持嵌套）→ 至多一个列表标记。
-- @param line string 当前行（或光标左侧部分）
-- @return string 前导符字符串（保留原始 tab/空格混排）
function M.leading_prefix(line)
  local indent = line:match("^[ \t]*") or ""
  local prefix = indent
  local rest = line:sub(#indent + 1)

  -- blockquote 标记，可能嵌套（如 `> > `）
  while true do
    local quote = rest:match("^>[ \t]*")
    if not quote then
      break
    end
    prefix = prefix .. quote
    rest = rest:sub(#quote + 1)
  end

  -- 至多一个列表标记：无序 `- `/`* `/`+ ` 或有序 `1. `/`1) `
  local marker = rest:match("^[-*+][ \t]+") or rest:match("^%d+[.)][ \t]+")
  if marker then
    prefix = prefix .. marker
  end

  return prefix
end

-- 把前导符中的所有非空白字符替换为等宽空格，得到悬挂缩进。
-- 保留原有 tab/空格，以维持视觉列宽一致。
-- @param prefix string
-- @return string
function M.indent_of(prefix)
  return (prefix:gsub("%S", " "))
end

-- 运行时护栏：光标是否位于 fenced code block 内（此时走普通回车）。
-- @param bufnr number|nil
-- @return boolean
function M.in_code_block(bufnr)
  bufnr = bufnr or 0
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
  if not ok or not node then
    return false
  end
  while node do
    local t = node:type()
    if t == "fenced_code_block" or t == "code_fence_content" then
      return true
    end
    node = node:parent()
  end
  return false
end

-- 光标是否恰好处于一对 autopairs 括号中间（`(|)` / `[|]` / `{|}`）。
-- @param line string 当前行
-- @param col number 光标列（0 基字节偏移，nvim_win_get_cursor 返回值）
-- @return boolean
function M.between_pair(line, col)
  local left = line:sub(col, col)
  local right = line:sub(col + 1, col + 1)
  return right ~= "" and PAIRS[left] == right
end

-- 把已转义为 termcodes 的按键序列喂回插入模式（autopairs_cr 的返回值即已转义）。
local function feed(keys)
  vim.api.nvim_feedkeys(keys, "n", false)
end

-- 回退到 nvim-autopairs 的回车行为（含括号展开 / 普通换行）。
local function plain_cr()
  return require("nvim-autopairs").autopairs_cr()
end

-- 插入模式 <cr> 的处理入口。
function M.cr()
  -- 1) 补全菜单可见：交给补全处理，不做缩进
  local ok_blink, blink = pcall(require, "blink.cmp")
  if ok_blink and blink.is_visible() then
    if blink.get_selected_item() then
      blink.accept()
    else
      blink.cancel()
      feed(plain_cr())
    end
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1], cursor[2]
  local line = vim.api.nvim_get_current_line()

  -- 2) 成对括号中间或代码块内 → 交给 autopairs / 普通换行
  if M.between_pair(line, col) or M.in_code_block(bufnr) then
    feed(plain_cr())
    return
  end

  -- 3) 计算前导符；无前导符则回退普通回车
  local left = line:sub(1, col)
  local prefix = M.leading_prefix(left)
  if prefix == "" then
    feed(plain_cr())
    return
  end

  local indent = M.indent_of(prefix)
  local right = line:sub(col + 1):gsub("^%s+", "") -- 剩余文本：吸收行首空白进缩进

  -- 先断开 undo（在编辑前进入 typeahead），让本次智能缩进成为独立撤销块；
  -- 随后用 vim.schedule 确保 <C-g>u 处理完再做 buffer 编辑。
  feed(vim.api.nvim_replace_termcodes("<C-g>u", true, false, true))
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { left, indent .. right })
    vim.api.nvim_win_set_cursor(win, { row + 1, #indent })
  end)
end

-- buffer 级门控：是否应在该 buffer 启用智能回车。
-- 条件：buftype 为空 且（filetype 在白名单 或 TS 根解析语言为 markdown）。
-- @param bufnr number|nil
-- @return boolean
function M.should_attach(bufnr)
  bufnr = bufnr or 0
  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then
    return false
  end

  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  if FILETYPE_ALLOWLIST[ft] then
    return true
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser and parser:lang() == "markdown" then
    return true
  end

  return false
end

-- 在指定 buffer 注册 buffer-local 的 <cr> 映射（幂等，重复调用覆盖即可）。
-- @param bufnr number|nil
function M.attach(bufnr)
  bufnr = bufnr or 0
  vim.keymap.set("i", "<cr>", M.cr, {
    buffer = bufnr,
    desc = "Smart CR: markdown hanging indent",
  })
end

return M
