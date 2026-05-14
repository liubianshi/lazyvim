-- Neovim startup optimization and highlight management
-- Bootstrap lazy.nvim, LazyVim, and plugins
require("env").launch_writing_room()
require("config.lazy")
require("global_functions")
require("commands")

-- Workaround for Neovim 0.12.2 _changetracking.lua:352
-- 当 R.nvim 的 rnvimserver (r_ls) 与 air language server 同时 attach 同一个 R buffer
-- 时,两者 sync_kind 不同导致落入不同 group;其中一个 group 未走过 init()
-- 路径,state.buffers[bufnr] 为 nil,进入插入模式首次按键即崩。
-- 这里只吞带 "buf_state" 字样的错误,其它 LSP 异常照常抛出。
-- 上游若在 _changetracking.lua 加 nil-guard (预计 0.12.3+) 后,本块可删除。
do
  local ok, ct = pcall(require, "vim.lsp._changetracking")
  if ok and ct and ct.send_changes and not ct._buf_state_guard then
    local orig = ct.send_changes
    ct.send_changes = function(bufnr, firstline, lastline, new_lastline)
      local ok2, err = pcall(orig, bufnr, firstline, lastline, new_lastline)
      if not ok2 and type(err) == "string" and err:find("buf_state", 1, true) then
        return
      elseif not ok2 then
        error(err)
      end
    end
    ct._buf_state_guard = true
  end
end

-- Define and maintain a border highlight that adapts to the current colorscheme and GUI
local function setup_myborder_hl()
  local function get_hl_bg(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
    if ok and hl and hl.bg then
      return hl.bg
    end
    return nil
  end

  -- Try to read Pmenu background color; fallback to Normal, then to "NONE"
  local bg = get_hl_bg("Pmenu") or get_hl_bg("Normal") or "NONE"

  -- Foreground: in Neovide, make the border seamless; otherwise prefer configured orange, fallback to bg
  local fg = vim.fn.exists("g:neovide") ~= 1 and (vim.g.lbs_colors and vim.g.lbs_colors.orange) or bg

  -- Apply the highlight group
  vim.api.nvim_set_hl(0, "MyBorder", { fg = fg, bg = bg })
end

-- Initialize highlight once at startup
setup_myborder_hl()

-- Keep highlight in sync with colorscheme or GUI changes
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("MyBorderHL", { clear = true }),
  callback = function()
    require("util.ui").adjust_hi_group()
    setup_myborder_hl()
  end,
})
