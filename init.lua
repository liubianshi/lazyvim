-- Neovim startup optimization and highlight management
-- Bootstrap lazy.nvim, LazyVim, and plugins
require("env").launch_writing_room()
require("config.lazy")
require("global_functions")
require("commands")

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
  callback = setup_myborder_hl,
})


