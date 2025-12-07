--- Window Inspector Module
--- Provides utilities to inspect and display information about windows and buffers
local M = {}

--- Get comprehensive information about a window and its buffer
--- @param win number|nil Window ID (defaults to current window)
--- @return table Information about the window
function M.get_window_info(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local win_config = vim.api.nvim_win_get_config(win)

  -- Get buffer options
  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
  local bufname = vim.api.nvim_buf_get_name(buf)
  local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
  local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = buf })

  -- Get window options
  local winhl = vim.api.nvim_get_option_value("winhighlight", { win = win })
  local winblend = vim.api.nvim_get_option_value("winblend", { win = win })

  return {
    -- Window info
    win_id = win,
    win_config = win_config,
    focusable = win_config.focusable,
    relative = win_config.relative,
    zindex = win_config.zindex,
    width = vim.api.nvim_win_get_width(win),
    height = vim.api.nvim_win_get_height(win),
    winhighlight = winhl,
    winblend = winblend,

    -- Buffer info
    buf_id = buf,
    bufname = bufname,
    filetype = ft,
    buftype = buftype,
    modified = modified,
    modifiable = modifiable,
    line_count = vim.api.nvim_buf_line_count(buf),
  }
end

--- Format window information into human-readable lines
--- @param info table Window information from get_window_info()
--- @return table Array of formatted strings
function M.format_info(info)
  local lines = {
    "╭─ Window Inspector ──────────────────────────────╮",
    "│                                                 │",
    string.format("│ %-15s %-31s │", "Window ID:", info.win_id),
    string.format("│ %-15s %-31s │", "Buffer ID:", info.buf_id),
    "│                                                 │",
  }

  -- Buffer information
  table.insert(lines, "│ Buffer Information:                             │")
  table.insert(
    lines,
    string.format(
      "│   %-13s %-31s │",
      "Name:",
      info.bufname == "" and "<unnamed>" or vim.fn.fnamemodify(info.bufname, ":~:.")
    )
  )
  table.insert(
    lines,
    string.format("│   %-13s %-31s │", "Filetype:", info.filetype == "" and "<none>" or info.filetype)
  )
  table.insert(
    lines,
    string.format("│   %-13s %-31s │", "Buftype:", info.buftype == "" and "normal" or info.buftype)
  )
  table.insert(lines, string.format("│   %-13s %-31s │", "Lines:", info.line_count))
  table.insert(lines, string.format("│   %-13s %-31s │", "Modified:", info.modified and "yes" or "no"))
  table.insert(lines, string.format("│   %-13s %-31s │", "Modifiable:", info.modifiable and "yes" or "no"))
  table.insert(lines, "│                                                 │")

  -- Window information
  table.insert(lines, "│ Window Information:                             │")
  table.insert(lines, string.format("│   %-13s %-31s │", "Size:", string.format("%dx%d", info.width, info.height)))
  table.insert(lines, string.format("│   %-13s %-31s │", "Focusable:", tostring(info.focusable)))
  table.insert(
    lines,
    string.format("│   %-13s %-31s │", "Relative:", info.relative == "" and "<none>" or info.relative)
  )
  table.insert(lines, string.format("│   %-13s %-31s │", "Z-Index:", info.zindex or "<none>"))
  table.insert(lines, string.format("│   %-13s %-31s │", "Winblend:", info.winblend))

  if info.winhighlight ~= "" then
    table.insert(lines, string.format("│   %-13s %-31s │", "WinHighlight:", info.winhighlight:sub(1, 31)))
  end

  table.insert(lines, "│                                                 │")
  table.insert(
    lines,
    "╰─────────────────────────────────────────────────╯"
  )
  table.insert(lines, "")
  table.insert(lines, "Press 'q' or <Esc> to close")

  return lines
end

--- Create and display a floating window with window information
--- @param win number|nil Window ID to inspect (defaults to current window)
function M.show(win)
  win = win or vim.api.nvim_get_current_win()

  -- Get and format information
  local info = M.get_window_info(win)
  local lines = M.format_info(info)

  -- Calculate window dimensions
  local width = 53
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer for the inspector window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "window-inspector", { buf = buf })

  -- Create floating window
  local float_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
    noautocmd = true,
  })

  -- Set window options
  vim.api.nvim_set_option_value("winblend", 0, { win = float_win })
  vim.api.nvim_set_option_value("cursorline", false, { win = float_win })

  -- Set up keymaps to close the window
  local close_keys = { "q", "<Esc>", "<CR>" }
  for _, key in ipairs(close_keys) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
      end
    end, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc = "Close window inspector",
    })
  end

  -- Set up syntax highlighting
  vim.api.nvim_buf_call(buf, function()
    vim.cmd([[
      syntax match WindowInspectorBorder /[╭─╮│╰╯]/
      syntax match WindowInspectorKey /^\s*│\s*\zs[^:│]\+\ze:/
      syntax match WindowInspectorValue /:\s*\zs[^│]\+\ze\s*│/
      syntax match WindowInspectorHeader /│\s*\zs[A-Z][^:│]*\ze\s*│/
      syntax match WindowInspectorHint /^Press.*$/

      highlight default link WindowInspectorBorder Comment
      highlight default link WindowInspectorKey Identifier
      highlight default link WindowInspectorValue String
      highlight default link WindowInspectorHeader Title
      highlight default link WindowInspectorHint Comment
    ]])
  end)
end

--- Show a comparison of two windows side by side
--- @param win1 number First window ID
--- @param win2 number Second window ID
function M.compare(win1, win2)
  local info1 = M.get_window_info(win1)
  local info2 = M.get_window_info(win2)

  local lines = {
    "Window Comparison",
    string.rep("=", 60),
    "",
    string.format("%-30s | %-30s", "Window " .. win1, "Window " .. win2),
    string.rep("-", 60),
    string.format("%-30s | %-30s", "Buffer: " .. info1.buf_id, "Buffer: " .. info2.buf_id),
    string.format(
      "%-30s | %-30s",
      "Filetype: " .. (info1.filetype == "" and "<none>" or info1.filetype),
      "Filetype: " .. (info2.filetype == "" and "<none>" or info2.filetype)
    ),
    string.format(
      "%-30s | %-30s",
      "Size: " .. info1.width .. "x" .. info1.height,
      "Size: " .. info2.width .. "x" .. info2.height
    ),
    string.format("%-30s | %-30s", "Z-Index: " .. (info1.zindex or "none"), "Z-Index: " .. (info2.zindex or "none")),
  }

  -- Display in a new buffer
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
  vim.api.nvim_set_option_value("modifiable", false, { buf = 0 })
end

--- List all windows in the current tab with basic info
--- @return table Array of window information
function M.list_windows()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  local result = {}

  for _, win in ipairs(windows) do
    local info = M.get_window_info(win)
    table.insert(result, {
      win_id = info.win_id,
      buf_id = info.buf_id,
      filetype = info.filetype,
      size = string.format("%dx%d", info.width, info.height),
      floating = info.relative ~= "",
    })
  end

  return result
end

--- Print a summary of all windows in the current tab
function M.print_summary()
  local windows = M.list_windows()
  print("Windows in current tab:")
  print(string.rep("-", 60))
  print(string.format("%-8s %-8s %-15s %-12s %-8s", "Win ID", "Buf ID", "Filetype", "Size", "Float"))
  print(string.rep("-", 60))

  for _, win_info in ipairs(windows) do
    print(
      string.format(
        "%-8d %-8d %-15s %-12s %-8s",
        win_info.win_id,
        win_info.buf_id,
        win_info.filetype == "" and "<none>" or win_info.filetype,
        win_info.size,
        win_info.floating and "yes" or "no"
      )
    )
  end
end

return M
