-- Neovim 启动引导
require("env").launch_writing_room()
require("config.lazy")
require("global_functions")
require("commands")

-- 绕过 Neovim _changetracking.lua 的 buf_state 竞态，实现与删除条件见 lbs/lsp.lua。
require("lbs.lsp").patch_changetracking()

-- 浮窗边框高亮：启动时设一次，之后随 colorscheme 与 GUI 变化同步。
local palette = require("lbs.ui.palette")
palette.setup_myborder_hl()
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("MyBorderHL", { clear = true }),
  callback = function()
    palette.adjust_hi_group()
    palette.setup_myborder_hl()
  end,
})
