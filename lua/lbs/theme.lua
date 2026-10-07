-- Detect terminal background changes through OSC 11 replies.
-- Autocommands are registered in config/autocmds.lua.
local M = {}

--- background ---------------------------------------------------------- {{{2
-- Translate an OSC 11 reply (`ESC ] 11 ; rgb:RRRR/GGGG/BBBB ...`) into
-- "dark" / "light" by perceived luminance — terminal-agnostic, replaces the
-- previous Kitty-only path that read $TERM_BACKGROUND_CACHE.
function M.osc11_to_background(sequence)
  local r, g, b = sequence:match("rgb:(%x+)/(%x+)/(%x+)")
  if not (r and g and b) then
    return nil
  end
  local function unit(hex)
    return tonumber(hex, 16) / (16 ^ #hex - 1)
  end
  local lum = 0.299 * unit(r) + 0.587 * unit(g) + 0.114 * unit(b)
  return lum > 0.5 and "light" or "dark"
end

-- DEC 2031 enables CSI ?997 notifications. Neovim's TUI consumes these and
-- queries OSC 11; only the resulting color reply reaches TermResponse.
-- Query once as well, since the startup reply can precede our autocmd.
function M.enable_dec2031()
  vim.api.nvim_ui_send("\27[?2031h\27]11;?\7")
end

function M.apply_background(bg)
  if bg ~= "dark" and bg ~= "light" then
    return
  end
  vim.schedule(function()
    local cs = (vim.g.default_colorscheme or {})[bg]
    -- Neovim may have updated background before this callback, without
    -- selecting our separate light/dark colorscheme. Check both values.
    if bg == vim.o.background and (not cs or cs == vim.g.colors_name) then
      return
    end
    vim.o.background = bg
    if cs then
      pcall(vim.cmd.colorscheme, cs)
    end
    pcall(function()
      require("lualine").setup({})
    end)
  end)
end

return M
