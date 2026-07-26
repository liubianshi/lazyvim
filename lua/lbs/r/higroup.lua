local M = {}
local ns_id = vim.api.nvim_create_namespace("roxygen_hl")
local debounce_timer = nil

-- 2. 重构后的高亮函数，可处理指定行范围
function M.highlight_roxygen_tags(buf, start_line, end_line)
  -- 清除指定范围内的旧高亮
  vim.api.nvim_buf_clear_namespace(buf, ns_id, start_line, end_line)

  local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)

  for i, line in ipairs(lines) do
    if line:match("^#'") then
      local line_nr = start_line + i - 1

      -- First, find and highlight all @tags
      local last_end = 1
      while true do
        local s, e = line:find("@%w+", last_end)
        if not s then
          break
        end
        vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, s - 1, {
          end_col = e,
          hl_group = "@keyword",
        })
        last_end = e + 1
      end

      -- Second, find and highlight all content within `backticks`
      last_end = 1
      while true do
        local s, e = line:find("`[^`]+`", last_end)
        if not s then
          break
        end
        vim.api.nvim_buf_set_extmark(buf, ns_id, line_nr, s - 1, {
          end_col = e,
          hl_group = "@function", -- Use a different group for backticked content
        })
        last_end = e + 1
      end
    end
  end
end

-- 3. 实现带防抖的、只扫描可见区域的调度函数
function M.schedule_viewport_highlight()
  if debounce_timer then
    debounce_timer:close()
  end

  debounce_timer = vim.uv.new_timer()
  if not debounce_timer then
    return
  end
  debounce_timer:start(150, 0, function()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      -- vim.fn.line('w0') 获取窗口可见区域的第一行行号
      local view_start = vim.fn.line("w0") - 1
      local view_end = vim.fn.line("w$")
      M.highlight_roxygen_tags(buf, view_start, view_end)
    end)
  end)
end

return M
