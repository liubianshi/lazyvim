local M = {}

---@class ExtMarkOpts
---
---@field window? number 窗口编号 (可选, 默认当前窗口)。
---@field row? number 行号 (0-indexed) (可选, 默认当前光标行)。
---@field col? number 列号 (0-indexed) (可选, 默认当前光标列)。
---@field hl_group? string 用于虚拟文本的高亮组 (可选, 默认 "Comment")。
---@field namespace? string|number 用于 extmark 的命名空间 (可选, 默认 "virtual_text_above")。

--- 在指定位置上方或默认当前光标位置上方显示虚拟文本。
---@paramn ctx string 要显示的文本 (必需)。
---@param opts? ExtMarkOpts 位置选项表，包含以下字段 (如果为 nil 或空，则使用默认值):
---@return number | nil extmark 的 ID，如果 `content_opts.text` 未提供则返回 nil。
function M.show_virtual_text_above(ctx, opts)
  if not ctx then
    vim.notify("show_virtual_text_above: 'content_opts.text' is required", vim.log.levels.WARN)
    return nil
  end
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    hl_group = "Comment",
    namespace = "LBS_extmark",
    window = 0,
  })

  if opts.row == nil or opts.col == nil then
    local current_pos = vim.api.nvim_win_get_cursor(0) -- [row, col] 1-based
    opts.row = opts.row or current_pos[1] - 1 -- extmark 是 0-based
    opts.col = opts.col or current_pos[2] + 1 -- extmark 列号与光标列号一致
  end

  local ns_id
  if type(opts.namespace) == "string" then
    ---@diagnostic disable: param-type-mismatch
    ns_id = vim.api.nvim_create_namespace(opts.namespace)
  elseif type(opts.namespace) == "number" then
    ns_id = opts.namespace -- Assume it's a valid existing namespace ID
  else
    -- Fallback or error handling if needed
    ns_id = vim.api.nvim_create_namespace("virtual_text_above") -- Default namespace
  end

  -- 创建或更新 extmark
  local bufnr = vim.api.nvim_win_get_buf(opts.window)
  return vim.api.nvim_buf_set_extmark(bufnr, ns_id, opts.row, opts.col, {
    virt_text = { { ctx, opts.hl_group } }, -- 要显示的文本和高亮组
    virt_text_pos = "inline",
    hl_mode = "combine", -- 合并高亮
  })
end

return M
