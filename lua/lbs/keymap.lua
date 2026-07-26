-- 键位注册。经由 which-key 的 add()，因此必须在 which-key setup 之后调用
-- 才会真正落地——add() 只入队，队列仅在 setup 时 flush 一次。
local M = {}

function M.keymap(mapping)
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add({ mapping })
    return
  end

  -- Fallback to native vim.keymap.set if which-key is not found.
  local lhs = mapping[1]
  local rhs = mapping[2]
  if not lhs or not rhs then
    return
  end

  -- Prepare options for vim.keymap.set
  local opts = {}
  for k, v in pairs(mapping) do
    if type(k) == "string" then
      opts[k] = v
    end
  end

  local mode = opts.mode or "n"
  opts.mode = nil -- Mode is a separate argument for vim.keymap.set
  opts = vim.tbl_deep_extend("keep", opts, { silent = true, remap = false })
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.wk_reg(mapping, opts)
  local wk_ok, wk = pcall(require, "which-key")
  if not wk_ok then
    return
  end
  wk.add(mapping, opts)
end

return M
