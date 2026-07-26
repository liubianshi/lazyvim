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

local lbs_zen = require("lbs.zen")
local lbs_theme = require("lbs.theme")
local lbs_lsp = require("lbs.lsp")
local aucmd = vim.api.nvim_create_autocmd

local function augroup(name)
  name = "LBS_" .. name
  return vim.api.nvim_create_augroup(name, { clear = true })
end

-- 以名字为键的 augroup 表：augroups.Buffer / augroups.SmartCR 等。
-- 注意：不能用 vim.tbl_map(fn, {...})，它会保留输入列表的整数键，导致
-- 按名字索引（augroups.Buffer）恒为 nil，使所有 autocmd 实际「无 group」。
local augroups = {}
for _, name in ipairs({
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
  "ColorScheme",
  "Lsp",
  "HiGroup",
  "Background",
  "SmartCR",
}) do
  augroups[name] = augroup(name)
end

-- Buffer --------------------------------------------------------------- {{{1
aucmd({ "BufWritePre" }, {
  group = augroups.Buffer,
  command = [[%s/\v\s+$//e]],
  desc = "Delete suffix space before writing",
})

-- Auto-save function
require("util.autosave").setup()

------------------------------------------------------------------------ }}}

-- Zen mode related ----------------------------------------------------- {{{1
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
      local rc = lbs_zen.process_win(win)
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
  callback = function(ev)
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.bufhidden = "hide"
    vim.opt_local.foldcolumn = "0"
  end,
})

-- IM Switch ------------------------------------------------------------- {{{1
-- 延迟初始化输入法自动切换模块
vim.schedule(function()
  require("util.im_switch").setup()
end)

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
  pattern = { "newsboat", "quarto", "rmarkdown", "markdown" },
  group = augroups.Formatprg,
  callback = function(ev)
    vim.bo[ev.buf].formatexpr = nil
    vim.bo[ev.buf].formatprg = vim.b[ev.buf].filetype == "newsboat" and "mdwrap --tonewsboat" or "mdwrap -w 70"
  end,
})

-- Lsp ------------------------------------------------------------------ {{{1
-- Create an autocommand that triggers on buffer rename events.
-- This assumes `augroups.Lsp` is an augroup created elsewhere in your config.
vim.api.nvim_create_autocmd("BufFilePost", {
  group = augroups.Lsp,
  pattern = "*",
  callback = lbs_lsp.restart_on_rename,
  desc = "Restart LSP clients on buffer rename.",
})

-- Guard: coerce any *function* `client.root_dir` into a resolved string.
-- `vim.lsp.enable` resolves a function root_dir via `on_dir` before the client
-- is created, but `vim.lsp.start` (lsp.lua:740) does NOT — it copies the
-- function straight into `client.root_dir`. LazyVim's root detector / lualine
-- then call `vim.fs.normalize` on it and crash with
-- "attempt to index local 'path' (a function value)" on every statusline
-- refresh. We re-run the function form (signature `fun(bufnr, on_dir)`),
-- capturing the synchronous `on_dir` result, and fall back to nil so the
-- string-expecting consumers always see a string or nil.
vim.api.nvim_create_autocmd("LspAttach", {
  group = augroups.Lsp,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    if type(client.root_dir) == "function" then
      local resolved
      pcall(client.root_dir, ev.buf, function(dir)
        resolved = dir
      end)
      client.root_dir = type(resolved) == "string" and resolved or nil
    end
    if client.config and type(client.config.root_dir) == "function" then
      client.config.root_dir = client.root_dir
    end
  end,
  desc = "Resolve function root_dir to prevent LazyVim/lualine root crash.",
})

-- Roxygen2 highlight --------------------------------------------------- {{{2
local r_higroup = require("lbs.r.higroup")
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
require("util.lightbulb").setup()

--- background ---------------------------------------------------------- {{{2
lbs_theme.enable_dec2031()

vim.api.nvim_create_autocmd("TermResponse", {
  group = augroups.Background,
  callback = function(ev)
    local seq = ev.data and ev.data.sequence
    if not seq then
      return
    end
    if seq:find("^\27%]11;rgb") then
      lbs_theme.apply_background(lbs_theme.osc11_to_background(seq))
    elseif seq:find("^\27%[%?2031;[12]n") then
      lbs_theme.apply_background(seq:find(";1n", 1, true) and "dark" or "light")
    end
  end,
})

-- SmartCR ------------------------------------------------------------- {{{1
-- 在 markdown 类 buffer 注册「智能回车」悬挂缩进映射。
--   FileType   : 覆盖有 filetype 的 buffer（含 codecompanion_input）。
--   BufWinEnter: 兜底 TS 延迟解析，以及从不触发 FileType 的空 ft scratch buffer。
aucmd({ "FileType", "BufWinEnter" }, {
  group = augroups.SmartCR,
  pattern = "*",
  callback = function(ev)
    local smart_cr = require("util.smart_cr")
    if smart_cr.should_attach(ev.buf) then
      smart_cr.attach(ev.buf)
    end
  end,
  desc = "Attach Smart CR (markdown hanging indent) on eligible buffers",
})

-- external
-- region yank
require("lbs.reg_yank")
