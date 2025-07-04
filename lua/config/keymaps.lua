local keymap = require("util").keymap
local vimkey = function(key, desc, cmd, opts)
  local mapping = vim.tbl_extend("keep", opts or {}, {
    key,
    cmd,
    mode = "n",
    desc = desc,
    silent = true,
    noremap = true,
  })
  keymap(mapping)
end
local nmap = vimkey
local function imap(key, desc, cmd, opts)
  opts = opts or {}
  opts.mode = "i"
  vimkey(key, desc, cmd, opts)
end
local function tmap(key, desc, cmd, opts)
  opts = opts or {}
  opts.mode = "t"
  vimkey(key, desc, cmd, opts)
end
local function vmap(key, desc, cmd, opts)
  opts = opts or {}
  opts.mode = "v"
  vimkey(key, desc, cmd, opts)
end

-- Register ------------------------------------------------------------- {{{1
vimkey("c", "Change text without putting it into register", '"_c', {
  mode = { "n", "x" },
})

-- Navigation ----------------------------------------------------------- {{{1
nmap("j", "Display line downwards", "gj")
nmap("k", "Display line upwards", "gk")
vmap("j", "Display line downwards", "gj")
vmap("k", "Display line upwards", "gk")
vmap("<", "Shift selection line leftwords", "<gv")
vmap(">", "Shift selection line rightwords", ">gv")
nmap("]b", "bnext", "<cmd>bnext<cr>")
nmap("[b", "bprevious", "<cmd>bprevious<cr>")
nmap("]B", "blast", "<cmd>blast<cr>")
nmap("[B", "bfirst", "<cmd>bfirst<cr>")
nmap("]t", "tabnext", "<cmd>tabnext<cr>")
nmap("[t", "tabprevious", "<cmd>tabprevious<cr>")
nmap("]T", "tablast", "<cmd>tablast<cr>")
nmap("[T", "tabfirst", "<cmd>tabfirst<cr>")
imap(";a", "Goto end of line", "<esc>A")
imap(
  ";<enter>",
  "Wrap line before punctuation",
  '<esc>?\\v[,.:?")，。)，。：》”；？、」） ]<cr>:noh<cr>a<enter><esc>`^A'
)
nmap("<A-M>", "Shift cursor To:", "<cmd>call utils#ShiftLine(line('.') + 1, col('.') - 1)<cr>")
imap("<A-M>", "Move cursor to:", "<esc>:call utils#MoveCursorTo('')<cr>a")
vimkey("<A-m>", "Move cursor To:", "<cmd>call utils#MoveCursorTo()<cr>", { mode = { "n", "i" } })

-- Visual mode pressing * or # searches for the current selection --------- {{{1
vmap("*", "searches for the current selection", ":<C-u>call utils#VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>")

-- Fold and add symbol -------------------------------------------------- {{{1
nmap("<leader>z-", "Add - as seporator with Fold marker", '<cmd>call utils#AddFoldMark("-")<cr>')
nmap("<leader>z=", "Add = as seporator with Fold marker", '<cmd>call utils#AddFoldMark("=")<cr>')
nmap("<leader>z.", "Add . as seporator with Fold marker", '<cmd>call utils#AddFoldMark(".")<cr>')
nmap("<leader>z*", "Add * as seporator with Fold marker", '<cmd>call utils#AddFoldMark("*")<cr>')
nmap("<leader>a-", "Add - as seporator", '<cmd>call utils#AddDash("-")<cr>')
nmap("<leader>a=", "Add = as seporator", '<cmd>call utils#AddDash("=")<cr>')
nmap("<leader>a.", "Add . as seporator", '<cmd>call utils#AddDash(".")<cr>')
nmap("<leader>a*", "Add * as seporator", '<cmd>call utils#AddDash("*")<cr>')
nmap("<leader>zf", "Add Fold Marker", "g_a <esc>3a{<esc>")
nmap("<leader>z1", "Add Fold Marker 1", "g_a <esc>3a{<esc>a1<esc>")
nmap("<leader>z2", "Add Fold Marker 2", "g_a <esc>3a{<esc>a2<esc>")
nmap("<leader>z3", "Add Fold Marker 3", "g_a <esc>3a{<esc>a3<esc>")

-- diff ----------------------------------------------------------------- {{{1
keymap({ "<leader>d", group = "Diff", icon = { icon = "", hl = "WhichKeyIconOrange" } })
nmap("<leader>dl", "Diffget Local", "<cmd>diffget LOCAL<cr>:diffupdate<cr>")
nmap("<leader>dr", "Diffget Remote", "<cmd>diffget REMOTE<cr>:diffupdate<cr>")

--- run ------------------------------------------------------------------ {{{1
nmap("<leader>o:", "Open Terminal", "<cmd>ToggleTerm<cr>")
nmap("<leader>ob", "Toggle Status Line", "<cmd>call utils#Status()<cr>")
nmap("<leader>od", "Source VIMRC", "<cmd>source $MYVIMRC<cr>")
nmap("<leader>op", "Change to Directory File Located ", function()
  vim.cmd("cd " .. vim.fn.expand("%:p:h"))
end)
nmap("<leader>oz", "Toggle Zen Mode (diy)", "<cmd>call utils#ToggleZenMode()<cr>")
nmap("<leader><enter>", "Redraw / Clear hlsearch / Diff Update", "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>")

--- buffer --------------------------------------------------------------- {{{1
-- nmap("<leader>bd", "Delete Buffer",             "<cmd>Bclose<cr>")
nmap("<leader>bD", "Delete Buffer (force)", "<cmd>Bclose!<cr>")
nmap("<leader>bp", "Previous Buffer", "<cmd>bp<cr>")
nmap("<leader>bn", "Next Buffer", "<cmd>bn<cr>")
nmap("<leader>bq", "Quit Buffer", "<cmd>q<cr>")
nmap("<leader>bQ", "Quit Buffer (force)", "<cmd>q!<cr>")
nmap("<leader>bl", "Pick Buffer on BufferLine", "<cmd>BufferLinePick<cr>")
nmap("<leader>bF", "Close Float buffer", "<cmd>fclose<cr>")

--- search -------------------------------------------------------------- {{{1
nmap("<leader>og", "Display Highlight Group", function()
  vim.fn["utils#Extract_hl_group_link"]()
end)

--- insert special symbol ----------------------------------------------- {{{1
imap("<localleader><space>", "Semicolons: ;", ";")
imap("<localleader>0", "Special Symbol: zero-width spaces", "<C-v>u200b")
imap("<localleader>)", "Chinese Punctuation: （I）", "<C-v>uFF08 <C-v>uFF09<C-o>F <c-o>x")
imap("<localleader>]", "Chinese Punctuation: 「I」", "<C-v>u300c <C-v>u300d<C-o>F <c-o>x")
imap("<localleader>}", "Chinese Punctuation: “I”", "<C-v>u201C <C-v>u201D<C-o>F <c-o>x")
imap("<localleader>'", "Chinese Punctuation: 「", "<C-v>u300c")
imap('<localleader>"', "Chinese Punctuation: 」", "<C-v>u300d")
imap("<localleader>,", "Chinese Punctuation: ，", "<C-v>uFF0C")
imap("<localleader>.", "Chinese Punctuation: 。", "<C-v>u3002")
imap("<localleader>\\", "Chinese Punctuation: 、", "<C-v>u3001")
imap("<localleader>:", "Chinese Punctuation: ：", "<C-v>uff1a")
imap("<localleader>/", "Chinese Punctuation: ；", "<C-v>uff1b")
imap("<localleader>_", "Chinese Punctuation: ——", "<C-v>u2014<c-v>u2014")
imap("<localleader>^", "Chinese Punctuation: ……", "<C-v>u2026<c-v>u2026")
imap("<localleader>?", "Special Punctuation: ？", "<C-v>uff1f")
imap("<localleader>-", "Special Punctuation: —", "<C-v>u2014")

--- window manager ------------------------------------------------------ {{{1
nmap("w0", "Window: Suitable Width", "<cmd>88wincmd |<cr>")
nmap("wt", "Move Current Window to a New Tab", "<cmd>wincmd T<cr>")
nmap("wo", "Make current window the only one", "<cmd>only<cr>")
nmap("wv", "Vertical Split Current Buffer", "<c-w>v")
nmap("ws", "Split Current Buffer", "<c-w>s")
-- nmap("ww",    "Move cursor to window below/right", "<c-w>w")
-- nmap("wW",    "Move cursor to window above/left",  "<c-w>W")
nmap("wf", "Goto Float Buffer", function()
  local popup_win_id = require("util.ui").get_highest_zindex_win()
  if not popup_win_id then
    return
  end
  vim.fn.win_gotoid(popup_win_id)
end)
nmap("wF", "Close Float Buffer", "<cmd>fclose<cr>")
nmap("wh", "Move cursor to window left", "<c-w>h")
nmap("wj", "Move cursor to window below", "<c-w>j")
nmap("wk", "Move cursor to window above", "<c-w>k")
nmap("wl", "Move cursor to window right", "<c-w>l")
nmap("wH", "Move current window left", "<c-w>H")
nmap("wJ", "Move current window below", "<c-w>J")
nmap("wK", "Move current window above", "<c-w>K")
nmap("wL", "Move current window right", "<c-w>L")
nmap("wx", "Exchange window", "<c-w>x")
nmap("wq", "Quit the current window", "<c-w>q")
nmap("w=", "Make Window size equally", "<c-w>=")
nmap("<c-j>", "resize -2", "<cmd>resize -2<cr>")
nmap("<c-k>", "resize +2", "<cmd>resize +2<cr>", { remap = true })
nmap("<c-h>", "vertical resize -2", "<cmd>vertical resize -2<cr>")
nmap("<c-l>", "vertical resize +2", "<cmd>vertical resize +2<cr>")

--- edit special files -------------------------------------------------- {{{1
nmap("<leader>ev", "Neovim Plugin List", "<cmd>Oil ~/.config/nvim/lua/plugins<cr>")
nmap("<leader>ek", "Neovim Keymap", "<cmd>edit ~/.config/nvim/lua/config/keymaps.lua<cr>")
nmap("<leader>ea", "Neovim Keymap", "<cmd>edit ~/.config/nvim/lua/config/autocmds.lua<cr>")
nmap("<leader>eo", "Neovim Options", "<cmd>edit ~/.config/nvim/lua/config/options.lua<cr>")
nmap("<leader>ef", "Neovim Options", "<cmd>edit ~/.config/nvim/lua/global_functions.lua<cr>")
nmap("<leader>er", "R Profile", "<cmd>edit ~/.Rprofile<cr>")
nmap("<leader>es", "Stata profile", "<cmd>edit ~/.config/stata/profile.do<cr>")
nmap("<leader>ez", "Zshrc", "<cmd>edit ~/.zshrc<cr>")
nmap("<leader>eZ", "User Zshrc", "<cmd>edit ~/useScript/usr.zshrc<cr>")
nmap("<leader>eu", "Snippets", "<cmd>edit ~/.config/nvim/UltiSnips<cr>")
nmap("<leader>et", "Open Plan to Do", "<cmd>edit +ToggleZenMode ~/Documents/Writing/plantodo.norg<cr>zt")
nmap("<leader>eT", "Open Plan to Do", "<cmd>edit +$ ~/Documents/Writing/todo.norg<cr>zt")
nmap("<leader>ew", "Open Daily Englist", function()
  vim.cmd("edit " .. require("util").get_daily_filepath("md", "ReciteWords"))
end)

--- Teminal ------------------------------------------------------------- {{{1
local newterm = function(direction)
  local Terminal = require("toggleterm.terminal").Terminal
  Terminal:new({ direction = direction }):toggle()
end
nmap("<space><space>v", "Toggle Terminal vertical", "<cmd>ToggleTerm direction=vertical<cr>")
nmap("<space><space>s", "Toggle Terminal Horizontal", "<cmd>ToggleTerm direction=horizontal<cr>")
nmap("<space><space>f", "Toggle Terminal Float", "<cmd>ToggleTerm direction=float<cr>")
nmap("<space><space>t", "Toggle Terminal Tab", "<cmd>ToggleTerm direction=tab<cr>")
nmap("<space><space>V", "New Terminal vertical", function()
  newterm("vertical")
end)
nmap("<space><space>S", "New Terminal Horizontal", function()
  newterm("horizontal")
end)
nmap("<space><space>F", "New Terminal Float", function()
  newterm("float")
end)
nmap("<space><space>T", "New Terminal Tab", function()
  newterm("tab")
end)

tmap(";j", "Esc", [[<C-\><C-n>]])
if vim.fn.has("mac") == 1 then
  tmap("<c-space>", "Esc", [[<C-\><C-n>]])
  tmap("<M-w>", "Wincmd", [[<C-\><C-n><C-w>]])
  tmap("∑", "Wincmd", [[<C-\><C-n><C-w>]])
  tmap("<M-h>", "WinCmd Left", [[<C-\><C-n><C-w>H]])
  tmap("˙", "WinCmd Left", [[<C-\><C-n><C-w>H]])
  tmap("<M-j>", "WinCmd Down", [[<C-\><C-n><C-w>J]])
  tmap("∆", "WinCmd Down", [[<C-\><C-n><C-w>J]])
  tmap("<M-k>", "WinCmd Up", [[<C-\><C-n><C-w>K]])
  tmap("˚", "WinCmd Up", [[<C-\><C-n><C-w>K]])
  tmap("<M-l>", "WinCmd Right", [[<C-\><C-n><C-w>L]])
  tmap("¬", "WinCmd Right", [[<C-\><C-n><C-w>L]])
else
  tmap("<A-space>", "Esc", [[<C-\><C-n>]])
  tmap("<A-w>", "Wincmd", [[<C-\><C-n><C-w>]])
  tmap("<A-h>", "WinCmd Left", [[<C-\><C-n><C-w>H]])
  tmap("<A-j>", "WinCmd Down", [[<C-\><C-n><C-w>J]])
  tmap("<A-k>", "WinCmd Up", [[<C-\><C-n><C-w>K]])
  tmap("<A-l>", "WinCmd Right", [[<C-\><C-n><C-w>L]])
end

--- notifications ------------------------------------------------------- {{{1
nmap("<leader>hN", "Redir Notifications", "<cmd>Redir Notifications<cr>")
nmap("<leader>hm", "Display messages", "<cmd>messages<cr>")
nmap("<leader>hM", "Redir messages", "<cmd>Redir messages<cr>")

-- format --------------------------------------------------------------- {{{1
imap("<localleader>w", "Format Line", "<esc>gqq}kA")
imap("<A-;>", "Format Line", "<esc>gqq}kA")

-- object --------------------------------------------------------------- {{{1
keymap({ "i", mode = { "x", "o" }, group = "Object: inner", icon = { icon = "", hl = "WhichKeyIconOrange" } })
keymap({ "a", mode = { "x", "o" }, group = "Object: outter", icon = { icon = "", hl = "WhichKeyIconOrange" } })
vimkey("iB", "Object: Buffer", "<cmd>call text_obj#Buffer()<cr>", { mode = { "x", "o" } })
vimkey("iu", "Object: URL", "<cmd>call text_obj#URL()<cr>", { mode = { "x", "o" } })
vimkey("il", "Object: current line", "^o$h", { mode = "x" })
vimkey("il", "Object: current line", "<cmd>normal vil<cr>", { mode = "o" })
vimkey("al", "Object: current line (with \\n)", "^o$", { mode = "x" })
vimkey("al", "Object: current line (with \\n)", "<cmd>normal val<cr>", { mode = "o" })
vimkey("ic", "Object: Markdown chunk", "<cmd>call text_obj#MdCodeBlock('i')", { mode = { "o", "x" } })
vimkey("ac", "Object: Markdown chunk", "<cmd>call text_obj#MdCodeBlock('a')", { mode = { "o", "x" } })

-- Translate ------------------------------------------------------------ {{{1
keymap({
  "<F4>",
  function()
    local trans_ok, trans = pcall(require, "translate")
    if not trans_ok or not trans then
      vim.notify("Failed to load module translate", vim.log.levels.ERROR)
      return
    end
    local current_mode = vim.api.nvim_get_mode().mode
    if current_mode == "n" then
      local toggle_re = trans.toggle()
      if toggle_re and toggle_re == 0 then
        trans.translate_line()
      end
    else
      trans.translate_selection()
    end
  end,
  mode = { "n", "v" },
  desc = "Translate",
})
vimkey("L", "Translate", function()
  local trans_ok, trans = pcall(require, "translate")
  if not trans_ok or not trans then
    vim.notify("Failed to load module translate", vim.log.levels.ERROR)
    return
  end
  trans.trans_op()
end, { mode = { "v", "n" } })
imap("<localleader>l", "Translate", function()
  local trans_ok, trans = pcall(require, "translate")
  if trans_ok and trans then
    trans.replace_line()
  end
end)
nmap("LL", "Translate", function()
  Snacks.input({ prompt = "Translate" }, function(value)
    if not value or value == "" then
      return
    end
    local trans_ok, trans = pcall(require, "translate")
    if trans_ok and trans then
      trans.translate_content(value)
    end
  end)
end)

-- File manager --------------------------------------------------------- {{{1
nmap("<leader>fs", "Save File", "<cmd>write<cr>")
nmap("<leader>fS", "Save File (force)", "<cmd>write!<cr>")

-- Picker --------------------------------------------------------------- {{{1
local picker = require("pickers")
nmap("<leader>sP", "System Clipboad", picker.clipcat)
nmap("<leader>hc", "CheatSheet: TL;DR", picker.cheat)
nmap("<leader>fz", "Jump with fasd", picker.fasd)
nmap("<leader>fq", "Open my library file", picker.mylib)
nmap("<leader>hs", "Stata help pages", picker.stata_doc)
keymap({
  "<leader>a/",
  picker.fabric,
  desc = "Fabric: clipboad as input",
  mode = { "n", "v" },
  icon = { icon = "", hl = "WhichKeyIconOrange" },
})
keymap({
  "<leader>ic",
  function()
    require("pickers").citation()
  end,
  desc = "Insert Citation Keys",
})
keymap({
  "<localleader>ic",
  function()
    require("pickers").citation()
  end,
  desc = "Insert Citation Keys",
  mode = { "i" },
})
