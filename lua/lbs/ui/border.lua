-- 浮窗边框字符表生成。
local M = {}

function M.border(symbol, type, neovide, highlight)
  symbol = symbol or "═"
  type = type or "top"
  neovide = neovide or false
  highlight = highlight or "MyBorder"

  if vim.fn.exists("g:neovide") == 1 and not neovide then
    return "none"
  end

  if type == "top" then
    return { "", { symbol, highlight }, "", "", "", "", "", "" }
  elseif type == "bottom" then
    return { "", "", "", "", "", { symbol, highlight }, "", "" }
  elseif type == "left" then
    return { "", "", "", "", "", "", "", { symbol, highlight } }
  end
end

return M
