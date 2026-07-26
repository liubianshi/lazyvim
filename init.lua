-- Neovim 启动引导
require("lbs.env").launch_writing_room()
require("config.lazy")
require("global_functions")
require("lbs.commands")

-- 浮窗边框高亮：随 colorscheme 与 GUI 变化同步。VimEnter 必然触发，
-- 启动期的首次设置由它承担，不必在这里再裸调一次。
local palette = require("lbs.ui.palette")
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("MyBorderHL", { clear = true }),
  callback = function()
    palette.adjust_hi_group()
    palette.setup_myborder_hl()
  end,
})
