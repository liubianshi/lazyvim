-- Neovim startup optimization and highlight management
-- Bootstrap lazy.nvim, LazyVim, and plugins
require("env").launch_writing_room()
require("config.lazy")
require("global_functions")
require("commands")

-- Define and maintain a border highlight that adapts to the current colorscheme and GUI
local function setup_myborder_hl()
  -- Try to read Pmenu background color; fallback to Normal if Pmenu is not defined
  local ok_pmenu, pmenu = pcall(vim.api.nvim_get_hl, 0, { name = "Pmenu" })
  local bg = ok_pmenu and pmenu and pmenu.bg or nil
  if not bg then
    local ok_norm, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })
    bg = ok_norm and normal and normal.bg or nil
  end

  -- Use "NONE" if no background could be determined
  if not bg then
    bg = "NONE"
  end

  -- Foreground: in Neovide, make the border seamless; otherwise prefer configured orange, fallback to bg
  local fg
  if vim.fn.exists("g:neovide") == 1 then
    fg = bg
  else
    fg = (vim.g.lbs_colors and vim.g.lbs_colors.orange) or bg
  end

  -- Apply the highlight group
  vim.api.nvim_set_hl(0, "MyBorder", { fg = fg, bg = bg })
end

-- Initialize highlight once at startup
setup_myborder_hl()

-- Keep highlight in sync with colorscheme or GUI changes
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("MyBorderHL", { clear = true }),
  callback = setup_myborder_hl,
})
