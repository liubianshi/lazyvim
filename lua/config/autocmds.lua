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
})

-- Buffer --------------------------------------------------------------- {{{1
aucmd({ "BufWritePre" }, {
  group = augroups.Buffer,
  command = [[%s/\v\s+$//e]],
  desc = "Delete suffix space before writing",
})

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
    local windows = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ""
        or (
          vim.g.lbs_zen_mode
          and vim.api.nvim_get_option_value("buftype", { buf = vim.api.nvim_win_get_buf(win) }) == ""
        )
    end, vim.v.event.windows)
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
aucmd({ "FileType" }, {
  group = augroups.Keywordprg,
  pattern = { "perl", "perldoc" },
  callback = function(ev)
    vim.bo[ev.buf].keywordprg = ":Perldoc"
  end,
})
aucmd({ "FileType" }, {
  group = augroups.Keywordprg,
  pattern = { "stata", "statadoc" },
  callback = function(ev)
    vim.bo[ev.buf].keywordprg = ":Shelp"
  end,
})
aucmd({ "FileType" }, {
  group = augroups.Keywordprg,
  pattern = { "man", "sh", "bash" },
  callback = function(ev)
    vim.bo[ev.buf].keywordprg = ":Man"
  end,
})
aucmd({ "FileType" }, {
  group = augroups.Keywordprg,
  pattern = { "r", "rmd", "rdoc" },
  callback = function(ev)
    if vim.g.R_Nvim_status and vim.g.R_Nvim_status == 7 then
      vim.bo[ev.buf].keywordprg = ":RHelp"
    else
      vim.bo[ev.buf].keywordprg = ":Rdoc"
    end
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
    -- 解决 vim 帮助文件的示例代码的不够突显的问题
    vim.cmd("hi def link helpExample Special")
    if vim.fn.exists("g:neovide") == 1 then
      vim.cmd("highlight MyBorder guifg=bg guibg=NONE")
    else
      vim.cmd("highlight MyBorder guifg=" .. vim.g.lbs_colors.orange .. " guibg=NONE")
    end
    vim.cmd("highlight DiagnosticSignInfo guibg=NONE")
    -- Setting the color scheme of the Complement window
    local pallete = {
      background = vim.g.lbs_colors.yellow,
      fg = vim.g.lbs_colors.darkblue,
      strong = vim.g.lbs_colors.red,
    }
    if vim.o.background == "dark" then
      pallete = {
        background = vim.g.lbs_colors.darkblue,
        fg = vim.g.lbs_colors.fg_float,
        strong = vim.g.lbs_colors.red,
      }
    end

    vim.cmd("highlight MyPmenu guibg=" .. pallete.background)
    vim.cmd("highlight CmpItemAbbr guifg=" .. pallete.fg)
    vim.cmd("highlight CmpItemAbbrMatch guifg=" .. pallete.strong)
    vim.cmd("highlight MsgSeparator guibg=bg guifg=" .. pallete.strong)
    vim.cmd("highlight ObsidianHighlightText guifg=" .. pallete.strong)
    vim.cmd("highlight @markdown.strong gui=underline")
    vim.cmd("highlight @markup.raw.markdown_inline guibg=NONE")

    vim.cmd.highlight("link IndentLine LineNr")
    vim.cmd.highlight("IndentLineCurrent guifg=" .. vim.g.lbs_colors.orange)
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
