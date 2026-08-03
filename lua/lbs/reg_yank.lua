-- from: telegram neovim group @csm, adjusted with ai (codecompanion + gpt5)
-- region Yank
-- Maintains a yank ring by shifting the numbered registers (1-9) on every yank,
-- which Vim itself only does for multi-line yanks.
--
-- Deliberately *not* handled here:
--   * cursor / view restoration after a yank -> yanky's `preserve_cursor_position`
--     (on by default, and it restores the window view too);
--   * highlighting the yanked region -> yanky's `highlight.on_yank`, which is why
--     `lazyvim_highlight_yank` is deleted in config/autocmds.lua;
--   * clipboard synchronisation -> `clipboard=unnamedplus` plus the provider
--     chosen in `lbs.clipboard`.
--
-- Mapping `y` here used to shadow the lazy.nvim placeholder that loads yanky, so
-- yanky never loaded and its ring stayed empty. Leave `y` alone.

local yank_group = vim.api.nvim_create_augroup("LBS_YankEnhancements", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Shift numbered registers to keep a yank ring",
  group = yank_group,
  callback = function()
    if vim.v.event.operator ~= "y" then
      return
    end

    -- Fall back to the builtin highlight only when yanky is not around to do it.
    if not package.loaded["yanky"] then
      vim.hl.on_yank()
    end

    -- 9 <- 8 <- ... <- 1 <- 0
    for i = 9, 1, -1 do
      local src = tostring(i - 1)
      local info = vim.fn.getreginfo(src)
      vim.fn.setreg(tostring(i), info.regcontents, info.regtype)
    end
  end,
})

-- endregion
