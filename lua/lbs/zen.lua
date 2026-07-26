-- Zen 模式下的窗口尺寸编排：按 buffer 类型决定各窗口宽度与 signcolumn/foldcolumn。
-- autocmd 注册留在 config/autocmds.lua，这里放编排本身——注意它直接改写窗口选项、
-- 也会执行 :vertical resize，不是可以随处复用的纯计算。
local M = {}

function M.process_win(win)
  local winnr = vim.fn.win_id2win(win)
  if winnr == 0 then
    return
  end

  local ww = vim.api.nvim_win_get_width(win)
  local bufnr = vim.api.nvim_win_get_buf(win)
  local _, zen_oriwin = pcall(vim.api.nvim_buf_get_var, bufnr, "zen_oriwin")

  if vim.bo[bufnr].syntax == "rbrowser" then
    if ww <= 30 then
      return
    end
    vim.cmd("vertical " .. winnr .. "resize 30")
    return "break"
  end

  -- 两条 zen 路径的阈值完全相同，只有 signcolumn 上限不同（全局 zen 收到 6，
  -- 窗口自带 zen_oriwin.zenmode 的放到 9），合成一条，阈值只写一遍。
  local cap = (vim.g.lbs_zen_mode and 6) or (type(zen_oriwin) == "table" and zen_oriwin.zenmode and 9)
  if cap then
    vim.wo[win].signcolumn = (ww <= 88 and "auto:1")
      or (ww <= 100 and "yes:4")
      or ("yes:" .. math.min(math.floor((ww - 81) / 4), cap))
    return
  end

  local narrow = ww <= 40
  vim.wo[win].signcolumn = narrow and "no" or "auto:1"
  vim.wo[win].foldcolumn = narrow and "0" or vim.o.foldcolumn
end

return M
