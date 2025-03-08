-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

require("global_functions")
require("commands")
-- require("theme")

local bg_color = vim.api.nvim_get_hl(0, { name = "Pmenu" }).bg
if vim.fn.exists("g:neovide") == 1 then
  vim.api.nvim_set_hl(0, "MyBorder", { fg = bg_color, bg = bg_color })
else
  vim.api.nvim_set_hl(0, "MyBorder", { fg = vim.g.lbs_colors.orange, bg = bg_color })
end
