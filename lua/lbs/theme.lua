-- 终端背景色探测：把 OSC 11 回复换算成 dark/light，并开启 DEC 2031 主题变更上报。
-- autocmd 注册留在 config/autocmds.lua。
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

-- Opt in to DEC mode 2031 so Ghostty / modern Kitty actively report theme
-- changes via `CSI ?2031;1n` (dark) / `CSI ?2031;2n` (light). Written direct
-- to /dev/tty because io.write inside Neovim goes to :messages, not the TTY.
function M.enable_dec2031()
  local tty = io.open("/dev/tty", "w")
  if tty then
    tty:write("\27[?2031h")
    tty:close()
  end
end

function M.apply_background(bg)
  if not bg or bg == vim.o.background then
    return
  end
  vim.schedule(function()
    vim.o.background = bg
    local cs = (vim.g.default_colorscheme or {})[bg]
    if cs then
      pcall(vim.cmd.colorscheme, cs)
    end
    pcall(function()
      require("lualine").setup({})
    end)
  end)
end

return M
