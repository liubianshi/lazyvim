-- from: telegram neovim group @csm, adjusted with ai (codecompanion + gpt5)
-- region Yank
-- Enhanced yank/paste behavior with clipboard sync and yank-ring maintenance.
-- Goals:
--   - Preserve cursor position after yanking.
--   - Maintain a yank ring by shifting numbered registers (1-9).
--   - Conditionally sync the unnamed register to the system clipboard (+) shortly
--     before losing focus or exiting, but cancel if a paste happens within Neovim
--     or if the sync window expires.
--   - Be robust in environments without a clipboard provider.

-- Libuv timer (Neovim 0.10+: vim.uv; fallback to vim.loop for older versions)
local uv = vim.uv or vim.loop
local timer = assert(uv.new_timer())

-- Local augroup for this feature
local yank_group = vim.api.nvim_create_augroup("LBS_YankEnhancements", { clear = true })

-- Short alias for autocmd
local autocmd = vim.api.nvim_create_autocmd

-- Track cursor position prior to yank so it can be restored after yanking
local cursor_pre_yank

-- Track whether we should sync yanks to the system clipboard
local sync_yank = false

-- Helpers ---------------------------------------------------------------------

local function stop_timer()
  if timer and timer:is_active() then
    timer:stop()
  end
end

local function start_sync_window(ms)
  stop_timer()
  sync_yank = true
  timer:start(ms, 0, function()
    sync_yank = false
  end)
end

-- Check if the + register can be read (clipboard provider may be unavailable)
local function clipboard_available()
  local ok, _ = pcall(vim.fn.getreg, "+")
  return ok
end

-- Copy unnamed register ("") to system clipboard (+), preserving type
local function sync_to_system_clipboard()
  if not clipboard_available() then
    return
  end
  local info = vim.fn.getreginfo('"')
  -- setreg({regname}, {value}, {regtype})
  vim.fn.setreg("+", info.regcontents, info.regtype)
end

-- Copy system clipboard (+) to unnamed register ("), preserving type
local function sync_from_system_clipboard()
  if not clipboard_available() then
    return
  end
  local sys = vim.fn.getreg("+")
  local cur = vim.fn.getreg('"')
  if sys ~= cur then
    local info = vim.fn.getreginfo("+")
    vim.fn.setreg('"', info.regcontents, info.regtype)
  end
end

-- Keymaps ---------------------------------------------------------------------

-- Capture cursor before yanking, then forward the actual keys
for key, actual in pairs({ y = "y", Y = "y$" }) do
  vim.keymap.set({ "n", "x" }, key, function()
    cursor_pre_yank = vim.api.nvim_win_get_cursor(0)
    return actual
  end, {
    expr = true,
    silent = true,
    desc = "Record cursor before yank and forward to actual yank",
  })
end

-- On paste inside Neovim, cancel pending clipboard sync window
for _, key in ipairs({ "p", "P", "]p", "[p", "gp", "gP" }) do
  vim.keymap.set({ "n", "x" }, key, function()
    stop_timer()
    -- Cancel syncing to system clipboard if paste occurs inside Neovim
    sync_yank = false
    return key
  end, {
    expr = true,
    remap = true, -- honor default behavior of these paste keys
    silent = true,
    desc = "Paste and cancel pending system clipboard sync",
  })
end

-- Autocommands ----------------------------------------------------------------

autocmd("TextYankPost", {
  desc = "Yank improvements: highlight, restore cursor, yank ring, sync window",
  group = yank_group,
  callback = function()
    if vim.v.event.operator ~= "y" then
      return
    end

    -- Highlight yanked text
    vim.hl.on_yank()

    -- Restore cursor position after yanking
    if cursor_pre_yank then
      pcall(vim.api.nvim_win_set_cursor, 0, cursor_pre_yank)
      cursor_pre_yank = nil
    end

    -- Maintain a yank ring by shifting numbered registers (1..9)
    -- 9 <- 8 <- ... <- 1 <- 0
    for i = 9, 1, -1 do
      local src = tostring(i - 1)
      local info = vim.fn.getreginfo(src)
      vim.fn.setreg(tostring(i), info.regcontents, info.regtype)
    end

    -- Start a short window where we will sync to system clipboard
    -- unless the user pastes in Neovim or the window expires.
    start_sync_window(5000) -- 5 seconds
  end,
})

-- Sync to system clipboard on FocusLost if within sync window
autocmd("FocusLost", {
  desc = "Sync unnamed register to system clipboard on focus lost (if recent yank)",
  group = yank_group,
  callback = function()
    if sync_yank then
      sync_yank = false
      stop_timer()
      sync_to_system_clipboard()
    end
  end,
})

-- Final sync and timer cleanup on exit
autocmd("ExitPre", {
  desc = "Final clipboard sync and timer cleanup on exit",
  group = yank_group,
  callback = function()
    if sync_yank then
      sync_yank = false
      stop_timer()
      sync_to_system_clipboard()
    end
    -- Close the timer handle to avoid leaks
    if timer and not timer:is_closing() then
      pcall(timer.close, timer)
    end
  end,
})

-- Pull system clipboard into unnamed register on gain focus / startup
autocmd({ "FocusGained", "VimEnter" }, {
  desc = "Sync system clipboard to unnamed register",
  group = yank_group,
  callback = function()
    -- In case we switched from another Neovim instance, delay slightly
    vim.defer_fn(function()
      sync_from_system_clipboard()
    end, 200)
  end,
})

-- endregion
