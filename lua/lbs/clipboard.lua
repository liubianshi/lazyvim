-- Clipboard provider decision.
--
-- Local sessions keep Neovim's own probe (wl-copy / xsel), which already works.
-- Remote sessions (SSH, with or without tmux) get an explicit provider:
--   * copy  -> OSC 52, so the yank lands in the *local* machine's clipboard;
--   * paste -> the unnamed register, because the OSC 52 read query blocks for
--              up to 10s on terminals that refuse to answer it.
--
-- Setting vim.g.clipboard hits the highest-priority branch of
-- $VIMRUNTIME/autoload/provider/clipboard.vim, bypassing the tool-existence
-- probe order that would otherwise pick lemonade / a forwarded $DISPLAY /
-- tmux load-buffer before ever reaching OSC 52.

local M = {}

-- SSH_TTY is only set for interactive sessions; SSH_CONNECTION / SSH_CLIENT
-- cover the rest.
local function is_remote()
  return (vim.env.SSH_TTY or vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT) ~= nil
end

-- Read back from the unnamed register instead of querying the terminal.
-- Returning { lines, regtype } (rather than bare lines) preserves blockwise
-- yanks; see the get() handler in clipboard.vim.
local function paste_fallback()
  return function()
    local info = vim.fn.getreginfo('"')
    return { info.regcontents or {}, info.regtype or "v" }
  end
end

function M.setup()
  if not is_remote() then
    return
  end

  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return
  end

  vim.g.clipboard = {
    name = "OSC 52 (copy) / local register (paste)",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = paste_fallback(),
      ["*"] = paste_fallback(),
    },
  }
end

return M
