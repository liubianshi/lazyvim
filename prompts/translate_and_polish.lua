local M = {}

M.get_content = function(context)
  local lines = vim.api.nvim_buf_get_lines(context.bufnr, context.start_line - 1, context.end_line, false)
  local grouped_strings = table.concat(require("util").join_strings_by_paragraph(lines), "\n")

  local head_chars = vim.trim(grouped_strings):sub(1, 20)
  local is_cjk = false
  for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
    local check = _G.is_cjk_character or function(c) return false end
    if check(char) then
      is_cjk = true
      break
    end
  end

  return string.format("%s\n\n%s", (is_cjk and "en_US" or "zh_CN"), grouped_strings)
end

return M
