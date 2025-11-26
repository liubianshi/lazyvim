-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_del_augroup_by_name("lazyvim_resize_splits")
-- yanky.nvim 提供类似高亮复制区域的功能
vim.api.nvim_del_augroup_by_name("lazyvim_highlight_yank")
-- vim.api.nvim_del_augroup_by_name("lazyvim_last_loc")

local aucmd = vim.api.nvim_create_autocmd

local function augroup(name)
  name = "LBS_" .. name
  return vim.api.nvim_create_augroup(name, { clear = true })
end

local augroups = vim.tbl_map(function(name)
  return augroup(name)
end, {
  "Buffer",
  "Cursor",
  "FASD",
  "Fugitive",
  "Help",
  "Keywordprg",
  "Man",
  "Term",
  "Yank",
  "Zen",
  "Formatprg",
  "Quit",
  "Snacks",
  "Untitled",
  "ColorScheme",
  "Lsp",
  "HiGroup",
  "LightBulb",
  "Background",
})

-- Buffer --------------------------------------------------------------- {{{1
aucmd({ "BufWritePre" }, {
  group = augroups.Buffer,
  command = [[%s/\v\s+$//e]],
  desc = "Delete suffix space before writing",
})

-- Auto-save functionality for Neovim buffers.
-- This module implements auto-saving of modified buffers after a specified timeout
-- or upon certain events like losing focus or exiting Neovim.

-- Configuration:
local timeout = 10000 -- Auto-save delay in milliseconds (e.g., 10000ms = 10 seconds)

-- State:
-- Stores active timers, mapping buffer numbers (integers) to libuv timer objects.
local timers = {}

-- Note: The following functions `aucmd` and `augroups.Buffer` are assumed to be
-- defined elsewhere in your Neovim configuration.
-- Example setup:
-- local my_augroup = vim.api.nvim_create_augroup("UserAutoSave", { clear = true })
-- local augroups = { Buffer = my_augroup }
-- local function aucmd(...) vim.api.nvim_create_autocmd(...) end

-- Core save function
-- @param buf integer: The buffer number to save.
local function save(buf)
  -- Use nvim_buf_call to ensure operations are performed in the context of the target buffer.
  -- 'noautocmd update' writes the buffer if modified, without triggering autocommands
  -- (like BufWritePre, BufWritePost), preventing potential save loops.
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("noautocmd update")
  end)
end

-- Autocommand: Schedule auto-save on buffer modification or leaving insert mode.
aucmd({ "InsertLeave", "TextChanged" }, {
  group = augroups.Buffer,
  desc = "Schedule auto-saving for modified buffers",
  callback = function(event)
    local buf = event.buf
    local bo = vim.bo[buf] -- Buffer-local options

    -- Conditions to skip auto-saving:
    -- 1. Buffer has no associated file (unnamed).
    -- 2. Buffer is a special type (e.g., 'nofile', 'quickfix', 'terminal', 'prompt').
    -- 3. Buffer is for a git commit message.
    -- 4. Buffer is read-only.
    -- 5. Buffer has not been modified.
    if
      vim.api.nvim_buf_get_name(buf) == ""
      or bo.buftype ~= ""
      or bo.filetype == "gitcommit"
      or bo.readonly
      or not bo.modified
    then
      return
    end

    local timer = timers[buf]
    -- If an active timer already exists for this buffer, stop it to reset the countdown.
    if timer and timer:is_active() then
      timer:stop()
    end

    -- If no timer exists for this buffer, create a new one.
    if not timer then
      timer = vim.uv.new_timer()
      if not timer then
        vim.notify("AutoSave: Failed to create timer for buffer " .. buf, vim.log.levels.ERROR)
        return
      end
      timers[buf] = timer
    end

    -- Start (or restart) the timer.
    -- It will fire once after 'timeout' milliseconds.
    timer:start(
      timeout,
      0, -- A repeat count of 0 means the timer fires only once.
      vim.schedule_wrap(function() -- Wrap in vim.schedule_wrap for safety from async context.
        -- Before saving, re-check conditions as buffer state might have changed.
        if vim.api.nvim_buf_is_valid(buf) then
          local current_bo = vim.bo[buf] -- Re-fetch buffer options
          if current_bo and current_bo.modified and not current_bo.readonly then
            save(buf)
          end
        end
      end)
    )
  end,
})

-- Autocommand: Save all pending buffers immediately on specific global events.
-- Events:
--   FocusLost: Neovim window loses focus.
--   ExitPre: Before Neovim exits (ensures data is saved).
--   TermEnter: When entering a terminal buffer (often means user is switching tasks).
aucmd({ "FocusLost", "ExitPre", "TermEnter" }, {
  group = augroups.Buffer,
  desc = "Save all modified buffers with pending auto-save timers immediately",
  callback = function()
    for buf, timer in pairs(timers) do
      if vim.api.nvim_buf_is_valid(buf) then
        if timer:is_active() then
          timer:stop() -- Stop the scheduled save.
          local bo = vim.bo[buf]
          -- Save immediately if the buffer is still modified and not read-only.
          if bo and bo.modified and not bo.readonly then
            save(buf)
          end
        end
      else
        -- Buffer is no longer valid, clean up its timer.
        if timer:is_active() then
          timer:stop()
        end
        timer:close()
        timers[buf] = nil
      end
    end
  end,
})

-- Autocommand: Cancel scheduled auto-saving on manual save or entering insert mode.
-- Events:
--   BufWritePost: After a buffer has been successfully written (manual save by user).
--   InsertEnter: When user starts typing (no need to auto-save immediately).
aucmd({ "BufWritePost", "InsertEnter" }, {
  group = augroups.Buffer,
  desc = "Cancel scheduled auto-saving for the current buffer",
  callback = function(event)
    local timer = timers[event.buf]
    if timer and timer:is_active() then
      timer:stop()
    end
  end,
})

-- Autocommand: Clean up timer when a buffer is deleted.
aucmd({ "BufDelete" }, {
  group = augroups.Buffer,
  desc = "Remove and close timer for a deleted buffer",
  callback = function(event)
    local timer = timers[event.buf]
    if timer then
      if timer:is_active() then
        timer:stop()
      end
      timer:close() -- Release libuv resources associated with the timer.
      timers[event.buf] = nil -- Remove the timer from our tracking table.
    end
  end,
})

------------------------------------------------------------------------ }}}

-- Zen mode related ----------------------------------------------------- {{{1
local function process_win(win)
  local winnr = vim.fn.win_id2win(win)
  if winnr == 0 then
    return
  end

  local ww = vim.api.nvim_win_get_width(win)
  local bufnr = vim.api.nvim_win_get_buf(win)
  local _, zen_oriwin = pcall(vim.api.nvim_buf_get_var, bufnr, "zen_oriwin")

  if vim.bo[bufnr].syntax == "rbrowser" then
    if ww <= 30 then
      return
    end
    vim.cmd("vertical " .. winnr .. "resize 30")
    return "break"
  end

  if vim.g.lbs_zen_mode then
    if ww <= 88 then
      vim.wo[win].signcolumn = "auto:1"
    elseif ww <= 100 then
      vim.wo[win].signcolumn = "yes:4"
    else
      vim.wo[win].signcolumn = "yes:" .. math.min(math.floor((ww - 81) / 4), 6)
    end
  elseif zen_oriwin and type(zen_oriwin) == "table" and zen_oriwin.zenmode then
    if ww <= 88 then
      vim.wo[win].signcolumn = "auto:1"
    elseif ww <= 100 then
      vim.wo[win].signcolumn = "yes:4"
    else
      vim.wo[win].signcolumn = "yes:" .. math.min(math.floor((ww - 81) / 4), 9)
    end
  else
    if ww <= 40 then
      vim.wo[win].signcolumn = "no"
      vim.wo[win].foldcolumn = "0"
    else
      vim.wo[win].signcolumn = "auto:1"
      vim.wo[win].foldcolumn = vim.o.foldcolumn
    end
  end
end

aucmd({ "WinResized" }, {
  group = augroups.Zen,
  callback = function(_)
    local event_related_windows = vim.v.event.windows
    if not event_related_windows or #event_related_windows == 0 then
      return
    end
    local windows = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ""
        or (
          vim.g.lbs_zen_mode
          and vim.api.nvim_get_option_value("buftype", { buf = vim.api.nvim_win_get_buf(win) }) == ""
        )
    end, event_related_windows)
    for _, win in ipairs(windows) do
      local rc = process_win(win)
      if rc == "break" then
        return
      end
    end
  end,
})

aucmd({ "BufWinEnter", "BufRead", "BufEnter" }, {
  group = augroups.Zen,
  callback = function(ev)
    local bufnr = ev.buf
    local winid = vim.fn.bufwinid(bufnr)
    if winid == -1 or vim.api.nvim_win_get_config(winid).zindex then
      return
    end
    local win_attr = vim.api.nvim_win_get_config(winid)

    local zen_oriwin = vim.b[bufnr].zen_oriwin
    local is_zen_buffer = zen_oriwin and zen_oriwin.zenmode
    local is_zen_window = vim.w[winid].zen_mode
    local _, lualine = pcall(require, "lualine")

    if is_zen_window and is_zen_buffer then
      vim.go.showtabline = 0
      vim.go.laststatus = 0
      ---@diagnostic disable: missing-fields
      if lualine then
        lualine.hide({})
      end
      return
    end

    if not is_zen_buffer and not is_zen_window then
      vim.go.showtabline = vim.g.showtabline or 1
      vim.go.laststatus = vim.g.laststatus or 3
      ---@diagnostic disable: missing-fields
      if lualine then
        lualine.hide({ unhide = true })
      end
      return
    end

    if is_zen_buffer then
      vim.fn["utils#ZenMode_Insert"](false)
    else
      vim.fn["utils#ZenMode_Leave"](false)
      vim.go.showtabline = vim.g.showtabline or 1
      vim.go.laststatus = vim.g.laststatus or 3
    end
  end,
})

-- Keywordprg ----------------------------------------------------------- {{{1
local function show_document(ft)
  local keyword = vim.fn.expand("<cword>")
  if vim.tbl_contains({ "vim", "help" }, ft) then
    vim.cmd.help(keyword)
  elseif vim.tbl_contains({ "perl", "perldoc" }, ft) then
    vim.cmd.Perldoc(keyword)
  elseif vim.tbl_contains({ "stata", "statadoc" }, ft) then
    vim.cmd.Shelp(keyword)
  elseif vim.tbl_contains({ "r", "quarto", "rdoc", "rmd" }, ft) then
    if vim.g.R_Nvim_status and vim.g.R_Nvim_status == 7 then
      vim.cmd.RHelp(keyword)
    else
      vim.cmd.Rdoc(keyword)
    end
  else
  end
end
aucmd({ "FileType" }, {
  group = augroups.Keywordprg,
  pattern = { "perl", "perldoc", "vim", "help", "stata", "statadoc", "r", "quarto", "rdoc" },
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    vim.keymap.set("n", "gk", function()
      show_document(ft)
    end, {
      desc = "Show Document",
      buffer = ev.buf,
    })
  end,
})

-- Fasd Update ---------------------------------------------------------- {{{1
aucmd({ "BufNew", "BufNewFile" }, {
  group = augroups.FASD,
  callback = function(ev)
    if (vim.bo[ev.buf].buftype == "" or vim.bo[ev.buf].filetype == "dirvish") and ev.file ~= "" then
      vim.system({ "fasd", "-A", ev.file })
    end
  end,
})

-- cursorline ----------------------------------------------------------- {{{1
-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/autocmd.lua
aucmd({ "InsertEnter", "WinLeave", "BufLeave" }, {
  group = augroups.Cursor,
  command = "if &cursorline && ! &pvw | setlocal nocursorline | endif",
})

aucmd({ "InsertLeave", "WinEnter", "BufEnter" }, {
  group = augroups.Cursor,
  command = "if ! &cursorline && ! &pvw | setlocal cursorline | endif",
})

-- Term Open ------------------------------------------------------------ {{{1
aucmd({ "TermOpen" }, {
  group = augroups.Term,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.bufhidden = "hide"
    vim.opt_local.foldcolumn = "0"
  end,
})

-- Highlight on yank ---------------------------------------------------- {{{1
aucmd("InsertEnter", {
  group = augroups.Yank,
  callback = function()
    vim.schedule(function()
      vim.cmd("nohlsearch")
    end)
  end,
})

aucmd("CursorMoved", {
  group = augroups.Yank,
  callback = function()
    if vim.v.hlsearch == 1 and vim.fn.searchcount().exact_match == 0 then
      vim.schedule(function()
        vim.cmd.nohlsearch()
      end)
    end
  end,
})

-- make it easier to close man-files when opened inline ----------------- {{{1
aucmd("FileType", {
  group = augroups.Man,
  pattern = { "man" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- auto-delete fugitive buffers ----------------------------------------- {{{1
-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/autocmd.lua
aucmd("BufReadPost", {
  group = augroups.Fugitive,
  pattern = "fugitive:*",
  command = "set bufhidden=delete",
})

-- Display help|man in vertical splits and map 'q' to quit -------------- {{{1
-- https://github.com/ibhagwan/nvim-lua/blob/main/lua/autocmd.lua
local function open_vert()
  -- do nothing for floating windows or if this is
  -- the fzf-lua minimized help window (height=1)
  local cfg = vim.api.nvim_win_get_config(0)
  if cfg and (cfg.external or cfg.relative and #cfg.relative > 0) or vim.api.nvim_win_get_height(0) == 1 then
    return
  end
  -- do not run if Diffview is open
  if vim.g.diffview_nvim_loaded and require("diffview.lib").get_current_view() then
    return
  end
  vim.cmd("wincmd L")
  -- local width = math.floor(vim.o.columns * 0.75)
  -- vim.cmd("vertical resize " .. width)
  vim.keymap.set("n", "q", "<CMD>q<CR>", { buffer = true })
end

aucmd("FileType", {
  group = augroups.Help,
  pattern = "help,man",
  callback = open_vert,
})

-- we also need this auto command or help
-- still opens in a split on subsequent opens
aucmd("BufNew", {
  group = augroups.Help,
  pattern = { "*.txt", "*.cnx", "*.md" },
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "help" then
      open_vert()
    end
  end,
})

aucmd("BufHidden", {
  group = augroups.Help,
  pattern = "man://*",
  callback = function()
    if vim.bo.filetype == "man" then
      local bufnr = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end, 0)
    end
  end,
})

-- ColorScheme ---------------------------------------------------------- {{{1
vim.api.nvim_create_autocmd({ "ColorScheme" }, {
  pattern = "*",
  group = augroups.ColorScheme,
  callback = function()
    vim.cmd([[
      " 用于实现弹出窗口背景透明
      highlight VertSplit      cterm=None gui=None guibg=bg
      highlight FoldColumn     guibg=bg
      highlight Folded         gui=bold guifg=LightGreen guibg=bg
      highlight SignColumn     guibg=bg
      highlight LineNr         guibg=bg
      highlight NormalFloat    guibg=NONE
      highlight FloatBorder    guibg=NONE
      highlight FloatTitle     guibg=NONE
      highlight DiagnosticSignInfo guibg=NONE
      highlight DiagnosticSignHint guibg=NONE
      highlight DiagnosticSignWarn guibg=NONE
      highlight DiagnosticSignError guibg=NONE
    ]])
  end,
  desc = "remove unnecessary background",
})

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
  pattern = "*",
  group = augroups.ColorScheme,
  callback = function()
    require("util.ui").adjust_hi_group()
  end,
  desc = "Define personal highlight group",
})

-- Untitled file -------------------------------------------------------- {{{1
-- 退出 Neovim 时，忽略未保存的 Untitled buffer 对退出进程的干扰
vim.api.nvim_create_autocmd({ "QuitPre" }, {
  group = augroups.Quit,
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      -- 检查缓冲区是否已加载并且没有文件名
      if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == "" then
        vim.bo[buf].modified = false
      end
    end
  end,
})

-- Formatprg --------------------------------------------------------------- {{{1
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "newsboat", "quarto", "rmarkdown" },
  group = augroups.Formatprg,
  callback = function(ev)
    vim.bo[ev.buf].formatexpr = nil
    vim.bo[ev.buf].formatprg = vim.b[ev.buf].filetype == "newsboat" and "mdwrap --tonewsboat" or "mdwrap"
  end,
})

-- Lsp ------------------------------------------------------------------ {{{1
--- Restarts LSP clients for a buffer after it has been renamed.
-- This is useful after commands like `:saveas` or `:file new_name`, which
-- can confuse LSP servers that track files by their path.
local function restart_lsp_on_rename(args)
  local bufnr = args.buf

  -- Ensure the buffer is still valid before proceeding.
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Get all active LSP clients attached to the buffer.
  -- `get_active_clients` is the modern and recommended function.
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  -- If there are no clients to restart, do nothing.
  if #clients == 0 then
    return
  end

  vim.notify("Buffer renamed, restarting LSP clients...", vim.log.levels.INFO, {
    title = "LSP",
  })

  -- Detach and then schedule a re-attachment for each client.
  -- `vim.schedule` ensures re-attachment happens in the next event loop tick,
  -- preventing potential race conditions.
  for _, client in ipairs(clients) do
    -- codecompanion-history 的自动设置标题功能因调用 `vim.api.nvim_buf_set_name()`
    -- 会导致 `rime_ls` 失效，需要先 detach 再 attach rime_ls
    -- 其实也会导致其他 lsp 失效，但由于 codecompanion 下启用的 lsp 通常只有 rime_ls
    -- 为了避免影响扩散，现在只处理 rime_ls
    if client.name ~= "rime_ls" then
      return
    end
    vim.lsp.buf_detach_client(bufnr, client.id)
    vim.schedule(function()
      vim.lsp.buf_attach_client(bufnr, client.id)
    end)
  end
end

-- Create an autocommand that triggers on buffer rename events.
-- This assumes `augroups.Lsp` is an augroup created elsewhere in your config.
vim.api.nvim_create_autocmd("BufFilePost", {
  group = augroups.Lsp,
  pattern = "*",
  callback = restart_lsp_on_rename,
  desc = "Restart LSP clients on buffer rename.",
})

-- Roxygen2 hililight --------------------------------------------------- {{{2
local r_higroup = require("rlib.higroup")
vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  pattern = "r",
  group = augroups.HiGroup,
  callback = function()
    -- 进入文件时，对整个文件进行一次完整扫描
    r_higroup.highlight_roxygen_tags(vim.api.nvim_get_current_buf(), 0, -1)
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved" }, {
  pattern = "r",
  group = augroups.HiGroup,
  -- 编辑和移动时，调用防抖的、只扫描可视区域的函数
  callback = r_higroup.schedule_viewport_highlight,
})

-- lightbulb ------------------------------------------------------------ {{{1
-- Show a lightbulb when code actions are available at the cursor
-- from: https://github.com/rockyzhang24/dotfiles/blob/master/.config/nvim/lua/rockyz/lsp/lightbulb.lua
-- Like VSCode, the lightbulb is displayed at the beginning (the first column) of the same line, or
-- the previous line if the space is not enough.
--
-- This is implemented by using window-local extmark
local bulb_icon = ""

local method = "textDocument/codeAction"

local opts = {
  virt_text = {
    { bulb_icon .. " ", "LightBulb" },
  },
  hl_mode = "combine",
  virt_text_win_col = 0,
}

-- Get the line number where the bulb should be displayed
local function get_bulb_linenr()
  local linenr = vim.fn.line(".")
  if vim.fn.indent(".") <= 2 then
    if linenr == vim.fn.line("w0") then
      return linenr + 1
    else
      return linenr - 1
    end
  end
  return linenr
end

-- Remove the lightbulb
local function lightbulb_remove(winid, bufnr)
  if
    not vim.api.nvim_win_is_valid(winid)
    or not vim.api.nvim_buf_is_valid(bufnr)
    or vim.w[winid].bulb_ns_id == nil and vim.w[winid].bulb_mark_id == nil
  then
    return
  end
  vim.api.nvim_buf_del_extmark(bufnr, vim.w[winid].bulb_ns_id, vim.w[winid].bulb_mark_id)
  vim.w[winid].prev_bulb_linenr = nil
end

-- Create or update the lightbulb
local function lightbulb_update(winid, bufnr, bulb_linenr)
  -- No need to update the bulb if its position does not change
  if not vim.api.nvim_win_is_valid(winid) or bulb_linenr == vim.w[winid].prev_bulb_linenr then
    return
  end
  -- Create a window-local namespace for the extmark
  if vim.w[winid].bulb_ns_id == nil then
    local ns_id = vim.api.nvim_create_namespace("rockyz.bulb." .. winid)
    vim.api.nvim__ns_set(ns_id, { wins = { winid } })
    vim.w[winid].bulb_ns_id = ns_id
  end
  -- Create an extmark or update the existing one
  if vim.w[winid].bulb_mark_id == nil then
    vim.w[winid].bulb_mark_id = vim.api.nvim_buf_set_extmark(bufnr, vim.w[winid].bulb_ns_id, bulb_linenr, 0, opts)
    vim.w[winid].bulb_mark_opts = vim.tbl_extend("keep", opts, {
      id = vim.w[winid].bulb_mark_id,
    })
  else
    vim.api.nvim_buf_set_extmark(bufnr, vim.w[winid].bulb_ns_id, bulb_linenr, 0, vim.w[winid].bulb_mark_opts)
  end
  vim.w[winid].prev_bulb_linenr = bulb_linenr
end

local function lightbulb()
  -- Don't display the bulb in diff window
  if vim.wo.diff then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local bulb_linenr = get_bulb_linenr() - 1 -- 0-based for extmark
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
  local has_action = false
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  local cursor_lnum = cursor_row - 1 -- 0-indexed

  for _, client in ipairs(clients) do
    local context = {}
    -- For each client, only retrieve the diagnostics that belong to it. They are the ones that are
    -- pushed to this client by the server and ones this client pulls from the server.
    -- NOTE: Diagnostics returned by vim.diagnostic.get() are vim.Diagnostics[].
    local ns_push = vim.lsp.diagnostic.get_namespace(client.id, false)
    local ns_pull = vim.lsp.diagnostic.get_namespace(client.id, true)
    local diagnostics = {}
    vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_pull }))
    vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_push }))

    -- Fetch lsp diagnostics (lsp.Diagnostics[]) that only overlaps the cursor position
    context.diagnostics = vim
      .iter(diagnostics)
      :map(function(d)
        --
        -- After the client receives diagnostics (lsp.Diagnostics[]) from the server, each lsp
        -- diagnostic gets converted to vim diagnostic (vim.Diagnostics[]) and then catched. In the
        -- conversion, the original lsp diagnostic is stored in diagnostic.user_data.lsp.
        -- Reference: handle_diagnostics() in
        -- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/diagnostic.lua
        --
        -- Now we need the lsp diagnostics and use them to request code actions. We just need to fetch
        -- them from vim diagnostic's user_data.lsp.
        -- Reference: code_action() in
        -- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/buf.lua
        --
        if
          (d.lnum < cursor_lnum or d.lnum == cursor_lnum and d.col <= cursor_col)
          and (d.end_lnum > cursor_lnum or d.end_lnum == cursor_lnum and d.end_col > cursor_col)
        then
          return d.user_data.lsp
        end
      end)
      :totable()

    local params = vim.lsp.util.make_range_params(winid, client.offset_encoding)
    params.context = context

    client:request(method, params, function(_, result, _)
      if has_action then
        return
      end
      for _, action in pairs(result or {}) do
        if action then
          has_action = true
        end
      end
      if has_action and bulb_linenr < vim.fn.line("$") then
        lightbulb_update(winid, bufnr, bulb_linenr)
      else
        lightbulb_remove(winid, bufnr)
      end
    end, bufnr)
  end
end

vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = augroups.lightbulb,
  callback = lightbulb,
})

--- background ---------------------------------------------------------- {{{2
-- Optimized function to get the first word from the background cache file
-- Uses more efficient file handling and error checking
local function fetch_terminal_background()
  local file_path = os.getenv("TERM_BACKGROUND_CACHE")
  if not file_path then
    return nil
  end

  local file, err = io.open(file_path, "r")
  if not file then
    -- Log error if needed: print("Error opening file: " .. err)
    return nil
  end

  -- Read the first line efficiently
  local line = file:read("*l")
  file:close()

  if not line then
    return nil
  end

  -- Extract the first word using pattern matching
  local first_word = line:match("%S+")
  return first_word
end

vim.api.nvim_create_autocmd("TermResponse", {
  group = augroups.Background,
  callback = function(ev)
    if ev.data and ev.data.sequence and ev.data.sequence:find("^%\27%]11;rgb") then
      local term_background = fetch_terminal_background()
      if not term_background or not vim.tbl_contains({ "dark", "light" }, term_background) then
        return
      end
      local current_background = vim.api.nvim_get_option_value("background", { scope = "global" })
      if term_background == current_background then
        return
      end
      vim.schedule(function()
        vim.api.nvim_set_option_value("background", term_background, { scope = "global" })
        vim.cmd.colorscheme(vim.g.default_colorscheme[term_background])
        require("lualine").setup({})
      end)
    end
  end,
})

-- external
-- region yank
require("reg_yank")
