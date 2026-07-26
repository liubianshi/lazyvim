-- Zen 模式下的窗口尺寸编排：按 buffer 类型决定各窗口宽度与 signcolumn/foldcolumn。
-- autocmd 注册留在 config/autocmds.lua，这里只放计算逻辑。
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

  if vim.g.lbs_zen_mode then
    if ww <= 88 then
      vim.wo[win].signcolumn = "auto:1"
    elseif ww <= 100 then
      vim.wo[win].signcolumn = "yes:4"
    else
      vim.wo[win].signcolumn = "yes:" .. math.min(math.floor((ww - 81) / 4), 6)
    end
  elseif zen_oriwin and type(zen_oriwin) == "table" and zen_oriwin.zenmode then
    if ww <= 88 then
      vim.wo[win].signcolumn = "auto:1"
    elseif ww <= 100 then
      vim.wo[win].signcolumn = "yes:4"
    else
      vim.wo[win].signcolumn = "yes:" .. math.min(math.floor((ww - 81) / 4), 9)
    end
  else
    if ww <= 40 then
      vim.wo[win].signcolumn = "no"
      vim.wo[win].foldcolumn = "0"
    else
      vim.wo[win].signcolumn = "auto:1"
      vim.wo[win].foldcolumn = vim.o.foldcolumn
    end
  end
end

return M
