-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
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
