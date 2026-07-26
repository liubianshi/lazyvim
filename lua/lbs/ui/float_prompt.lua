local M = {}

-- 状态池：Key 为实例名称 (name)，Value 为对象 { buf, win, config }
M.instances = {}

-- 默认配置
local default_opts = {
  filetype = "markdown",
  separator = "## 💬: ",
  width_ratio = 0.8,
  height = 5,
  pos = "bottom",
  title_prefix = " 📝 ",
  buf_prefix = "FloatPrompt://",
  on_submit = function(text)
    print("Sending: " .. text)
  end,
  hide_after_submit = true,
}

--- 获取当前光标所在的文本块 (Normal) 或 选区 (Visual)
local function get_content(buf, separator, mode)
  local pattern_sep = "^" .. separator .. "%s*"

  -- 1. 处理 Visual 模式
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.cmd("normal! \27") -- 强制退出 visual 模式以更新标记
    local s_start = vim.api.nvim_buf_get_mark(buf, "<")
    local s_end = vim.api.nvim_buf_get_mark(buf, ">")
    local lines = vim.api.nvim_buf_get_lines(buf, s_start[1] - 1, s_end[1], false)
    lines[1] = string.gsub(lines[1], pattern_sep, "")

    return table.concat(lines, "\n"), nil, nil
  end

  -- 2. 处理 Normal 模式 (Block 检测)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line_count = vim.api.nvim_buf_line_count(buf)

  local start_row = 0
  local end_row = line_count

  -- 向上找分隔符
  for i = cursor_row, 0, -1 do
    local line = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
    if line and line:match(pattern_sep) then
      start_row = i
      break
    end
  end

  -- 向下找分隔符
  for i = cursor_row + 1, line_count do
    local line = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
    if line and line:match(pattern_sep) then
      end_row = i
      break
    end
  end

  if start_row >= end_row then
    return nil, nil, nil
  end
  local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)
  lines[1] = string.gsub(lines[1], pattern_sep, "")
  return table.concat(lines, "\n"), start_row, end_row
end

--- 提交逻辑
local function submit(id, mode)
  local chat = M.instances[id]
  if not chat or not vim.api.nvim_buf_is_valid(chat.buf) then
    return
  end

  local text, _, end_row = get_content(chat.buf, chat.config.separator, mode)

  if not text or text:match("^%s*$") then
    vim.notify("❌ 内容为空", vim.log.levels.WARN)
    return
  end

  -- 调用该实例特定的回调
  if chat.config.on_submit then
    chat.config.on_submit(text)
  end

  if (mode == "n" or mode == "i") and end_row then
    local line_count = vim.api.nvim_buf_line_count(chat.buf)

    -- 如果 end_row 等于 line_count，说明下方没有分隔符了，也就是在最后一个块
    if end_row >= line_count then
      local sep = chat.config.separator
      -- 在末尾追加：空行 + 分隔符 + 空行
      -- 这样格式比较整洁
      vim.api.nvim_buf_set_lines(chat.buf, line_count, line_count, false, { "", sep, "" })

      -- 将光标移动到新生成的最后一行
      local new_last_line = vim.api.nvim_buf_line_count(chat.buf)
      vim.api.nvim_win_set_cursor(chat.win, { new_last_line, 0 })

      -- 如果是在 Insert 模式下触发的，保持输入流畅性，自动进入插入模式
      if mode == "i" then
        vim.cmd("startinsert!")
      end
    end
  end

  if chat.config.hide_after_submit then
    M.hide_window(id)
  end
end

--- 主入口：根据 id 切换窗口
---@param id string 唯一标识符，例如 'general', 'refactor'
---@param opts table 配置项
function M.toggle(id, opts)
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  -- 初始化状态槽
  if not M.instances[id] then
    M.instances[id] = { buf = -1, win = -1, config = opts }
  else
    -- 更新配置 (允许运行时改变回调)
    M.instances[id].config = opts
  end

  local chat = M.instances[id]

  -- 1. 窗口已打开 -> 关闭
  if chat.win and vim.api.nvim_win_is_valid(chat.win) then
    M.hide_window(id)
    return
  end

  -- 2. Buffer 不存在 -> 创建并初始化
  if not chat.buf or not vim.api.nvim_buf_is_valid(chat.buf) then
    chat.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[chat.buf].bufhidden = "hide" -- 关键：隐藏不销毁
    vim.bo[chat.buf].filetype = opts.filetype

    -- 尝试设置 Buffer 名称，方便 :ls 查看
    local buf_name = opts.buf_prefix .. id

    -- 清理僵尸 Buffer (防止 rename 报错)
    local existing_buf = vim.fn.bufnr("^" .. vim.fn.escape(buf_name, "\\/.*$^~[]") .. "$")
    if existing_buf ~= -1 and existing_buf ~= chat.buf then
      vim.api.nvim_buf_delete(existing_buf, { force = true })
    end

    pcall(vim.api.nvim_buf_set_name, chat.buf, buf_name)
    vim.api.nvim_buf_set_lines(chat.buf, 0, 1, false, { opts.separator })

    local function map_with_desc(desc)
      local map_opts = { buffer = chat.buf, noremap = true, silent = true }
      return vim.tbl_extend("force", map_opts, { desc = desc })
    end
    -- stylua: ignore start
    vim.keymap.set("n", "<CR>",   function() submit(id, "n")    end, map_with_desc("Submit current prompt block"))
    vim.keymap.set("n", "<C-CR>", function() submit(id, "n")    end, map_with_desc("Submit current prompt block"))
    vim.keymap.set("i", "<C-CR>", function() submit(id, "i")    end, map_with_desc("Submit current prompt block"))
    vim.keymap.set("v", "<CR>",   function() submit(id, "v")    end, map_with_desc("Submit selection"))
    vim.keymap.set("n", "q",      function() M.hide_window(id) end, map_with_desc("Hide window"))
    vim.keymap.set("n", "<Esc>",  function() M.hide_window(id) end, map_with_desc("Hide window"))
    vim.keymap.set("n", "<C-q>",  function() M.delete_window(id) end, map_with_desc("Close window"))
    -- stylua: ignore end
  end

  -- 3. 创建窗口：split 模式 vs 浮动模式
  local height = opts.height_ratio and math.floor(vim.o.lines * opts.height_ratio) or opts.height

  if opts.pos == "split" then
    local anchor = opts.anchor_win_fn and opts.anchor_win_fn() or nil
    if anchor and vim.api.nvim_win_is_valid(anchor) then
      vim.api.nvim_set_current_win(anchor)
      vim.cmd((opts.split_dir or "belowright") .. " " .. height .. "split")
    else
      vim.cmd("botright " .. height .. "split")
    end
    chat.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(chat.win, chat.buf)
    vim.wo[chat.win].winbar = (opts.title_prefix or "") .. id
  else
    local width = math.floor(vim.o.columns * opts.width_ratio)
    local row, col

    if opts.pos == "bottom" then
      row = vim.o.lines - height - 1
      if vim.o.laststatus > 0 then
        row = row - 2
      end
      if vim.o.cmdheight > 0 then
        row = row - vim.o.cmdheight -- 让出命令行位置，防止遮挡
      end
    else
      row = math.floor((vim.o.lines - height) / 2)
    end
    col = math.floor((vim.o.columns - width) / 2)

    local win_opts = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = opts.pos == "center" and (opts.title_prefix .. id) or nil,
      title_pos = opts.pos == "center" and "center" or nil,
      zindex = 50, -- 确保在最上层
    }

    chat.win = vim.api.nvim_open_win(chat.buf, true, win_opts)
  end
  vim.wo[chat.win].scrolloff = 0

  -- 自动定位到最后一行
  local line_count = vim.api.nvim_buf_line_count(chat.buf)
  vim.api.nvim_win_set_cursor(chat.win, { line_count, 0 })
  vim.cmd("startinsert!")
end

-- 补充 helper 以防报错
function M.hide_window(id)
  local chat = M.instances[id]
  if chat and chat.win and vim.api.nvim_win_is_valid(chat.win) then
    vim.api.nvim_win_hide(chat.win)
  end
end

function M.delete_window(id)
  local chat = M.instances[id]
  if chat and chat.win and vim.api.nvim_win_is_valid(chat.win) then
    vim.api.nvim_win_close(chat.win, true)
  end
end

return M
