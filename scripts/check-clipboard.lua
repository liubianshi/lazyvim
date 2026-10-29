-- Run from the repo root: nvim --headless -u NONE -l scripts/check-clipboard.lua
vim.opt.rtp:prepend(vim.fn.getcwd())

local clipboard = require("lbs.clipboard")
local env_keys = {
  "SSH_TTY",
  "SSH_CONNECTION",
  "SSH_CLIENT",
  "HERDR_ENV",
  "HERDR_PANE_ID",
  "TERM_PROGRAM",
  "ZMX_SESSION",
  "TMUX",
  "STY",
  "WAYLAND_DISPLAY",
  "DISPLAY",
  "XDG_RUNTIME_DIR",
}
local function reset_env()
  for _, key in ipairs(env_keys) do
    vim.env[key] = nil
  end
  vim.g.lbs_clipboard_mode = nil
end

-- Model the remote host's display socket and installed clipboard tools without
-- touching either the host's clipboard or the terminal client's clipboard.
rawset(vim.uv, "fs_stat", function(path)
  if path == "/clipboard-check/wayland-1" then
    return { type = "socket" }
  end
  return nil
end)
-- Replace the native function only for this test process.
---@diagnostic disable-next-line: duplicate-set-field
vim.fn.executable = function(cmd)
  return (cmd == "wl-copy" or cmd == "wl-paste") and 1 or 0
end
local function display_env()
  reset_env()
  vim.env.XDG_RUNTIME_DIR = "/clipboard-check"
  vim.env.WAYLAND_DISPLAY = "wayland-1"
end

display_env()
assert(clipboard.resolve() == "native", "ordinary desktop should use native clipboard")
for _, marker in ipairs({
  { "HERDR_ENV", "1" },
  { "HERDR_PANE_ID", "w1:p6" },
  { "TERM_PROGRAM", "herdr" },
}) do
  display_env()
  vim.env[marker[1]] = marker[2]
  assert(clipboard.resolve() == "osc52", marker[1] .. " must override a reachable host display")
end
display_env()
vim.env.SSH_CONNECTION = "192.0.2.1 1234 192.0.2.2 22"
assert(clipboard.resolve() == "osc52", "SSH should use terminal clipboard")
reset_env()
assert(clipboard.resolve() == "osc52", "headless host should use terminal clipboard")
display_env()
vim.env.HERDR_ENV = "1"
vim.g.lbs_clipboard_mode = "native"
assert(clipboard.resolve() == "native", "explicit native override should take precedence")
vim.g.lbs_clipboard_mode = nil

-- Preload a different provider to catch the bootstrap's early-return guard.
local stale_copies = 0
local stale_copy = function()
  stale_copies = stale_copies + 1
end
local stale_paste = function()
  return { { "stale" }, "v" }
end
vim.g.clipboard = {
  name = "stale provider",
  copy = { ["+"] = stale_copy, ["*"] = stale_copy },
  paste = { ["+"] = stale_paste, ["*"] = stale_paste },
}
vim.cmd("runtime autoload/provider/clipboard.vim")
local sent = {}
-- Replace the native function only for this test process.
---@diagnostic disable-next-line: duplicate-set-field
vim.api.nvim_ui_send = function(sequence)
  sent[#sent + 1] = sequence
end
clipboard.setup()
vim.o.clipboard = "unnamedplus"
local lines = { "中文 clipboard", "second line" }
vim.fn.setreg("+", lines, "V")
assert(stale_copies == 0, "provider reload must discard the previous copy handler")
assert(
  sent[1] == "\027]52;c;" .. vim.base64.encode(table.concat(lines, "\n") .. "\n") .. "\027\\",
  "copy should send the payload to the terminal clipboard: " .. vim.inspect(sent)
)
assert(vim.deep_equal(vim.fn.getreg("+", 1, true), lines), "paste should preserve copied text")
assert(vim.fn.getregtype("+") == "V", "paste should preserve linewise register type")
vim.fn.setreg("+", lines, "b")
assert(vim.fn.getregtype("+"):sub(1, 1) == "\022", "paste should preserve blockwise register type")
print("clipboard checks passed")
